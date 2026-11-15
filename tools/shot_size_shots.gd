extends RefCounted
## --shot-size-shots --shots-dir=<dir> [--res=720|1080]: each Hunter's LMB projectile in flight at the default
## camera (on the shooter), measured on rendered frames of exactly res x 16:9 (its own SubViewport, so the
## window size doesn't matter). Writes <dir>/shotsize_<hero>_<res>.png (a 3x crop round the shot) and
## <dir>/MANIFEST.txt lines "shotsize|<hero>|<res>|<look px>|<core px>|<rim px>", widths across the flight line:
## "look" is the shot's own drawing (sphere or kit skin: the pixels that change when the shot is moved away,
## beacons left out); "core" the hot white pixels of ShotFloor's beacon, "rim" its whole footprint.
## Time is frozen while a shot is measured, so particles hold still between the frames compared.
## Run with a renderer (jobq --needs gpu).

const HEROES := ["gunslinger", "tender", "dolm", "archer", "dredge", "rimewright", "mage", "thief", "ostra"]
const DT := 1.0 / 60.0
const HOLD := {"archer": 0.7}      # s of LMB held before the release (a drawn bow); the rest tap
const DIFF := 0.08                 # a pixel channel change that counts as the shot's (0..1)
const HOT := 0.8                   # the darkest channel of a core pixel (0..1: near white)
const AWAY := Vector3(0, 0, 400)   # m: where a shot is parked for the frame without it
const AIM_AT := 16.0               # m to the target: far enough that a fast bolt is still flying when measured

var main: Node
var m: Match
var sv: SubViewport
var eye: Camera3D
var lines: Array = []

