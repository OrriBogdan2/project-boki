extends RefCounted
## --bot-kit-check[=<arch>] [--bot-kit-t=90] [--bot-kit-seed=7]: a headless bot-vs-bot fight per Hunter on the flat
## duel island (both fighters play that Hunter, every slot open, the bond meter refilled every 30 s: Fuse is on offer).
## Counts what the bots really do in each slot (LMB, RMB, E, R, dash, glide, Fuse) and the hits landed, prints a
## table row per Hunter (docs/BOT_KIT_USE.md) and fails any slot a bot never uses, or uses in a way that cannot
## hit: a recast never recast, a hold never released, Kael's Lunge never perfect-released, Lace never drawing
## the Heavy Shot to full. The fix lives in the kit's bot_use or the Bot, never in the kit's numbers.
## Never touches the save.

## arch -> the kit's own counters (keys of the tally) that must be above zero.
const MUST := {
	"juggernaut": ["lunge perfect", "chain reel"],
	"bulwark": ["hammer throw", "hammer recall", "shield charge"],
	"rimewright": ["skate", "rink freeze"],
	"dolm": ["hop recast"],
	"ashwick": ["cloak pull"],
	"archer": ["full draw"],
	"mage": ["kitefall foes"],
	"thief": ["knife blink"],
	"ostra": ["brimseed pop", "lantern swap"],
	"tender": ["hearth toss"],
}
const NO_ULT := ["tender"]       # Hearth Call needs a downed or under-35% squadmate: the test does not stage one
const COLS := [
	"lmb s", "lmb hit", "rmb press", "rmb hold", "rmb hit", "e", "e hit", "ultimate", "dash", "glide", "fuse", "hit",
]
## Counters every Hunter must show (and the ultimate, bar Meeko's).
const ALWAYS := ["lmb s", "lmb hit", "rmb press", "e", "dash", "glide", "fuse", "hit"]

const FILL_EVERY := 30.0       # s between bond-meter refills (a merge also locks the hero's own X for its length)

var bad := 0

