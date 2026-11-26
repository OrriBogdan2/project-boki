extends "res://tools/toon_lineup_shots.gd"
## --toon-lineup-farm-shots --shots-dir=<dir> [--species=a,b] [--arch=a,b]: the lineup of tools/toon_lineup_shots.gd
## on the real farm at its default third-person camera (golden hour, HUD and marks hidden), each model standing 2.4 m
## in front of that camera. Needs the farm third-person camera (PR #943) and a renderer.

const ISLAND_SEED := 11
const DAY_T := 0.72
const FRAMES_PER_S := 30
const FARM_FIT := 1.25

var farm: Node3D
var farm_spot := Vector3.ZERO


func _stage() -> Vector3:
	crop_px = Vector2i(300, 340)
	zoom = 1.4
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	seed(ISLAND_SEED)
	var d := Save.fresh()
	d["cls"] = Arch.weight("mage")
	d["arch"] = "mage"
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	HomeLayout.new_fs(d, ISLAND_SEED)
	Save.d = d
	farm = load("res://scripts/home/home.gd").new()
	farm.set("zone", "")
	main.add_child(farm)
	main.set("current", farm)
	for i in 3:
		await main.get_tree().process_frame
	while farm.building:
		await main.get_tree().process_frame
	Settings.set_v("tips", false)
	farm._close_panel()
	farm.ui.visible = false
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	RenderingServer.frame_pre_draw.connect(_hide_marks)
	world = farm
	farm.player.visible = false
	await _settle(1.0)
	farm_spot = farm.world.free_spot_near(Vector3(56.0, 0, 29.0), [], 0.8)
	farm.ppos = farm_spot + Vector3(0, 0, 2.4)
	farm.player.position = farm.ppos
	farm.farm_cam.yaw = 0.0
	farm.cam.zoom_to = CamWheel.far()
	farm.cam.zoom = farm.cam.zoom_to
	farm.cam.snap(farm.ppos)
	await _settle(1.0)
	return farm_spot


func _settle(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FRAMES_PER_S)):
		await main.get_tree().process_frame
		farm.day_t = DAY_T


## A Boki on the farm is drawn at FARM_FIT (the live farm size, the owner's scale sheet), a Hunter at its own size.
func _spawn(row: Array, at: Vector3) -> Node3D:
	var node := super._spawn(row, at)
	if row[0] == "boki":
		node.scale = Vector3.ONE * FARM_FIT
	return node


func _hide_marks() -> void:
	farm.ui.visible = false
	for l in farm.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	for sp in farm.find_children("*", "Sprite3D", true, false):
		(sp as Sprite3D).visible = false
