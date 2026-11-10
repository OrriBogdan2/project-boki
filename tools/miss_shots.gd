extends "res://tools/vv_shots.gd"
## --miss-shots --shots-dir=<dir> [--miss-hero=gunslinger|archer|mage]: strips of Vex, Lace and Sparkle's left click
## missing into a cliff face and into open air (MissFx), on a live Arena match (xvfb with a renderer). Each strip is
## one frame in flight, then the puff as it opens and fades, cropped round where the shot ended.
## Files: <dir>/<hero>_miss_wall.png, <hero>_miss_air.png and MANIFEST_<hero>.txt.

const HEROES := {"gunslinger": "vex", "archer": "lace", "mage": "sparkle"}
const MISS_CROP := Vector2i(220, 150)         # px round the end point for a frame (scaled 2x)
const AFTER_S := [0.0, 0.07, 0.14, 0.22, 0.32]   # s after the puff appears that a frame is taken
const CLIFF_GAP := 8                          # tiles of flat ground in front of the cliff
const FIRE_S := 0.12                          # s the button is held: one shot
const WATCH_S := 2.5                          # s to wait for the shot to end

var end_pt := Vector3.ZERO
var prev_img: Image
var fxd: DJFx

func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = HEROES.keys()
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--miss-hero="):
			heroes = [arg.substr(12)]
	DirAccess.make_dir_recursive_absolute(dir)
	for id in heroes:
		who = id
		hero_name = HEROES[id]
		lines.clear()
		strips.clear()
		await _setup()
		fxd = DJFx.of(m)
		fxd.prewarm(P.pos)
		T.teleport(home + Vector3(-30, 0, 30))
		await _miss("wall", _cliff_dir())
		await _miss("air", _open_dir())
		var f := FileAccess.open(dir.path_join("MANIFEST_%s.txt" % hero_name), FileAccess.WRITE)
		for l in lines:
			f.store_line(l)
		f.close()
		m.queue_free()
		await main.get_tree().process_frame
	print("MISSSHOTS in %s" % dir)
	main.get_tree().quit(0)

## A direction with a real cliff face CLIFF_GAP tiles away (a tile at least one level higher), as a unit vector in x/z.
func _cliff_dir() -> Vector2:
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var lv: int = int(m.world.level[m.world.idx(int(floor(home.x)), int(floor(home.z)))])
		var p: Vector3 = home + Vector3(d.x, 0, d.y) * CLIFF_GAP
		if m.world.inb(int(p.x), int(p.z)) and int(m.world.level[m.world.idx(int(p.x), int(p.z))]) > lv:
			return d
	return Vector2(1, 0)

## A direction whose ground stays level out to the weapon's range.
func _open_dir() -> Vector2:
	var rng := float(P.wpn["range"])
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var clear := true
		for s in range(2, int(rng), 2):
			var g := m.world.ground_at(home.x + d.x * s, home.z + d.y * s)
			if g > home.y + 0.05 or m.world.is_block(home.x + d.x * s, home.z + d.y * s):
				clear = false
		if clear:
			return d
	return Vector2(-1, 0)

func _miss(part: String, d: Vector2) -> void:
	await _reset(7.0)
	T.teleport(home + Vector3(-30, 0, 30))
	end_pt = home + Vector3(d.x, 0, d.y) * (CLIFF_GAP if part == "wall" else float(P.wpn["range"]))
	_aim(home + Vector3(d.x, 0, d.y) * 12.0)
	cam_at = end_pt.lerp(home, 0.35)
	var seen := {"t": -1.0, "taken": []}      # (a lambda copies plain variables, so its state lives in a dictionary)
	var watch := func(t: float):
		P.inp["fire"] = t < FIRE_S
		var puff_t: float = seen["t"]
		if puff_t < 0.0 and not fxd.live.is_empty():
			seen["t"] = t
			end_pt = (fxd.live[0]["node"] as Node3D).global_position
			_frame(part, "in flight: the shot a moment before it ended", prev_img)
		elif puff_t >= 0.0:
			for dt in AFTER_S:
				if t >= puff_t + dt and not seen["taken"].has(dt):
					seen["taken"].append(dt)
					_frame(part, "the puff %.2f s in" % dt, main.get_viewport().get_texture().get_image())
		prev_img = main.get_viewport().get_texture().get_image()
	await _go(WATCH_S, watch)
	P.inp["fire"] = false
	print("MISS %s %s puff_t %.2f frames %d" % [hero_name, part, seen["t"], seen["taken"].size()])

func _frame(part: String, caption: String, img: Image) -> void:
	if img == null:
		return
	var file := "%s_miss_%s.png" % [hero_name, part]
	if not strips.has(file):
		strips[file] = []
		lines.append("%s/%s|%s|LMB missing into %s: %s" % [hero_name, tag, file, "a cliff face" if part == "wall" else "open air", caption])
	(strips[file] as Array).append(_crop(img, end_pt, MISS_CROP, 2.0))
	_save_strip(file)
