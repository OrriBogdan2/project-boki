extends "res://tools/archer_bulwark_combo_check.gd"
## --mob-cc-check: Hunter abilities work on monsters the way they work on Hunters (the source's PvE).
## One CC or displacement ability of every kit is cast at a Hunter dummy (the control), a skitter, a
## brute and a lair boss. A monster never feels less than the control does: a stun, root, slow, Grounded
## or Daze that lands on the Hunter lands on it, a knock moves it (by Mass), and a displacement only
## ever moves it less than the Hunter. Prints MOBCC rows (the table in docs/KIT_PARITY.md) and ends
## with MOBCC DONE. Mass: skitter 1, brute 3, boss 80 (Mob.mass, Boss.mass); the Hunter's is 1.

const KINDS := ["hunter", "skitter", "brute", "boss"]
const STATUSES := ["stun", "root", "slow", "gnd", "dazed"]
const FOCUS := 1.0e6                 # hp: nothing dies or changes phase mid-test
const NOTHING := 0.05                # s / m: below this a status or a move did not happen
const NOTHING_SLOW := 0.5            # s: a shorter slow is the Hunter's own hit stagger (Oomph), not the kit's
## kit, ability, cast (e, x, dash, rmb, rmb:<hold s>, joined with +), start gap (m), run time (s), wall
## (x offset of a raised block from the target, 0 = none), how it moves a body: knock (an impulse, scaled by Mass),
## pull (a tow or a shove aside: the same for all) or gate (a pull an old mass >= 6 gate keeps off bosses)
const CASES := [
	["archer", "Heavy Shot hold: knock, wall stun", "rmb:1.2", 7.0, 1.5, 1, "knock"],
	["ashwick", "Furnace Cloak pull", "e", 4.0, 1.0, 0, "gate"],
	["ashwick", "Soot Ram knock", "dash", 3.0, 0.8, 0, "knock"],
	["bulwark", "Shield Charge: knock, stun", "rmb:0.3+dash", 3.0, 1.5, 0, "knock"],
	["bulwark", "Faultline stun, slow", "x", 4.0, 1.5, 0, "knock"],
	["dolm", "Quakefall knock", "rmb:0.3", 3.0, 1.5, 0, "knock"],
	["dolm", "Basalt Spine slow", "x", 5.0, 1.5, 0, "pull"],
	["dredge", "Abyssal Hand pull", "rmb", 7.0, 2.0, 0, "gate"],
	["dredge", "Anchor Drop stun", "e", 2.0, 1.5, 0, "knock"],
	["gunslinger", "Burr direct hit, Daze", "rmb", 6.0, 1.5, 0, "knock"],
	["gunslinger", "Burr cone: push, Daze, wall stun", "burr_cone", 0.0, 1.0, -3, "knock"],
	["juggernaut", "Smash push", "rmb", 3.0, 1.5, 0, "knock"],
	["mage", "Storm Rod hold: knock, wall stun", "rmb:1.1", 5.0, 1.5, 2, "knock"],
	["mage", "Skycall Grounded, drag", "e", 6.0, 2.0, 0, "pull"],
	["ostra", "Shard Snap slow", "rmb", 5.0, 1.5, 0, "knock"],
	["ostra", "Nightwell stun, pull", "x", 6.0, 2.0, 0, "pull"],
	["rimewright", "Rink Wall push", "e", 4.0, 1.5, 0, "pull"],
	["rimewright", "Rimelock stun", "x", 4.0, 4.2, 0, "knock"],
	["tender", "Burrseed root", "rmb", 5.0, 2.6, 0, "knock"],
	["thief", "Bola Grounded, slow", "rmb", 5.0, 1.5, 0, "knock"],
]

