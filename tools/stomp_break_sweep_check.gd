extends RefCounted
## --stomp-break-sweep-check (docs/decisions/0061-stomp-lock.md, Owner 2026-11-11 "stomping"): a stomp ends only
## when it finishes or its stomper is stunned or hard-CC'd. For every Hunter, every slot (LMB, RMB, E, R, Shift) is
## cast at a bot that is mid-stomp, as a tap at 3 m, and each cast must follow the rule:
##  - it breaks the stomp when it put a hard CC on the stomper by then (a stun, root, Ground, hex, grapple, pad
##    flight, a pull or push, or a launch) and the wisp lives;
##  - it never breaks it with a slow, Daze, plain damage or the small shove most hits carry (a knock under
##    Capture.HARD_KNOCK, and Hunter.impulse's 4 m/s floor under that).
## EXPECT pins the hard CC each move is known to land in this setup (the CC table in docs/KIT_PARITY.md), so a
## CC tag lost from a move turns a row red. Moves the generic cast cannot reach (a wall, a pair, a ground
## target, a delayed stun) are listed in docs/KIT_PARITY.md, not pinned here. SWEEP_ONLY=<arch> runs one Hunter.
## Reuses the dash-flow check's training match. Never touches the save.

const WATCH := 150             # steps watched after the press (2.5 s: the stomp itself needs Stomp.TIME, 3.0 s)
const SLOTS := ["lmb", "rmb", "e", "x", "dash"]
const HARD := ["stun", "root", "gnd", "launch", "hex", "grap", "tow"]
const TAP := [3.0, 1]          # [distance to the stomper in m, steps the key is held]: every slot is cast like this
## Casts that need another press: [arch, slot, metres, steps held, effect it must put on the stomper].
## They pin the CC table of docs/KIT_PARITY.md as it lands here, so a CC tag lost from a move turns its row red.
## (The Daze and slow rows are soft: the sweep asserts they never break the stomp.)
const EXPECT := [
	["gunslinger", "rmb", 3.0, 1, "daze"], ["bulwark", "lmb", 3.0, 90, "stun"], ["bulwark", "x", 3.0, 1, "stun"],
	["ostra", "rmb", 3.0, 1, "stun"], ["ostra", "x", 3.0, 1, "stun"],
	["thief", "rmb", 3.0, 1, "gnd"], ["dredge", "rmb", 3.0, 1, "stun"], ["dredge", "e", 3.0, 1, "gnd"],
	["mage", "e", 3.0, 1, "gnd"], ["ashwick", "dash", 3.0, 1, "launch"],
	["ashwick", "e", 3.0, 1, "tow"], ["dolm", "dash", 3.0, 1, "launch"], ["juggernaut", "dash", 3.0, 1, "launch"],
	["rimewright", "e", 3.0, 1, "tow"], ["gil", "x", 3.0, 1, "stun"],
	["archer", "e", 3.0, 1, "slow"], ["dolm", "rmb", 3.0, 1, "slow"],
	["rimewright", "rmb", 3.0, 1, "slow"], ["gunslinger", "x", 3.0, 1, "slow"], ["thief", "e", 3.0, 1, "slow"],
]

