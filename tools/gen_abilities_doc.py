import json, os, sys
R = sys.argv[1]
def j(p): return json.load(open(os.path.join(R, p)))
def ab(i): return j(f"content/abilities/{i}.json")
out = []
w = out.append
w("# Project Boki abilities\n")
w("Every ability in an expedition, by slot. All of them are data. Hunter abilities: `content/abilities/*.json` (class dashes, weapon RMBs) and `content/gloves/*.json` (Q gloves), built from the effect verbs in `scripts/combat/effects.gd` and the world verbs in `scripts/combat/verbs.gd` (walls, mirrors, tethers, traps, bridges, yanks, decoys). Kin abilities, dodge riders and merges (E, its auto active, the Shift rider and R) are the kin grammar: `content/kin_v2`, `content/abilities_v2`, `content/merges_v2`, run by `scripts/kin/kin_exec.gd` (see docs/KIN_GRAMMAR.md). A new ability is a new JSON file either way.\n")
w("This file is generated from the JSON by a script; the descriptions are the one-liners players see in the kit panel (K) and on hover.\n")
w("## Archetypes (the kit you play)\n")
w("Every hunter plays one of six archetypes (`content/archetypes/*.json`, run by `scripts/arch/arch_kit.gd` and `scripts/arch/kits/*`; design in docs/ARCHETYPES.md). The archetype owns RMB (with contextual variants), Shift (its dash shape), E (utility), R (ultimate, run level 6, rank 2 at 9) and a passive with its resource; the weapon owns LMB; Q is the glove; C is the kin's own ability (it hops out, casts, hops back) and G or middle mouse sends / recalls the kin. With a full bond meter, R is Bonded: the kin merges 0.2s after the ult. The kin's typing fills each ability's sockets (docs/ARCHETYPES.md §4).\n")
w("| Archetype | Weight | Weapons | Dash | Passive | RMB | E | R |\n|---|---|---|---|---|---|---|---|")
for a in ["thief", "archer", "mage", "gunslinger", "juggernaut", "bulwark"]:
    d = j(f"content/archetypes/{a}.json")
    wn = " / ".join(j(f"content/weapons/{x}.json")["name"] for x in d["weapons"])
    w(f"| **{d['name']}** | {d['weight']} | {wn} | {d['dash']['name']} | {d['passive']['name']} | {d['rmb']['name']} | {d['e']['name']} ({d['e']['cooldown']:g}s) | {d['r']['name']} ({d['r']['cooldown']:g}s) |")
for a in ["thief", "archer", "mage", "gunslinger", "juggernaut", "bulwark"]:
    d = j(f"content/archetypes/{a}.json")
    w(f"\n### {d['name']} ({d['weight']})\n")
    w(f"_{d['fantasy']}_\n")
    w(f"- **Passive: {d['passive']['name']}.** {d['passive']['desc']}")
    w(f"- **Shift: {d['dash']['name']}** ({d['dash']['cd']:g}s a charge). {d['dash']['desc']}")
    r = d["rmb"]
    w(f"- **RMB: {r['name']}** ({r['cooldown']:g}s" + (f", {r['charges']} charges" if r.get("charges", 1) > 1 else "") + "):")
    for v, lab in [("tap", "tap"), ("hold", "hold"), ("air", "in the air"), ("during_e", "with E"), ("full", "resource full")]:
        if v in r["variants"]: w(f"  - {lab}: {r['variants'][v]}")
    w(f"- **E: {d['e']['name']}** ({d['e']['cooldown']:g}s). {d['e']['desc']}")
    w(f"- **R: {d['r']['name']}** ({d['r']['cooldown']:g}s, level 6). {d['r']['desc']}")
    w("- Level-up order (bots too): " + ", ".join({"sec": "RMB", "dash": "Dash", "kin": "E", "ult": "R", "gear": "Q"}[x] for x in d["order"]))
