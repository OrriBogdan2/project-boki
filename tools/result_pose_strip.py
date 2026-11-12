#!/usr/bin/env python3
"""The strip of all twelve Hunters' win, lose and board beats from --result-pose-shots (needs ffmpeg).
Usage: result_pose_strip.py <shots-dir> <out.png> [--width=<px per frame>]. One row per Hunter in Arch.ORDER,
columns win/lose/board x (arriving, held, breathing out)."""
import subprocess
import sys

ORDER = ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
         "rimewright", "tender", "thief"]
BEATS = ["win", "lose", "board"]


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2
    shots, out = args
    width = 200
    for a in sys.argv[1:]:
        if a.startswith("--width="):
            width = int(a[8:])
    files = [f"{shots}/{hid}/{beat}_{n}.png" for hid in ORDER for beat in BEATS for n in range(3)]
    cols = len(BEATS) * 3
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for f in files:
        cmd += ["-i", f]
    layout = "|".join(f"{(i % cols) * width}_{(i // cols) * width}" for i in range(len(files)))
    scaled = "".join(f"[{i}:v]scale={width}:{width}[s{i}];" for i in range(len(files)))
    stack = "".join(f"[s{i}]" for i in range(len(files)))
    cmd += ["-filter_complex", f"{scaled}{stack}xstack=inputs={len(files)}:layout={layout}", out]
    return subprocess.run(cmd).returncode


if __name__ == "__main__":
    sys.exit(main())