## The Bot, counting the keys it presses right after it decides (swapped in for Match.bot_brain).
class Probe extends Bot:
	var n: Dictionary = {}
	var arch := ""
	func tick(m: Match, h: Hunter, dt: float) -> void:
		if h.ak == null or h.ak.id != arch:
			super.tick(m, h, dt)          # (a squadmate: plays, is not counted)
			return
		var was := {}
		for k in ["sec", "dash"]:
			was[k] = bool(h.inp.get(k, false))
		super.tick(m, h, dt)
		if bool(h.inp.get("fire", false)):
			n["lmb s"] = float(n.get("lmb s", 0.0)) + dt
		for k in ["sec", "dash"]:
			if bool(h.inp.get(k, false)) and not was[k]:
				var key: String = "rmb press" if k == "sec" else k
				n[key] = int(n.get(key, 0)) + 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var only := ""
	var secs := 90.0
	var seed_n := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-kit-check="): only = a.substr(16)
		if a.begins_with("--bot-kit-t="): secs = float(a.substr(12))
		if a.begins_with("--bot-kit-seed="): seed_n = int(a.substr(15))
	for arch in Arch.ids():
		if only == "" or only == arch:
			await _fight(main, String(arch), seed_n, secs)
	print("BOTKIT done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fight(main: Node, arch: String, seed_n: int, secs: float) -> void:
	seed(seed_n)
	var o := Match.duel_opts()
	o.merge({"autoplay": true, "seed": seed_n, "arch": arch, "cls": Arch.weight(arch)}, true)
	o["weapon"] = Arch.signature(arch)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	m.duel.arch = arch
	m.duel.spawn_bot()
	var probe := Probe.new()
	probe.arch = arch
	m.bot_brain = probe
	var fighters: Array = [m.player, m.duel.bot]
	var all: Array = fighters.duplicate()
	if arch == "tender":
		for f in fighters:
			all.append(_mate(m, f))
	for h in all:
		h.ai = probe.new_mind(m.rng, 0.7)
		h.unlock_all()
		h.lvl = 12          # (the ultimate opens at level 6)
	var n := probe.n
	var cb_use := func(who, id, slot): if who in fighters: _use(n, String(id), String(slot))
	var cb_hit := func(by, _t, _d, tags): if by in fighters: _hit(n, tags)
	CombatBus.ability_used.connect(cb_use)
	CombatBus.hit_landed.connect(cb_hit)
	var prev := {}
	var fill := 0.0
	while m.time < secs and not m.over:
		if m.time >= fill:
			fill = m.time + FILL_EVERY
			for h in fighters:
				h.ult = 1.0          # a full bond meter, so Fuse is on offer
			for mate in all.slice(2):
				mate.hp = mate.max_hp * 0.4          # hurt and out of her ring: the light is thrown to them
		m.step(Match.DT)
		for h in fighters:
			_poll(n, h, prev)
	for h in fighters:
		_totals(n, h.ak)
	CombatBus.ability_used.disconnect(cb_use)
	CombatBus.hit_landed.disconnect(cb_hit)
	m.duel.teardown()
	m.queue_free()
	_report(arch, n)

## Meeko's Hearthlight is thrown to a hurt squadmate, so each side gets a Vex beside it.
func _mate(m: Match, side: Hunter) -> Hunter:
	var kit := {"arch": "gunslinger", "weapon": Arch.signature("gunslinger"), "perk": ""}
	var at := side.pos + Vector3(8, 0, 0)
	var w := Arch.weight("gunslinger")
	var mate: Hunter = m.make_hunter(m.next_id("mate"), side.team, w, "Mate", "bot", m.bot_kin_record(), at, kit, {})
	mate.lives = 99
	return mate

func _add(n: Dictionary, k: String, by := 1) -> void:
	n[k] = int(n.get(k, 0)) + by

func _use(n: Dictionary, id: String, slot: String) -> void:
	if slot == "kin": _add(n, "e")
	elif slot == "ultimate": _add(n, slot)
	elif id.ends_with("_throw") or id.ends_with("_recall"): _add(n, "hammer " + id.get_slice("_", 1))

func _hit(n: Dictionary, tags: Array) -> void:
	var t := String(tags[0]) if not tags.is_empty() else ""
	_add(n, "hit")
	if "shot" in tags or t == "primary": _add(n, "lmb hit")
	elif t == "utility": _add(n, "rmb hit")
	elif t == "k1": _add(n, "e hit")
	elif t == "flame" and not "cloak" in tags: _add(n, "lmb hit")      # (Cinder's flame tags no slot word)

## Edges of the kits' input states, per step: RMB press / release, glides, skates, freezes, hop chains.
func _poll(n: Dictionary, h: Hunter, prev: Dictionary) -> void:
	var k: ArchKit = h.ak
	var p: Dictionary = prev.get(h, {})
	var now := {"rmb": k.rmb_down, "glide": h.gliding, "fuse": KinMerge.active(h)}
	if k is RimewrightKit:
		now["skate"] = not k.rinkrun.is_empty()
		now["freeze"] = not k.wall.is_empty() and bool(k.wall.get("frozen", false))
	if k is DolmKit:
		now["hops"] = k.hop.hops
	if k is BulwarkKit:
		now["charge"] = k.front_t > 0.0
	if k is TenderKit:
		now["toss"] = bool(k.hearth.get("tossed", false))
	if now["fuse"] and not p.get("fuse", false): _add(n, "fuse")
	if now["rmb"] and k is ArcherKit and k.rmb_t >= k.rmb_charge_full(): p["full"] = true
	if p.get("rmb", false) and not now["rmb"]:
		var need := float(k.rmb_def().get("hold", 0.0))
		_add(n, "rmb hold" if need > 0.0 and k.rmb_t >= need else "rmb tap")
		if p.get("full", false): _add(n, "full draw")
		p["full"] = false
	if now["glide"] and not p.get("glide", false): _add(n, "glide")
	if now.get("skate", false) and not p.get("skate", false): _add(n, "skate")
	if now.get("freeze", false) and not p.get("freeze", false): _add(n, "rink freeze")
	if now.get("hops", 0) > p.get("hops", 0) and int(k.hop.st["n"]) >= 2:
		_add(n, "hop recast")          # a hop after the first of a chain
	if now.get("toss", false) and not p.get("toss", false): _add(n, "hearth toss")
	if now.get("charge", false) and not p.get("charge", false): _add(n, "shield charge")
	now["full"] = p.get("full", false)
	prev[h] = now

## The kits' own counters, once per fight.
func _totals(n: Dictionary, k: ArchKit) -> void:
	if k is JuggernautKit:
		_add(n, "lunge perfect", k.perfects)
		_add(n, "chain reel", k.warchain.reels)
	elif k is BulwarkKit:
		_add(n, "shield slam", k.shield_slams)
	elif k is AshwickKit:
		_add(n, "cloak pull", k.pulled)
	elif k is MageKit:
		_add(n, "kitefall foes", k.ult.hits)
	elif k is ThiefKit:
		_add(n, "knife blink", k.blinks)
	elif k is OstraKit:
		_add(n, "brimseed pop", k.pops)
		_add(n, "lantern swap", k.swaps)

func _report(arch: String, n: Dictionary) -> void:
	var cells: Array = COLS.map(func(c): return "%.0f" % float(n.get(c, 0)))
	var extras: Array = []
	for key in n.keys():
		if key in MUST.get(arch, []) or key == "shield slam":
			extras.append("%s %d" % [key, n[key]])
	print("BOTKIT | %s | %s | %s |" % [arch, " | ".join(cells), ", ".join(extras)])
	for key in ALWAYS + ([] if arch in NO_ULT else ["ultimate"]) + MUST.get(arch, []):
		_need(arch, n, key, "never uses '%s'" % key)
	if float(Arch.def(arch).get("rmb", {}).get("hold", 0.0)) > 0.0:
		_need(arch, n, "rmb hold", "presses RMB but never holds it to the hold threshold")
	if arch == "bulwark" and int(n.get("rmb tap", 0)) * 4 > int(n.get("rmb hold", 0)):
		print("BOTKIT FAIL bulwark taps the Aegis (%d taps, %d holds)" % [n.get("rmb tap", 0), n.get("rmb hold", 0)])
		bad += 1

func _need(arch: String, n: Dictionary, key: String, what: String) -> void:
	if float(n.get(key, 0)) <= 0.0:
		print("BOTKIT FAIL %s %s" % [arch, what])
		bad += 1
