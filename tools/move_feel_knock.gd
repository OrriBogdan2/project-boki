extends RefCounted
## --move-feel-check's knock arc (docs/MOVEMENT_FEEL.md "Knock arc"): four reference knocks pushed through
## Displace.knock (the synced path, the same Hunter.impulse a hit runs) on a standing Hunter on flat ground,
## no keys held. It asserts the shared curve (metres at 0.1 / 0.2 / 0.4 s, the step the keys come back, and
## how much of the slide is done by 0.4 s) and prints the rest of the table row (distance and time at rest,
## how far a wall still counts as a slam, the frame a cliff ahead stuns the body).

## Reference knocks: each kit's full-charge push on main d255acbee (m/s along the hit). The numbers are fixed
## here on purpose: these asserts pin the shared curve, so a kit retuning its push doesn't move them.
const REF := {
	"lace": 12.0,  # Heavy Shot, archer.json rmb.pin.push [8, 12]
	"sparkle": 9.0,  # Storm Rod, mage.json rmb.coil.push [6, 9]
	"albert": 13.0,  # hammer swing, bulwark.json lmb.smash_kb [5, 13]
	"kael": 6.0,  # Finishing Slam, juggernaut.json rmb.slam.push
}
## Every kit knock's push (m/s) and lift, printed only (docs/KIT_PARITY.md "Knock distances"): where it comes to
## rest on flat ground, no keys. A lift above 0 starts the body airborne (shoves 2.5, Tenzo's hits 2.0).
const SWEEP := [
	[1.0, -1.0],
	[1.5, -1.0],
	[3.0, -1.0],
	[3.5, -1.0],
	[4.0, -1.0],
	[4.4, -1.0],
	[5.0, -1.0],
	[6.0, -1.0],
	[6.6, -1.0],
	[7.0, -1.0],
	[8.0, -1.0],
	[9.0, -1.0],
	[11.0, -1.0],
	[12.0, -1.0],
	[13.0, -1.0],
	[18.2, -1.0],
	[6.0, 2.0],
	[8.0, 2.0],
	[11.0, 2.0],
	[4.0, 2.5],
	[5.0, 2.5],
	[6.0, 2.5],
	[11.0, 2.5]
]
const SAMPLES := [6, 12, 24]  # steps: 0.1, 0.2 and 0.4 s at 60 steps a second
const SETTLE := 90  # steps (1.5 s): every reference knock is at rest by then
const WALL_GAP := 1.5  # m from the body's centre to the cliff face

## key -> [op, target, unit, note], as move_feel_check's T. Distances are ours (the source's knock curve is
## not in the data and the 5 fps footage can't resolve it), held within a few centimetres; the share done by
## 0.4 s is the footage's.
const T := {
	"knock_lace_01_m": ["~", [1.12, 1.22], "m", "Heavy Shot push 12 at 0.1 s"],
	"knock_lace_02_m": ["~", [2.22, 2.32], "m", "Heavy Shot push 12 at 0.2 s"],
	"knock_lace_04_m": ["~", [4.03, 4.23], "m", "Heavy Shot push 12 at 0.4 s"],
	"knock_lace_keys_s": ["~", [0.33, 0.37], "s", "Heavy Shot push 12: keys back (knock_t, capped 0.35 s)"],
	"knock_sparkle_01_m": ["~", [0.81, 0.91], "m", "Storm Rod push 9 at 0.1 s"],
	"knock_sparkle_02_m": ["~", [1.62, 1.72], "m", "Storm Rod push 9 at 0.2 s"],
	"knock_sparkle_04_m": ["~", [2.62, 2.82], "m", "Storm Rod push 9 at 0.4 s"],
	"knock_sparkle_keys_s": ["~", [0.27, 0.30], "s", "Storm Rod push 9: keys back (0.1 + 0.02 s per m/s)"],
	"knock_albert_01_m": ["~", [1.21, 1.31], "m", "hammer swing push 13 at 0.1 s"],
	"knock_albert_02_m": ["~", [2.42, 2.52], "m", "hammer swing push 13 at 0.2 s"],
	"knock_albert_04_m": ["~", [4.51, 4.71], "m", "hammer swing push 13 at 0.4 s"],
	"knock_albert_keys_s": ["~", [0.35, 0.38], "s", "hammer swing push 13: keys back (the 0.35 s cap)"],
	"knock_kael_01_m": ["~", [0.51, 0.61], "m", "Finishing Slam push 6 at 0.1 s"],
	"knock_kael_02_m": ["~", [1.02, 1.12], "m", "Finishing Slam push 6 at 0.2 s"],
	"knock_kael_04_m": ["~", [1.52, 1.72], "m", "Finishing Slam push 6 at 0.4 s"],
	"knock_kael_keys_s": ["~", [0.22, 0.25], "s", "Finishing Slam push 6: keys back"],
	# [footage] a knock is done in about 0.4 s (Joule spear 0064-0066, Ghost wall cone 0073-0077)
	"knock_done_04": [">=", 0.85, "share", "[footage] the least share of the four landed by 0.4 s"],
}


