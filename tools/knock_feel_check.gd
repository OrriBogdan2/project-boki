extends RefCounted
## How a knock feels to the one knocked (docs/MOVEMENT_FEEL.md, "Knocks"), on four of the game's knocks with
## their push values from content: Kael's Smash, Albert's Shield Charge bash, Vex's Longneedle recoil and
## Grimble's Anchor Drop on an airborne foe (a spike and a stun, no sideways push).
##   rows(c): --move-feel-check's knock rows (c is that check: its hunter, its reset and its rec()).
##   --knock-feel-shots --shots-dir=<dir>: the four knocks as a strip of centre crops, one row each (GPU).

const DT := 1.0 / 60.0
const SPIKE := -16.0         # m/s: Grimble's Anchor Drop spikes an airborne foe down (dredge_kit.gd _slammed)
const AIR_LIFT := 4.0        # m/s up: an air knock in the rows (a Smash on a foe mid-jump)
const SIDE := Vector2(0, 1)  # the keys held across a knock along +x (directional influence)

## key -> [op, target, unit, note], as move_feel_check.T
const T := {
	"knock_curve_err": ["<=", 0.25, "m/s",
		"[game data] ground knock speed at 0.1/0.2/0.3 s vs UE's walking brake: dv/dt = -2v - 22.2"],
	"knock_dist_ratio": ["~", [0.94, 1.06], "x",
		"ground distance vs the old fixed slide's (distance vs mass is audited elsewhere: kept)"],
	"knock_ctrl_t": ["~", [0.3, 0.38], "s",
		"[game data] Albert's bash (push 11) back to run speed under UE's brake: 0.34 s"],
	"knock_keys_add_m": ["<=", 0.15, "m",
		"[game data] over max speed UE brakes whatever the keys: keys along add nothing"],
	"knock_di_deg": ["~", [3.0, 30.0], "deg",
		"[patch] Jun 2025: WASD steers knockback (high influence 0.5, keys across), never cancels it"],
	"knock_dash_frames": ["<=", 1.0, "frames",
		"[wiki] a knock is no crowd control (GROUNDED is the separate dash lock): dash out at once"],
	"knock_air_stun": ["<=", 0.0, "s", "[game data] UE lands a launch into walking: no stun or recovery"],
	"knock_air_ctrl_t": ["<=", 0.45, "s", "[game data] landing over run speed: UE's brake, then the walk"],
	"knock_spike_ctrl_frames": ["<=", 1.0, "frames", "Grimble's slam: control the step its stun ends, no recovery"],
}

var c: RefCounted

func _arch(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % id))

## [label, push m/s, lift m/s (-1: none)] for the four knocks, from content.
func knocks() -> Array:
	var kael: Dictionary = _arch("juggernaut")["rmb"]["slam"]
	var albert: Dictionary = _arch("bulwark")["dash"]
	var vex: Dictionary = _arch("gunslinger")["e"]
	return [["Kael Smash", float(kael["push"]), -1.0], ["Albert bash", float(albert["charge_kb"]), -1.0],
		["Vex recoil", float(vex["recoil"]), -1.0], ["Grimble slam", 0.0, -1.0]]

## The source's ground knock speed t seconds in (UE: dv/dt = -k*v - b, k = ground_friction, b = brake).
static func src_speed(v0: float, t: float) -> float:
	var k := HunterMove.ground_friction
	var b := HunterMove.brake_decel
	return maxf(0.0, (v0 + b / k) * exp(-k * t) - b / k)

## The old fixed slide's ground distance for a push (knock_t 0.1 + 0.02 s per m/s at 6 m/s^2, then the shed
## and the walking stop), kept here as the reference the distance must hold to.
static func old_dist(s: float) -> float:
	var v := s
	var kt := clampf(0.1 + s * 0.02, 0.12, 0.35)
	var d := 0.0
	while v > 0.001:
		if kt > 0.0:
			kt -= DT
			v = maxf(0.0, v - 6.0 * DT)
		elif v > 4.70:
			v = maxf(4.65, v - Hunter.GROUND_SHED * DT)
		else:
			v = maxf(0.0, v * (1.0 - HunterMove.ground_friction * DT) - HunterMove.brake_decel * DT)
		d += v * DT
	return d

## Knock the check's hunter along +x at push s with `keys` held; returns [distance, seconds to run speed,
## speeds at 0.1/0.2/0.3 s, the offset when it got back to run speed].
func _slide(s: float, keys: Vector2, steer := 0.3) -> Array:
	var P: Hunter = c.P
	c._reset(c.flat + Vector3(-5, 0, 0))
	P.knock_steer = steer
	P.impulse(Vector2(s, 0))
	var p0 := P.pos
	var ctrl := -1.0
	var end := Vector3.ZERO      # where the knock handed back to the walk
	var at := []
	for i in 120:
		P.inp["move"] = keys
		c.m.step(DT)
		if i + 1 in [6, 12, 18]:
			at.append(Vector2(P.vel.x, P.vel.z).length())
		if ctrl < 0.0 and P.knock_t <= 0.0:
			ctrl = (i + 1) * DT
			end = P.pos - p0
	return [P.pos.x - p0.x, ctrl, at, end]