w("")
w("The old class dashes and weapon RMBs below are kept as data (the verbs return as gloves and other content); a hunter with no archetype still uses them.\n")
w("## Ranks\n")
w("Every run starts with abilities locked (see `Hunter.slot_lv`). A skill point unlocks a slot at rank 1 and further points raise it (RMB, Q, Shift, E: ranks 1-3; R: ranks 1-2). Per rank past the first:\n")
w("- damage +15% (`Effects.level_k`)")
w("- cooldown 10% shorter (RMB, Q via `AbilityRunner`/`Hunter.rank_cd_k`, E via `KinRunner`); Shift dashes recharge 15% faster")
w("- each verb grows the numbers that define it (`Effects.RANK_GROW`): walls +20% health, +15% time, +10% length; mirrors +20% time; tethers +15% time, +20% snap stun; traps +15% time and root; zones +15% time, +10% radius; fissures +10% length; shots +10% range and +15% stun/root/slow; pulls +15% strength; chains +1 hop per rank; yanks and swaps +25% stun; bridges +20% time; cloaks/decoys/reveals +20-25% time; shields and heals +15%; blinks +10% distance; blink-strike crit window +25%")
w("- kin abilities grow through the core rank table `KinRules.RANK_GROW` (never through data), clamped to each part's bounds")
w("- the merge (R) at rank 2 lasts 30% longer and its effects hit 15% harder")
w("- dash and charge distances never grow: dashes stay short\n")
w("An ability JSON can override any of these with `\"per_level\": {\"key\": flat amount per rank}`.\n")
w("## Shift: class dashes\n")
w("Each class has its own dodge verb. Grounded with a charge, Shift does the class dodge; in the air or out of charges it does the class's long dash (its own cooldown). Both chain straight into a jump or the glider.\n")
w("| Class | Dash | Charges / cooldown | What it does |\n|---|---|---|---|")
for c in ["light", "medium", "heavy"]:
    a = ab(j(f"content/classes/{c}.json")["dodge"])
    e = a["effects"][0]
    w(f"| {c.capitalize()} | **{a['name']}** ({e['speed']*e['time']:.1f}m) | {a.get('charges',1)} / {a['cooldown']}s | {a['desc']} |")
w("\n### Kin dodge riders\n")
w("The kin you brought adds a rider to every class dodge (`dodge_rider` in `content/kin_v2/<id>.json`).\n")
w("| Kin | Rider | What it adds |\n|---|---|---|")
KV = {}
for f in sorted(os.listdir(os.path.join(R, "content/kin_v2"))):
    k = j("content/kin_v2/" + f); KV[k["id"]] = k
def parts(effs):
    out = []
    for e in effs:
        t = e["type"]
        if t == "damage": out.append(("%s damage over %ss" % (e["amount"], e.get("over", 3))) if e.get("preset") == "poison" or e.get("over") else "%s damage" % e["amount"])
        elif t == "mark": out.append("%s %ss" % (e.get("mode", e.get("preset", "mark")), e.get("duration", 3)))
        elif t == "signature": out.append(e["id"])
        else: out.append(t)
    return ", ".join(out)
def stage(st):
    d = st["delivery"]
    t = d["type"] + (" %sm" % d["radius"] if "radius" in d else "")
    return t + ((": " + parts(st.get("effects", []))) if st.get("effects") else "")
for kid, k in KV.items():
    rd = k.get("dodge_rider")
    if not rd: continue
    bits = []
    if rd.get("as") == "blink": bits.append("the dodge is an instant blink")
    if rd.get("on_pass"): bits.append("what you pass through: " + parts(rd["on_pass"]))
    for st in rd.get("on_start", []): bits.append("where you start: " + stage(st))
    for st in rd.get("on_end", []): bits.append("where you stop: " + stage(st))
    for md in rd.get("modifiers", []): bits.append("a second, shorter dodge a beat later")
    w(f"| {k['name']} | **{rd['name']}** | {'; '.join(bits)} |")
w("\n## RMB: weapon signature abilities (no archetype)\n")
w("Right click is your weapon's own verb. Hold RMB to see its telegraph (lane, landing circle, wall footprint or arc); release to cast. Rail Charge charges while held instead.\n")
w("| Weapon | Class | Ability | Verb | Cooldown | What it does |\n|---|---|---|---|---|---|")
for f in sorted(os.listdir(os.path.join(R, "content/weapons"))):
    wp = j("content/weapons/" + f)
    if not wp.get("utility"):
        continue      # the archetype weapons (Longbow, Spellstaff, Tower Shield & Mace) have no RMB of their own
    a = ab(wp["utility"])
    w(f"| {wp['name']} | {', '.join(wp['classes'])} | **{a['name']}** | {a.get('verb','')} | {a['cooldown']}s | {a['desc']} |")
w("\n## Q: active gloves\n")
w("Gloves drop in runs. Rarer gloves keep the same verb with bigger numbers: damage, wall health, heals and shields x1 / x1.3 / x1.6 / x2 (common to legendary), durations and pull strength by half as much, cooldown 8% shorter per step. Rank (skill points into Q) stacks on top.\n")
w("| Glove | Verb | Cooldown | What it does |\n|---|---|---|---|")
pas = []
for f in sorted(os.listdir(os.path.join(R, "content/gloves"))):
    g = j("content/gloves/" + f)
    if float(g.get("cd", 0)) > 0:
        w(f"| **{g['name']}** | {g.get('verb','')} | {g['cd']}s | {g['desc']} |")
    else:
        pas.append(g)
