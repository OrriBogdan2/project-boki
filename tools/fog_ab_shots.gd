extends RefCounted
## --fog-ab-shots --shots-dir=<dir> [--fog-mode=training|expedition] [--raid=<condition>]: the sight look
## measured on one frame. You stand on open ground aiming; the same camera frame is saved with the sight fog
## off (ref.png: the scene as lit) and on (fog.png), then the ground in front of you (inside the cone) and
## behind you (outside it) is compared pixel for pixel: luma on/ref and the hue shift. Outside sight should
## be a slight dark fog (see RaidLook.VIS_DARK / VIS_GREY), partly grey, no blue cast. `--vis-dark=<x>
## --vis-grey=<x>` try other numbers on the same frame (the sheet of 11-23). Prints one FOGAB line, writes fogab.txt.
## Run on a real GPU (jobq --needs gpu); docs/specs/VISION_LOOK.md.

const SPAWN_WAIT := 30
const SETTLE := 70
const IN_DEG := 40.0     # ground inside the cone: within this many degrees of your aim
const OUT_DEG := 80.0    # ground outside it: further off your aim than this
const R_MIN := 4.0       # m, clear of the lit circle and the hunter's own model
const R_MAX := 16.0

var main: Node
var dir := "user://fog_ab"

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d["first_guide"] = 99
	Settings.set_v("tips", false, false)
	Game.god = true
	var mode := "training"
	var dark := -1.0
	var grey := -1.0
	var raid := "clear"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--raid="): raid = String(a).substr(7)
		if String(a).begins_with("--fog-mode="): mode = String(a).substr(11)
		if String(a).begins_with("--vis-dark="): dark = float(String(a).substr(11))
		if String(a).begins_with("--vis-grey="): grey = float(String(a).substr(11))
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	if mode == "training":
		await m.start({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9,
			"seed": 4242, "no_drop": true})
	else:
		await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1500.0, "seed": 5101, "no_drop": true,
			"raid": raid, "tut_test": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if dark >= 0.0:
		RenderingServer.global_shader_parameter_set("vis_dark", dark)
	if grey >= 0.0:
		RenderingServer.global_shader_parameter_set("vis_greyness", grey)
	var P := m.player
	for i in SPAWN_WAIT:
		await main.get_tree().process_frame
	var spot := _open_spot(m, P.pos)
	P.teleport(spot[0])
	var a: float = spot[1]
	for f in SETTLE:
		P.inp["move"] = Vector2.ZERO
		P.inp["aim"] = P.pos + Vector3(cos(a) * 6.0, 0.9, sin(a) * 6.0)
		main.get_viewport().warp_mouse(m.cam.unproject_position(P.inp["aim"]))
		await main.get_tree().process_frame
	var on_img := await _grab(false)
	var ref_img := await _grab(true)
	on_img.save_png(dir.path_join("fog.png"))
	ref_img.save_png(dir.path_join("ref.png"))
	var inside := _stats(m, on_img, ref_img, P.pos, a, 0.0, IN_DEG)
	var outside := _stats(m, on_img, ref_img, P.pos, a, OUT_DEG, 180.0)
	var line := "FOGAB mode=%s raid=%s inside_luma=%.3f outside_luma=%.3f" % [
		mode, raid, inside["ratio"], outside["ratio"]]
	line += " outside_hue_deg=%.2f outside_bshift=%.4f n_in=%d n_out=%d" % [
		outside["hue"], outside["b"], inside["n"], outside["n"]]
	line += " out_rb_on=%.4f out_rb_ref=%.4f out_rb_cast=%.4f" % [
		outside["rb_on"], outside["rb_ref"], outside["rb_cast"]]
	print(line)
	var f := FileAccess.open(dir.path_join("fogab.txt"), FileAccess.WRITE)
	f.store_line(line)
	f.close()
	Game.god = false
	main.get_tree().quit()

## One frame as drawn; `fog_off` switches the sight fog off for that frame only (the match sets it again next frame).
func _grab(fog_off: bool) -> Image:
	await RenderingServer.frame_pre_draw     # after the match's _process set vis_on for this frame
	if fog_off:
		RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()

