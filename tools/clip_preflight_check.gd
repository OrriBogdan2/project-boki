extends RefCounted
## --clip-preflight-check: the film tools' pre-render asset check (tools/clip_preflight.gd) tells a good scene from
## a bad one: the drawn Motley glb is the v95 current one (where the box has the v95 folder), a placeholder hunter,
## an old glb, a primitive Boki and every overlay switch are each named, and a clean scene passes.

const Preflight := preload("res://tools/clip_preflight.gd")
const V95 := "/home/boki/meshy/v95"

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CLIPPREFLIGHT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var saved := [Settings.v.get("show_fps", 0), Settings.v.get("tips", true), Record.level]
	Settings.v["show_fps"] = 0
	Settings.v["tips"] = false
	Record.set_level(1)
	var stage := Node3D.new()
	main.add_child(stage)
	var look := PlayerLook.neutral()
	var hunter := Models.hunter(Arch.weight("ostra"), Data.TEAM_COLORS[0], Arch.signature("ostra"), "", look, "ostra")
	stage.add_child(hunter)
	var kin := Models.kin("nimbostrich")
	stage.add_child(kin)
	var have_v95 := DirAccess.dir_exists_absolute(V95)
	_scene(stage, have_v95)
	_glb(have_v95)
	_overlays(stage)
	stage.queue_free()
	Settings.v["show_fps"] = saved[0]
	Settings.v["tips"] = saved[1]
	Record.set_level(saved[2])
	print("CLIPPREFLIGHT %s (%d bad)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(0 if bad == 0 else 1)


func _scene(stage: Node3D, have_v95: bool) -> void:
	var hunter := stage.get_child(0) as Node3D
	ok(bool(hunter.get_meta("meshy_native", false)), "ostra is dressed on its native glb here")
	ok(Preflight.problems(stage, 1).is_empty() or not have_v95, "a clean scene has no problems")
	hunter.set_meta("meshy_native", false)
	ok(_has(Preflight.problems(stage, 1), "placeholder body"), "a hunter on the procedural body is named")
	hunter.set_meta("meshy_native", true)
	var flex := Node3D.new()
	flex.name = "Flex"
	stage.add_child(flex)
	ok(_has(Preflight.problems(stage, 1), "primitive placeholder"), "a Boki without a rigged model is named")
	flex.queue_free()


func _glb(have_v95: bool) -> void:
	if not have_v95:
		print("CLIPPREFLIGHT skip no v95 folder on this box (glb-vs-current tests)")
		return
	ok(Preflight.glb_problem("ostra", WardenGlb.path("ostra"), V95) == "", "Motley's drawn glb is the v95 current")
	ok(Preflight.glb_problem("ostra", WardenGlb.path("sable"), V95) != "", "another hunter's glb is refused for Motley")
	ok(Preflight.glb_problem("ostra", "res://art/wardens/ostra/ostra.glb", V95) != "", "the contract glb is refused")
	ok(Preflight.glb_problem("nobody", WardenGlb.path("ostra"), V95) != "", "an art name with no v95 folder fails")


func _overlays(stage: Node3D) -> void:
	Settings.v["show_fps"] = 1
	ok(_has(Preflight.overlays(stage, 1), "show_fps"), "the frame-rate switch is named")
	Settings.v["show_fps"] = 0
	Settings.v["tips"] = true
	ok(_has(Preflight.overlays(stage, 1), "tips"), "tips are named for a clean clip")
	ok(not _has(Preflight.overlays(stage, 0), "tips"), "tips pass where the HUD may show")
	Settings.v["tips"] = false
	Record.set_level(0)
	ok(_has(Preflight.overlays(stage, 1), "Record level"), "a HUD at full is named for a clean clip")
	ok(Preflight.overlays(stage, 0).is_empty(), "the HUD at full passes where it may show")
	Record.set_level(1)


func _has(list: PackedStringArray, part: String) -> bool:
	for p in list:
		if part in p:
			return true
	return false
