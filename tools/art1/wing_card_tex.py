"""wing_card_tex.py PAIR.png OUT.png: a Gemini cut-out of the two wings on pure black (Meeko r3, wing3/w1a) into the left wing's
RGBA card texture (alpha from the brightest channel; the clear pixels take the nearby wing colour, no dark mip fringe), 1024 px.
v95_swap.py `wing_cards` skins it to wing.L / wing.R (mirrored by the card); the game's `card-wing` slot draws it see-through."""
import sys

import cv2
import numpy as np
from PIL import Image

LEFT_WING = (slice(40, 830), slice(30, 575))      # (rows, cols) of the left wing in the 1136 x 944 pair
SIZE = 1024


def main(src, out):
    a = np.asarray(Image.open(src).convert("RGB"), np.float32)[LEFT_WING] / 255
    m = a.max(2)
    t = np.clip((m - 0.07) / 0.62, 0, 1)
    alpha = np.clip(t * t * (3 - 2 * t) * 0.9, 0, 1)
    col = np.clip(a / np.maximum(m[..., None], 1e-3) * np.clip(m[..., None] * 1.25 + 0.25, 0, 1), 0, 1)   # hue kept, brightness lifted
    near = cv2.GaussianBlur(col * alpha[..., None], (0, 0), 9) / np.maximum(cv2.GaussianBlur(alpha, (0, 0), 9)[..., None], 1e-3)
    w = np.clip(alpha * 4, 0, 1)[..., None]
    col = col * w + near * (1 - w)
    im = Image.fromarray((np.dstack([col, alpha]) * 255).astype(np.uint8), "RGBA")
    k = SIZE / max(im.size)
    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card.paste(im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS), (0, 0))
    card.save(out)
    print(out, card.size)


if __name__ == "__main__":
    main(*sys.argv[1:3])