func rows(check: RefCounted) -> void:
	c = check
	var P: Hunter = c.P
	var err := 0.0
	var ratio := 1.0
	for k in knocks():
		var s: float = k[1] / P.mass()
		if s <= 2.5:
			continue
		var r := _slide(s, Vector2.ZERO)
		var v0 := s * HunterMove.knock_launch
		for j in 3:
			err = maxf(err, absf(float(r[2][j]) - src_speed(v0, 0.1 * (j + 1))))
		var rr: float = r[0] / old_dist(s)
		if absf(rr - 1.0) > absf(ratio - 1.0):
			ratio = rr
		print("MFEEL knock %-13s push %4.1f  start %5.2f m/s  0.1s %5.2f 0.2s %5.2f 0.3s %5.2f" % [
			k[0], s, v0, r[2][0], r[2][1], r[2][2]], "  %.2f m (old slide %.2f)  run speed at %.2f s" % [
			r[0], old_dist(s), r[1]])
	c.rec("knock_curve_err", err, T["knock_curve_err"])
	c.rec("knock_dist_ratio", ratio, T["knock_dist_ratio"])
	var albert: float = knocks()[1][1] / P.mass()
	var none := _slide(albert, Vector2.ZERO)
	c.rec("knock_ctrl_t", float(none[1]), T["knock_ctrl_t"])
	var along: Vector3 = _slide(albert, Vector2(1, 0))[3]
	c.rec("knock_keys_add_m", along.x - (none[3] as Vector3).x, T["knock_keys_add_m"])
	var di: Vector3 = _slide(albert, SIDE, 0.5)[3]
	c.rec("knock_di_deg", rad_to_deg(atan2(di.z, di.x)), T["knock_di_deg"])
	_dash(albert)
	_air(knocks()[0][1] / P.mass())
	_spike()

## Dash pressed two steps into a knock: it goes out the next step (no lock).
func _dash(s: float) -> void:
	var P: Hunter = c.P
	c._reset(c.flat + Vector3(-5, 0, 0))
	P.impulse(Vector2(s, 0))
	c._steps(2)
	var n := 99
	for i in 6:
		P.inp["dash"] = true
		P.inp["move"] = Vector2(-1, 0)
		c.m.step(DT)
		if P.roll_t > 0.0:
			n = i + 1
			break
	P.inp["dash"] = false
	c.rec("knock_dash_frames", n, T["knock_dash_frames"])

## A Smash on a foe mid-jump with a lift: it flies the falling rules, lands into the walk.
func _air(s: float) -> void:
	var P: Hunter = c.P
	c._reset(c.flat + Vector3(-5, 1.0, 0), false)
	P.impulse(Vector2(s, 0), AIR_LIFT * P.mass())
	var land := -1.0
	var ctrl := -1.0
	var stun := 0.0
	for i in 150:
		c.m.step(DT)
		if land < 0.0 and P.grounded:
			land = i * DT
			stun = P.stun_t
		if land >= 0.0 and Vector2(P.vel.x, P.vel.z).length() <= P.base_speed + 0.01:
			ctrl = i * DT - land
			break
	var out: float = P.pos.x - c.flat.x + 5.0
	print("MFEEL knock air: lands at %.2f s, back to run speed %.2f s later, %.2f m out" % [land, ctrl, out])
	c.rec("knock_air_stun", stun, T["knock_air_stun"])
	c.rec("knock_air_ctrl_t", ctrl, T["knock_air_ctrl_t"])

## Grimble's Anchor Drop on a foe 3 m up: spiked, stunned, and the keys work the step the stun ends.
func _spike() -> void:
	var P: Hunter = c.P
	c._reset(c.flat + Vector3(0, 3.0, 0), false)
	c.m.displace.spike(P, SPIKE)
	P.stun_t = float(_arch("dredge")["e"]["stun"])
	var n := 99
	for i in 120:
		P.inp["move"] = Vector2(1, 0)
		c.m.step(DT)
		if P.stun_t <= 0.0:
			n = 0
			for j in 6:
				if P.vel.x > 0.5:
					break
				n += 1
				c.m.step(DT)
			break
	c.rec("knock_spike_ctrl_frames", n, T["knock_spike_ctrl_frames"])
	c._clear_inp()

# ---------------------------------------------------------------- GPU strip
const CROP := Vector2i(480, 300)
const AHEAD := Vector3(2.0, 1.0, 0)   # m: the crop is held on this point past the start (the slide crosses it)
const SHOTS := 6
const SHOT_EVERY := 4          # frames between crops

func run(main: Node, _mode: String) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true,
		"tut_test": true})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		if h != m.player:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if m.player.kin: (m.player.kin as Kin).stow()
	m.player.ctrl = "local"
	c = load("res://tools/move_feel_check.gd").new()
	c.m = m
	c.w = m.world
	c.P = m.player
	c.flat = c._flat_spot(8.0)
	var dir := "user://knock_feel_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	var ks := knocks()
	var strip := Image.create(CROP.x * SHOTS, CROP.y * ks.size(), false, Image.FORMAT_RGB8)
	for row in ks.size():
		var P: Hunter = c.P
		c._reset(c.flat + Vector3(-4, 3.0 if row == 3 else 0.0, 0), row != 3)
		m.cam.snap(P.pos)
		var start := P.pos
		for i in 10:
			await main.get_tree().process_frame
		if row == 3:
			m.displace.spike(P, SPIKE)
			P.stun_t = float(_arch("dredge")["e"]["stun"])
		else:
			P.impulse(Vector2(float(ks[row][1]), 0))
		for n in SHOTS:
			for f in SHOT_EVERY:
				await main.get_tree().process_frame
			var img := main.get_viewport().get_texture().get_image()
			var px := main.get_viewport().get_camera_3d().unproject_position(start + AHEAD)
			var at := (Vector2i(px) - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
			var to := Vector2i(CROP.x * n, CROP.y * row)
			strip.blit_rect(img.get_region(Rect2i(at, CROP)), Rect2i(Vector2i.ZERO, CROP), to)
		print("KNOCKFEEL row %d %s" % [row, ks[row][0]])
	strip.save_png(dir.path_join("knock_feel.png"))
	print("KNOCKFEEL SHOTS DONE")
	main.get_tree().quit()