w("\nPassive gloves (no Q, stats only): " + "; ".join(f"**{g['name']}** ({g['desc']})" for g in pas) + "\n")
w("## E, the kin's own ability, and R, the merge\n")
w("Each kin has one E ability (`active`), an auto active it uses by itself (`auto`), a throw (C), a dodge rider and a merge (R, unlocked at run level 6 with a full bond meter). Its abilities are built from grammar parts; the lines below are the creators' flavour text. In a match the HUD and hover panels read the parts themselves (`KinText`). E is cast from your shoulder (you perform it) or by the kin where it stands, aimed at the cursor.\n")
def a2(i): return j(f"content/abilities_v2/{i}.json")
for kid, k in KV.items():
    w(f"### {k['name']} ({' + '.join(k['animals'])}, {k['carry']['style']})\n")
    e1 = a2(k["active"]); e2 = a2(k["auto"]) if k.get("auto") else None
    u = j(f"content/merges_v2/{k['merge']}.json")
    w(f"- **E: {e1['name']}** ({e1['stages'][0]['delivery']['type']}, {e1.get('cooldown', 8)}s): {e1.get('flavor', '')}")
    if e2: w(f"- **Auto: {e2['name']}** ({e2['stages'][0]['delivery']['type']}, {e2.get('cooldown', 8)}s): {e2.get('flavor', '')}")
    if k.get("throw"): w(f"- **Throw (C)**: stuns what it hits; also {parts(k['throw']['effects'])}.")
    if k.get("dodge_rider"): w(f"- **Shift rider: {k['dodge_rider']['name']}**")
    w(f"- **R: {u['name']}** ({u['duration']}s): {u.get('flavor', '')}\n")
w("## Element variants of shared verbs\n")
w("Several verbs appear in more than one element, tuned to fit it:\n")
w("- **Hook / yank**: Hook Glove (neutral, drags to your feet or zips you to terrain), Stinger Hook (venom: poisons and blights), Leash Bolt (tether that snaps back).")
w("- **Wall**: Barrier Glove (stone, blocks shots and bodies both ways), Bulwark (energy, follows your aim, yours pass through), Mass Guard (gravity plate, raised for you when you're shot), Prism Wall (crystal, reflects shots).")
w("- **Reflect**: Mirror Glove (all-round bubble), Riposte (frontal, parries melee), Refraction (prism, auto when hurt), Prism Wall (reflecting wall).")
w("- **Slam / knock-up**: Earthshatter (hunter leap), Gravity Slam (kin meteor that pulls in first), Fissure Glove (a line eruption), Vortex Glove (pull then pop).")
w("- **Blink**: Blink Glove (blink-strike), Shadow Step (appear behind who your knife hits), Moon Swap (lunar: trade places), Lunar dash rider.")
w("- **Trap / zone**: Tripwire Mine (root + reveal), Puffcap Mines (spore triangle), Spore Patch (spore cloud), Spore dash rider.\n")
w("## Readability\n")
w("- Holding RMB, Q, E or R shows the cast's shape before you let go: a lane for shots and rushes (with a tick at the far end), a range ring plus landing circle for lobs and leaps, the wall's footprint across your aim, a cone, or a ring round you (`Match._update_indicators`, shape from `AbilityDef.aim_spec` and, for kin, `KinText.aim`).")
w("- Enemy area casts get a 0.32s filling ground marker before they land; leaps show their landing circle to everyone; fissures show their lane filling.")
w("- Each verb has its own shape in the world (wall slabs, a mirror shell, a rope for tethers, a disc, a hook, an orb, trap pads, ice tiles, ghost decoys) in its colour (kin abilities: effect category colour, `KinRules.CAT_COLORS`), plus HOOKED / SPIKED / PARRIED / SNAP / TRAP words when they go off.\n")
w("## Bots\n")
w("Each ability carries a `bot` hint (`when`: in_range, under_fire, clumped, hurt, gap, always; `min`/`max`), read by `Bot.ability_aim`: walls and mirrors go up when a bot is being shot, hooks and slams when the target is in reach and in sight, vortex and fissure when foes bunch, Rail Charge is held to full. Bots shoot decoys while the real hunter is cloaked. Bot points are spent automatically (`Hunter._bot_spend`).\n")
open(os.path.join(R, "docs/ABILITIES.md"), "w").write("\n".join(out) + "\n")
print("ok")
