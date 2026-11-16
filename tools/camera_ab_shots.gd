extends "res://tools/gameplay_media.gd"
## --camera-ab-shots --hero=<arch id> --shots-dir=<dir>: one Hunter in three staged moments, each shot under the
## Supervive camera and the source_scale one (the flag, docs/CAMERA_AB.md), as <dir>/<hero>_<moment>_<style>.png:
##   fight   open ground: the hero and a rival fighting at FIGHT_GAP
##   glide   a ledge drop: the hero runs off an edge over the abyss and glides
##   squads  three squads of three, SQUAD_GAP apart, the hero's in the middle of it
## Both styles share one match and the same placements; the bots' rolls differ a little between the two.
## The camera is driven as Match does it, minus the cursor lean (the cursor sits idle).
## Needs a renderer (jobq --needs gpu).

const STYLES := ["supervive", "source_scale"]
const SIZE := Vector2i(1280, 720)   # px of each shot
const FIGHT_SECS := 2.0             # s of fight before the open-ground shot
const SQUAD_SECS := 2.5             # s of fight before the squads shot
const GLIDE_SECS := 1.4             # s after the run-off before the glide shot
const RUN_MAX := 6.0                # s the run to the edge may take before the glide shot is given up on
const SQUAD_GAP := 12.0             # m between the three squads' centres
const EDGE_RUN := 6.0               # m of run-up to the edge the glide starts from
const RIVALS := [["archer", "wisplet"], ["bulwark", "burrlet"], ["mage", "puddlet"], ["juggernaut", "pebbit"],
		["gunslinger", "zapple"]]

var hero := "gunslinger"
var pool: Array = []         # the rivals, parked (out) between shots
var used := 0
var home := Vector3.ZERO     # open ground the fights are staged on (the glide leaves the hero over the abyss)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="): hero = String(a).substr(7)
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	for style in STYLES:
		if m:
			m.queue_free()
			pool.clear()
		await _start(hero, "cindle")      # a match each: the fights leave burns and slows on the hero
		m.player.ctrl = "bot"
		m.player.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
		home = _ground(m.player.pos)
		_style(style)
		await _glide_shot(style)
		await _fight_shot(style)
		await _squads_shot(style)
	print("CAMERAAB %s in %s" % [hero, dir])
	main.get_tree().quit(0)

## The style under test, set the way the Settings do (the Hunters' models are refitted on their next render).
func _style(id: String) -> void:
	Settings.set_v("cam_style", id, false)
	m.cam_style = id
	m.cam.use_style(id)

## The next unused rival, put on `team` at `at` and back in the fight.
func _rival(team: int, at: Vector3) -> Hunter:
	if used >= pool.size():
		var r: Array = RIVALS[used % RIVALS.size()]
		pool.append(_hunter("r%d" % used, team, r[0], r[1], _ground(at)))
	var h: Hunter = pool[used]
	used += 1
	h.team = team
	h.out = false
	h.hp = h.max_hp
	h.vel = Vector3.ZERO
	h.ctrl = "bot"
	h.teleport(_ground(at))
	return h

## Steps `secs` of the match as Match runs a frame (the camera follows the hero, the zoom eases), then saves the shot.
func _take(secs: float, file: String, each: Callable, until := Callable()) -> void:
	var P := m.player
	var t := 0.0
	m.cam.zoom = 1.0
	m.cam.snap(P.pos)
	while t < secs and not (until.is_valid() and until.call(t)):
		_purge()
		each.call(t)
		for _i in 2:
			m.step(STEP)
		m.cam.zoom_to = 1.25 if P.gliding else 1.0
		m.cam.lead_vel = m.cam_lead_vel()
		m.cam.follow(P.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	var east := m.cam.unproject_position(P.pos + Vector3(10, 0, 0)) - m.cam.unproject_position(P.pos)
	print("CAMERAAB shot %s: 10 m of ground is %.0f px across" % [file, east.x])

## The rivals are parked (out), the hero set down at `at` with full health.
func _clear(at: Vector3) -> void:
	for h in pool:
		h.out = true
	used = 0
	var P := m.player
	P.teleport(at)
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	P.out = false
	P.downed = false
	P.stun_t = 0.0
	P.root_t = 0.0

func _fight_shot(style: String) -> void:
	var base := home
	_clear(base)
	var foe := _rival(1, base + Vector3(FIGHT_GAP, 0, 0))
	var mine: Array = [m.player]
	await _take(FIGHT_SECS, "%s_fight_%s.png" % [hero, style], func(t: float): _assist(t, mine, [foe]))

func _squads_shot(style: String) -> void:
	var base := home
	_clear(base)
	var mine: Array = [m.player, _rival(0, base + Vector3(-1.4, 0, 1.6)), _rival(0, base + Vector3(-1.4, 0, -1.6))]
	var squads: Array = [mine]
	for k in 2:
		var c := base + Vector3(SQUAD_GAP, 0, 0).rotated(Vector3.UP, TAU * (k + 1) / 3.0)
		squads.append([_rival(k + 1, c), _rival(k + 1, c + Vector3(1.4, 0, 1.6)),
				_rival(k + 1, c + Vector3(1.4, 0, -1.6))])
	await _take(SQUAD_SECS, "%s_squads_%s.png" % [hero, style], func(t: float):
		for s in squads.size():
			_assist(t, squads[s], squads[(s + 1) % squads.size()]))

## A ground tile with void next to it (and EDGE_RUN m of ground behind it): [the tile, the direction to the void].
func _edge() -> Array:
	var w := m.world
	for r in range(0, w.w / 2 - 3):
		for z in range(w.h / 2 - r, w.h / 2 + r + 1):
			for x in range(w.w / 2 - r, w.w / 2 + r + 1):
				if w.kind[w.idx(x, z)] != World.T_GROUND:
					continue
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if not w.inb(x + 2 * d.x, z + 2 * d.y) or w.kind[w.idx(x + d.x, z + d.y)] != World.T_VOID:
						continue
					var back: Vector2i = Vector2i(x, z) - d * int(EDGE_RUN)
					if w.inb(back.x, back.y) and w.kind[w.idx(back.x, back.y)] == World.T_GROUND:
						return [Vector2i(x, z), d]
	return [Vector2i(w.w / 2, w.h / 2), Vector2i(0, 1)]

func _glide_shot(style: String) -> void:
	var P := m.player
	var e := _edge()
	var d := Vector3(e[1].x, 0, e[1].y)
	var tile: Vector2i = e[0]
	var edge_at := Vector3(tile.x + 0.5, m.world.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5)
	_clear(edge_at - d * EDGE_RUN)
	var foe := _rival(1, edge_at - d * (EDGE_RUN + 3.0))
	foe.ctrl = "idle"
	P.ctrl = "idle"
	var left := [-1.0]      # the time the hero left the ground
	await _take(RUN_MAX, "%s_glide_%s.png" % [hero, style], func(t: float):
		if left[0] < 0.0 and not P.grounded:
			left[0] = t
		P.inp["move"] = Vector2(d.x, d.z)
		P.inp["glide_press_only"] = true
		P.inp["glide"] = left[0] >= 0.0
		P.inp["glide_btn"] = left[0] >= 0.0,
		func(t: float): return left[0] >= 0.0 and t - left[0] >= GLIDE_SECS)
	print("CAMERAAB glide %s: gliding=%s y=%.1f" % [style, str(P.gliding), P.pos.y])
	P.ctrl = "bot"
