extends RefCounted
## --move-feel-check's fire-slow rows (docs/MOVEMENT_FEEL.d/1128-fire-slow.md): per Hunter and move, the share of
## that Hunter's own plain run while firing, charging, casting or carrying, keys held on the real match step,
## against ours in the data (the weapon's fire_slow/draw_slow, the kit's rows). The reference numbers are the
## catalog's (sv-refs CATALOG-13-1127 pattern 6 and the hero sections); where it names one, the data now holds it.
## Gil is ours on purpose, by the owner's rule, and has no row. One blended move, no sprint: each row is one share of
## the one run, never a second gait.

const SETTLE_STEPS := 30  # after the kit swap: a swap slows the walk (x0.8) for its first 0.25 s
const RUN_STEPS := 30  # the run-up to full speed before the move starts
const MEASURE := 6  # frames averaged for the share
const TOL := 0.02  # x: the measured share of the run against the data's
const MULT_TOL := 0.01  # x: the hunter's move multiplier (every slow on him, multiplied) against the data's
const KICKED := 0.1  # x: how far under the data a kicking weapon's share may sit (each shot shoves him back)
const KICKS := {"dredge": "the shotgun's kick (0.16) pushes him back on each shot"}

var c  # the move-feel check (its hunter, match and ok)
var h: Hunter
var mate: Hunter  # the carry row's teammate
var mate_team := 0


func _init(check) -> void:
	c = check
	h = check.p_v


## Each row: hunter id, move, the input held, frames into the move before measuring, ours in the data (a _want
## path, read after the swap), an optional start (called once the run-up is done; it may hold its own keys) and end.
func _rows() -> Array:
	return [
		["archer", "LMB draw", "fire", 30, "wpn:draw_slow:0.7"],
		["archer", "RMB Heavy Shot hold", "sec", 30, "rmb:pin.hold_move"],
		["ashwick", "LMB Open Flame", "fire", 30, "full"],
		["ashwick", "E Furnace Cloak spin", "", 15, "e:spin_move", _press("sig")],
		["bulwark", "RMB Brightshield held", "sec", 30, "rmb:shield.slow"],
		["bulwark", "Brightshield broken", "", 10, "rmb:shield.break_move", _break_shield],
		["dolm", "LMB punch hold", "fire", 34, "wpn:fire_slow:0.8"],
		["dolm", "RMB Quakefall charge", "sec", 12, "rmb:slam.walk_k"],
		["dredge", "LMB Broadside fire", "fire", 30, "wpn:fire_slow:0.8"],
		["gunslinger", "LMB Brass Tacks", "fire", 30, "wpn:fire_slow:0.8"],
		["juggernaut", "RMB Lunge charge", "sec", 30, "rmb:lunge.walk_k"],
		["juggernaut", "Lunge missed", "", 12, "rmb:lunge.miss_move", _miss_lunge],
		["mage", "LMB Finger Guns", "fire", 30, "wpn:fire_slow:0.8"],
		["mage", "RMB Storm Rod hold", "sec", 40, "rmb_less:self_slow"],
		["ostra", "LMB", "fire", 30, "wpn:fire_slow:0.8"],
		["rimewright", "LMB Ice Darts", "fire", 30, "full"],
		["tender", "LMB Ember Cast", "fire", 30, "wpn:fire_slow:0.8"],
		["tender", "RMB Burrseed wind-up", "sec", 10, "rmb:wind_move"],
		["tender", "Carrier: carrying a teammate", "", 20, "passive:carry_move", _carry, _uncarry],
		["thief", "LMB Sleight Trigger", "fire", 30, "wpn:fire_slow:0.8"],
	]


## Ours for a row, from the data: "full" (1.0), "wpn:<key>:<default>" (the weapon), "rmb:<dotted path>",
## "rmb_less:<key>" (1 minus it: a slow given as the share taken off), "e:<key>" or "passive:<key>" (the kit).
func _want(spec: String) -> float:
	var parts := spec.split(":")
	match parts[0]:
		"full":
			return 1.0
		"wpn":
			return float(h.wpn.get(parts[1], float(parts[2])))
		"rmb_less":
			return 1.0 - float(h.ak.rmb_def()[parts[1]])
	var node: Variant = {"rmb": h.ak.rmb_def(), "e": h.ak.e_def(), "passive": h.ak.d["passive"]}[parts[0]]
	for k in parts[1].split("."):
		node = (node as Dictionary)[k]
	return float(node)


