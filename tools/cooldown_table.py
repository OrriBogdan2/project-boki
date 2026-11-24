#!/usr/bin/env python3
"""Cooldown parity table: today's content vs source level 1 vs footage card (docs/KIT_PARITY.d/cooldowns-1122.md).

Usage: python3 tools/cooldown_table.py [--write] [--verify-ref REF]
Reads content/archetypes/*.json (the 12 Hunters; `gil` is not a Hunter). Prints a markdown table, and with
--write rewrites docs/KIT_PARITY.d/cooldowns-1122.md between the TABLE markers. Changes no game number.
SRC1 = source data level 1 (sv/briefs supervive_kits.md; "@IV" values put back to level 1 with the listed upgrades;
same numbers ext/cooldown-parity-verify asserts in tools/cooldown_parity_check.gd). CARD = footage hunter's card
(briefs/hero-ref/*.md on ext/agent-briefs; the footage hunter is levelled, so cards read low). None = not on the card.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SLOTS = ["rmb", "e", "x", "dash"]
LABEL = {"rmb": "RMB", "e": "E", "x": "R", "dash": "dash"}
# id: (name, source hunter, footage ref, {slot: source L1}, {slot: footage card})
KITS = {
    "gunslinger": ("Vex", "Ghost", "venator", {"rmb": 9, "e": 12, "x": 55, "dash": 11.5}, {"rmb": 5.4, "e": 10, "x": 37.5, "dash": 7.5}),
    "juggernaut": ("Kael", "Brall", "juggernaut", {"rmb": 2.5, "e": 16, "x": 45, "dash": 13}, {"rmb": 1.2, "e": 9.4, "x": 21.7, "dash": None}),
    "archer": ("Lace", "Myth", "pin", {"rmb": 16, "e": 15, "x": 60, "dash": 9.5}, {"rmb": 9, "e": 8.3, "x": 33.3, "dash": None}),
    "ashwick": ("Cinder", "Felix", "linwick", {"rmb": 9, "e": 13, "x": 45, "dash": 9}, {"rmb": 5.8, "e": 8.3, "x": 25, "dash": None}),
    "bulwark": ("Albert", "Oath", "bjorn", {"rmb": 6, "e": 12, "x": 50, "dash": 8}, {"rmb": None, "e": 10, "x": 33.3, "dash": 9.2}),
    "tender": ("Meeko", "Elluna", "mooshmoosh", {"rmb": 11.5, "e": 12, "x": 60, "dash": 7}, {"rmb": 7.2, "e": 10, "x": 41.6, "dash": None}),
    "dredge": ("Grimble", "Kingpin", "dredge", {"rmb": 18, "e": 12, "x": 36, "dash": 7}, {"rmb": 11.7, "e": 6.7, "x": 20.8, "dash": None}),
    "dolm": ("Tenzo", "Tetra", "breah", {"rmb": 11, "e": 12.5, "x": 45, "dash": 12}, {"rmb": 9, "e": 10, "x": 35, "dash": 9}),
    "rimewright": ("Neve", "Celeste", "tamsin", {"rmb": 12, "e": 20, "x": 80, "dash": 13}, {"rmb": None, "e": 16.7, "x": 45.8, "dash": 8.3}),
    "mage": ("Sparkle", "Joule", "vireo", {"rmb": 10, "e": 12, "x": 60, "dash": 9}, {"rmb": 7, "e": 9.2, "x": 37.5, "dash": None}),
    "thief": ("Sable", "Shiv", "dancer", {"rmb": 13, "e": 28, "x": 50, "dash": 5}, {"rmb": 6.7, "e": 15, "x": 29.1, "dash": 4.2}),
    "ostra": ("Motley", "Void", "ostra", {"rmb": 10, "e": 10, "x": 70, "dash": 9.5}, {"rmb": 5.8, "e": None, "x": 58.3, "dash": 7.5}),
}


# extra air slots: (hero id, JSON path, label, source L1, footage card)
EXTRA = [("juggernaut", "rmb.drop", "air RMB", 9, 5), ("tender", "dash.air", "air dash", 14, None), ("dredge", "dash.air", "air dash", 12.5, None)]


def cd_of(arch: dict):
    out = {}
    for s in SLOTS:
        slot = arch.get(s) or {}
        out[s] = slot.get("cd", slot.get("cooldown"))
    for hid, path, _l, _a, _c in EXTRA:
        if hid == arch.get("id"):
            slot = arch
            for k in path.split("."):
                slot = slot.get(k) or {}
            out[path] = slot.get("cd", slot.get("cooldown"))
    return out


def load(hid: str, ref: str | None):
    if ref:
        txt = subprocess.run(["git", "show", f"{ref}:content/archetypes/{hid}.json"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    else:
        txt = open(os.path.join(ROOT, "content", "archetypes", hid + ".json")).read()
    return cd_of(json.loads(txt))


def build(verify_ref: str | None):
    rows, stats = [], {"cells": 0, "below": 0, "kits_below": 0, "kits_changed": 0, "ratios": [], "card_ratios": []}
    for hid, (name, src, foot, l1, card) in KITS.items():
        now = load(hid, None)
        ver = load(hid, verify_ref) if verify_ref else {}
        kit_below = kit_changed = False
        for s in SLOTS:
            n, a, c = now[s], l1[s], card[s]
            ratio = n / a
            stats["cells"] += 1
            if ratio < 0.995:
                stats["below"] += 1
                kit_below = True
                stats["ratios"].append(ratio)
            changed = bool(verify_ref) and abs((ver.get(s) or 0) - n) > 1e-6
            kit_changed = kit_changed or changed
            if c is not None:
                stats["card_ratios"].append(c / a)
            rows.append((name, src, LABEL[s], n, a, c, ratio, (c / a) if c is not None else None, ver.get(s) if verify_ref else None, changed))
        for xid, path, lab, a, c in EXTRA:
            if xid != hid:
                continue
            n = now[path]
            stats["cells"] += 1
            if n / a < 0.995:
                stats["below"] += 1
                kit_below = True
                stats["ratios"].append(n / a)
            if c is not None:
                stats["card_ratios"].append(c / a)
            changed = bool(verify_ref) and abs((ver.get(path) or 0) - n) > 1e-6
            kit_changed = kit_changed or changed
            rows.append((name, src, lab, n, a, c, n / a, (c / a) if c is not None else None, ver.get(path) if verify_ref else None, changed))
        stats["kits_below"] += kit_below
        stats["kits_changed"] += kit_changed
    return rows, stats


def f(v):
    return "-" if v is None else ("%g" % v)


def render(rows, stats, verify_ref):
    o = ["| Hunter | Source | Slot | Today (main) | Source L1 | Footage card | Today / L1 | Card / L1 | Verify branch sets | Verify changes it |", "|---|---|---|---|---|---|---|---|---|---|"]
    for name, src, slot, n, a, c, r, cr, v, ch in rows:
        o.append("| %s | %s | %s | %g | %g | %s | %.2f | %s | %s | %s |" % (name, src, slot, n, a, f(c), r, "-" if cr is None else "%.2f" % cr, f(v), "**yes**" if ch else "no"))
    return "\n".join(o)


def main():
    ref = None
    if "--verify-ref" in sys.argv:
        ref = sys.argv[sys.argv.index("--verify-ref") + 1]
    rows, st = build(ref)
    table = render(rows, st, ref)
    r = sorted(st["ratios"])
    summary = "cells %d, below L1 %d (kits %d of 12), today/L1 on those: min %.2f max %.2f; verify changes %d kits; card/L1 min %.2f max %.2f" % (
        st["cells"], st["below"], st["kits_below"], r[0], r[-1], st["kits_changed"], min(st["card_ratios"]), max(st["card_ratios"]))
    print(table)
    print("\nSUMMARY: " + summary)
    if "--write" in sys.argv:
        p = os.path.join(ROOT, "docs", "KIT_PARITY.d", "cooldowns-1122.md")
        s = open(p).read()
        a, b = s.index("<!-- TABLE -->"), s.index("<!-- /TABLE -->")
        open(p, "w").write(s[: a + 14] + "\n" + table + "\n" + s[b:])


main()
