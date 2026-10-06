#!/usr/bin/env python3
"""Generate the release-time binary recipes for the prebuilt payload.

The prebuilt payload is produced by packaging/scripts/build-prebuilt.sh and
uploaded to the GitHub release, so its hash is only known at release time. These
recipes therefore cannot be rendered by render-recipes.py.

Formats:
    aur   -> PKGBUILD                     (AUR `veshell-bin`)
    rpm   -> veshell-bin.spec + changes   (OBS / COPR binary RPM)

Usage:
    packaging/scripts/gen-bin-recipes.py --format aur|rpm --prebuilt-sha SHA \\
        [--tag TAG] --out DIR
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "release.json"
SOURCE_REPO = "https://github.com/free-explorers/veshell"

# format -> [(template, output filename)]
FORMATS = {
    "aur": [("PKGBUILD-bin.in", "PKGBUILD")],
    "rpm": [
        ("veshell-bin.spec.in", "veshell-bin.spec"),
        ("veshell-bin.changes.in", "veshell-bin.changes"),
    ],
}


def load_renderer():
    spec = importlib.util.spec_from_file_location(
        "render_recipes", ROOT / "scripts" / "render-recipes.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", required=True, choices=sorted(FORMATS))
    parser.add_argument("--prebuilt-sha", required=True, help="sha256 of the prebuilt tarball")
    parser.add_argument("--tag", help="release tag (default: v<release-id>)")
    parser.add_argument("--out", required=True, type=Path, help="output directory")
    args = parser.parse_args()

    renderer = load_renderer()
    manifest = json.loads(MANIFEST.read_text())
    renderer.validate(manifest)
    tokens = renderer.build_tokens(manifest)

    release_id = tokens["RELEASE_ID"]
    tag = args.tag or f"v{release_id}"
    asset = f"veshell-{release_id}-x86_64.tar.zst"

    tokens["PREBUILT_URL"] = f"{SOURCE_REPO}/releases/download/{tag}/{asset}"
    tokens["PREBUILT_SHA256"] = args.prebuilt_sha
    tokens["TAG"] = tag

    args.out.mkdir(parents=True, exist_ok=True)
    for template_name, output_name in FORMATS[args.format]:
        template = ROOT / "templates" / template_name
        if not template.is_file():
            renderer.fail(f"missing template: {template}")
        rendered = renderer.render(template.read_text(), tokens, str(template))
        (args.out / output_name).write_text(rendered)
        print(f"wrote {args.out / output_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
