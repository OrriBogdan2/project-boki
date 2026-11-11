extends RefCounted
## --neve-feel-film --shots-dir=<dir> [--film=shards|skate]: Neve at the match camera, every frame saved as
## <dir>/frames/NNNNN.jpg at 30 fps for an MP4 made off the GPU box (ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg).
##   shards  she darts a bot until it Shatters, twice: the ice shards build in its body, then go with the burst
##   skate   three skates: a 90 degree key swing, a full reverse, a zigzag; each let go into the slide-out
## Run it on the tree before and after a Skate change to film the two side by side. Needs a renderer.

const DT := 1.0 / 60.0
const FRAME_W := 960           # px wide, each saved frame
const SEED := 5                # the demo map's roll (Dusk Isles), as tools/gameplay_media.gd
const CLEAR := 18              # m: the open ground looked for round her each way (a skate runs about 18 m)

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var dir := ""
var frames := 0
var home := Vector3.ZERO

func run(main_node: Node) -> void:
	main = main_node
	var film := "shards"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
		if a.begins_with("--film="):
			film = a.substr(7)
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	Save.no_write = true
	await _start()
	await _go(0.6)
	if film == "skate":
		T.teleport(home + Vector3(13, 0, -13))       # parked in a corner, clear of the skates
		await _skate(Vector3(-8, 0, -8), [Vector2(0, 1)], 0.0)
		await _skate(Vector3(-6, 0, -3), [Vector2(-1, 0.05)], 0.0)
		await _skate(Vector3(-9, 0, 0), [Vector2(0, 1), Vector2(0, -1)], 0.35)
	else:
		for i in 2:
			await _shatter()
	print("NEVE_FILM_DONE %s %d frames" % [film, frames])
	main.get_tree().quit(0)

## A seeded Dusk Isles match with only Neve (no drop, no mobs, no guide text) and a standing bot to dart.
func _start() -> void:
	var o := {"teams": 2, "squad": 3, "total": 1, "tier": 1, "seed": SEED, "length": 1e9, "no_drop": true,
		"raid": "clear", "blight": false, "sim_keep": true, "arch": "rimewright", "cls": Arch.weight("rimewright"),
		"weapon": Arch.signature("rimewright")}
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	if m.hud:
		m.hud.guide_hidden = true
	P = m.player
	P.unlock_all()
	P.lvl = 6
	T = m.make_hunter("T", P.team + 1, "medium", "Rival", "idle", {}, P.pos, {"arch": "thief"})
	T.max_hp = 10000.0
	T.hp = T.max_hp
	_open_ground()
	HeroVfx.of(m)

## Moves home to the middle of the widest open, flat patch of the map (so no skate runs off the edge), and hides
## what stands tall there.
func _open_ground() -> void:
	var W = m.world
	var best := -1
	for z in range(0, W.h, 2):
		for x in range(0, W.w, 2):
			var r := _open_r(W, x, z)
			if r > best:
				best = r
				home = Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	print("NEVE_FILM open ground r=%d at %s" % [best, home])
	P.teleport(home)
	T.teleport(home + Vector3(6, 0, 0))
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var n := g as GeometryInstance3D
		if n.global_transform.origin.y > home.y + 0.4 and not n is MultiMeshInstance3D:
			var owned := false
			for h in m.hunters:
				owned = owned or (h as Node).is_ancestor_of(n)
			if not owned:
				n.visible = false

## The open radius (m) round tile x, z: grown ring by ring until a tile is not plain ground at x, z's level.
func _open_r(W, x: int, z: int) -> int:
	var lv := int(W.level[W.idx(x, z)])
	for r in range(0, CLEAR):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				if not W.inb(x + dx, z + dz):
					return r
				var i: int = W.idx(x + dx, z + dz)
				if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or W.walls.has(i) or W.props.has(i):
					return r
	return CLEAR

## Darts at the bot until it Shatters (the shards build one per dart), then a beat after.
func _shatter() -> void:
	var K: RimewrightKit = P.ak
	var s0 := K.splinter_log
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y
	P.inp["fire"] = true
	var t := 0.0
	while K.splinter_log == s0 and t < 4.0:
		await _go(DT * 2.0)
		t += DT * 2.0
	P.inp["fire"] = false
	await _go(1.6)

## One skate from home + `from` along +x: after 0.2 s the keys go to keys[0] (then alternate through `keys` every `swap`
## s); Shift held 1.4 s, then let go with no keys for the slide-out.
func _skate(from: Vector3, keys: Array, swap: float) -> void:
	P.teleport(home + from)
	P.vel = Vector3.ZERO
	await _go(0.3)
	P.dashes = 1.0
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	await _go(DT * 2.0)
	P.inp["dash"] = false
	var t := 0.0
	while t < 1.4:
		if t >= 0.2:
			var k := 0 if swap <= 0.0 else int((t - 0.2) / swap) % keys.size()
			P.inp["move"] = keys[k]
		await _go(DT * 2.0)
		t += DT * 2.0
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	await _go(1.0)

## Steps the match `secs`, saving one frame every two steps (30 fps).
func _go(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.001:
		for i in 2:
			m.step(DT)
			for mb in m.mobs:
				mb.queue_free()
			m.mobs.clear()
			for h in m.hunters:
				(h as Hunter).render(DT, 1.0)
		m.cam.snap(P.pos)
		await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
		img.save_jpg(dir.path_join("frames/%05d.jpg" % frames), 0.9)
		frames += 1
		t += DT * 2.0