var bad := 0
var rows := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	rows += 1
	if not cond:
		bad += 1
		print("SWEEP FAIL %s" % what)

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(flow._on_used)
	var only := OS.get_environment("SWEEP_ONLY").split(",", false)
	for hero in Arch.ORDER:
		if not only.is_empty() and not only.has(hero):
			continue
		var m: Match = flow._match(main, hero, 2)
		if m.biomes: m.biomes.hazards.clear()      # a lightning rod's stun would break stomps (see stomp_check.gd)
		for slot in SLOTS:
			var seen := _trial(m, hero, slot, TAP[0], TAP[1])
			print("SWEEP %s %s: %s" % [hero, slot, seen.keys()])
		for row in EXPECT:
			if row[0] == hero:
				var got := _trial(m, hero, row[1], row[2], row[3])
				ok(got.has(row[4]), "%s %s lands %s on the stomper (%s)" % [hero, row[1], row[4], got.keys()])
		m.queue_free()
		await main.get_tree().process_frame
	print("STOMP BREAK SWEEP DONE, rows: %d, failures: %d" % [rows, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## One cast of `slot` at a stomping bot; the rule is asserted on what it did.
func _trial(m: Match, hero: String, slot: String, dist: float, held: int) -> Dictionary:
	var h: Hunter = flow.hunter
	flow._ready_up(m)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != h.team)[0]
	var w: Hunter = m.hunters.filter(func(x): return x.team == h.team and x != h)[0]
	_reset(m, h, foe, w, dist)
	var seen := {}
	var hard_at_break := false
	var broke := false
	h.inp["move"] = Vector2(0, -1) if slot == "dash" else Vector2.ZERO
	Stomp.start(m, foe, w)
	for i in WATCH:
		if i == 0 or i < held:
			_hold(slot)
		else:
			_release()
		h.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		m.step(Match.DT)
		_note(m, foe, seen)
		if foe.stomp.is_empty() and not broke:
			broke = true
			hard_at_break = HARD.any(func(k): return seen.has(k))
	var tag := "%s %s (%.0f m, held %d)" % [hero, slot, dist, held]
	ok(broke == hard_at_break, "%s: stomp %s with %s on the stomper" % [tag, "broke" if broke else "held", seen.keys()])
	ok(w.downed and not w.out, "%s: the wisp lives" % tag)
	h.inp["move"] = Vector2.ZERO
	Stomp.end(m, foe, "gone")
	return seen

func _hold(slot: String) -> void:
	var h: Hunter = flow.hunter
	if slot == "dash":
		h.inp["dash"] = true
	else:
		flow._press(slot)

func _release() -> void:
	var h: Hunter = flow.hunter
	for k in ["fire", "sec", "sig", "dash", "gear1"]:
		h.inp[k] = false

## The stomper at `dist` m in front of the caster with a fresh wisp beside it, no CC left from the last cast.
func _reset(m: Match, h: Hunter, foe: Hunter, w: Hunter, dist: float) -> void:
	for x in m.hunters:
		if x != h and x != foe and x != w:
			x.teleport(h.pos + Vector3(80, 0, 80))
	if w.downed:
		m.revive_hunter(w, null)
	for kk in [w.kin, w.kin2]:
		if kk: (kk as Kin).dead = true
	foe.max_hp = 1e6          # nothing a kit does may down the stomper: that is a break of its own
	foe.hp = 1e6
	foe.armor = 0.0
	foe.shield = 0.0
	foe.stun_t = 0.0
	foe.root_t = 0.0
	foe.slow_t = 0.0
	foe.dr = {}
	foe.cc_immune_t = 0.0
	foe.launched_at = -9.0
	foe.kb_t = -9.0
	foe.set_meta("gnd_until", 0.0)
	foe.set_meta("rat_until", 0.0)
	foe.set_meta("hex_until", 0.0)
	foe.teleport(h.pos + Vector3(0, 0, -dist))
	w.teleport(foe.pos + Vector3(0.6, 0, 0))
	foe.vel = Vector3.ZERO
	m.knock(w, foe, {})

func _note(m: Match, foe: Hunter, seen: Dictionary) -> void:
	var now := {
		"stun": foe.stun_t > 0.0, "root": foe.root_t > 0.0, "gnd": KitStatus.grounded(foe),
		"daze": KitStatus.rattled(foe), "slow": foe.slow_t > 0.0, "launch": foe.launched_at > -9.0,
		"shove": foe.kb_t > -9.0, "hex": Hex.active(foe), "grap": not foe.grap.is_empty() or not foe.pad.is_empty(),
		"tow": not m.displace.towing(foe).is_empty(), "dmg": foe.hp < foe.max_hp - 0.5,
	}
	for k in now:
		if now[k]:
			seen[k] = true
