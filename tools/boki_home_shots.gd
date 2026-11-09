extends RefCounted
## --boki-home-shots --shots-dir=<dir> [--species=cindle,kestrike,selenfin,hivara] [--px=256]: one sheet per
## home state (settle, nap, wake, munch, nudge, climb, splash; BokiHomeClips): a row per species, FRAMES over the
## clip, in the engine. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const STATES := ["settle", "nap", "wake", "munch", "nudge", "climb", "splash"]
const FRAMES := 6
var species := ["cindle", "kestrike", "selenfin", "hivara"]

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
	var vp := s._stage(Vector2i(s.px, s.px))
	s._close_cam(vp)
	var sheets := {}
	for c in STATES:
		sheets[c] = Image.create(s.px * FRAMES, s.px * species.size(), false, Image.FORMAT_RGBA8)
	for row in species.size():
		s.species = species[row]
		var kr := s._kin(vp)
		(kr[0] as Node3D).rotation.y = PI * 0.72
		var rig := kr[1] as BokiRig
		for c in STATES:
			rig.set_clip(c, 0.0)
			var length := rig.player.get_animation(c).length
			for f in FRAMES:
				var k := float(f) / float(FRAMES - 1 if c in ["settle", "wake"] else FRAMES)
				rig.set_face(s._face_for(rig, c, k))
				rig.seek(k * length)
				var img: Image = await s._grab(vp)
				img.convert(Image.FORMAT_RGBA8)
				(sheets[c] as Image).blit_rect(img, Rect2i(0, 0, s.px, s.px), Vector2i(f * s.px, row * s.px))
		(kr[0] as Node3D).free()
	for c in STATES:
		(sheets[c] as Image).save_png(s.out.path_join("home_%s.png" % c))
	print("BOKI_HOME_SHOTS_DONE")
	m.get_tree().quit()
