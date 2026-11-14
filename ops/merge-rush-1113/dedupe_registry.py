#!/usr/bin/env python3
"""Drop check registry keys that union merges doubled, keeping main's exact line (else the first copy)."""

import collections
import re
import subprocess

PATH = "tools/check_registry.gd"
KEY = re.compile(r'\s*("--[a-z0-9-]+"):')


def main() -> None:
    lines = open(PATH).read().split("\n")
    main_lines = set(
        subprocess.run(["git", "show", f"origin/main:{PATH}"], capture_output=True, text=True).stdout.split("\n")
    )
    seen = collections.defaultdict(list)
    for i, line in enumerate(lines):
        match = KEY.match(line)
        if match:
            seen[match.group(1)].append(i)
    drop = set()
    for rows in seen.values():
        if len(rows) > 1:
            keep = next((i for i in rows if lines[i] in main_lines), rows[0])
            drop |= {i for i in rows if i != keep}
    for i in sorted(drop):  # a comment doubled right above a dropped entry goes too
        if i > 0 and lines[i - 1].lstrip().startswith("#") and lines.count(lines[i - 1]) > 1 and i - 1 not in drop:
            drop.add(i - 1)
    open(PATH, "w").write("\n".join(line for i, line in enumerate(lines) if i not in drop))
    print(f"dropped {len(drop)} doubled lines")


if __name__ == "__main__":
    main()
