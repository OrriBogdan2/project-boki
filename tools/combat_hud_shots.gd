extends RefCounted
## --combat-hud-shots --shots-dir=<dir> [--fight=duel|pve]: the same fight frame on the real HUD (GPU, or xvfb
## with a renderer). "duel": you and a rival bot trading hits; "pve": you against the nearest monsters.
## Prints COMBATHUD <fight> <n> lines for the HUD calm check and saves <fight>.png.

const DT := 1.0 / 60.0
const SHOT_SIZE := Vector2i(1920, 1080)      # px: the frame the owner reads
const FIGHT_SECS := 4.0      # s of real fighting before the frame is taken

var main: Node
var m: Match
var P: Hunter

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	var fight := "duel"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--fight="):
			fight = String(a).substr(8)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = SHOT_SIZE
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "length": 1e9})
	m.set_process(false)
	P = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var foe = _stage(fight)
	for i in int(FIGHT_SECS / DT):
		P.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		P.inp["fire"] = true
		m.step(DT)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(fight + ".png"))
	print("COMBATHUD ", fight, " hp ", int(P.hp), " foe ", int(foe.hp))
	main.get_tree().quit(0)

## Puts the player beside the first rival (duel) or the nearest monster (pve); returns the target.
func _stage(fight: String):
	var foes: Array = m.hunters.filter(func(h): return h.team != P.team)
	var target = foes[0]
	if fight == "pve":
		var near: Array = m.mobs.duplicate()
		near.sort_custom(func(a, b): return a.pos.distance_to(P.pos) < b.pos.distance_to(P.pos))
		target = near[0]
	for h in m.hunters:
		if h != P and h != target:
			h.ctrl = "idle"
	P.teleport(m.world.free_spot_near(target.pos + Vector3(5, 0, 3), [], 1.0, 0.45, 4.0))
	return target
