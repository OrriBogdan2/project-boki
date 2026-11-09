extends RefCounted
## --hero-vfx-gallery --shots-dir=<dir> [--reel-hero=<arch>] (under xvfb with a renderer): every move in a Hero's data
## (or, with no Hero given, one of every layer kind) played side by side at the match camera, captured a few times
## through their lives: <dir>/gallery_<arch>_<n>.png. For tuning a palette and checking a new look reads.

const SLOW := 0.05             # Engine.time_scale while capturing
const GAP := 3.2               # m between moves
const PER_ROW := 6
const SHOTS := [0.08, 0.2, 0.4, 0.8]    # s after the moves start

func run(main: Node) -> void:
	var dir := ""
	var arch := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--reel-hero="): arch = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	var who := arch if arch != "" else "juggernaut"
	# (the Hero's own class and weapon: a Hero of another class than the save's would not take)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"arch": who, "cls": Arch.weight(who), "weapon": Arch.signature(who)})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	if m.hud: m.hud.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	var tag := arch
	if arch == "":
		tag = "kinds"
		HeroVfx.set_data(P.arch, _every_kind())
	var moves: Array = (HeroVfx.data(P.arch).get("moves", {}) as Dictionary).keys()
	var V := HeroVfx.of(m)
	var base := P.pos + Vector3(-GAP * (PER_ROW - 1) * 0.5, 0, -2.0)
	var rows := int(ceil(moves.size() / float(PER_ROW)))
	m.cam.snap(P.pos + Vector3(0, 0, GAP * (rows - 1) * 0.5 - 2.0))
	Sfx.listener = P.pos
	for i in moves.size():
		var at := base + Vector3(GAP * (i % PER_ROW), 0, GAP * (i / PER_ROW))
		V.play(P, String(moves[i]), at, Vector2(1, 0), {"r": 1.6, "len": 2.6, "w": 1.0, "k": 1.0,
			"to": at + Vector3(2.4, 1.0, 0.0)})
	print("GALLERY moves: %s" % ", ".join(moves))
	# (a software renderer draws a frame in ~0.5 s: game time slows so the captures land inside the looks)
	Engine.time_scale = SLOW
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		if t >= float(SHOTS[shot]):
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("gallery_%s_%d.png" % [tag, shot]))
			shot += 1
	Engine.time_scale = 1.0
	print("GALLERY done %s" % dir)
	main.get_tree().quit(0)

## One move per layer kind, in a neutral fire palette (the gallery's default).
func _every_kind() -> Dictionary:
	var moves := {}
	for kind: String in HeroVfx.MODES:
		var layer := {"p": kind, "size": 1.2, "life": 1.2, "y": 0.8 if kind == "flare" else 0.0}
		if kind == "bolt":
			layer = {"p": kind, "size": 0.9, "life": 1.0, "jag": 0.6, "y": 1.0}
		if kind == "ribbon":
			continue        # a trail needs something moving; the reel shows it
		moves[kind] = {"fx": [layer]}
	for kind: String in HeroVfx.LOOKS:
		moves[kind] = {"fx": [{"p": kind, "n": 24, "y": 0.8, "speed": 2.5, "spread": 1.0, "life": 1.2,
			"size": 0.25 if kind in ["card", "coin", "star", "shard"] else 0.1, "grav": 2.0}]}
	return {"palette": {"main": "#5a8cff", "hot": "#e8f4ff", "char": "#101830", "smoke": "#506070"}, "moves": moves}
