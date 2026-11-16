#!/usr/bin/env python3
"""Choose which bundle members to download: game-relevant categories, short files only.
  sonniss_pick.py MEMBERS.jsonl PICK.txt MAX_FILE_MB
Writes PICK.txt for sonniss_remote.py get, and prints counts and total size per bundle."""

import collections, json, re, sys

WANT = re.compile(
    r"gun|rifle|pistol|revolver|smg|shotgun|sniper|musket|weapon|blaster|laser|plasma|bullet|shot|reload|cock|"
    r"whoosh|swoosh|swish|swipe|swing|flyby|fly-by|dash|glide|wind gust|impact|hit|punch|slam|smash|thud|crack|"
    r"\bui\b|interface|click|button|menu|hover|select|confirm|pickup|pick up|coin|collect|reward|level|"
    r"magic|spell|cast|zap|electric|elemental|fire ?ball|ice |frost|buff|heal|summon|"
    r"creature|monster|growl|roar|grunt|pain|hurt|death|die|scream|vocal|groan|"
    r"foot|step|jump|land|body ?fall|stinger|sting|transition|cinematic hit|sci-?fi|synth|knock|glitch|arcade|cartoon|fun ",
    re.I,
)
SKIP = re.compile(
    r"ambien|room tone|drone|loop|music|traffic|crowd|city|forest|jungle|rain|thunder|ocean|river|"
    r"engine|car |vehicle|motorbike|harley|tank|jet|airshow|aircraft|train|dog|bird|animal|office|golf|basketball|tennis|"
    r"guitar|piano|voice of god|speech|dialog|phrase|water|geyser|construction|street|kamchatka",
    re.I,
)
mb = float(sys.argv[3]) * (1 << 20)
out, tot, cnt = [], collections.Counter(), collections.Counter()
for line in open(sys.argv[1]):
    d = json.loads(line)
    if d["size"] > mb or not WANT.search(d["name"]) or SKIP.search(d["name"]):
        continue
    out.append("%s\t%s\n" % (d["url"], d["name"]))
    tot[d["bundle"]] += d["size"]
    cnt[d["bundle"]] += 1
open(sys.argv[2], "w", encoding="utf-8").writelines(out)
for k in sorted(tot):
    print(k, cnt[k], "files %.1f GB" % (tot[k] / (1 << 30)))
print("total %d files %.1f GB" % (len(out), sum(tot.values()) / (1 << 30)))
