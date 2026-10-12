#!/usr/bin/env python3
"""probe-sdk-hashes.py - resolve the Nix SDK pins for a Flutter version.

The Nix build needs four hashes nixpkgs' `mkFlutter` cannot derive: the Flutter
SDK tarball, the bootstrap Dart SDK, the per-platform artifact sets (which
nixpkgs produces by running the Flutter tool), and the Flutter tools pubspec.lock.
Each is a fixed-output hash, so none of them can be computed by a plain fetch --
the hash *is* the input. This seeds the pin with `lib.fakeHash`, builds the
corresponding derivation, reads the real value back from the mismatch, and
repeats, then regenerates nix/flutter-tools-lock.json.

Run inside `nix shell nixpkgs#yq nixpkgs#jq` (it shells out to nix and yq).

Usage: nix/probe-sdk-hashes.py --version 3.50.0 --engine-version <rev> --dart-version 3.14.0
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAKE = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
SYSTEM = "x86_64-linux"
PIN = ROOT / "nix" / "flutter-sdk.json"
TOOLS_LOCK = ROOT / "nix" / "flutter-tools-lock.json"
PRELUDE = ("let f = builtins.getFlake (toString ./.); "
           "p = f.inputs.nixpkgs.legacyPackages." + SYSTEM + "; ")
HELPER = "import ./nix/flutter-sdk-update.nix { pkgs = p; %s }"


def fail(message: str) -> "NoReturn":  # noqa: F821
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load() -> dict:
    return json.loads(PIN.read_text())


def save(data: dict) -> None:
    PIN.write_text(json.dumps(dict(sorted(data.items())), indent=2, ensure_ascii=False) + "\n")


def build(expr: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", PRELUDE + "in " + expr],
        capture_output=True, text=True,
    )


def mismatched(result: subprocess.CompletedProcess) -> tuple[str, str] | None:
    if result.returncode == 0:
        return None
    match = re.search(r"hash mismatch in fixed-output derivation '[^']*/([^/']+?)(?:\.drv)?':", result.stderr)
    value = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", result.stderr)
    if not value:
        return None
    return (match.group(1) if match else "", value.group(1))


def resolve(expr: str, setter, label: str) -> None:
    for _ in range(10):
        result = build(expr)
        if result.returncode == 0:
            print(f"  {label}: resolved")
            return
        found = mismatched(result)
        if found is None:
            fail(f"{label}: build failed without a usable hash mismatch\n{result.stderr[-2000:]}")
        name, value = found
        setter(name, value)
    fail(f"{label}: still unresolved after 10 attempts")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", required=True)
    parser.add_argument("--engine-version", required=True)
    parser.add_argument("--dart-version", required=True)
    args = parser.parse_args()

    for tool in ("nix", "yq", "jq"):
        if shutil.which(tool) is None:
            fail(f"missing {tool}; run inside `nix shell nixpkgs#yq nixpkgs#jq`")

    # Cargo.toml must name the new version: flutter.nix asserts it against the SDK.
    cargo = ROOT / "Cargo.toml"
    cargo.write_text(re.sub(r'(?m)^(flutter_version\s*=\s*)"[^"]*"', rf'\g<1>"{args.version}"', cargo.read_text()))

    data = load()
    data[args.version] = {
        "engineVersion": args.engine_version,
        "flutterHash": FAKE,
        "dartVersion": args.dart_version,
        "dartHash": {SYSTEM: FAKE},
        "artifactHashes": {"universal": {SYSTEM: FAKE}, "linux": {SYSTEM: FAKE}},
        "toolsLockHash": FAKE,
    }
    save(data)

    def set_flutter(_name: str, value: str) -> None:
        data = load(); data[args.version]["flutterHash"] = value; save(data)

    def set_dart(_name: str, value: str) -> None:
        data = load(); data[args.version]["dartHash"][SYSTEM] = value; save(data)

    def set_tools_lock(_name: str, value: str) -> None:
        data = load(); data[args.version]["toolsLockHash"] = value; save(data)

    def set_artifact(name: str, value: str) -> None:
        match = re.search(r"flutter-artifacts-(universal|linux)-", name)
        if match is None:
            fail(f"unexpected artifact derivation: {name}")
        data = load(); data[args.version]["artifactHashes"][match.group(1)][SYSTEM] = value; save(data)

    print("resolving the Flutter SDK hash")
    resolve(f"(import ./nix/flutter-sdk-update.nix {{ pkgs = p; }}).source", set_flutter, "flutterHash")
    print("resolving the bootstrap Dart hash")
    resolve(f"(import ./nix/flutter-sdk-update.nix {{ pkgs = p; }}).dart", set_dart, "dartHash")
    print("resolving the Flutter tools lock hash")
    resolve(f"(import ./nix/flutter-sdk-update.nix {{ pkgs = p; lockHash = p.lib.fakeHash; }}).toolsLock",
            set_tools_lock, "toolsLockHash")
    print("resolving the artifact hashes")
    resolve(f"(import ./nix/flutter-sdk-update.nix {{ pkgs = p; }}).artifacts", set_artifact, "artifactHashes")

    print("regenerating nix/flutter-tools-lock.json")
    result = build(f"(import ./nix/flutter-sdk-update.nix {{ pkgs = p; }}).toolsLock")
    if result.returncode != 0:
        fail(f"could not build the tools lock\n{result.stderr[-2000:]}")
    lock = Path(result.stdout.strip())
    slurped = subprocess.run(["yq", "-s", ".", str(lock)], capture_output=True, text=True, check=True)
    rendered = subprocess.run(["jq", "-S", ".[0]"], input=slurped.stdout, capture_output=True, text=True, check=True)
    TOOLS_LOCK.write_text(rendered.stdout if rendered.stdout.endswith("\n") else rendered.stdout + "\n")

    entry = load()[args.version]
    print(json.dumps({
        "flutterHash": entry["flutterHash"],
        "dartHash": entry["dartHash"][SYSTEM],
        "artifactHashes": entry["artifactHashes"],
        "toolsLockHash": entry["toolsLockHash"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
