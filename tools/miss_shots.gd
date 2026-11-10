extends "res://tools/vv_shots.gd"
## --miss-shots --shots-dir=<dir> [--miss-hero=gunslinger|archer|mage]: strips of Vex, Lace and Sparkle's left click
## missing into a cliff face and into open air (MissFx), on a live Arena match (xvfb with a renderer). Each strip is
## one frame in flight, then the puff as it opens and fades, cropped round where the shot ended.
## Files: <dir>/<hero>_miss_wall.png, <hero>_miss_air.png and MANIFEST_<hero>.txt.

const HEROES := {"gunslinger": "vex", "archer": "lace", "mage": "sparkle"}
const MISS_CROP := Vector2i(220, 150)         # px round the end point for a frame (scaled 2x)
const AFTER_S := [0.0, 0.07, 0.14, 0.22, 0.32]   # s after the puff appears that a frame is taken
const SHOT_H := 0.95                        # m: ground this far above home stops a shot fired at chest height
const SCAN_M := 40                            # m to look along a direction for a wall
const WALL_GAP := 6.0                         # m from the shooter to the wall
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
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
		await _miss("wall", Vector2.ZERO)
		await _miss("air", _open_dir())
		var f := FileAccess.open(dir.path_join("MANIFEST_%s.txt" % hero_name), FileAccess.WRITE)
		for l in lines:
			f.store_line(l)
		f.close()
		m.queue_free()
		await main.get_tree().process_frame
	print("MISSSHOTS in %s" % dir)
	main.get_tree().quit(0)

## A tile in front of a wall or rock with WALL_GAP tiles of level ground behind it: [shooter start, direction],
## or [] if the map has none.
func _wall_spot() -> Array:
	var W = m.world
	for z in range(4, W.h - 4):
		for x in range(4, W.w - 4):
			if not W.is_block(x + 0.5, z + 0.5):
				continue
			for d in DIRS:
				var start := Vector3(x + 0.5 - d.x * WALL_GAP, 0, z + 0.5 - d.y * WALL_GAP)
				start.y = W.ground_at(start.x, start.z)
				if _level_run(start, d):
					return [start, d]
	return []

## Level, open ground from `start` along d for WALL_GAP tiles, a tile either side too.
func _level_run(start: Vector3, d: Vector2) -> bool:
	for s in range(0, int(WALL_GAP)):
		for side: int in [-1, 0, 1]:
			var x: float = start.x + d.x * s - d.y * side
			var z: float = start.z + d.y * s + d.x * side
			if not m.world.inb(int(x), int(z)) or m.world.is_block(x, z):
				return false
			if absf(m.world.ground_at(x, z) - start.y) > 0.05:
				return false
	return true

## Metres from home along d to the first tile that stops a level shot (higher ground or a rock), or INF.
func _wall_dist(d: Vector2) -> float:
	for s in range(2, SCAN_M):
		var x := home.x + d.x * s
		var z := home.z + d.y * s
		if m.world.ground_at(x, z) > home.y + SHOT_H or m.world.is_block(x, z):
			return float(s)
	return INF

## A direction with no wall for well past the weapon's range (the shot runs out in the air).
func _open_dir() -> Vector2:
	var best := Vector2(-1, 0)
	var far := 0.0
	for d in DIRS:
		var w := _wall_dist(d)
		if w > far:
			far = w
			best = d
	return best

func _miss(part: String, d: Vector2) -> void:
	await _reset(7.0)
	T.teleport(home + Vector3(-30, 0, 30))
	var from := home
	end_pt = home + Vector3(d.x, 0, d.y) * float(P.wpn["range"])
	if part == "wall":
		var spot := _wall_spot()
		if spot.is_empty():
			print("MISS no wall with level ground in front of it on this map")
			return
		from = spot[0]
		d = spot[1]
		end_pt = from + Vector3(d.x, 0, d.y) * WALL_GAP
		P.teleport(from)
	_aim(from + Vector3(d.x, 0, d.y) * 12.0)
	cam_at = end_pt.lerp(from, 0.35)
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
		var into := "a cliff face" if part == "wall" else "open air"
		lines.append("%s/%s|%s|LMB missing into %s: %s" % [hero_name, tag, file, into, caption])
	(strips[file] as Array).append(_crop(img, end_pt, MISS_CROP, 2.0))
	_save_strip(file)
