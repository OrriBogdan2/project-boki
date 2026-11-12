#!/usr/bin/env python3
"""Makes the full-size painted art the title and loading screens show, and the boot splash.

Every piece in content/rules/splash_gallery.json names the approved file it is made from ("src"). A
"briefs/..." source is read from the ext/agent-briefs branch with git (no checkout needed), cut to 16:9
around its centre (never stretched), resized with Lanczos to SIZE and written as a high-quality JPEG. A
"site:..." source (a Bokidex hero cutout from the projectboki.com repo) is committed as it is.

The boot splash (art/splash.png) is the wordmark at its own size, centred on a clear SIZE canvas: the boot
screen (stretch mode Keep) and ScreenFade then show it at the same share of any window, pixel for pixel
on a 1440p one.

    python3 tools/splash_art.py                   # every piece and the boot splash
    python3 tools/splash_art.py --only=thief_perch.jpg,keyart_egg.jpg
    python3 tools/splash_art.py --briefs=<git ref of the briefs branch>
"""
import json
import subprocess
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GALLERY = ROOT / "content/rules/splash_gallery.json"
SIZE = (2560, 1440)    # px: 16:9, pixel for pixel on a 1440p screen, mipmapped down for smaller ones
QUALITY = 90           # JPEG quality with full-resolution colour (4:4:4): no banding, no soft red edges
WORDMARK = ROOT / "art/brand/logo_wordmark.png"
BOOT_SPLASH = ROOT / "art/splash.png"


def res_to_path(res: str) -> Path:
    return ROOT / res.removeprefix("res://")


def read_briefs(ref: str, path: str) -> Image.Image:
    blob = subprocess.run(["git", "-C", str(ROOT), "show", f"{ref}:{path}"], capture_output=True, check=True)
    return Image.open(BytesIO(blob.stdout))


def cut_to_size(img: Image.Image) -> Image.Image:
    """The biggest 16:9 window around the image's centre, resized to SIZE."""
    width, height = img.size
    keep_w = min(width, height * SIZE[0] // SIZE[1])
    keep_h = min(height, width * SIZE[1] // SIZE[0])
    left, top = (width - keep_w) // 2, (height - keep_h) // 2
    return img.convert("RGB").crop((left, top, left + keep_w, top + keep_h)).resize(SIZE, Image.LANCZOS)


def write_boot_splash() -> None:
    logo = Image.open(WORDMARK).convert("RGBA")
    canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(logo, ((SIZE[0] - logo.width) // 2, (SIZE[1] - logo.height) // 2))
    canvas.save(BOOT_SPLASH, optimize=True)
    print(f"splash_art: {WORDMARK.relative_to(ROOT)} -> {BOOT_SPLASH.relative_to(ROOT)}")


def main() -> None:
    ref = "origin/ext/agent-briefs"
    only: list[str] = []
    for arg in sys.argv[1:]:
        if arg.startswith("--briefs="):
            ref = arg.removeprefix("--briefs=")
        elif arg.startswith("--only="):
            only = arg.removeprefix("--only=").split(",")
    for piece in json.loads(GALLERY.read_text())["art"]:
        out = res_to_path(piece["file"])
        if not piece["src"].startswith("briefs/") or (only and out.name not in only):
            continue
        cut_to_size(read_briefs(ref, piece["src"])).save(out, quality=QUALITY, subsampling=0, optimize=True)
        print(f"splash_art: {piece['src']} -> {out.relative_to(ROOT)}")
    if not only:
        write_boot_splash()


if __name__ == "__main__":
    main()
