extends "res://tools/aimkit_shots.gd"
## Screenshots for --mob-tell-check --shots-dir=<dir>: one strip per monster (mob_tell_<kind>.png), the
## wind-up frozen at 25 / 60 / 100 % so the ground tell filling and the body glow brightening read side
## by side. The glimmerkin never attacks: its strip is one frame, with nothing on the ground.
## Writes <dir>/MANIFEST.txt (mobtell|<file>|<caption>). Run under xvfb with a renderer.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const STEPS := [0.25, 0.6, 1.0]
const CROP := Vector2i(900, 560)  # px of each frame kept, round the monster


func take(main_node: Node, out: String) -> void:
	main = main_node
	dir = out
	DirAccess.make_dir_recursive_absolute(dir)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("gunslinger"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _spot(P.pos)
	for x in m.hunters:
		if x != P:
			x.teleport(home + Vector3(-30, 0, 30))
	if m.hud:
		m.hud.visible = false
	for k in KINDS:
		await _strip(k)
	var f := FileAccess.open(dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("MOBTELL shots: %d in %s" % [lines.size(), dir])
	m.queue_free()
	await main.get_tree().process_frame


func _strip(kind: String) -> void:
	var at := home + Vector3(2, 0, 0)
	var mb := m.spawn_mob(kind, at)
	mb.teleport(at)
	P.teleport(at + Vector3(3.0, 0, 0))
	P.vel = Vector3.ZERO
	var attacks: bool = mb.md["attack"] != "none"
	mb.tgt = P
	if attacks:
		mb._begin_attack()
	var frames: Array = []
	for f in STEPS if attacks else [0.0]:
		mb.st_t = float(mb.md["windup"]) * (1.0 - float(f))
		for i in 6:
			if attacks:
				MobTell.update(mb)
			mb.render(1.0 / 60.0, 1.0)
			P.render(1.0 / 60.0, 1.0)
			m.cam.snap(at + Vector3(3.5, 0, 0))
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
		var rg := Rect2i(c - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		frames.append(img.get_region(rg))
	var w: int = (frames[0] as Image).get_width()
	var h: int = (frames[0] as Image).get_height()
	var strip := Image.create(w * frames.size(), h, false, (frames[0] as Image).get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(w * i, 0))
	strip.resize(strip.get_width() / 2, strip.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	var file := "mob_tell_%s.png" % kind
	strip.save_png(dir.path_join(file))
	var note := "wind-up at 25 / 60 / 100 %" if attacks else "it never attacks: no tell"
	lines.append("mobtell|%s|%s: %s" % [file, mb.md["name"], note])
	MobTell.clear(mb)
	mb.dead = true
	mb.visible = false
	m.mobs.erase(mb)
	mb.queue_free()
