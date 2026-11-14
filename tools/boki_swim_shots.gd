extends RefCounted
## --boki-swim-shots --shots-dir=<dir> [--species=puddlet,cindle,kestrike] [--px=256]: swim.png, a row per species
## afloat in DEPTH m of water (BokiRig's swim state: swim for a Water type, paddle for the rest), FRAMES over its
## loop, through a see-through surface with the bed under it. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const FRAMES := 6
const DEPTH := 1.0                                   # m of water over the bed
const WATER := Color(0.36, 0.78, 0.86, 0.55)         # ZoneDress' shallows
const BED := Color("4d5f58")
var species := ["puddlet", "cindle", "kestrike"]

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
	var vp := s._stage(Vector2i(s.px, s.px), false)
	s._close_cam(vp).look_at(Vector3(0, 0.12, 0))
	_plane(vp, 0.0, WATER)
	_plane(vp, -DEPTH, BED)
	var sheet := Image.create(s.px * FRAMES, s.px * species.size(), false, Image.FORMAT_RGBA8)
	for row in species.size():
		s.species = species[row]
		var kr := s._kin(vp)
		var k := kr[0] as Node3D
		var rig := kr[1] as BokiRig
		k.position.y = -DEPTH
		k.rotation.y = PI * 0.72
		rig._water = DEPTH                           # what a pond says through the root meta "kwater"
		rig._keep_flex()
		var c := rig._swim_clip()
		rig.set_clip(c if c != "" else "idle", 0.0)          # one that hovers stays over the water
		var length := rig.player.get_animation(rig.clip).length
		for f in FRAMES:
			rig.set_face(s._face_for(rig, rig.clip, float(f) / float(FRAMES)))
			rig.seek(length * float(f) / float(FRAMES))
			var img: Image = await s._grab(vp)
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, s.px, s.px), Vector2i(f * s.px, row * s.px))
		k.free()
	sheet.save_png(s.out.path_join("swim.png"))
	print("BOKI_SWIM_SHOTS_DONE")
	m.get_tree().quit()

func _plane(vp: SubViewport, y: float, colour: Color) -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	p.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if colour.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.roughness = 0.15
	p.material_override = mat
	p.position.y = y
	vp.add_child(p)
