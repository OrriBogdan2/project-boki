extends RefCounted
## --dash-flow-check: for every hero, every dash -> ability pair does what its row in content/dash_flow says
## (DashFlow): pressed early in the dash and on its last step, on the ground and in the air, the ability goes off
## mid-dash ("fire"), at the dash's end ("buffer"), or ends the dash and goes off at once ("cancel"), and the press
## is never lost. A dash the file lists in kit_owns must stay out of DashFlow's sight, and every other one in it.
## It walks DashFlow.SLOTS for every hero, so rows added later are covered. Never touches the save.

const QUIET_MAX := 900          # steps: the last trial's ability (an ult, a zone) winds down first
const DASH_WAIT := 40           # steps: a dash with a wind-up shows up within this
const WATCH := 120              # steps after the press that we watch for the ability
const GLOVE := "barrier"        # Q: an active glove that stays where it's cast

var bad := 0
var skipped := 0
var cast_n := {}                # CombatBus slot name -> casts by the hunter under test
var hunter: Hunter
var wait_s := 0.0               # how long after the dash's end a buffered press went off

func ok(cond: bool, what: String) -> void:
	print("DASHFLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	for hero in Arch.ORDER:
		for slot in DashFlow.SLOTS:
			var m := _match(main, hero)
			_slot(m, hero, slot)
			m.queue_free()
			await main.get_tree().process_frame
	print("DASHFLOW DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

func _on_used(caster: Node, _ability: String, slot: String) -> void:
	if caster == hunter:
		cast_n[slot] = int(cast_n.get(slot, 0)) + 1

func _slot(m: Match, hero: String, slot: String) -> void:
	for in_air in [false, true]:
		if not _goes_idle(m, slot, in_air):
			skipped += 1
			print("DASHFLOW skip %s %s %s: it doesn't go off without a dash here either" % [
					hero, "air" if in_air else "ground", slot])
			continue
		var want := String(DashFlow.row_of(hero, slot, in_air)["mode"])
		var owned: bool = ("air" if in_air else "ground") in DashFlow.file_of(hero).get("kit_owns", [])
		for late in [false, true]:
			var what := "%s %s dash -> %s, pressed %s" % [hero, "air" if in_air else "ground", slot,
					"on its last step" if late else "early"]
			var got := _trial(m, slot, in_air, late)
			if owned or got == "n/a":
				ok(owned == (got == "n/a"), "%s: %s, kit_owns %s" % [what, got, "lists it" if owned else "doesn't"])
				continue
			# on the dash's last step a cancel can't be told from a fire: the dash ends there either way
			var at_end_same: bool = late and got in ["fire", "cancel"] and want in ["fire", "cancel"]
			var waited := " %.2fs after the dash" % wait_s if got == "buffer" else ""
			ok(got == want or at_end_same, "%s: %s%s (row: %s)" % [what, got, waited, want])

## A fresh training match as `hero` on a flat patch, every slot open, a glove on Q, level 10.
func _match(main: Node, hero: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	hunter = m.player
	var world: World = m.world
	var cx := int(floor(hunter.pos.x))
	var cz := int(floor(hunter.pos.z))
	var home_i: int = world.idx(cx, cz)
	var level: int = int(world.level[home_i]) if world.kind[home_i] != World.T_VOID else 0
	for dz in range(-24, 25):
		for dx in range(-24, 25):
			if not world.inb(cx + dx, cz + dz):
				continue
			var i: int = world.idx(cx + dx, cz + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = level
			world.island[i] = world.island[home_i]
			world.walls.erase(i)
			world.props.erase(i)
			world.stairs.erase(i)
	hunter.teleport(Vector3(cx + 0.5, level * World.LEVEL, cz + 0.5))
	hunter.set_arch(hero)
	hunter.unlock_all()
	hunter.lvl = 10
	hunter.gear[0] = {"id": GLOVE, "rar": 1}
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	set_meta("home", hunter.pos)
	_steps(m, 20)
	return m

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(Match.DT)

## Waits out the last trial (its dash, E, R, ult, held RMB), then puts the hunter back home, everything ready.
func _ready_up(m: Match) -> void:
	var k := hunter.ak
	for i in QUIET_MAX:
		var busy := k.e_t > 0.0 or k.r_t > 0.0 or not k.fuse.is_empty() or k.rmb_down or k.ult_running()
		if not busy and hunter.roll_t <= 0.0 and k.dash_left() <= 0.0 and hunter.grounded and i > 30:
			break
		m.step(Match.DT)
	hunter.teleport(get_meta("home"))
	hunter.vel = Vector3.ZERO
	hunter.hp = hunter.max_hp
	hunter.stun_t = 0.0
	for key in k.cd:
		k.cd[key] = 0.0
	k.ch_rmb = float(k.rmb_charges())
	hunter.gear_cd[0] = 0.0
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.fire_cd = 0.0
	hunter.reload_t = 0.0
	hunter.ammo = maxi(hunter.ammo, int(hunter.wpn.get("mag", 0)))
	hunter.inp["move"] = Vector2.ZERO
	hunter.inp["fire"] = false
	hunter.inp["aim"] = hunter.pos + Vector3(0, 0.9, -6)
	_steps(m, 2)

## Control: the slot goes off when pressed without a dash, on the ground or up in the air (some need ground in
## reach or a target the trial doesn't set up).
func _goes_idle(m: Match, slot: String, in_air: bool) -> bool:
	_ready_up(m)
	if in_air:
		_lift()
	var before := _snap()
	_press(slot)
	for i in 30:
		m.step(Match.DT)
		hunter.inp["fire"] = false
		if _went_off(before, slot):
			return true
	return false

## One press during one dash: "fire" (went off mid-dash), "cancel" (went off at once and the dash stopped),
## "buffer" (held, then went off once the dash was over: a kit's own recovery after its dash can delay it), "lost",
## or "n/a" (no dash DashFlow sees).
func _trial(m: Match, slot: String, in_air: bool, late: bool) -> String:
	_ready_up(m)
	if in_air:
		_lift()
	hunter.inp["move"] = Vector2(0, -1)
	hunter.inp["dash"] = true
	var n := 0
	while not hunter.ak.in_dash() and n < DASH_WAIT:
		m.step(Match.DT)
		n += 1
	if not hunter.ak.in_dash():
		return "n/a"
	while late and hunter.ak.dash_left() > Match.DT * 1.5 and n < 300:
		m.step(Match.DT)
		n += 1
	var dash_left := hunter.ak.dash_left()
	var before := _snap()
	_press(slot)
	m.step(Match.DT)
	hunter.inp["fire"] = false
	if _went_off(before, slot):
		var stopped := not hunter.ak.in_dash() and dash_left > Match.DT * 2.5
		return "cancel" if stopped else "fire"
	var ended := -1
	for i in WATCH:
		var dashing := hunter.ak.in_dash()
		if not dashing and ended < 0:
			ended = i
		m.step(Match.DT)
		if _went_off(before, slot):
			wait_s = float(i - ended) * Match.DT
			return "fire" if dashing else "buffer"
	return "lost"

func _lift() -> void:
	hunter.pos += Vector3(0, 7, 0)
	hunter.grounded = false

func _press(slot: String) -> void:
	match slot:
		"lmb":
			hunter.inp["fire"] = true      # a tap: one step down
		"x":
			HunterKeys.ult_pressed(hunter)
		_:
			hunter.inp[DashFlow.KEY_OF[slot]] = true

## What a press leaves behind, to tell whether it went off.
func _snap() -> Dictionary:
	var k := hunter.ak
	return {
		"cd": k.cd.duplicate(), "ch": k.ch_rmb, "rmb_down": k.rmb_down, "e_t": k.e_t, "used": hunter.used.duplicate(),
		"gear": float(hunter.gear_cd[0]), "fire_cd": hunter.fire_cd, "swing": hunter.swing_t, "draw": hunter.draw_t,
		"mel": hunter.mel_hold, "ammo": hunter.ammo, "cast": cast_n.duplicate(), "shots": _last_shot(),
	}

## The id of the newest shot of the hunter's still in flight (a kit's own LMB, like darts, keeps no fire_cd).
func _last_shot() -> int:
	var last := -1
	for s in hunter.m.shots:
		if s["by"] == hunter:
			last = maxi(last, int(s["sid"]))
	return last

func _went_off(b: Dictionary, slot: String) -> bool:
	var now := _snap()
	var up := func(key: String) -> bool: return float(now[key]) > float(b[key]) + 0.0001
	var more := func(dict: String, key: String) -> bool:
		return float(now[dict].get(key, 0)) > float(b[dict].get(key, 0)) + 0.0001
	match slot:
		"lmb":
			var drew: bool = float(b["draw"]) < 0.0 and float(now["draw"]) >= 0.0
			return up.call("fire_cd") or up.call("swing") or up.call("mel") or up.call("shots") or drew \
					or int(now["ammo"]) < int(b["ammo"])
		"rmb":
			return more.call("used", "utility") or more.call("cd", "rmb") or more.call("cast", "secondary") \
					or float(now["ch"]) < float(b["ch"]) or (bool(now["rmb_down"]) and not bool(b["rmb_down"]))
		"e":
			return more.call("used", "k1") or more.call("cd", "e") or up.call("e_t") or more.call("cast", "kin")
		"x":
			return more.call("used", "x") or more.call("cd", "x") or more.call("cast", "ultimate")
		"q":
			return up.call("gear")
	return false
