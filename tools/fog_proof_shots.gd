extends RefCounted
## --fog-proof-shots --shots-dir=<dir> [--half-deg=60]: owner stills. Expedition start, hunter standing, aim to the
## screen's upper right; saves the frame as drawn (default camera, HUD on), the same frame with fog off, and the same
## pair at a low camera pitch. Prints cone numbers (mean RGB in/out, edge profile, blue-violet pixels).

const SPAWN_WAIT := 30
const SETTLE := 70
const R_MIN := 4.0
const R_MAX := 16.0
const AIM := -PI / 4.0     # +x and -z: the camera looks north, so up and to the right on screen

var main: Node
var dir := "user://fog_proof"

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d["first_guide"] = 99
	Settings.set_v("tips", false, false)
	Game.god = true
	var half := 60.0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--half-deg="): half = float(String(a).substr(11))
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1500.0, "seed": 5101, "no_drop": true,
		"raid": "clear", "tut_test": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P := m.player
	for i in SPAWN_WAIT:
		await main.get_tree().process_frame
	var spot := _open_spot(m, P.pos)
	P.teleport(spot)
	var out := []
	for pitch_deg in [57.0, 28.0]:
		m.cam.pitch = deg_to_rad(pitch_deg)
		for f in SETTLE:
			P.inp["move"] = Vector2.ZERO
			P.inp["aim"] = P.pos + Vector3(cos(AIM) * 6.0, 0.9, sin(AIM) * 6.0)
			main.get_viewport().warp_mouse(m.cam.unproject_position(P.inp["aim"]))
			await main.get_tree().process_frame
		var tag := "" if pitch_deg > 50.0 else "low_"
		var on := await _grab(false)
		var ref := await _grab(true)
		on.save_png(dir.path_join(tag + "fog.png"))
		ref.save_png(dir.path_join(tag + "ref.png"))
		if tag == "":
			out = _report(m, on, ref, P.pos, half)
	out.append("SPOT biome=%s map=%s pos=%s" % [m.world.biome_at(P.pos.x, P.pos.z), m.map_name, str(P.pos)])
	var fl := FileAccess.open(dir.path_join("proof.txt"), FileAccess.WRITE)
	for l in out:
		print(l)
		fl.store_line(l)
	fl.close()
	Game.god = false
	main.get_tree().quit()

func _grab(fog_off: bool) -> Image:
	await RenderingServer.frame_pre_draw
	if fog_off:
		RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()

func _luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

## Ground pixels 4-16 m from you, binned by degrees off your aim (5 deg bins): on/ref luma, mean RGB, violet counts.
func _report(m: Match, on: Image, ref: Image, at: Vector3, half: float) -> Array:
	var bins := {}
	var size := on.get_size()
	for y in range(40, size.y - 120, 3):
		for x in range(40, size.x - 40, 3):
			var p := Vector2(x, y)
			var o := m.cam.project_ray_origin(p)
			var d := m.cam.project_ray_normal(p)
			if absf(d.y) < 0.01:
				continue
			var t := (at.y - o.y) / d.y
			if t <= 0.0:
				continue
			var g := o + d * t
			if m.world.is_void(g.x, g.z):
				continue
			var rel := Vector2(g.x - at.x, g.z - at.z)
			var dist := rel.length()
			if dist < R_MIN or dist > R_MAX:
				continue
			var off := rad_to_deg(absf(angle_difference(rel.angle(), AIM)))
			var k := int(off / 5.0)
			if not bins.has(k):
				bins[k] = {"n": 0, "on": Vector3.ZERO, "ref": Vector3.ZERO, "von": 0, "vref": 0}
			var b: Dictionary = bins[k]
			var c := on.get_pixel(x, y)
			var r := ref.get_pixel(x, y)
			b["n"] += 1
			b["on"] += Vector3(c.r, c.g, c.b)
			b["ref"] += Vector3(r.r, r.g, r.b)
			if _violet(c): b["von"] += 1
			if _violet(r): b["vref"] += 1
	var lines := []
	var zones := {"inside": [0.0, half - 10.0], "edge": [half - 10.0, half + 10.0], "outside": [half + 20.0, 180.0]}
	for zn in zones:
		var s_on := Vector3.ZERO
		var s_ref := Vector3.ZERO
		var n := 0
		var vo := 0
		var vr := 0
		for k in bins:
			var mid: float = (k + 0.5) * 5.0
			if mid >= zones[zn][0] and mid <= zones[zn][1]:
				var b: Dictionary = bins[k]
				s_on += b["on"]; s_ref += b["ref"]; n += b["n"]; vo += b["von"]; vr += b["vref"]
		if n == 0:
			continue
		var mo := s_on / n
		var mr := s_ref / n
		lines.append("ZONE %s n=%d fog_rgb255=%d,%d,%d luma=%.1f | nofog_rgb255=%d,%d,%d luma=%.1f | violet_px fog=%d nofog=%d" % [
			zn, n, mo.x * 255, mo.y * 255, mo.z * 255, _luma(Color(mo.x, mo.y, mo.z)) * 255,
			mr.x * 255, mr.y * 255, mr.z * 255, _luma(Color(mr.x, mr.y, mr.z)) * 255, vo, vr])
	var keys := bins.keys()
	keys.sort()
	var prof := "PROFILE on/ref luma by deg off aim:"
	for k in keys:
		var b: Dictionary = bins[k]
		var mo: Vector3 = b["on"] / b["n"]
		var mr: Vector3 = b["ref"] / b["n"]
		prof += " %d:%.2f" % [k * 5, _luma(Color(mo.x, mo.y, mo.z)) / maxf(_luma(Color(mr.x, mr.y, mr.z)), 0.001)]
	lines.append(prof)
	return lines

## Blue-violet: hue 230-290 degrees, saturated enough to read as tinted, bright enough not to be shadow black.
func _violet(c: Color) -> bool:
	var h := c.h * 360.0
	return h >= 230.0 and h <= 290.0 and c.s > 0.15 and c.v > 0.25

func _open_spot(m: Match, from: Vector3) -> Vector3:
	for r in range(0, 80, 4):
		for j in 12:
			var p := from + Vector3(cos(TAU * j / 12.0), 0, sin(TAU * j / 12.0)) * r
			if not _open(m, p, p): continue
			p.y = m.world.ground_at(p.x, p.z)
			var ok := true
			for s: float in [-1.0, 1.0, 0.0, 2.0]:
				var b: float = AIM + PI * 0.5 * s
				for k: float in [4.0, 8.0, 12.0, 16.0]:
					if not _open(m, p, p + Vector3(cos(b), 0, sin(b)) * k):
						ok = false
			if ok:
				return p
	return from

func _open(m: Match, p: Vector3, q: Vector3) -> bool:
	var y := m.world.ground_at(p.x, p.z)
	var W := m.world
	return not (W.is_void(q.x, q.z) or W.is_block(q.x, q.z) or W.in_bush(q.x, q.z)
		or absf(W.ground_at(q.x, q.z) - y) > 0.5)
