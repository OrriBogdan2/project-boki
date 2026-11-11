extends RefCounted
## --empty-shots --shots-dir=<dir>: review screenshots of the Empty creator (Male / Female, three heights,
## builds, hollow styles), the Relics viewer and the first-Relic moment (xvfb with a renderer). Add
## --only=creator|viewer|mask|shroud|feet|gait|farm|eggs to take one group (eggs: the egg pick, then the black
## mystery egg picked; shroud: the creator from front, side and back,
## the aura levels and shroud styles; feet: the soles at the shortest and tallest height, standing and walking;
## farm: the Empty at home from every side and above; gait: three bodies running past floor posts, not run by default).

const LOOKS := {
	"creator_female": {"gender": 0},
	"creator_male_short": {"height": 0}, "creator_male_tall": {"height": 2},
	"creator_female_short": {"gender": 0, "height": 0}, "creator_female_tall": {"gender": 0, "height": 2},
	"creator_slight": {"build": 0}, "creator_sturdy": {"build": 2},
	"void_mask_ember": {"hollow": 1, "glow": 1, "ghost": 2, "aura": 2},
	"void_torn_violet": {"gender": 0, "hollow": 2, "glow": 2, "ghost": 3, "colour": 5},
	"void_crescent_gold": {"hollow": 3, "glow": 4, "ghost": 1, "colour": 7},
}

const GAIT_SHOTS := 8        # frames of the gait strip
const GAIT_EVERY := 4        # frames (60 fps) between its shots: 8 x 4 = half a second, about two strides

var dir := ""
var only := ""
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--only="):
			only = String(a).substr(7)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var tree := main.get_tree()
	if main.fade != null:
		main.fade.reveal(0.05)
	if only in ["", "creator"]:
		await _creator(tree)
	if only in ["", "viewer"]:
		await _viewer(tree)
	if only in ["", "mask"]:
		await _mask(tree)
	if only in ["", "shroud"]:
		await _shroud(tree)
	if only == "gait":
		await _gait(tree)
	if only in ["", "feet"]:
		await _feet(tree)
	if only in ["", "farm"]:
		await _farm(tree)
	if only in ["", "eggs"]:
		await _eggs(tree)
	print("EMPTYSHOTS done in %s" % dir)
	tree.quit(0)

func _fresh() -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}

func _creator(tree: SceneTree) -> void:
	_fresh()
	var hx = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	await _shot(tree, "creator_default", 2.0)
	for file in LOOKS:
		hx.look = Unmasked.default_look()
		hx.look.merge(LOOKS[file], true)
		hx.preview_yaw = PI
		hx._show_create()
		await _shot(tree, file, 0.8)
	hx.queue_free()
	await tree.process_frame

func _eggs(tree: SceneTree) -> void:
	_fresh()
	Save.d["look"] = Unmasked.default_look()
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	await tree.process_frame
	hx._looks_good()
	await _shot(tree, "hatch_eggs", 2.5)
	hx._pick(3)
	await _shot(tree, "hatch_mystery_picked", 1.2)
	hx.queue_free()
	await tree.process_frame

func _viewer(tree: SceneTree) -> void:
	_fresh()
	var layer := CanvasLayer.new()
	main.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UI.theme()
	layer.add_child(host)
	var viewer := HunterViewer.make("gunslinger", Vector2(220, 300), Vector2(240, 135), 3)
	host.add_child(viewer)
	await _shot(tree, "viewer_vex_a", 1.0)
	await _shot(tree, "viewer_vex_b", 0.7)
	viewer.set_hunter("juggernaut")
	await _shot(tree, "viewer_kael", 1.2)
	layer.queue_free()
	await tree.process_frame

func _mask(tree: SceneTree) -> void:
	_fresh()
	Save.d["look"] = Unmasked.default_look()
	Save.d["look"].merge({"gender": 0, "glow": 0, "ghost": 1}, true)
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	await tree.process_frame
	hx._looks_good()
	var kin := Models.kin("cindle", {"level": 1})
	kin.position = Vector3(0, 0, 0.6)
	hx.add_child(kin)
	hx.kin_node = kin
	for e in hx.eggs:
		(e["holder"] as Node3D).visible = false
	hx._mask_moment(func(): pass)
	var moment: MaskMoment = hx.get_children().filter(func(c): return c is MaskMoment)[0]
	await _shot(tree, "mask_1_arrives", 1.2)
	await _shot(tree, "mask_2_boki_looks", 1.6)
	await _shot(tree, "mask_3_put_on_prompt", 1.6)
	moment.put_on()
	await _shot(tree, "mask_4_reach", 0.25)
	await _shot(tree, "mask_5_ghost_face", 0.35)
	await _shot(tree, "mask_6_you_as_vex", 0.9)
	await _shot(tree, "mask_7_vex_intro", 2.2)
	hx.queue_free()
	await tree.process_frame

