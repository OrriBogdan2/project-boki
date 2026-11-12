"""Lays frame strips out as one review sheet: a row per strip, its label at the left, the frames in order.
Run: python3 tools/art1/strip_sheet.py <out.jpg> <label>=<dir-of-fNNN.png> [<label>=<dir> ...] [--every=N] [--h=160]"""
import glob
import sys

from PIL import Image, ImageDraw

LABEL_W = 110


def main(argv):
    out, rows, every, h = argv[0], [], 1, 160
    for a in argv[1:]:
        if a.startswith("--every="):
            every = int(a[8:])
        elif a.startswith("--h="):
            h = int(a[4:])
        else:
            label, d = a.split("=", 1)
            rows.append((label, sorted(glob.glob(d + "/f*.png"))[::every]))
    cols = max(len(r[1]) for r in rows)
    sheet = Image.new("RGB", (LABEL_W + cols * h, len(rows) * h), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    for r, (label, frames) in enumerate(rows):
        draw.text((6, r * h + 6), label, fill=(235, 235, 235))
        for c, f in enumerate(frames):
            im = Image.open(f).convert("RGB")
            im = im.resize((h, h)) if im.size != (h, h) else im
            sheet.paste(im, (LABEL_W + c * h, r * h))
            draw.text((LABEL_W + c * h + 3, r * h + h - 14), f.rsplit("/", 1)[1][:-4], fill=(200, 200, 200))
    sheet.save(out, quality=82)
    print(out, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1:])
