extends RefCounted
## --kin-type-trail-shots --shots-dir=<dir> (needs a real renderer: jobq submit --needs gpu): one wild Boki of
## every type walks along its own lane at the match camera so its trail (KinTypeTrail) can be read by eye:
## <dir>/trail_<n>.png. Then each lane's Boki is captured (Capture pop in its type colour): <dir>/pop_0.png.

const SPEED := 3.0            # m/s the Boki walk
const LANE := 2.2             # m between lanes
const SHOTS := [0.5, 1.0, 2.0]    # s of walking at each trail shot
## One species per type that has any (water, normal and dragon have none yet).
const SPECIES := {"spore": "burrlet", "flying": "squalltross", "steel": "tuatrune", "poison": "velvorm",
	"sound": "zapple", "rock": "basaltoad", "dark": "caecilith", "psychic": "casquebill", "fire": "cindowary",
	"ice": "floenatee", "grass": "heatherhorn", "bug": "hivara", "electric": "kestrike", "fairy": "moonloris",
	"crystal": "nacrolin"}

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	if m.hud: m.hud.visible = false
	m.player.ctrl = "idle"
	var kins: Array[Kin] = []
	var start: Vector3 = m.player.pos + Vector3(-6.0, 0, -LANE * SPECIES.size() * 0.5)
	for t: String in SPECIES:
		var k := m.spawn_wild(Save.new_kin(SPECIES[t], t.capitalize()), start + Vector3(0, 0, LANE * kins.size()))
		k.state = "dazed"
		kins.append(k)
	m.cam.snap(m.player.pos + Vector3(0, 0, -1.0))
	for k in kins:
		k.state = "wild"
		k.set_physics_process(false)
		k.set_process(false)
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await main.get_tree().process_frame
		var dt := main.get_process_delta_time()
		t += dt
		for k in kins:
			k.vel = Vector3(SPEED, 0, 0)
			k.global_position += k.vel * dt
			k.pos = k.global_position
			k.render(dt, 1.0)
		if t >= float(SHOTS[shot]):
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("trail_%d.png" % shot))
			shot += 1
	for k in kins:
		k.vel = Vector3.ZERO
		Capture._pop(m, m.player, k)
	for _i in 6:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("pop_0.png"))
	print("TRAILSHOTS done %s (%d walkers, %.1fs)" % [dir, kins.size(), t])
	main.get_tree().quit(0)