func run() -> void:
	var cls_was := h.cls
	var arch_was := h.arch
	var wid_was := h.wid
	for row in _rows():
		_row(row)
	h.reclass(cls_was, arch_was, wid_was)
	for a in [c.m.shots, c.m.zones, c.m.fields, c.m._later]:
		a.clear()
	c._reset(c.flat)


func _row(row: Array) -> void:
	var id: String = row[0]
	h.reclass(Arch.weight(id), id)
	c._reset(c.flat + Vector3(-3.0, 0, 0))
	c._steps(SETTLE_STEPS)
	c._reset(c.flat + Vector3(-3.0, 0, 0))
	h.inp["move"] = Vector2(1, 0)
	_aim_steps(RUN_STEPS)
	var key: String = row[2]
	_hold(key, true)
	if row.size() > 5:
		(row[5] as Callable).call()
	_aim_steps(int(row[3]))
	var sum := 0.0
	var mult := 0.0
	for i in MEASURE:
		_aim_steps(1)
		# over his unslowed run this frame: the bonuses add (a kin passive may switch on mid-row), slows multiply
		var run := HunterMove.ground_speed(
			h.base_speed, HunterMove.speed_bonus(h, h.inp["move"]), 1.0
		)
		sum += (c._hv(h) as Vector2).length() / run
		mult += h._move_mult()
	var share := sum / MEASURE
	mult /= MEASURE
	var want := _want(row[4])
	var low := want - (KICKED if KICKS.has(id) and key == "fire" else TOL)
	c.ok(
		absf(mult - want) <= MULT_TOL and share >= low and share <= want + TOL,
		"fire_slow %-10s %-28s x%.3f, %.3f of the run (data %.2f)" % [id, row[1], mult, share, want]
	)
	if row.size() > 6:
		(row[6] as Callable).call()
	_hold(key, false)
	h.inp["sig"] = false
	_aim_steps(20)  # let the move end before the next swap


## Hold or let go of an input; RMB is the press plus its hold flag (as the input gather sends them).
func _hold(key: String, on: bool) -> void:
	if key != "":
		h.inp[key] = on
	if key == "sec":
		h.inp["sec_hold"] = on


## Steps with the aim held 4 m ahead along +x, the run's way.
func _aim_steps(n: int) -> void:
	for i in n:
		h.inp["aim"] = h.pos + Vector3(4.0, 0, 0)
		c.m.step(c.DT)


## A one-frame press of `key`.
func _press(key: String) -> Callable:
	return func() -> void:
		h.inp[key] = true
		_aim_steps(1)
		h.inp[key] = false


## Raise the Brightshield, then break it (its wall gone from the match, as when its health runs out).
func _break_shield() -> void:
	_hold("sec", true)
	_aim_steps(20)
	c.m.verbs.walls.erase(h.ak.wall)
	_aim_steps(1)
	_hold("sec", false)


## Charge the Lunge to full, let go into empty ground, and wait for it to end (the miss).
func _miss_lunge() -> void:
	_hold("sec", true)
	_aim_steps(60)
	_hold("sec", false)
	for i in 60:
		_aim_steps(1)
		if h.ak.lunge.is_empty():
			break
	h.inp["move"] = Vector2(1, 0)


## A downed teammate on Meeko's shoulder (CareUtil.set_carry, as her Carrier pickup does).
func _carry() -> void:
	for o in c.m.hunters:
		if o != h:
			mate = o
			break
	mate_team = mate.team
	mate.team = h.team
	mate.downed = true
	CareUtil.set_carry(c.m, mate, h.nid)


## Set the teammate down again and send them back out of the way.
func _uncarry() -> void:
	CareUtil.set_carry(c.m, mate, "")
	mate.downed = false
	mate.team = mate_team
	mate.teleport(Vector3(-500, 50, -500))