func run(main_node: Node, _mode: String) -> void:
	main = main_node
	var res := 720
	var out := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--res="): res = int(String(a).substr(6))
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("gunslinger"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	sv = SubViewport.new()
	sv.size = Vector2i(res * 16 / 9, res)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	eye = Camera3D.new()
	sv.add_child(eye)
	main.add_child(sv)      # no world of its own: it draws the match's
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var spot = load("res://tools/aimkit_shots.gd").new()
	spot.main = main
	spot.m = m
	var home: Vector3 = spot._spot(P.pos)
	if m.hud: m.hud.visible = false
	for hero in HEROES:
		await _hero(hero, P, home, out, res)
	var f := FileAccess.open(out.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	print("SHOTSIZE shots: %d in %s at %dp (frames %s)" % [lines.size(), out, res, sv.size])
	Engine.time_scale = 1.0
	m.queue_free()
	await main.get_tree().process_frame
	main.get_tree().quit()

func _hero(hero: String, P: Hunter, home: Vector3, out: String, res: int) -> void:
	m.set_process(false)      # stepped by hand: the live input would overwrite the scripted trigger
	Engine.time_scale = 1.0
	for x in m.hunters:
		if x != P: x.teleport(home + Vector3(-30, 0, 30))
	P.set_arch(hero)
	P.unlock_all()
	P.teleport(home)
	P.vel = Vector3.ZERO
	for i in 30:
		m.step(DT)      # the new kit settles (its cooldowns and holds start clean)
	var at := home + Vector3(AIM_AT, 0, 0)
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, at, {"arch": "none"})
	T.max_hp = 10000.0
	T.hp = T.max_hp
	var found := {}
	var t := 0.0
	while t < 1.6 and found.is_empty():
		P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
		P.inp["aim_y"] = T.pos.y
		P.inp["fire"] = t < float(HOLD.get(hero, 0.1))
		m.step(DT)
		t += DT
		for s in m.shots:
			if s["by"] == P and ShotFloor.wants(s):
				found = s
	P.inp["fire"] = false
	if found.is_empty():
		lines.append("shotsize|%s|%d|no projectile||" % [hero, res])
		print("SHOTSIZE %-10s %dp no projectile" % [hero, res])
	else:
		for i in 2:
			if m.shots.has(found): m.step(DT)      # clear of the muzzle flash
		if m.shots.has(found):
			await _measure(hero, found, out, res)
		else:
			lines.append("shotsize|%s|%d|ended before measured||" % [hero, res])
			print("SHOTSIZE %-10s %dp ended before measured" % [hero, res])
	m.hunters.erase(T)
	T.queue_free()
	await main.get_tree().process_frame

## Three frames with time frozen: the shot without beacons, the shot parked away, the shot with its beacon.
func _measure(hero: String, s: Dictionary, out: String, res: int) -> void:
	Engine.time_scale = 0.0
	m.hitstop = 0.0      # (a freeze from an earlier hit would never run out at a zero delta and skip the render)
	m.set_process(true)      # renders (shots, skins, beacons) but steps nothing at a zero delta
	m.cam.snap(m.player.pos)
	var p: Vector3 = s["pos"]
	var v: Vector2 = s["vel"]
	var bare := await _frame(s, p, false)
	var gone := await _frame(s, p + AWAY, false)
	var lit := await _frame(s, p, true)
	m.set_process(false)
	if bare.is_empty() or lit.is_empty():
		lines.append("shotsize|%s|%d|no frame||" % [hero, res])
		return
	var c := eye.unproject_position(p)
	var along := (eye.unproject_position(p + Vector3(v.x, 0, v.y).normalized()) - c).normalized()
	var across := Vector2(-along.y, along.x)
	var look := _span(c, across, func(q: Vector2i) -> bool: return _diff(bare, gone, q))
	var core := _span(c, across, func(q: Vector2i) -> bool: return _hot(lit, q))
	var rim := _span(c, across, func(q: Vector2i) -> bool: return _diff(lit, bare, q) or _hot(lit, q))
	var want := Rect2i(Vector2i(int(c.x) - 80, int(c.y) - 50), Vector2i(160, 100))
	var rg := want.intersection(Rect2i(Vector2i.ZERO, lit.get_size()))
	var crop := lit.get_region(rg)
	crop.resize(rg.size.x * 3, rg.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("shotsize_%s_%d.png" % [hero, res]))
	lines.append("shotsize|%s|%d|%d|%d|%d" % [hero, res, look, core, rim])
	print("SHOTSIZE %-10s %dp look %d px, beacon core %d px, rim %d px (floor %.0f)" % [hero, res, look, core, rim,
		ShotFloor.MIN_CORE_PX * res / ShotFloor.REF_H])

## One rendered frame of the match with the shot at `at` (beacons drawn or not); an empty Image without a renderer.
func _frame(s: Dictionary, at: Vector3, beacons: bool) -> Image:
	s["pos"] = at
	s["prev"] = at
	eye.fov = m.cam.fov
	eye.environment = m.cam.environment
	eye.attributes = m.cam.attributes
	eye.global_transform = m.cam.global_transform
	eye.cull_mask = 0xFFFFF if beacons else 0xFFFFF & ~ShotFloor.LAYER
	if DisplayServer.get_name() == "headless":
		return Image.new()      # nothing is drawn (the firing still runs, for a quick look without a GPU)
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	return img if img != null else Image.new()

## Pixels across the shot through screen point `c` along `dir` for which `inside` holds (gaps of 1 px bridged).
func _span(c: Vector2, dir: Vector2, inside: Callable) -> int:
	var n := 0
	for sgn in [-1.0, 1.0]:
		var miss := 0
		for k in range(0 if sgn > 0 else 1, 60):
			var q := Vector2i((c + dir * k * sgn).round())
			if inside.call(q):
				n += 1 + miss
				miss = 0
			else:
				miss += 1
				if miss > 1: break
	return n

func _diff(a: Image, b: Image, q: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, a.get_size()).has_point(q): return false
	var x := a.get_pixelv(q)
	var y := b.get_pixelv(q)
	return maxf(absf(x.r - y.r), maxf(absf(x.g - y.g), absf(x.b - y.b))) > DIFF

func _hot(a: Image, q: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, a.get_size()).has_point(q): return false
	var x := a.get_pixelv(q)
	return minf(x.r, minf(x.g, x.b)) > HOT