func _shroud(tree: SceneTree) -> void:
	_fresh()
	var hx = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	await _shot(tree, "creator_warmup", 2.5)
	var views := {"front": PI, "side": PI * 0.5, "back": 0.0}
	for view in views:
		hx.look = Unmasked.default_look()
		hx.look.merge({"hollow": 1, "glow": 2, "colour": 5, "aura": 1}, true)
		hx._show_create()
		hx.preview.rotation.y = views[view]
		await _shot(tree, "creator_shroud_" + view, 0.8)
	for level in Unmasked.AURA.size():
		hx.look = Unmasked.default_look()
		hx.look.merge({"aura": level, "glow": 0, "colour": 10}, true)
		hx._show_create()
		hx.preview.rotation.y = PI * 0.8
		await _shot(tree, "creator_aura_%d_%s" % [level, String(Unmasked.AURA[level]).to_lower()], 2.5)
	for style in Unmasked.SHROUDS.size():
		hx.look = Unmasked.default_look()
		hx.look.merge({"shroud": style, "gender": style % 2, "colour": 2 + style * 3}, true)
		hx._show_create()
		hx.preview.rotation.y = PI * 0.8
		await _shot(tree, "creator_style_%s" % String(Unmasked.SHROUDS[style]).to_lower(), 0.8)
	hx.queue_free()
	await tree.process_frame

## The soles on a floor at the shortest and tallest height, standing and mid-stride, close and low.
func _feet(tree: SceneTree) -> void:
	_fresh()
	var stage := Node3D.new()
	main.add_child(stage)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.55, 0.3)
	plane.material = floor_mat
	stage.add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.position = Vector3(0.3, 0.35, 3.2)
	cam.look_at(Vector3(0.0, 0.25, 0.0))
	cam.make_current()
	var models := []
	var anims := []
	for h in [0, 2]:
		var look := Unmasked.clean({"unmasked": true, "height": h, "build": h})
		var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", look)
		m.get_node("Rig/Torso/Aim/Gun").free()
		m.position = Vector3(-0.55 + 1.1 * (h / 2), 0, 0)
		m.rotation.y = -PI * 0.5
		stage.add_child(m)
		models.append(m)
		anims.append(HunterAnim.new(m))
	for step in 2:
		var vel := Vector3(0, 0, 0) if step == 0 else Vector3(3.5, 0, 0)
		for i in 75:
			for a in anims:
				(a as HunterAnim).update(1.0 / 60.0, {"fired": 99.0, "face": -PI * 0.5, "vel": vel})
			await tree.process_frame
		await _shot(tree, "feet_%s_short_tall" % ("idle" if step == 0 else "walking"), 0.0)
	stage.queue_free()
	await tree.process_frame

## The gait strip: short/slight, average and tall/sturdy bodies running at the farm's full stick from the side past
## floor posts every half metre (a planted foot holds against them, a sliding one skates), GAIT_SHOTS shots
## GAIT_EVERY frames apart from the moment the lead body enters the frame.
func _gait(tree: SceneTree) -> void:
	_fresh()
	var stage := Node3D.new()
	main.add_child(stage)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 8)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.55, 0.3)
	plane.material = floor_mat
	stage.add_child(floor_mesh)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.9, 0.85, 0.6)
	for i in 13:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.25, 0.03)
		box.material = post_mat
		post.mesh = box
		post.position = Vector3(-3.0 + 0.5 * i, 0.125, 0.9)
		stage.add_child(post)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32.0
	stage.add_child(cam)
	cam.position = Vector3(0.0, 0.7, 6.0)
	cam.look_at(Vector3(0.0, 0.5, 0.0))
	cam.make_current()
	var anims := []
	var models := []
	for b in 3:
		var look := Unmasked.clean({"unmasked": true, "height": b, "build": b, "shroud": 1})     # a Wrap: the legs show
		var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", look)
		m.get_node("Rig/Torso/Aim/Gun").free()
		m.position = Vector3(-4.6 - 0.6 * b, 0, -0.8 + 0.8 * b)
		m.rotation.y = -PI * 0.5
		stage.add_child(m)
		models.append(m)
		anims.append(HunterAnim.new(m))
	var vel := Vector3(5.0, 0, 0)
	var shot := 0
	for i in 200:
		for j in anims.size():
			(models[j] as Node3D).position += vel / 60.0
			(anims[j] as HunterAnim).update(1.0 / 60.0, {"fired": 99.0, "face": -PI * 0.5, "vel": vel})
		await tree.process_frame
		if (models[0] as Node3D).position.x >= -1.5 and (i % GAIT_EVERY) == 0 and shot < GAIT_SHOTS:
			await _shot(tree, "gait_%02d" % shot, 0.0)
			shot += 1
	stage.queue_free()
	await tree.process_frame

## The Empty at home: the farm's own camera, and the Empty turned to face every way.
func _farm(tree: SceneTree) -> void:
	_fresh()
	var d := Save.d
	d["roster"] = [Save.new_kin("cindle", "Ember")]
	d["active"] = d["roster"][0]["uid"]
	d["look"] = Unmasked.default_look()
	d["look"].merge({"hollow": 1, "glow": 2, "colour": 5, "aura": 2}, true)
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true, "match": true}
	var hm = await main._hb_home()
	var views := {"topdown": PI, "front": PI, "side": PI * 0.5, "back": 0.0}
	for view in views:
		hm.pface = views[view]
		hm.player.rotation.y = views[view]
		await _shot(tree, "farm_" + view, 1.2)
	hm.queue_free()
	await tree.process_frame

func _shot(tree: SceneTree, file: String, secs: float) -> void:
	await tree.create_timer(secs).timeout
	tree.root.get_texture().get_image().save_png(dir.path_join(file + ".png"))