static func run(c) -> void:
	var done := 1.0
	for key in REF:
		var arc := _arc(c, float(REF[key]))
		var dist: Array = arc["d"]
		for j in SAMPLES.size():
			c.rec("knock_%s_0%d_m" % [key, [1, 2, 4][j]], float(dist[j]), T)
		c.rec("knock_%s_keys_s" % key, float(arc["keys_t"]), T)
		done = minf(done, float(dist[2]) / float(arc["rest"]))
		var row := [key, REF[key], arc["rest"], arc["stop_t"], arc["slam_m"], WALL_GAP, _wall_frame(c, float(REF[key]))]
		print(
			(
				(
					"MFEEL knock %s push %.1f: rest %.2f m after %.2f s, wall slams up to %.2f m,"
					+ " cliff %.1f m ahead: step %d"
				)
				% row
			)
		)
	c.rec("knock_done_04", done, T)
	for row in SWEEP:
		var a := _arc(c, float(row[0]), float(row[1]))
		var vals := [row[0], row[1], a["rest"], a["stop_t"]]
		print("MFEEL knock sweep push %.1f lift %.1f: rest %.2f m after %.2f s" % vals)


## Distance over time on open ground, the step the keys come back, and how far the body gets while a wall
## would still count as a slam (Hunter: inside 0.6 s of the knock and faster than 8 m/s).
static func _arc(c, push: float, lift := -1.0) -> Dictionary:
	var body: Hunter = c.P
	c._reset(c.flat + Vector3(-3.0, 0, 0))
	var x0 := body.pos.x
	c.m.displace.knock(body, Vector2(push, 0.0), lift)
	var out := {"d": [0.0, 0.0, 0.0], "keys_t": -1.0, "stop_t": -1.0, "slam_m": 0.0}
	for i in SETTLE:
		c.m.step(c.DT)
		var t: float = (i + 1) * c.DT
		var d: float = body.pos.x - x0
		var s: float = c._hv(body).length()
		var j := SAMPLES.find(i + 1)
		if j >= 0:
			out["d"][j] = d
		if float(out["keys_t"]) < 0.0 and body.knock_t <= 0.0:
			out["keys_t"] = t
		if float(out["stop_t"]) < 0.0 and s < 0.05:
			out["stop_t"] = t
		if t < 0.6 and s > 8.0:
			out["slam_m"] = d
	out["rest"] = body.pos.x - x0
	return out


## The step a cliff WALL_GAP ahead stuns the knocked body (-1: no slam). The cliff is raised for the test
## and put back.
static func _wall_frame(c, push: float) -> int:
	var body: Hunter = c.P
	var world: World = c.w
	var at: Vector3 = c.flat + Vector3(-3.0, 0, 0)
	var face := int(floor(at.x + WALL_GAP))
	var cz := int(floor(at.z))
	var saved := {}
	for dx in 3:
		for dz in range(-2, 3):
			var i: int = world.idx(face + dx, cz + dz)
			saved[i] = world.level[i]
			world.level[i] = world.level[i] + 3
	c._reset(at)
	body.wslam_t = 0.0
	c.m.displace.knock(body, Vector2(push, 0.0))
	var frame := -1
	for i in 60:
		c.m.step(c.DT)
		if body.stun_t > 0.0:
			frame = i + 1
			break
	for i in saved:
		world.level[i] = saved[i]
	c._reset(at)
	body.wslam_t = 0.0
	# the slam's hit-stop and slow-mo only run down in Match._process, which the e2e section drives
	c.m.hitstop = 0.0
	c.m.slowmo = 0.0
	return frame
