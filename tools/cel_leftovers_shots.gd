extends RefCounted
## --cel-leftovers-shots --shots-dir=<dir> --preset=<very_low|low|medium|high> (under xvfb with a renderer): the
## looks that were not on the cel pass (KitLooks' tinted lumps: sigil, mote, aura, rock cracks, crater, the seed's ring
## in Vex green / Sparkle pink / Tenzo blue; CareLook's ice: spikes, shell, frost, Rink Wall) at the match camera.
## Writes <dir>/cel_<preset>_<n>.png and prints "CELSHOTS draws <preset> <n> <draw calls> <objects>" per shot, to
## compare before and after a change to those materials.

const SLOW := 0.1              # Engine.time_scale while capturing
const SHOTS := [0.45, 0.9]     # s after the looks start
const GREEN := Color("b8f03c")     # Vex, Sparkle and Tenzo: Arch.color
const PINK := Color("ff5ab4")
const BLUE := Color("3a7cff")
const HELD_S := 4.0            # s a timed look is given, so a shot lands in its up-and-held part

func run(main: Node) -> void:
	var dir := ""
	var preset := "high"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--preset="): preset = String(a).substr(9)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["quality"] = preset
	Settings._apply_quality()
	Settings._apply_render_scale()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"arch": "rimewright", "cls": Arch.weight("rimewright"), "weapon": Arch.signature("rimewright")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	if m.hud: m.hud.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	var at := P.pos + Vector3(0, 0, -2.0)
	m.cam.snap(at)
	Sfx.listener = P.pos
	_kit_row(m, P, at + Vector3(0, 0, -1.6))
	var care := _care_row(m, P, at + Vector3(0, 0, 1.6))
	Engine.time_scale = SLOW
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		care.tick(main.get_process_delta_time())
		if t >= float(SHOTS[shot]):
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("cel_%s_%d.png" % [preset, shot]))
			var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			print("CELSHOTS draws %s %d %d %d (frame %d)" % [preset, shot, draws, objs, Engine.get_process_frames()])
			shot += 1
	Engine.time_scale = 1.0
	main.get_tree().quit(0)

func _kit_row(m: Node, P: Hunter, at: Vector3) -> void:
	var K := KitLooks.of(m)
	var cols := [GREEN, PINK, BLUE]
	for i in cols.size():
		var x := at + Vector3(-6.5 + 1.7 * i, 0, 0)
		K.sigil("sigil%d" % i, P, x, 0.8, 0.8, cols[i])
		K.hold_on("mote%d" % i, "mote", P, x + Vector3(0, 0.9, 0.6), 1.0, cols[i])
		HeroZones.seed_visual(m, "seed%d" % i, at + Vector3(4.6 + 1.5 * i, 0, 0), 0.6, 0.01, cols[i])
	K.hold_on("aura", "aura", P, at + Vector3(0.4, 0, 0))
	K.impact(at + Vector3(2.6, 0, 0), 1.6, 1.0, HELD_S)
	var rock := RockLook.make()
	m.add_child(rock)
	rock.global_position = at + Vector3(-1.2, 0, 0)

func _care_row(m: Node, P: Hunter, at: Vector3) -> CareLook:
	var C := CareLook.new(m, P)
	C.burst("spikes", at + Vector3(-4.0, 0, 0), {"col": Color("8ae6ff"), "r": 1.4, "dur": HELD_S})
	C.burst("shell", at + Vector3(-1.8, 0, 0), {"col": Color("8ae6ff"), "r": 1.3, "dur": HELD_S})
	C.keep("frost", "frost", at + Vector3(0.2, 0, 0), {"r": 1.3})
	C.keep("wall", "wall", at, {"a": Vector2(at.x + 1.8, at.z), "b": Vector2(at.x + 5.0, at.z), "y": at.y})
	return C
