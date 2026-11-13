extends RefCounted
## --yaw-lock-check: does the body turn freely, slowly or not at all while each Hunter's slot runs? For every
## Hunter and slot (LMB hold, RMB, E, X and the E/X recasts) the cursor sits east at the press and swings 90
## degrees mid-cast (north) and again later (west); the body's turn over each window must match the slot's row in
## the kit JSON's "turn" block (ArchKit.turn_rule, the table in docs/heroes/dash_interactions.md).
## --yaw-lock-check=<id>,<id> runs only those Hunters.

const DT := 1.0 / 60.0
const HEROES := [
	"juggernaut",
	"thief",
	"archer",
	"bulwark",
	"mage",
	"gunslinger",
	"ashwick",
	"dredge",
	"tender",
	"rimewright",
	"dolm",
	"ostra"
]
const SLOTS := ["lmb", "rmb", "e", "x", "e_recast", "x_recast"]
const PRESS_AT := 20  # frame of the recast press (0.33 s after the first)
const HOLD_F := 30  # frames a held slot (LMB, RMB) stays down
const WINDOWS := {"early": [6, 20], "late": [32, 46]}  # frames: the sweep, then the reading
const FREE_DEG := 60.0  # a free body follows a 90 degree sweep by at least this much in 0.23 s
const LOCK_DEG := 3.0  # a locked body moves no more than this (rounding, a knock)
## Where the rival stands from the Hunter: east (where every slot is aimed at the press) at FOE_DEFAULT m. Dredge's
## hand leaves after its 0.2 s coil-back along the aim then (the early sweep's north), and close enough that it
## lands before the late window, so his reel is hauling through it.
const FOE_AT := {"dredge": Vector3(0, 0, -5.0)}
const FOE_DEFAULT := Vector3(5.0, 0, 0)
const SLOW_GAP := 3.0  # a capped turn: more than locked, no more than deg_s x window plus this

var bad := 0
var skipped := 0


func ok(cond: bool, what: String) -> void:
	print("YAWLOCK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	(
		m
		. start(
			{
				"training": true,
				"teams": 2,
				"squad": 1,
				"tier": 0,
				"length": 1e9,
				"seed": 77,
				"no_drop": true,
				"cls": Arch.weight(arch),
				"arch": arch,
				"weapon": Arch.signature(arch),
			}
		)
	)
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var w: World = m.world
	var cx := int(floor(P.pos.x))
	var cz := int(floor(P.pos.z))
	var home_i: int = w.idx(cx, cz)
	var level: int = int(w.level[home_i]) if w.kind[home_i] != World.T_VOID else 0
	for dz in range(-24, 25):
		for dx in range(-24, 25):
			if not w.inb(cx + dx, cz + dz):
				continue
			var i: int = w.idx(cx + dx, cz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = level
			w.island[i] = w.island[home_i]
			w.walls.erase(i)
			w.props.erase(i)
			w.stairs.erase(i)
	P.teleport(Vector3(cx + 0.5, level * World.LEVEL, cz + 0.5))
	P.set_arch(arch)
	P.unlock_all()
	P.lvl = 6
	var foe_set := false
	for other in m.hunters:
		if other == P:
			continue
		other.ctrl = "idle"
		# one rival where the slot lands (a hook, a grab or a step needs someone to land on)
		var at: Vector3 = FOE_AT.get(arch, FOE_DEFAULT)
		other.teleport(P.pos + (at if not foe_set and other.team != P.team else Vector3(40, 0, 40)))
		foe_set = foe_set or other.team != P.team
	for i in 20:
		_aim(P, Vector2(1, 0))
		m.step(DT)
	return m


func _aim(P: Hunter, d: Vector2) -> void:
	P.inp["aim"] = P.pos + Vector3(d.x, 0.0, d.y) * 8.0 + Vector3(0, 0.9, 0)


func _press(P: Hunter, slot: String) -> void:
	match slot:
		"rmb":
			P.inp["sec"] = true
		"e", "e_recast":
			P.inp["sig"] = true
		"x", "x_recast":
			HunterKeys.ult_pressed(P)


## The most the body turned from where it was at each window's sweep: {"early": deg, "late": deg}.
func probe(m: Match, slot: String) -> Dictionary:
	var P: Hunter = m.player
	var out := {}
	var face0 := 0.0
	var aims := {"early": Vector2(0, -1), "late": Vector2(-1, 0)}
	var aim := Vector2(1, 0)
	var before := _spent(P)
	_press(P, slot)
	for f in 60:
		P.inp["fire"] = slot == "lmb" and f < HOLD_F
		P.inp["sec_hold"] = slot == "rmb" and f < HOLD_F
		if f == PRESS_AT and slot.ends_with("_recast"):
			_press(P, slot)
		for wname in WINDOWS:
			var win: Array = WINDOWS[wname]
			if f == int(win[0]):
				aim = aims[wname]
				face0 = P.face
			if f > int(win[0]) and f <= int(win[1]):
				var turned := absf(rad_to_deg(angle_difference(face0, P.face)))
				out[wname] = maxf(float(out.get(wname, 0.0)), turned)
		_aim(P, aim)
		m.step(DT)
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	out["went"] = slot == "lmb" or _spent(P) != before
	return out


## What the slots have spent so far (a press that went off changes it).
func _spent(P: Hunter) -> String:
	return str([P.used, P.ak.cd, P.ak.ch_rmb, P.ak.rmb_t, HeroUlt.cast_id(P.ak)])


## Does a turn of `deg` over a window match `rule` ("free", "locked" or a deg/s cap)?
func matches(rule, deg: float) -> bool:
	if rule is String and rule == "free":
		return deg >= FREE_DEG
	if rule is String and rule == "locked":
		return deg <= LOCK_DEG
	var cap := float(rule) * float(WINDOWS["early"][1] - WINDOWS["early"][0]) * DT
	return deg > LOCK_DEG and deg <= cap + SLOW_GAP


func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--yaw-lock-check=") and arg.length() > 17:
			return arg.substr(17).split(",")
	return HEROES


func run(main: Node) -> void:
	Save.no_write = true
	for arch in _heroes():
		for slot in SLOTS:
			var m := _match(main, arch)
			var r := probe(m, slot)
			var want: Dictionary = m.player.ak.turn_rule(slot)
			if not r["went"]:
				print("YAWLOCK skip %-10s %-8s did not go off here" % [arch, slot])
				skipped += 1
				m.queue_free()
				await main.get_tree().process_frame
				continue
			for wname in WINDOWS:
				var rule = want[wname]
				ok(
					matches(rule, float(r[wname])),
					"%-10s %-8s %-5s turned %5.1f deg, row says %s" % [arch, slot, wname, float(r[wname]), str(rule)]
				)
			m.queue_free()
			await main.get_tree().process_frame
	print("YAWLOCK DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit(1 if bad > 0 else 0)
