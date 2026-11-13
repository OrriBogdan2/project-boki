"""Unit checks for prior_work.py on a synthetic state (no git, no ~/cj). Run: python3 test_prior_work.py"""
import collections, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, "/home/boki/coord/boki-tools", "/home/boki/bin"]
os.environ.setdefault("PW_ALIASES", os.path.join(HERE, "concept-aliases.tsv"))
import prior_work as P

NOW = time.time()
def item(kind, id, title, t_h=-1, **kw):
    d = {"kind": kind, "id": id, "title": title, "body": kw.pop("body", ""), "t": NOW + t_h * 3600, "status": "", "refs": set(),
         "lane": P.lane_of(title), "running_now": False, "fin": None, "key": P.D.norm_key(title), "br": ""}
    d.update(kw); return d

def state(extra):
    filler = [item("main", f"main f{i}", f"chore {w} tidy {i}") for i, w in enumerate("alpha beta gamma delta eps zeta eta theta iota kappa".split() * 8)]
    items = filler + extra
    for it in items: it["f"] = P.feats(it["title"], it["body"])
    df = collections.Counter()
    for it in items: df.update(it["f"].keys())
    return {"items": items, "df": df, "n": len(items), "now": NOW}

def test_alias_concepts():
    assert "wisp-summon" in P.concepts(P.toks("boki control on G")), P.concepts(P.toks("boki control on G"))
    assert "chest" in P.concepts(P.toks("the keyed chest opens"))
    assert "skitter" in P.concepts(P.toks("spider nest"))
    assert "relic" not in P.concepts(P.toks("hatch mask anim slower")), "mask is the hatch mask, not a relic"

def test_semantic_refuse_and_override():
    st = state([item("ready", "ext/feel-summon-on-g", "READY ext/feel-summon-on-g abc (summon your boki on G)", t_h=-5),
                item("branch", "ext/feel-summon-on-g", "ext/feel-summon-on-g", t_h=-5)])
    code, why, block, ms = P.decide("Boki control G->C", "Move boki control from G to C and make the throw snappier.", st)
    assert code == 75 and "ext/feel-summon-on-g" in why, (code, why)
    code, why, block, ms = P.decide("Boki control G->C", "Move boki control from G to C.\nBuilds on: ext/feel-summon-on-g", st)
    assert code == 0 and "PRIOR WORK FOUND" in block, (code, block)
    code, *_ = P.decide("Boki control G->C", "Move boki control from G to C.\nNot a dupe: owner wants C now", st)
    assert code == 0

def test_broad_area_never_refuses():
    st = state([item("job", "20261111-020640-a6", "[combat] Unsealed lairs keep a boss as mid-game XP prize", t_h=-1, running_now=True)])
    code, why, block, ms = P.decide("[combat] Lair bosses vs source bosses: HP, phases, leash", "Boss parity table for lair bosses.", st)
    assert code == 0, why

def test_presentation_lane_does_not_block():
    st = state([item("job", "20261112-100000-a1", "[feel] Glide ring lift tuning", t_h=-1, running_now=True)])
    code, why, *_ = P.decide("[sfx] Glide rings: a pass-through cue", "Sound cue when passing a glide ring.", st)
    assert code == 0, why

def test_exempt_chores():
    st = state([])
    assert P.decide("rebase ext/foo", "rebase it", st)[0] == 0

if __name__ == "__main__":
    n = 0
    for k, f in list(globals().items()):
        if k.startswith("test_"): f(); n += 1; print("ok", k)
    print(f"{n} tests passed")
