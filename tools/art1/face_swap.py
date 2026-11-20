"""face_swap.py GAME.glb FACE.glb BASE.glb OUT.glb [--image v95]
Put a texture-only face pass into a game .glb: the pixels FACE.glb's body albedo changed against BASE.glb (the master
the pass was made on; same mesh and UVs) are blended into GAME.glb's embedded image (default "v95"); every other game
pixel, the mesh, rig, clips, weapons and materials stay as they are. The game has no normal or roughness maps.
The changed albedo is the base-colour image that differs between FACE and BASE. Re-run it on any later game .glb of the
same Hunter (one command), e.g. after the rig-weights PR lands:
  python3 -I tools/art1/face_swap.py art/wardens/kael/kael.glb FACE.glb BASE.glb /tmp/kael.glb && cp /tmp/kael.glb art/wardens/kael/kael.glb"""

import argparse
import io
import os
import struct
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_image_swap

Image.MAX_IMAGE_PIXELS = None
CHANGED = 12  # per-channel 0-255 step that counts as "the face pass painted here" (above JPEG noise)
GROW_PX = 5  # px at game size: the mask grows by this much, then softens by SOFT_PX
SOFT_PX = 3
QUALITY = 92


def image_bytes(path):
    """{image index: jpeg bytes} of the glb's base-colour images."""
    j, binary = glb_image_swap.load(path)
    out = {}
    for m in j["materials"]:
        tex = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is not None:
            view = j["bufferViews"][j["images"][j["textures"][tex["index"]]["source"]]["bufferView"]]
            off = view.get("byteOffset", 0)
            out[j["textures"][tex["index"]]["source"]] = binary[off : off + view["byteLength"]]
    return out


def changed_albedo(face, base):
    """(face image, base image) of the one base-colour image that differs between the two glbs."""
    a, b = image_bytes(face), image_bytes(base)
    hit = [i for i in a if i in b and a[i] != b[i]]
    if len(hit) != 1:
        sys.exit("face_swap: %d base-colour images differ between face and base" % len(hit))
    return [Image.open(io.BytesIO(x[hit[0]])).convert("RGB") for x in (a, b)]


def blend(game_img, face, base):
    size = game_img.size
    f = np.asarray(face.resize(size, Image.LANCZOS), dtype=np.float32)
    b = np.asarray(base.resize(size, Image.LANCZOS), dtype=np.float32)
    mask = Image.fromarray(((np.abs(f - b).max(axis=2) > CHANGED) * 255).astype(np.uint8))
    mask = mask.filter(ImageFilter.MaxFilter(GROW_PX * 2 + 1)).filter(ImageFilter.GaussianBlur(SOFT_PX))
    alpha = np.asarray(mask, dtype=np.float32)[..., None] / 255.0
    g = np.asarray(game_img, dtype=np.float32)
    print("face_swap: %.2f%% of the texture painted" % (100.0 * (alpha > 0.5).mean()))
    return Image.fromarray(np.clip(g * (1 - alpha) + f * alpha + 0.5, 0, 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("face")
    ap.add_argument("base")
    ap.add_argument("out")
    ap.add_argument("--image", default="v95", help="name of the game .glb's embedded image to repaint")
    a = ap.parse_args()
    j, binary = glb_image_swap.load(a.game)
    hit = [i for i in j["images"] if i.get("name") == a.image]
    if len(hit) != 1:
        sys.exit("face_swap: %d game images named %s" % (len(hit), a.image))
    view = j["bufferViews"][hit[0]["bufferView"]]
    off = view.get("byteOffset", 0)
    game_img = Image.open(io.BytesIO(binary[off : off + view["byteLength"]])).convert("RGB")
    face, base = changed_albedo(a.face, a.base)
    result = blend(game_img, face, base)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "face.jpg")
        result.save(path, quality=QUALITY)
        glb_image_swap.main(a.game, a.image, path, a.out)
    print("face_swap: wrote", a.out)


if __name__ == "__main__":
    main()
