extends "res://tools/hero_pair_check.gd"
## Tarek's Quakefall (RMB) out of every glide state (DECISIONS Kits: "the glider never blocks it", as in the
## source). Runs from --dolm-combo-check, which adds n and fails. In each state the press starts the plunge on
## that step (the glider's dive speed, data 32.5 m/s down), the glider folds and stays shut with glide still held,
## and the slam lands where he does and hits the dummy there.
##   opening: the step after the glider opens; full: a second into a glide (also: sideways speed x0.25);
##   overheated: the glider burnt out and still lifting him (at half strength) out of the abyss by an island's wall,
##   pushing for land at the press (the ledge catch takes him over the lip and the slam lands on top);
##   pad: the glider opened off a jump pad's flight; updraft: a lair updraft's auto-glide (Hunter.auto_glide).

const HIGH := 8.0  # m over the strip: the glide states' start height
const ABYSS := 10  # tiles: where the strip's abyss starts (8 wide, land again beyond)
const LIP_UNDER := 1.2  # m under the lip: the overheated lift's press, inside Quakefall's void_drop (3 m)
const WALL_GAP := 0.6  # m off the island's wall for the overheated lift: pushing in at the press catches its ledge

var m: Match
var tarek: Hunter
var dummy: Hunter
var kit: DolmKit
var home: Vector3


func states(main_node: Node) -> void:
	main = main_node
	var r := setup("dolm", 5.0, ABYSS)
	m = r[0]
	tarek = r[1]
	dummy = r[2]
	home = r[3]
	kit = tarek.ak
	_slam_from("opening", _opening)
	_slam_from("full", _full)
	_slam_from("pad", _pad)
	_slam_from("updraft", _updraft)
	_slam_from("overheated", _overheated)
	await done(m)


## Puts him in the glide state with `prep` (true once there), presses RMB, then holds glide until he lands.
func _slam_from(state: String, prep: Callable) -> void:
	_reset()
	var there: bool = prep.call()
	var s0 := kit.slams
	var vx0 := absf(tarek.vel.x)
	var x := land_x() + 0.6 if tarek.over_void() else tarek.pos.x + signf(tarek.vel.x) * 0.8
	dummy.teleport(Vector3(x, home.y, tarek.pos.z + 1.0))
	fresh(dummy)
	tap(m, tarek)
	var vy := tarek.vel.y
	var started := kit.dive and kit.dive_glide and kit.ch_rmb < 1.0 and vy <= -30.0
	var folded := not tarek.gliding and not tarek.auto_glide
	var auto := tarek.auto_glide
	var vx1 := absf(tarek.vel.x)
	var fall := 0.0
	var reopened := false
	while not tarek.grounded and fall < 3.0:
		tarek.inp["glide"] = true
		m.step(DT)
		fall += DT
		reopened = reopened or (tarek.gliding and kit.dive)
	tarek.inp["glide"] = false
	tarek.inp["move"] = Vector2.ZERO
	m.step(DT)
	ok(
		"glide slam (%s): RMB plunges on the press and folds the glider" % state,
		there and started and folded and not reopened,
		(
			"in state %s, started %s (vy %.1f), folded %s (auto-glide %s), reopened %s"
			% [there, started, vy, folded, auto, reopened]
		)
	)
	ok(
		"glide slam (%s): the slam lands with him and hits" % state,
		kit.slams == s0 + 1 and tarek.grounded and dmg(dummy) > 0.0,
		"slams +%d, %.2f s down, landed %s, dummy -%.0f" % [kit.slams - s0, fall, tarek.grounded, dmg(dummy)]
	)
	if state == "full":
		ok(
			"glide slam (full): sideways speed x0.25 and down in about 0.3 s from 8 m",
			vx1 <= vx0 * 0.3 + 0.1 and fall < 0.6,
			"vx %.1f -> %.1f, %.2f s down" % [vx0, vx1, fall]
		)
	step(m, 0.8)


func _reset() -> void:
	tarek.teleport(home)
	tarek.vel = Vector3.ZERO
	tarek.auto_glide = false
	tarek.glide_fuel = 1.0
	tarek.glide_cd = 0.0
	kit.ch_rmb = 1.0
	kit.cd["rmb"] = 0.0
	for key in ["glide", "jump", "sec_hold"]:
		tarek.inp[key] = false
	tarek.inp["move"] = Vector2.ZERO
	aim_at(tarek, home + Vector3(3, 0, 0))
	step(m, 0.25)


## Glide held in the air (scripted input) until the glider opens, at most `secs`.
func _glide_until_open(secs: float) -> bool:
	var t := 0.0
	while not tarek.gliding and t < secs:
		tarek.inp["glide"] = true
		m.step(DT)
		t += DT
	return tarek.gliding


## The far island's edge, past the strip's abyss.
func land_x() -> float:
	return home.x - 0.5 + ABYSS + 8.0


func _lift(up: float) -> void:
	tarek.pos.y += up
	tarek.grounded = false


func _opening() -> bool:
	_lift(HIGH)
	return _glide_until_open(1.0)


func _full() -> bool:
	_lift(HIGH)
	tarek.inp["move"] = Vector2(1, 0)
	_glide_until_open(1.0)
	step(m, 1.0, func(): tarek.inp["glide"] = true)
	tarek.inp["move"] = Vector2.ZERO
	return tarek.gliding


## Burnt out over the abyss off the far island's wall, rising toward its lip; the move pushes for land at the press.
func _overheated() -> bool:
	tarek.teleport(Vector3(land_x() - WALL_GAP, home.y - 4.0, home.z))
	tarek.grounded = false
	tarek.glide_fuel = 0.0
	_glide_until_open(0.5)
	var t := 0.0
	while tarek.gliding and tarek.pos.y < tarek.lip_y - LIP_UNDER and t < 2.0:
		tarek.inp["glide"] = true
		m.step(DT)
		t += DT
	tarek.inp["move"] = Vector2(1, 0)
	return tarek.gliding and tarek.glide_fuel <= 0.001 and tarek.below_lip and tarek.vel.y > 0.0


## A jump pad's flight toward the abyss' near edge, broken into a glide with a jump press.
func _pad() -> bool:
	tarek.pad_launch(home + Vector3(8, 0, 0))
	step(m, 0.3)
	tarek.inp["jump"] = true
	tarek.inp["glide"] = true
	m.step(DT)
	tarek.inp["jump"] = false
	step(m, 2 * DT, func(): tarek.inp["glide"] = true)
	return tarek.gliding and tarek.pad.is_empty()


## A lair updraft's carry (lairs.gd _tick_updraft): auto_glide on, the glider cool, no glide key held.
func _updraft() -> bool:
	_lift(HIGH)
	tarek.auto_glide = true
	tarek.glide_fuel = maxf(tarek.glide_fuel, 0.8)
	step(m, 0.4)
	return tarek.gliding and tarek.auto_glide
