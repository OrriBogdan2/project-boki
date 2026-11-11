"""The Python side of scripts/arch/arch_text.gd: fill the {tokens} of a hero's ability text from its own data.
Used by the doc generators so the wiki shows the same numbers the game does."""
import json
import math
import os
import re

SLOT_BASE = {"sec": ("rmb", "cooldown"), "dash": ("dash", "cd"), "kin": ("e", "cooldown")}
CD_STEP = {"sec": 0.1, "kin": 0.1, "dash": 0.15}
PER_LEVEL = 0.15      # Effects.PER_LEVEL: default damage gain per rank
TOKEN = re.compile(r"\{([a-z0-9_.]+)(-1)?(%?)\}")


def number(kit, path):
    seg = path.split(".")
    if seg[0] in ("cd", "cd2", "cd3", "dmg2", "dmg3") and len(seg) == 2:
        return rank_value(kit, seg[0], seg[1])
    cur = kit
    if seg[0] == "weapon":
        cur = {"weapon": weapon(kit.get("signature", ""))}
    for s in seg:
        if isinstance(cur, dict) and s in cur:
            cur = cur[s]
        elif isinstance(cur, list) and s.isdigit() and int(s) < len(cur):
            cur = cur[int(s)]
        else:
            return None
    return float(cur) if isinstance(cur, (int, float)) else None


def weapon(wid):
    """The signature weapon's file (content/weapons/<id>.json), for "{weapon.primary.range}" tokens."""
    p = os.path.join(os.path.dirname(__file__), "..", "content", "weapons", "%s.json" % wid)
    if not wid or not os.path.exists(p):
        return {}
    with open(p) as f:
        return json.load(f)


def rank_value(kit, what, slot):
    if slot not in SLOT_BASE:
        return None
    rank = int(what[-1]) if what != "cd" else 1
    cd = what.startswith("cd")
    row = kit.get("rank_cd" if cd else "rank_dmg", {}).get(slot, [])
    step = 1.0 - CD_STEP[slot] * (rank - 1) if cd else PER_LEVEL * (rank - 1) + 1.0
    k = float(row[rank - 1]) if len(row) >= rank else step
    if cd:
        a, b = SLOT_BASE[slot]
        return float(kit[a][b]) * k
    return k - 1.0


def fmt(v, coarse=False):
    q = 10.0 if coarse else 100.0
    r = math.floor(v * q + 0.5 + 1e-6) / q
    return str(int(r)) if r == int(r) else str(r)


def text(s, kit):
    def sub(m):
        v = number(kit, m.group(1))
        if v is None:
            return "{?%s}" % m.group(1)
        v -= 1.0 if m.group(2) else 0.0
        return fmt(v * 100.0 if m.group(3) == "%" else v, m.group(1).startswith("cd"))
    return TOKEN.sub(sub, s)


def fill(kit, node=None):
    """Fill every string under `node` (the whole kit by default), in place."""
    cur = kit if node is None else node
    for k in (cur.keys() if isinstance(cur, dict) else range(len(cur))):
        v = cur[k]
        if isinstance(v, str) and "{" in v:
            cur[k] = text(v, kit)
        elif isinstance(v, (dict, list)):
            fill(kit, v)
    return kit
