"""Fails when a Hunter texture would ship above 2048 px (art/wardens/<id>/*.jpg|png, the images Godot extracts from
the glb). The game camera never shows 4K detail and each 4K texture costs about 11 MB in the pack, so a source over
2048 px needs `process/size_limit=2048` (or lower) in its .import. A new or replaced glb re-extracts its textures with
size_limit=0, so this runs in tools/check.sh. Fix: set Import > Process > Size Limit to 2048 and re-import.
Run: python3 tools/warden_tex_guard.py"""

import glob
import re
import struct
import sys

MAX_PX = 2048  # px: longest side a Hunter texture may ship at


def image_size(path):
    """(width, height) from the file header, stdlib only (CI has no Pillow)."""
    with open(path, "rb") as f:
        head = f.read(32)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
        if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
            kind = head[12:16]
            if kind == b"VP8X":
                return 1 + int.from_bytes(head[24:27], "little"), 1 + int.from_bytes(head[27:30], "little")
            if kind == b"VP8L":
                b = int.from_bytes(head[21:25], "little")
                return (b & 0x3FFF) + 1, ((b >> 14) & 0x3FFF) + 1
            if kind == b"VP8 ":
                w, h = struct.unpack("<HH", head[26:30])
                return w & 0x3FFF, h & 0x3FFF
        if head[:2] == b"\xff\xd8":
            f.seek(2)
            while True:
                byte = f.read(1)
                if not byte:
                    break
                if byte != b"\xff":
                    continue
                marker = f.read(1)
                while marker == b"\xff":
                    marker = f.read(1)
                if marker in (b"\xd8", b"\x01") or b"\xd0" <= marker <= b"\xd7":
                    continue
                seg_len = struct.unpack(">H", f.read(2))[0]
                if marker[0] in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    h, w = struct.unpack(">xHH", f.read(5))
                    return w, h
                f.seek(seg_len - 2, 1)
    raise ValueError(f"unreadable image header: {path}")


def main():
    bad = []
    imports = sorted(glob.glob("art/wardens/*/*.import"))
    for imp in imports:
        src = imp.removesuffix(".import")
        if not src.endswith((".jpg", ".png", ".webp")):
            continue
        side = max(image_size(src))
        m = re.search(r"^process/size_limit=(\d+)$", open(imp).read(), re.M)
        limit = int(m.group(1)) if m else 0
        if side > MAX_PX and not 0 < limit <= MAX_PX:
            bad.append(src)
            print(f"FAILED: {src} is {side} px with size_limit={limit}: set process/size_limit={MAX_PX} in its .import")
    print(f"warden_tex_guard: {len(imports)} hunter imports, {len(bad)} over {MAX_PX} px")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