var rows: Dictionary = {}            # "kit|ability|kind" -> {stun, root, slow, gnd, dazed, moved}
var _m: Match
var _p: Hunter
var _tgt: Ent
var _spot: Vector3
var _rec := {}

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("mob_cc_check", self)      # (a RefCounted that awaits frames must be kept alive)
	var kits := {}
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--cc-kit="): only = String(a).substr(9)      # one kit only (debugging)
	for c in CASES:
		if only != "" and c[0] != only:
			continue
		for kind in KINDS:
			await _run_case(c, kind)
		kits[c[0]] = true
		_compare(c)
	ok("every kit has a case", kits.size() == 12 or only != "", "%d kits" % kits.size())
	print("MOBCC DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _run_case(c: Array, kind: String) -> void:
	var r := setup(String(c[0]), float(c[3]), "", false)
	_m = r[0]
	_p = r[1]
	var home: Vector3 = r[4]
	_spot = home + Vector3(float(c[3]), 0, 0)
	_tgt = _make_target(kind, r[2])
	if int(c[5]) != 0:
		_wall_at(_m, _spot, r[5], int(c[5]))
	_rec = {"stun": 0.0, "root": 0.0, "slow": 0.0, "gnd": 0.0, "dazed": 0.0, "moved": 0.0}
	var K: ArchKit = _p.ak
	_p.ult = 1.0
	_p.dashes = _p.max_dashes()
	K.ch_rmb = 3.0
	for slot in K.cd:
		K.cd[slot] = 0.0
	_cast(K, String(c[2]))
	_frames(float(c[4]), false)
	rows["%s|%s|%s" % [c[0], c[1], kind]] = _rec
	print("MOBCC %-10s %-34s %-8s stun %.2f root %.2f slow %.2f gnd %.2f dazed %.2f moved %.2f m" % [
		c[0], c[1], kind, _rec["stun"], _rec["root"], _rec["slow"], _rec["gnd"], _rec["dazed"], _rec["moved"]])
	await done(_m)

## The target at the spot: the dummy Hunter itself, or a monster that stands still (speed 0, huge hp).
func _make_target(kind: String, dummy: Hunter) -> Ent:
	if kind == "hunter":
		return dummy
	dummy.teleport(_spot + Vector3(0, 0, 9.0))
	var mb: Mob
	var lair := {"c": _spot, "half": 9, "state": "awake"}
	if kind == "boss":
		var b := Boss.new()
		b.init_boss(_m, _m.next_id("b"), "colossus", _spot, 1.0, lair)
		_m.add_child(b)
		_m.mobs.append(b)
		_m.ents_by_id[b.nid] = b
		b.dormant = false
		b.next_cd = 1.0e9
		mb = b
	else:
		mb = _m.spawn_mob(kind, _spot)
	_spot.x += mb.r - dummy.r      # (the same gap to its surface: a boss is wide)
	lair["c"] = _spot
	mb.md = mb.md.duplicate()
	mb.md["speed"] = 0.0
	mb.max_hp = FOCUS
	mb.hp = FOCUS
	mb.teleport(_spot)
	return mb

func _cast(K: ArchKit, spec: String) -> void:
	for step_spec in spec.split("+"):
		var parts := step_spec.split(":")
		match parts[0]:
			"e":
				K.use_e()
			"x":
				HunterKeys.ult_pressed(_p)
			"dash":
				_p.do_dash()
			"burr_cone":      # the blast of a Burr stuck 2 m past the target, as if it had hit the wall there
				var gs: GunslingerKit = _p.ak
				gs._cone(_spot + Vector3(2.0, 0, 0), Vector2(-1, 0), gs.rmb_def()["burr"], true)
			"rmb":
				if parts.size() > 1:
					_p.inp["sec_hold"] = true
					K.press_rmb()
					_frames(float(parts[1]), true)
					if "+" not in spec:
						_p.inp["sec_hold"] = false
				else:
					K.press_rmb()
		_m.step(DT)
	_p.inp["sec_hold"] = false

## Runs `secs`, aimed at the target, recording the most of each status and the farthest it was moved.
func _frames(secs: float, hold: bool) -> void:
	var t := 0.0
	while t < secs:
		aim_at(_p, _tgt.pos if is_instance_valid(_tgt) else _spot)
		if hold:
			_p.inp["sec_hold"] = true
		_m.step(DT)
		t += DT
		_rec["stun"] = maxf(_rec["stun"], _tgt.stun_t)
		_rec["root"] = maxf(_rec["root"], _tgt.root_t)
		_rec["slow"] = maxf(_rec["slow"], _tgt.slow_t)
		_rec["gnd"] = maxf(_rec["gnd"], float(_tgt.get_meta("gnd_until", 0.0)) - _m.time)
		_rec["dazed"] = maxf(_rec["dazed"], KitStatus.rattled_left(_tgt))
		_rec["moved"] = maxf(_rec["moved"], Vector2(_tgt.pos.x - _spot.x, _tgt.pos.z - _spot.z).length())

## A monster feels what the Hunter control felt: every kit status that landed there lands here (a slow
## under NOTHING_SLOW is only the Hunter's own hit stagger), and a knock moves it by Mass: the skitter
## (1) like the Hunter, the brute (3) less, the boss (80) hardly. Pulls move all but an old mass gate.
func _compare(c: Array) -> void:
	var tag := "%s %s" % [c[0], c[1]]
	var ctl: Dictionary = _row(c, "hunter")
	var did := false
	for k in STATUSES + ["moved"]:
		did = did or float(ctl[k]) > _least(k)
	ok("%s: lands on the Hunter control" % tag, did)
	for kind in ["skitter", "brute", "boss"]:
		var row: Dictionary = _row(c, kind)
		if kind == "boss" and c[6] == "gate":
			continue
		for k in STATUSES:
			if float(ctl[k]) > _least(k):
				ok("%s: %s on a %s" % [tag, k, kind], float(row[k]) > NOTHING, "%.2f vs %.2f" % [row[k], ctl[k]])
		if float(ctl["moved"]) > 0.5 and int(c[5]) == 0:      # (a wall stops the move: its stun is the check)
			var least := 0.002 if kind == "boss" and c[6] == "knock" else NOTHING
			ok("%s: moves a %s" % [tag, kind], float(row["moved"]) > least, "%.2f m" % row["moved"])
	var sk := float(_row(c, "skitter")["moved"])
	var br := float(_row(c, "brute")["moved"])
	var bo := float(_row(c, "boss")["moved"])
	if sk > 0.5 and c[6] == "knock" and int(c[5]) == 0:
		ok("%s: heavier moves less" % tag, br < sk and bo < br, "%.2f %.2f %.2f" % [sk, br, bo])

func _row(c: Array, kind: String) -> Dictionary:
	return rows["%s|%s|%s" % [c[0], c[1], kind]]

## The least a status or a move counts for.
func _least(k: String) -> float:
	return NOTHING_SLOW if k == "slow" else NOTHING
