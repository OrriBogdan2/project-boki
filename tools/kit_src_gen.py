#!/usr/bin/env python3
"""One-off: writes the `src` note of each content/archetypes/*.json from docs/KIT_PARITY.md rows.
Tags: [D] data card, [F] footage, [O] owner note, ours, [?] not stated."""
import json, re, sys
rows = {}; hero = None
for ln in open("docs/KIT_PARITY.md", encoding="utf-8"):
    m = re.match(r"## .*\(`(\w+)`, source", ln)
    if m: hero = m.group(1); continue
    if ln.startswith("## "): hero = None
    if hero and ln.startswith("| "):
        c = [x.strip() for x in ln.strip().strip("|").split("|")]
        if len(c) >= 4 and c[0] in ("LMB", "RMB", "E", "R", "Dash", "Passive"):
            rows[(hero, c[0])] = c
SLOT = {"LMB": "lmb", "RMB": "rmb", "E": "e", "R": "x", "Dash": "dash", "Passive": "passive"}
def note(c):
    src, ours, verd = c[1], c[2], c[3]
    tags = []
    for t in re.findall(r"\[([^\]]*)\]", src):
        for p in re.split(r"[ ,/]+", t):
            if p[:1] in "DFO" and p not in tags and len(p) == 1: tags.append(p)
    if re.search(r"\(F \d|footage", src) and "F" not in tags: tags.append("F")
    if re.search(r"owner", src + verd, re.I) and "O" not in tags: tags.append("O")
    s = " ".join("[%s]" % t for t in tags) or "[?]"
    if re.search(r"\bours\b", verd, re.I) or re.search(r"\(ours\)", ours): s += " ours"
    o = re.search(r"owner[^)]*", verd, re.I)
    if o: s += " (" + o.group(0).strip() + ")"
    return s + " (cd/dmg/range/timing: KIT_PARITY row)"
for h in sorted({k[0] for k in rows}):
    p = "content/archetypes/%s.json" % h
    src = {SLOT[s]: note(rows[(h, s)]) for s in SLOT if (h, s) in rows}
    t = open(p, encoding="utf-8").read().rstrip()
    assert t.endswith("}") and '"src"' not in t
    body = ",\n".join("\t\t%s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in src.items())
    open(p, "w", encoding="utf-8").write(t[:-1].rstrip() + ',\n\t"src": {\n' + body + "\n\t}\n}\n")
