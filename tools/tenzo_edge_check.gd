extends "res://tools/hero_pair_check.gd"
## --tenzo-edge-check: Tenzo's Quakefall (RMB) off a ledge never dunks him. On a small platform with open abyss
## all round, he uses it off the edge every way it can go there: tapped in the air after walking or running off,
## after a jump off, in a glide off it, the hold's hop off the rim, a charge carried off the rim and let go in the
## air; four directions, cursor level with the ledge, deep in the void and high. Each run asserts he never
## reaches the point of no return, ends the move lower than he started (the hop: no higher) but at least
## RECOVER_ROOM above that line, and then gets back onto the platform with the glider (glide held, steering home).

## The least room (m) above the point of no return the plunge must leave him (Hunter.abyss_kill_y).
const RECOVER_ROOM := 6.0
const PLATFORM_R := 2          # tiles from the centre that stay ground
const VOID_R := 24             # tiles of abyss round it
const DIRS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
const PITCHES := {"level": 0.0, "down": -8.0, "up": 5.0}      # cursor height (m) over the ledge
const MODES := ["walk_tap", "run_tap", "jump_tap", "glide_tap", "hop", "carry"]

var m: Match
var P: Hunter
var K: DolmKit
var home: Vector3

func run(main_node: Node) -> void:
	main = main_node
	var r := setup("dolm", 5.0)
	m = r[0]
	P = r[1]
	K = P.ak
	home = r[3]
	var T: Hunter = r[2]
	_island(T)
	for mode in MODES:
		for pitch in PITCHES:
			var bad: Array = []
			for dir in DIRS:
				var res := _edge(mode, dir, float(PITCHES[pitch]))
				if not res["ok"]: bad.append("%s %s" % [dir, res["info"]])
			ok("edge %s, cursor %s: alive, lower, room to recover, back on" % [mode, pitch], bad.is_empty(),
				"; ".join(bad))
	print("PAIRCHECK tenzo-edge DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Only a small platform round home is ground; the abyss runs VOID_R tiles every way. The dummy waits on it.
func _island(T: Hunter) -> void:
	var W: World = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-VOID_R, VOID_R + 1):
		for dx in range(-VOID_R, VOID_R + 1):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			var keep := absi(dx) <= PLATFORM_R and absi(dz) <= PLATFORM_R
			W.kind[i] = World.T_GROUND if keep else World.T_VOID
			W.walls.erase(i)
			W.props.erase(i)
	W._aref = PackedFloat32Array()      # the abyss lips are cached per tile
	T.teleport(home + Vector3(-1.5, 0, -1.5))
	T.max_hp = 1e9
	T.hp = T.max_hp

func _reset() -> void:
	P.out = false
	P.downed = false
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.gliding = false
	P.glide_fuel = 1.0
	P.glide_cd = 0.0
	P.roll_t = 0.0
	P.fly_t = 0.0
	P.hp = P.max_hp
	K.drop_holds()
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	for key in ["fire", "sec_hold", "jump", "glide", "crouch"]: P.inp[key] = false
	P.inp["move"] = Vector2.ZERO
	step(m, 0.2)

## One run off the edge toward `dir`: the move, then the recovery. {ok, info}.
func _edge(mode: String, dir: Vector2, pitch: float) -> Dictionary:
	_reset()
	var far := home + Vector3(dir.x, 0, dir.y) * 8.0
	P.inp["aim"] = far + Vector3(0, pitch + 0.9, 0)
	P.inp["aim_y"] = far.y + pitch
	var y0 := home.y
	var low := [INF]          # the least room over the point of no return, from the press on
	var fell := [false]       # put back by the abyss: a jump of metres in one step
	var watch := func(was: Vector3):
		if P.out or P.pos.distance_to(was) > 3.0: fell[0] = true
		if P.over_void() and not P.grounded: low[0] = minf(low[0], P.pos.y - P.abyss_kill_y())
	# off the rim
	if mode == "hop":
		P.teleport(home + Vector3(dir.x, 0, dir.y) * (PLATFORM_R + 0.3))
		step(m, 0.1)
		hold(m, P, 0.45)
	elif mode == "carry":
		P.teleport(home + Vector3(dir.x, 0, dir.y) * (PLATFORM_R + 0.2))
		P.inp["sec_hold"] = true
		P.ak.press_rmb()
		P.inp["move"] = dir
		var t := 0.0
		while P.grounded and t < 2.0:
			P.inp["sec_hold"] = true
			m.step(DT)
			t += DT
		P.inp["sec_hold"] = false
		m.step(DT)
	else:
		P.inp["move"] = dir
		if mode == "run_tap": P.vel = Vector3(dir.x, 0, dir.y) * P.base_speed
		var t := 0.0
		while not P.over_void() and t < 2.0:
			P.inp["jump"] = mode == "jump_tap" and P.pos.distance_to(home) > PLATFORM_R - 0.2
			m.step(DT)
			t += DT
		P.inp["jump"] = false
		step(m, 0.12, func(): P.inp["glide"] = mode == "glide_tap")
		P.inp["glide"] = false
		tap(m, P)
	var fired := not K.rmb_down and K.ch_rmb < 1.0
	# the move runs its course with no keys held: the plunge, or the hop's arc
	P.inp["move"] = Vector2.ZERO
	var t2 := 0.0
	while t2 < 1.5 and K.dive and (K.dive_fall or P.fly_t > 0.0) and not P.grounded and not fell[0]:
		var was := P.pos
		m.step(DT)
		watch.call(was)
		t2 += DT
	var after := P.pos.y - P.abyss_kill_y()
	var lower := P.pos.y < y0 + (0.05 if mode == "hop" else -0.3)      # (the hop's arc ends level with the rim)
	# the recovery: glide held, steering home
	var t3 := 0.0
	var back := false
	while t3 < 6.0 and not fell[0]:
		var to := Vector2(home.x - P.pos.x, home.z - P.pos.z)
		P.inp["move"] = to.normalized() if to.length() > 0.2 else Vector2.ZERO
		P.inp["glide"] = not P.grounded
		var was := P.pos
		m.step(DT)
		watch.call(was)
		t3 += DT
		if P.grounded and not m.world.is_void(P.pos.x, P.pos.z):
			back = true
			break
	P.inp["glide"] = false
	P.inp["jump"] = false
	P.inp["move"] = Vector2.ZERO
	var good: bool = fired and not fell[0] and lower and after >= RECOVER_ROOM and low[0] > 0.0 and back
	return {
		"ok": good,
		"info": "fired %s fell %s lower %s room %.1fm at %.2fs (least %.1f) back %s" % [
			fired, fell[0], lower, after, t2, low[0], back
		]
	}
