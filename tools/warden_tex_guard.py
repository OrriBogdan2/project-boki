"""Fails when a Hunter texture would ship above 2048 px (art/wardens/<id>/*.jpg|png, the images Godot extracts from
the glb). The game camera never shows 4K detail and each 4K texture costs about 11 MB in the pack, so a source over
2048 px needs `process/size_limit=2048` (or lower) in its .import. A new or replaced glb re-extracts its textures with
size_limit=0, so this runs in tools/check.sh. Fix: set Import > Process > Size Limit to 2048 and re-import.
Run: python3 tools/warden_tex_guard.py"""

import glob
import re
import sys

from PIL import Image

MAX_PX = 2048  # px: longest side a Hunter texture may ship at


def main():
    bad = []
    imports = sorted(glob.glob("art/wardens/*/*.import"))
    for imp in imports:
        src = imp.removesuffix(".import")
        if not src.endswith((".jpg", ".png", ".webp")):
            continue
        with Image.open(src) as im:
            side = max(im.size)
        m = re.search(r"^process/size_limit=(\d+)$", open(imp).read(), re.M)
        limit = int(m.group(1)) if m else 0
        if side > MAX_PX and not 0 < limit <= MAX_PX:
            bad.append(src)
            print(f"FAILED: {src} is {side} px with size_limit={limit}: set process/size_limit={MAX_PX} in its .import")
    print(f"warden_tex_guard: {len(imports)} hunter imports, {len(bad)} over {MAX_PX} px")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
