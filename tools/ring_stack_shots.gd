extends "res://tools/aimkit_shots.gd"
## --ring-stack-shots --shots-dir=<dir> (needs a renderer): a 3v3 melee piled on one spot, every Boki out, a
## cast telegraph from each side on top of the ownership rings. <dir>/melee_stack.png (match camera) and
## melee_stack_close.png (2x crop of the pile). Uses only calls that exist before and after the ground-order rule,
## so the same file takes the before and the after (docs/COMBAT_CLARITY.md, "Ground order").

const PILE := [
	Vector3(0, 0, 0), Vector3(0.9, 0, 0.3), Vector3(-0.8, 0, 0.5),
	Vector3(0.5, 0, -0.9), Vector3(-0.6, 0, -0.7), Vector3(0.1, 0, 1.1),
]
const TELE_S := 3.0       # s a telegraph fills over
const SETTLE := 75        # frames before the still: the fills are part way across

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var o := {"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	home = _spot(P.pos)
	if m.hud: m.hud.visible = false
	for i in mini(m.hunters.size(), PILE.size()):
		var h: Hunter = m.hunters[i]
		h.ctrl = "idle"
		h.teleport(home + PILE[i])
		h.vel = Vector3.ZERO
		if h.kin:
			(h.kin as Kin).state = "active"
			(h.kin as Kin).teleport(h.pos + Vector3(0.5, 0, 0.4))
	for i in 5: m.step(1.0 / 60.0)
	_stage()
	m.cam.snap(home)
	for i in SETTLE:
		for h in m.hunters: h.render(1.0 / 60.0, 1.0)
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("melee_stack.png"))
	var c := img.get_size() / 2
	var rg := Rect2i(c - Vector2i(320, 180), Vector2i(640, 360))
	var crop := img.get_region(rg)
	crop.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	crop.save_png(dir.path_join("melee_stack_close.png"))
	print("RINGSTACK shots in %s" % dir)
	main.get_tree().quit(0)

## Your cast, a teammate's and three rivals' (two ground circles, one AimKit disc), all over the pile.
func _stage() -> void:
	var rivals: Array = m.hunters.filter(func(h): return h.team != P.team)
	var mates: Array = m.hunters.filter(func(h): return h != P and h.team == P.team)
	P.ak.tele_circle(home, 3.2, Color("5ad0f0"), TELE_S)
	(mates[0] as Hunter).ak.tele_circle(home, 2.6, Color("ffc832"), TELE_S)
	(rivals[0] as Hunter).ak.tele_circle(home, 3.0, Color("ff7a3a"), TELE_S)
	(rivals[1] as Hunter).ak.tele_circle(home + Vector3(0.6, 0, 0.4), 2.2, Color("b06aff"), TELE_S)
	var disc := {"all": true, "at": home, "r": 2.8, "fill": 0.6, "dur": 4.0, "col": Color("9be85a")}
	AimKit.circle(rivals[2], "stack", disc)
