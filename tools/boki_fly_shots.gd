extends RefCounted
## --boki-fly-shots --shots-dir=<dir> [--species=kestrike,wisplet] [--px=256]: fly.png, a row per flier (BokiFly):
## HOVER frames over its hover loop LIFT m up, GLIDE frames over its glide, then FLARE frames of the flare as it
## comes down from where the flare starts to the ground. Its ground shadow stays on the grass. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const HOVER := 3
const GLIDE := 3
const FLARE := 2
const LIFT := 1.0                    # m: a hover in the middle of boki_fly.json's height band
const TALL := 1.5                    # frame height over width: room for the flier and its shadow under it
var species := ["kestrike", "wisplet"]

func run(m: Node) -> void:
	var s := Shots.new()
	s.main = m
	s.px = 256
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): s.out = a.substr(12)
		if a.begins_with("--species="): species = Array(a.substr(10).split(","))
		if a.begins_with("--px="): s.px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(s.out)
	if m.get("fade") != null:
		m.fade.reveal(0.01)
	var frame := Vector2i(s.px, roundi(s.px * TALL))
	var vp := s._stage(frame)
	var cam := s._close_cam(vp)
	cam.fov = 32.0
	cam.position = Vector3(0, 1.15, 3.1)
	cam.look_at(Vector3(0, 0.78, 0))
	var cols := HOVER + GLIDE + FLARE
	var sheet := Image.create(frame.x * cols, frame.y * species.size(), false, Image.FORMAT_RGBA8)
	for row in species.size():
		s.species = species[row]
		var kr := s._kin(vp)
		var k := kr[0] as Node3D
		var rig := kr[1] as BokiRig
		k.rotation.y = PI * 0.72
		var col := 0
		for shot in _plan():
			k.position.y = float(shot[2])
			k.set_meta("lift", float(shot[2]))
			rig.set_clip(String(shot[0]), 0.0)
			rig._keep_flex()
			var length := rig.player.get_animation(rig.clip).length
			rig.set_face(s._face_for(rig, rig.clip, float(shot[1])))
			rig.seek(length * float(shot[1]))
			var img: Image = await s._grab(vp)
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, frame), Vector2i(col * frame.x, row * frame.y))
			col += 1
		k.free()
	sheet.save_png(s.out.path_join("fly.png"))
	print("BOKI_FLY_SHOTS_DONE")
	m.get_tree().quit()

## [clip, 0..1 of it, m up] for each column: the loops at LIFT, the flare sinking from where it starts to the ground.
func _plan() -> Array:
	var out: Array = []
	for f in HOVER:
		out.append(["hover", float(f) / float(HOVER), LIFT])
	for f in GLIDE:
		out.append(["glide", float(f) / float(GLIDE), LIFT])
	for f in FLARE:
		var u := 0.25 + 0.4 * float(f) / float(FLARE - 1)
		out.append(["flare", u, BokiFly.flare_from() * maxf(0.0, 1.0 - 2.0 * u)])
	return out
