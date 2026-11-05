extends RefCounted
## --empty-shots --shots-dir=<dir>: review screenshots of the Empty creator (Male / Female, three heights,
## builds, hollow styles), the Masks viewer and the first-Mask moment (xvfb with a renderer). Add
## --only=creator|viewer|mask to take one group (the second Mask, from Hob: --hob-check --shots-dir=).

const LOOKS := {
	"creator_female": {"gender": 0},
	"creator_male_short": {"height": 0}, "creator_male_tall": {"height": 2},
	"creator_female_short": {"gender": 0, "height": 0}, "creator_female_tall": {"gender": 0, "height": 2},
	"creator_slight": {"build": 0}, "creator_sturdy": {"build": 2},
	"void_mask_ember": {"hollow": 1, "glow": 1, "ghost": 2, "motes": 2},
	"void_torn_violet": {"gender": 0, "hollow": 2, "glow": 2, "ghost": 3, "colour": 4},
	"void_crescent_gold": {"hollow": 3, "glow": 4, "ghost": 1, "colour": 8},
}

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
	await _shot(tree, "mask_4_lifting", 0.35)
	await _shot(tree, "mask_5_flash", 0.4)
	await _shot(tree, "mask_6_you_as_vex", 0.6)
	await _shot(tree, "mask_7_vex_intro", 2.2)
	hx.queue_free()
	await tree.process_frame

func _shot(tree: SceneTree, file: String, secs: float) -> void:
	await tree.create_timer(secs).timeout
	tree.root.get_texture().get_image().save_png(dir.path_join(file + ".png"))
