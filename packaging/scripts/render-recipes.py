#!/usr/bin/env python3
"""Render the distribution packaging recipes from the release manifest.

packaging/release.json is the single source of truth. This script validates it,
computes the per-distro version strings, and renders packaging/templates/ into
packaging/arch/, packaging/fedora/ and packaging/debian/. Rendered files carry a
"do not edit" header.

Usage:
    packaging/scripts/render-recipes.py [--check] [MANIFEST]

With --check nothing is written; the script exits non-zero if any rendered file
is out of date. It is meant to run in CI and before commits.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = ROOT / "release.json"

HELPER = ROOT / "scripts" / "build-veshell.sh"
RECIPES = ("arch", "fedora", "debian")

# template -> rendered output (both relative to packaging/)
RENDER_PAIRS = {
    "templates/PKGBUILD.in": "arch/PKGBUILD",
    "templates/veshell.spec.in": "fedora/veshell.spec",
    "templates/debian/changelog.in": "debian/debian/changelog",
    "templates/debian/rules.in": "debian/debian/rules",
}

TOKEN_RE = re.compile(r"@([A-Z][A-Z0-9_]*)@")

WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
PRERELEASE_RE = re.compile(r"^[A-Za-z0-9.]+$")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$")


def fail(message: str) -> "NoReturn":  # noqa: F821
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(obj: dict, path: str, kind: type, pattern: re.Pattern | None = None):
    node = obj
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            fail(f"manifest: missing {path}")
        node = node[part]
    if not isinstance(node, kind):
        fail(f"manifest: {path} must be {kind.__name__}")
    if pattern is not None and not pattern.match(node):
        fail(f"manifest: {path} does not match {pattern.pattern}")
    return node


def validate(manifest: dict) -> None:
    if manifest.get("schema") != 1:
        fail("manifest: schema must be 1")
    require(manifest, "name", str)
    require(manifest, "version", str, VERSION_RE)
    prerelease = manifest.get("prerelease")
    if prerelease is not None and (not isinstance(prerelease, str) or not PRERELEASE_RE.match(prerelease)):
        fail("manifest: prerelease must be null or a beta.N/rc.N style string")
    if manifest.get("channel") not in ("beta", "stable"):
        fail("manifest: channel must be beta or stable")
    require(manifest, "date", str, DATE_RE)
    require(manifest, "commit", str, COMMIT_RE)
    require(manifest, "maintainer", str)
    if not str(manifest.get("polkit_helper", "")).startswith("/"):
        fail("manifest: polkit_helper must be an absolute path")
    for key in ("source", "inputs"):
        value = require(manifest, f"mirrors.{key}", str)
        if not value.startswith("https://"):
            fail(f"manifest: mirrors.{key} must be an https URL")
    require(manifest, "flutter.version", str, VERSION_RE)
    require(manifest, "flutter.channel", str)
    require(manifest, "flutter.engine_revision", str, COMMIT_RE)
    for path in (
        "flutter.sdk",
        "flutter.engine",
        "flutter.artifacts.patched_sdk",
        "flutter.artifacts.patched_sdk_product",
        "flutter.artifacts.linux_x64_artifacts",
        "flutter.artifacts.linux_x64_debug_gtk",
        "flutter.artifacts.linux_x64_profile_gtk",
        "flutter.artifacts.linux_x64_release_gtk",
    ):
        url = require(manifest, f"{path}.url", str)
        if not url.startswith("https://"):
            fail(f"manifest: {path}.url must be an https URL")
        require(manifest, f"{path}.sha256", str, SHA256_RE)
    require(manifest, "inputs.cargo_vendor.sha256", str, SHA256_RE)
    require(manifest, "inputs.pubcache.sha256", str, SHA256_RE)


def helper_sha256() -> str:
    if not HELPER.is_file():
        fail(f"missing shared build helper: {HELPER}")
    digest = hashlib.sha256(HELPER.read_bytes()).hexdigest()
    for recipe in RECIPES:
        copy = ROOT / recipe / "build-veshell.sh"
        if not copy.is_file() or copy.read_bytes() != HELPER.read_bytes():
            fail(
                f"{recipe}/build-veshell.sh differs from scripts/build-veshell.sh; "
                "run packaging/scripts/sync-helpers.sh"
            )
    return digest


def build_tokens(manifest: dict) -> dict[str, str]:
    version = manifest["version"]
    prerelease = manifest.get("prerelease") or ""
    if prerelease:
        release_id = f"{version}-{prerelease}"
        sanitized = prerelease.replace(".", "").replace("-", "")
        arch_pkgver = f"{version}{sanitized}"
        rpm_release = f"0.1.{sanitized}"
        deb_version = f"{version}~{prerelease}-1"
    else:
        release_id = version
        arch_pkgver = version
        rpm_release = "1"
        deb_version = f"{version}-1"

    when = datetime.fromisoformat(manifest["date"].replace("Z", "+00:00")).astimezone(timezone.utc)
    date_rfc2822 = (
        f"{WEEKDAYS[when.weekday()]}, {when.day:02d} {MONTHS[when.month - 1]} {when.year:04d} "
        f"{when.hour:02d}:{when.minute:02d}:{when.second:02d} +0000"
    )
    date_rpm = f"{WEEKDAYS[when.weekday()]} {MONTHS[when.month - 1]} {when.day:02d} {when.year:04d}"

    flutter = manifest["flutter"]
    artifacts = flutter["artifacts"]
    tokens = {
        "NAME": manifest["name"],
        "VERSION": version,
        "RELEASE_ID": release_id,
        "PRERELEASE": prerelease,
        "CHANNEL": manifest["channel"],
        "COMMIT": manifest["commit"],
        "SHORTCOMMIT": manifest["commit"][:7],
        "MAINTAINER": manifest["maintainer"],
        "DATE_RFC2822": date_rfc2822,
        "DATE_RPM": date_rpm,
        "ARCH_PKGVER": arch_pkgver,
        "ARCH_PKGREL": "1",
        "RPM_VERSION": version,
        "RPM_RELEASE": rpm_release,
        "DEB_VERSION": deb_version,
        "SOURCE_MIRROR": manifest["mirrors"]["source"],
        "INPUT_MIRROR": manifest["mirrors"]["inputs"],
        "POLKIT_HELPER": manifest["polkit_helper"],
        "FLUTTER_VERSION": flutter["version"],
        "FLUTTER_CHANNEL": flutter["channel"],
        "FLUTTER_ENGINE_REVISION": flutter["engine_revision"],
        "FLUTTER_SDK_URL": flutter["sdk"]["url"],
        "FLUTTER_SDK_SHA256": flutter["sdk"]["sha256"],
        "ENGINE_URL": flutter["engine"]["url"],
        "ENGINE_SHA256": flutter["engine"]["sha256"],
        "CARGO_VENDOR_SHA256": manifest["inputs"]["cargo_vendor"]["sha256"],
        "PUBCACHE_SHA256": manifest["inputs"]["pubcache"]["sha256"],
        "BUILD_SCRIPT_SHA256": helper_sha256(),
    }
    for key, token in (
        ("patched_sdk", "FLUTTER_PATCHED_SDK"),
        ("patched_sdk_product", "FLUTTER_PATCHED_SDK_PRODUCT"),
        ("linux_x64_artifacts", "FLUTTER_LINUX_X64_ARTIFACTS"),
        ("linux_x64_debug_gtk", "FLUTTER_LINUX_X64_DEBUG_GTK"),
        ("linux_x64_profile_gtk", "FLUTTER_LINUX_X64_PROFILE_GTK"),
        ("linux_x64_release_gtk", "FLUTTER_LINUX_X64_RELEASE_GTK"),
    ):
        tokens[f"{token}_URL"] = artifacts[key]["url"]
        tokens[f"{token}_SHA256"] = artifacts[key]["sha256"]
    return tokens


def render(text: str, tokens: dict[str, str], label: str) -> str:
    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in tokens:
            fail(f"{label}: unknown token @{key}@")
        return tokens[key]

    return TOKEN_RE.sub(replace, text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manifest", nargs="?", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--check", action="store_true", help="verify rendered files are up to date")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        fail(f"manifest not found: {manifest_path}")

    manifest = json.loads(manifest_path.read_text())
    validate(manifest)
    tokens = build_tokens(manifest)

    out_of_date = []
    for tpl_rel, out_rel in RENDER_PAIRS.items():
        tpl = ROOT / tpl_rel
        out = ROOT / out_rel
        if not tpl.is_file():
            fail(f"missing template: {tpl_rel}")
        rendered = render(tpl.read_text(), tokens, tpl_rel)
        if args.check:
            if not out.is_file() or out.read_text() != rendered:
                out_of_date.append(out_rel)
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(rendered)
        # debian/rules must stay executable; the templates are not.
        out.chmod(0o755 if out_rel.endswith("debian/rules") else 0o644)
        print(f"rendered {out_rel}")

    if args.check:
        if out_of_date:
            print("recipes out of date with %s:" % manifest_path.relative_to(ROOT), file=sys.stderr)
            for rel in out_of_date:
                print(f"  {rel}", file=sys.stderr)
            print("run packaging/scripts/render-recipes.py", file=sys.stderr)
            return 1
        print(f"recipes are up to date with {manifest_path.relative_to(ROOT)}")
        return 0

    print(f"manifest: {manifest_path.relative_to(ROOT)} "
          f"({tokens['CHANNEL']}, release {tokens['RELEASE_ID']})")

    if shutil.which("makepkg"):
        subprocess.run(
            ["makepkg", "--printsrcinfo"],
            cwd=ROOT / "arch",
            stdout=(ROOT / "arch" / ".SRCINFO").open("w"),
            check=True,
        )
        print("regenerated arch/.SRCINFO")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