## Ground pixels between `lo` and `hi` degrees off the aim and R_MIN..R_MAX m from you: mean luma of the fogged
## frame over the reference frame, the hue shift (degrees) of the mean colour, and the change in B-(R+G)/2.
func _stats(m: Match, on: Image, ref: Image, at: Vector3, aim: float, lo: float, hi: float) -> Dictionary:
	var sum_on := Vector3.ZERO
	var sum_ref := Vector3.ZERO
	var n := 0
	var size := on.get_size()
	var gy := at.y
	for y in range(40, size.y - 120, 6):
		for x in range(40, size.x - 40, 6):
			var p := Vector2(x, y)
			var o := m.cam.project_ray_origin(p)
			var d := m.cam.project_ray_normal(p)
			if absf(d.y) < 0.01:
				continue
			var t := (gy - o.y) / d.y
			if t <= 0.0:
				continue
			var g := o + d * t
			if m.world.is_void(g.x, g.z):
				continue     # the cloud art past the island's edge is not fogged ground
			var rel := Vector2(g.x - at.x, g.z - at.z)
			var dist := rel.length()
			if dist < R_MIN or dist > R_MAX:
				continue
			var off := rad_to_deg(absf(angle_difference(rel.angle(), aim)))
			if off < lo or off > hi:
				continue
			var c := on.get_pixel(x, y)
			var r := ref.get_pixel(x, y)
			sum_on += Vector3(c.r, c.g, c.b)
			sum_ref += Vector3(r.r, r.g, r.b)
			n += 1
	if n == 0:
		return {"ratio": 0.0, "hue": 0.0, "b": 0.0, "n": 0, "rb_on": 0.0, "rb_ref": 0.0, "rb_cast": 0.0}
	var mo := sum_on / n
	var mr := sum_ref / n
	var co := Color(mo.x, mo.y, mo.z)
	var cr := Color(mr.x, mr.y, mr.z)
	var hue := 0.0
	if co.s > 0.02 and cr.s > 0.02:
		hue = absf(angle_difference(deg_to_rad(co.h * 360.0), deg_to_rad(cr.h * 360.0)))
		hue = rad_to_deg(hue)
	var rb_on := (mo.x - mo.z) / maxf(_luma(mo), 0.001)     # red minus blue, per unit of luma
	var rb_ref := (mr.x - mr.z) / maxf(_luma(mr), 0.001)
	return {"ratio": _luma(mo) / maxf(_luma(mr), 0.001), "hue": hue, "rb_on": rb_on, "rb_ref": rb_ref,
		"rb_cast": rb_on - rb_ref, "b": (mo.z - (mo.x + mo.y) * 0.5) - (mr.z - (mr.x + mr.y) * 0.5), "n": n}

func _luma(v: Vector3) -> float:
	return v.x * 0.299 + v.y * 0.587 + v.z * 0.114

## Open, level ground and an aim (radians) with 12 m of open ground ahead and behind.
func _open_spot(m: Match, from: Vector3) -> Array:
	for r in range(0, 80, 4):
		for j in 12:
			var p := from + Vector3(cos(TAU * j / 12.0), 0, sin(TAU * j / 12.0)) * r
			if not _open(m, p, p): continue
			p.y = m.world.ground_at(p.x, p.z)
			for i in 16:
				var a := TAU * i / 16.0
				var ok := true
				for s: float in [-1.0, 1.0, 0.0, 2.0]:
					var b: float = a + PI * 0.5 * s
					for k: float in [4.0, 8.0, 12.0, 16.0]:
						if not _open(m, p, p + Vector3(cos(b), 0, sin(b)) * k):
							ok = false
				if ok:
					return [p, a]
	return [from, 0.0]

func _open(m: Match, p: Vector3, q: Vector3) -> bool:
	var y := m.world.ground_at(p.x, p.z)
	var W := m.world
	return not (W.is_void(q.x, q.z) or W.is_block(q.x, q.z) or W.in_bush(q.x, q.z)
		or absf(W.ground_at(q.x, q.z) - y) > 0.5)
