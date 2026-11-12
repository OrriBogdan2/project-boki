extends RefCounted
## --revive-clip --shots-dir=<dir> [--media-size=1920x1080]: a knock and a revive from the game camera, recorded
## by the movie writer at 30 fps: a teammate goes down with no rival near, you walk into their ring and stand
## there until they are back up. Writes <dir>/clip1.avi and stills while they are down (down.png) and while
## you are reviving them (revive.png). Run it on a GPU worker (jobq --needs gpu); the match rig and the
## recording are tools/gameplay_media.gd's. Never writes the save.

const SECS := 9.0                # s filmed
const KNOCK_AT := 0.6            # s into the clip the teammate is knocked
const WALK_AT := 2.0             # s into the clip you start walking to them
const STAND_OFF := 0.6           # m from the wisp you stop walking at (inside the revive ring)
const STILL_DOWN := 1.9          # s: the still while they are down and you are away
const STILL_REVIVE := 4.5        # s: the still while you stand in the ring
const START_GAP := 9.0           # m between you and the teammate at the start

var main: Node
var media: RefCounted            # tools/gameplay_media.gd
var _knocked := false
var _stills := {}

func run(main_node: Node) -> void:
	main = main_node
	media = load("res://tools/gameplay_media.gd").new()
	media.main = main
	var res := "1920x1080"
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--media-size="):
			res = arg.substr(13)
		if arg.begins_with("--shots-dir="):
			media.dir = arg.substr(12)
	if String(media.dir).is_relative_path():
		media.dir = ProjectSettings.globalize_path("res://").path_join(media.dir)
	DirAccess.make_dir_recursive_absolute(media.dir)
	if not child:
		media._record(res)
		return
	Save.no_write = true
	Record.set_level(1)
	Settings.v["tips"] = false
	await _scene()
	print("MEDIA_DONE revive_clip frames=%d" % Engine.get_frames_drawn())
	main.get_tree().quit(0)

func _scene() -> void:
	await media._start("ashwick", "cindle")
	var m: Match = media.m
	var P := m.player
	var base: Vector3 = media._ground(P.pos)
	var mate: Hunter = media._hunter("a1", 0, "juggernaut", "pebbit", media._ground(base + Vector3(START_GAP, 0, 2.0)))
	var foe: Hunter = media._hunter("b0", 1, "archer", "wisplet", media._ground(base + Vector3(-90, 0, 0)))
	media.squad_a = [P, mate]
	media.squad_b = [foe]
	for h in media.squad_a + media.squad_b:
		h.teleport(h.pos)
	media._zoom(0.55)
	media._mark("start")
	await media._go(SECS, func(t: float): _beat(t, P, mate, foe), func(_t: float): return media._centre([P, mate]))

## Knocks the teammate, walks you into their ring, and saves the stills.
func _beat(t: float, P: Hunter, mate: Hunter, foe: Hunter) -> void:
	var m: Match = media.m
	foe.teleport(P.pos + Vector3(-90, 0, 0))          # the rival stays out of it
	if not _knocked and t >= KNOCK_AT:
		_knocked = true
		m.knock(mate, foe, {})
		media._mark("knock")
	var walk := Vector2.ZERO
	var to := Vector2(mate.pos.x - P.pos.x, mate.pos.z - P.pos.z)
	if t >= WALK_AT and to.length() > STAND_OFF:
		walk = to.normalized()
	P.inp["move"] = walk
	for still: Array in [["down", STILL_DOWN], ["revive", STILL_REVIVE]]:
		if not _stills.has(still[0]) and t >= float(still[1]):
			_stills[still[0]] = true
			main.get_viewport().get_texture().get_image().save_png(String(media.dir).path_join(String(still[0]) + ".png"))
			media._mark("still " + String(still[0]))
