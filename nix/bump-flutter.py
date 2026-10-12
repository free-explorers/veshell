#!/usr/bin/env python3
"""bump-flutter.py - resolve a new Flutter version's provenance for the app.

Given a Flutter release version and the Nix hashes the workflow probed, it
downloads and hashes the upstream artifacts and writes the entries in
nix/flutter-artifacts.json (URLs + sha256, owned by this repository) and
nix/flutter-sdk.json (the Nix inputs for building the SDK), and sets
package.metadata.flutter_version in Cargo.toml.

The engine revision, Dart version and archive URL come straight from Flutter's
release metadata; the sha256 values are fetched; the Nix hashes are supplied by
the caller (`nix/flutter-sdk-update.nix` probes) so this stays pure Python.

Usage:
  bump-flutter.py --version 3.50.0 --channel stable \
      --flutter-hash SHA --dart-hash SHA \
      --artifact-hash-universal SHA --artifact-hash-linux SHA \
      --tools-lock-hash SHA --engine-sha256 HEX
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASES = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
INFRA = "https://storage.googleapis.com/flutter_infra_release"
ENGINE_REPO = "free-explorers/flutter-engine"


def fail(message: str) -> "NoReturn":  # noqa: F821
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def sha256_url(url: str) -> str:
    print(f"  hashing {url.rsplit('/', 1)[-1]} ...")
    return hashlib.sha256(fetch(url)).hexdigest()


def artifact_urls(engine_revision: str) -> dict[str, str]:
    return {
        "patched_sdk": f"{INFRA}/flutter/{engine_revision}/flutter_patched_sdk.zip",
        "patched_sdk_product": f"{INFRA}/flutter/{engine_revision}/flutter_patched_sdk_product.zip",
        "linux_x64_artifacts": f"{INFRA}/flutter/{engine_revision}/linux-x64/artifacts.zip",
        "linux_x64_debug_gtk": f"{INFRA}/flutter/{engine_revision}/linux-x64-debug/linux-x64-flutter-gtk.zip",
        "linux_x64_profile_gtk": f"{INFRA}/flutter/{engine_revision}/linux-x64-profile/linux-x64-flutter-gtk.zip",
        "linux_x64_release_gtk": f"{INFRA}/flutter/{engine_revision}/linux-x64-release/linux-x64-flutter-gtk.zip",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", required=True)
    parser.add_argument("--channel", default="stable", choices=["stable", "beta", "dev"])
    parser.add_argument("--flutter-hash", required=True, help="nix hash (SRI) of the Flutter SDK source")
    parser.add_argument("--dart-hash", required=True, help="nix hash (SRI) of the bootstrap Dart SDK")
    parser.add_argument("--artifact-hash-universal", required=True)
    parser.add_argument("--artifact-hash-linux", required=True)
    parser.add_argument("--tools-lock-hash", required=True)
    parser.add_argument("--engine-sha256", required=True, help="sha256 (hex) of the published engine tarball")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    version = args.version
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        fail(f"version must be x.y.z, got {version!r}")

    data = json.loads(fetch(RELEASES))
    release = next((r for r in data["releases"] if r.get("version") == version and r.get("channel") == args.channel), None)
    if release is None:
        fail(f"no {args.channel} release {version} in releases_linux.json")

    archive = release["archive"]
    sdk = {"url": f"{INFRA}/releases/{archive}", "sha256": release["sha256"]}
    engine_revision = fetch(f"https://raw.githubusercontent.com/flutter/flutter/{version}/bin/internal/engine.version").decode().strip()
    if not re.fullmatch(r"[0-9a-f]{40}", engine_revision):
        fail(f"engine.version at {version} is not a revision: {engine_revision!r}")
    dart_version = release["dart_sdk_version"]

    urls = artifact_urls(engine_revision)
    artifacts = {}
    for name, url in urls.items():
        artifacts[name] = {"url": url, "sha256": sha256_url(url)}

    engine_asset = f"linux-engine-sdk-release-x86_64-{engine_revision}"
    engine = {
        "url": f"https://github.com/{ENGINE_REPO}/releases/download/{engine_asset}/{engine_asset}.tar.gz",
        "sha256": args.engine_sha256,
    }

    flutter_entry = {"channel": args.channel, "sdk": sdk, "artifacts": artifacts, "engine": engine}
    sdk_entry = {
        "engineVersion": engine_revision,
        "flutterHash": args.flutter_hash,
        "dartVersion": dart_version,
        "dartHash": {"x86_64-linux": args.dart_hash},
        "artifactHashes": {
            "universal": {"x86_64-linux": args.artifact_hash_universal},
            "linux": {"x86_64-linux": args.artifact_hash_linux},
        },
        "toolsLockHash": args.tools_lock_hash,
    }

    if args.dry_run:
        print(json.dumps({"flutter": {version: flutter_entry}, "sdk": {version: sdk_entry}}, indent=2))
        return 0

    for name, key, value in (("nix/flutter-artifacts.json", version, flutter_entry), ("nix/flutter-sdk.json", version, sdk_entry)):
        path = ROOT / name
        existing = json.loads(path.read_text()) if path.is_file() else {}
        existing[key] = value
        path.write_text(json.dumps(dict(sorted(existing.items())), indent=2, ensure_ascii=False) + "\n")
        print(f"wrote {name}: {version}")

    cargo = ROOT / "Cargo.toml"
    text = cargo.read_text()
    updated, count = re.subn(r'(?m)^(flutter_version\s*=\s*)"[^"]*"', rf'\g<1>"{version}"', text)
    if count != 1:
        fail("could not find package.metadata.flutter_version in Cargo.toml")
    cargo.write_text(updated)
    print(f"wrote Cargo.toml: flutter_version = {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
