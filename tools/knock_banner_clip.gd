extends RefCounted
## --knock-banner-clip --shots-dir=<dir> [--media-size=1920x1080]: the knock banners (KnockBanner) in a real
## squad fight, recorded by the movie writer at 30 fps: two rivals go down at once (KNOCK x2, early, before
## the bots knock anyone themselves), a rival knocks your teammate (ALLY KNOCKED, and their squad row's KNOCKED
## tag), then your squad knocks that rival (KNOCK).
## Writes <dir>/clip1.avi and a still while each banner holds (<dir>/knock.png, ally.png, knock_x2.png).
## Run it on a GPU worker (jobq --needs gpu); the match rig and the recording are tools/gameplay_media.gd's.
## Never writes the save.

const SECS := 7.0                # s of fight filmed
const STILL_AFTER := 0.3         # s after a knock its still is saved (the pop is over, the banner holds)
# [s into the fight, the squad that loses someone, the still's name]; the bots fight too, so each beat takes
# whoever is still up (never you: your own knock has no banner) and credits the other squad's first one up
const BEATS := [[1.5, "b", ""], [1.65, "b", "knock_x2"], [3.2, "a", "ally"], [5.0, "b", "knock"]]

var main: Node
var media: RefCounted            # tools/gameplay_media.gd
var _done := {}                  # beat index -> knocked; still name -> saved

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
	await _fight()
	print("MEDIA_DONE knock_banners frames=%d" % Engine.get_frames_drawn())
	main.get_tree().quit(0)

## gameplay_media's squad fight (clip 1) with the knocks on cue.
func _fight() -> void:
	await media._start("ashwick", "cindle")
	var m: Match = media.m
	var P := m.player
	P.ctrl = "bot"
	P.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	var base: Vector3 = media._ground(P.pos)
	var foe_at: Vector3 = media._ground(base + Vector3(media.FIGHT_GAP, 0, 0))
	media.squad_a = [P, media._hunter("a1", 0, "juggernaut", "pebbit", media._ground(base + Vector3(-1.4, 0, 1.6))),
			media._hunter("a2", 0, "gunslinger", "zapple", media._ground(base + Vector3(-1.4, 0, -1.6)))]
	media.squad_b = [media._hunter("b0", 1, "archer", "wisplet", foe_at),
			media._hunter("b1", 1, "bulwark", "burrlet", media._ground(foe_at + Vector3(1.4, 0, 1.6))),
			media._hunter("b2", 1, "mage", "puddlet", media._ground(foe_at + Vector3(1.4, 0, -1.6)))]
	for h in media.squad_a + media.squad_b:
		h.teleport(h.pos)
	media._zoom(0.55)
	media._mark("start")
	await media._go(SECS, _beat, func(_t: float): return media._centre(media.squad_a + media.squad_b))

## Knocks whoever is due at `t` and saves each banner's still once it holds.
func _beat(t: float) -> void:
	var m: Match = media.m
	for i in BEATS.size():
		var b: Array = BEATS[i]
		if not _done.has(i) and t >= float(b[0]):
			_done[i] = true
			var losers: Array = media.squad_a if b[1] == "a" else media.squad_b
			var winners: Array = media.squad_b if b[1] == "a" else media.squad_a
			var victim := _first_up(losers, m.player)
			var by := _first_up(winners, null)
			if victim != null:
				m.knock(victim, by if by != null else winners[0], {})
			media._mark("knock_%d %s x%d" % [i, m.hud.knocks.word(), m.hud.knocks.count])
		var still := String(b[2])
		if still != "" and not _done.has(still) and t >= float(b[0]) + STILL_AFTER:
			_done[still] = true
			main.get_viewport().get_texture().get_image().save_png(String(media.dir).path_join(still + ".png"))
			media._mark("still " + still)

## The first hunter of `squad` still up, other than `skip`.
func _first_up(squad: Array, skip: Hunter) -> Hunter:
	for h in squad:
		if h != skip and not (h as Hunter).downed and not (h as Hunter).out:
			return h
	return null
