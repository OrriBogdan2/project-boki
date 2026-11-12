"""In-game face sheet: before and after, per hunter, from the game's own cameras (ffmpeg only, no PIL).

    python3 tools/art1/ingame_face_sheet.py BEFORE_DIR AFTER_DIR OUT.jpg [warden_id ...]

BEFORE_DIR and AFTER_DIR are --warden-shots outputs (one folder per warden id). Each row shows the
front close-up (closeup_front.png, the engine's own head-and-shoulders camera) and the front figure
of the gameplay strip (turnaround_game.png, the match camera enlarged with nearest filtering), before
then after. The older facekeep sheets framed the glb in Blender with guessed face fractions of a
bounding box, in rest pose; this sheet only uses pixels the game rendered.
"""
import os
import subprocess
import sys
import tempfile

# warden id -> the name on the sheet (ids from scripts/*/warden_glb.gd ART)
NAMES = {
    "bulwark": "Albert", "archer": "Lace", "juggernaut": "Kael", "gunslinger": "Vex",
    "ostra": "Motley", "mage": "Sparkle", "dolm": "Tarek", "thief": "Sable",
    "rimewright": "Neve", "ashwick": "Cinder", "tender": "Meeko", "dredge": "Grimble",
}
TILE = 360        # px: every picture is scaled to a TILE x TILE square
LABEL_W = 220     # px: the name column
HEAD_H = 70       # px: the column titles
# turnaround_game.png: the true-pixel strip on top, the x3 strip below it starting at y 214; the
# front figure is the first of five, centred near x 170. This square holds it with its feet ring.
GAME_CROP = "crop=300:300:20:250"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BG = "0x1e1e22"


def text(label: str, x: str, y: str, size: int, colour: str = "white") -> str:
    return "drawtext=fontfile=%s:text='%s':x=%s:y=%s:fontsize=%d:fontcolor=%s" % (FONT, label, x, y, size, colour)


def ffmpeg(args: list) -> None:
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def row(wid: str, before: str, after: str, out: str) -> None:
    pics = [
        (os.path.join(before, wid, "closeup_front.png"), ""),
        (os.path.join(after, wid, "closeup_front.png"), ""),
        (os.path.join(before, wid, "turnaround_game.png"), GAME_CROP + ","),
        (os.path.join(after, wid, "turnaround_game.png"), GAME_CROP + ","),
    ]
    args, chains = [], []
    for i, (path, crop) in enumerate(pics):
        args += ["-i", path]
        chains.append("[%d:v]%sscale=%d:%d:flags=neighbor,format=rgb24[p%d]" % (i, crop, TILE, TILE, i))
    label = "color=c=%s:s=%dx%d,%s,%s[l]" % (BG, LABEL_W, TILE,
        text(NAMES.get(wid, wid), "20", "h/2-30", 40), text(wid, "20", "h/2+20", 24, "0xb0b0b0"))
    graph = ";".join(chains + [label, "[l][p0][p1][p2][p3]hstack=5"])
    ffmpeg(args + ["-filter_complex", graph, "-frames:v", "1", out])


def main() -> None:
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    before, after, out = sys.argv[1:4]
    ids = sys.argv[4:] or list(NAMES)
    width = LABEL_W + 4 * TILE
    with tempfile.TemporaryDirectory() as tmp:
        head = os.path.join(tmp, "head.png")
        titles = ["FACE before", "FACE after", "MATCH CAM before", "MATCH CAM after"]
        draws = [text(t, str(LABEL_W + i * TILE + 20), "22", 28, "0xffd25a") for i, t in enumerate(titles)]
        ffmpeg(["-f", "lavfi", "-i", "color=c=%s:s=%dx%d" % (BG, width, HEAD_H), "-vf", ",".join(draws),
            "-frames:v", "1", head])
        rows = [head]
        for wid in ids:
            rows.append(os.path.join(tmp, wid + ".png"))
            row(wid, before, after, rows[-1])
        args = []
        for path in rows:
            args += ["-i", path]
        ffmpeg(args + ["-filter_complex", "vstack=%d" % len(rows), "-frames:v", "1", "-q:v", "3", out])
    print(out)


if __name__ == "__main__":
    main()
