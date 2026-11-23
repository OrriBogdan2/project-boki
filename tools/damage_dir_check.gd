extends RefCounted
## --damage-dir-check [--shots-dir=<dir>]: hits on your Hunter light an arc on the ring that points at
## the Hunter who dealt them (screen space), bigger hits draw bolder arcs, the arcs fade in
## DamageDir.LIFE, and monster, hazard and Blight damage draw none. With --shots-dir (GPU) it saves
## the screen with four arcs lit. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DAMAGEDIR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await main.fade.reveal(0.01)       # the boot splash stays up when a tool starts the match by hand
	var m := Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=fight")
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "arch": "thief", "cls": Arch.weight("thief"),
		"weapon": Arch.signature("thief")})
	m.start(opts)
	for i in 30:
		await main.get_tree().process_frame
	var P: Hunter = m.player
	var foes: Array = m.hunters.filter(func(x): return x != P)
	ok(m.hud != null and foes.size() >= 4, "a match with the HUD and four rivals (%d)" % foes.size())
	if foes.size() < 4:
		return _done()
	var dd: DamageDir = m.hud.dmg_dir
	dd.hits.clear()
	var sides := {"right": Vector3(8, 0, 0), "down": Vector3(0, 0, 8),
		"left": Vector3(-8, 0, 0), "up": Vector3(0, 0, -8)}
	var want := {"right": 0.0, "down": PI * 0.5, "left": PI, "up": -PI * 0.5}
	var i := 0
	for side in sides:
		foes[i].pos = P.pos + sides[side]
		dd.hits.clear()
		m.on_damage(P, foes[i], 30.0, {})
		var got: float = dd.hits[0]["ang"] if dd.hits.size() == 1 else 99.0
		var off := absf(angle_difference(got, float(want[side])))
		ok(off < 0.35, "a hit from the %s lights the %s arc (%.2f rad)" % [side, side, got])
		i += 1
	dd.hits.clear()
	for side in sides:
		foes[i - 1].pos = P.pos + sides[side]
		m.on_damage(P, foes[i - 1], 30.0, {})
		i += 1
	ok(dd.hits.size() == 4, "four hits from four sides: four arcs (%d)" % dd.hits.size())
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	if _shots_dir() != "":
		DirAccess.make_dir_recursive_absolute(_shots_dir())
		main.get_viewport().get_texture().get_image().save_png(_shots_dir().path_join("damage_dir_four.png"))
	dd.hits.clear()
	m.on_damage(P, foes[0], 10.0, {})
	m.on_damage(P, foes[1], 90.0, {})
	ok(float(dd.hits[1]["power"]) > float(dd.hits[0]["power"]), "a big hit draws a stronger arc than a small one")
	dd.tick(DamageDir.LIFE * 0.5)
	ok(dd.hits.size() == 2, "arcs are still up half way through their fade")
	dd.tick(DamageDir.LIFE * 0.6)
	ok(dd.hits.is_empty(), "arcs are gone after %.1f s" % DamageDir.LIFE)
	var mob: Ent = m.mobs[0] if not m.mobs.is_empty() else null
	ok(mob != null, "there is a monster to hit you")
	if mob:
		mob.pos = P.pos + Vector3(6, 0, 0)
		m.on_damage(P, mob, 30.0, {})
	m.on_damage(P, null, 30.0, {"src": "blight"})
	m.on_damage(P, P, 30.0, {"src": "fall"})
	ok(dd.hits.is_empty(), "monster, Blight and hazard damage draw no arc")
	_done()

func _shots_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): return String(a).substr(12)
	return ""

func _done() -> void:
	print("DAMAGEDIR CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
