extends RefCounted
## --xp-armour-cues-reel: a 20 s film with sound of the three progress cues, one after another at the match
## camera: monster kills (xp_tick), hits on a rival Hunter until its armour tier goes up (armor_up_own), then a
## level-up (level_up). A caption names each moment. Run it under the movie writer (the audio is in the file):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 60 \
##       --write-movie <dir>/cues.avi -- --xp-armour-cues-reel
## Never writes the save.

const FILM_S := 20.0            # s of film
const KILL_AT := [1.5, 3.0, 4.5]      # s: a monster dies under your gun
const ARMOUR_AT := [7.0, 11.0]        # s: hits on a rival until its tier rises
const LEVEL_AT := 15.5                # s: enough XP for the next level
const HIT := 35.0                     # hit damage on the rival, armour XP per hit
const CAPTION_S := 2.5                # s a caption stays up

var _caption: Label
var _hide_at := 0.0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "blight": false,
		"tut_test": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
	m.set_process(true)
	rival.teleport(P.pos + Vector3(5, 0, 3))
	m.cam.snap(P.pos)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 44)
	_caption.position = Vector2(40, 380)
	main.add_child(_caption)
	var frame := 0
	var kills := KILL_AT.duplicate()
	var armours := ARMOUR_AT.duplicate()
	var level_done := false
	while frame < int(FILM_S * 60.0):
		var t := frame / 60.0
		P.hp = P.max_hp
		rival.hp = rival.max_hp
		if not kills.is_empty() and t >= float(kills[0]):
			kills.pop_front()
			_kill(m, P)
		if not armours.is_empty() and t >= float(armours[0]):
			armours.pop_front()
			_armour_hits(m, P, rival)
		if not level_done and t >= LEVEL_AT:
			level_done = true
			_say("LEVEL UP  (level_up)")
			P.gain_xp(float(Hunter.XP_TO[P.lvl]) - P.xp)
		_caption.visible = t < _hide_at
		frame += 1
		await main.get_tree().process_frame
	print("XP_ARMOUR_REEL done, %d frames, level %d, armour tier %d" % [frame, P.lvl, P.armor_tier])
	main.get_tree().quit(0)

func _say(text: String) -> void:
	_caption.text = text
	_hide_at = _now() + CAPTION_S

func _now() -> float:
	return float(Engine.get_process_frames()) / 60.0

## A monster dies to your last hit: kill XP lands (xp_tick).
func _kill(m: Match, P: Hunter) -> void:
	_say("KILL XP  (xp_tick)")
	var mob := m.spawn_mob("skitter", P.pos + Vector3(4, 0, 0))
	mob.max_hp = 30.0
	mob.hp = 30.0
	mob.hurt(30.0, P, {})

## Hits on a Hunter only build armour: nothing plays until its tier rises (armor_up_own).
func _armour_hits(m: Match, P: Hunter, rival: Hunter) -> void:
	_say("ARMOUR TIER  (armor_up_own)")
	var tier := P.armor_tier
	for i in 80:
		if P.armor_tier > tier:
			break
		m.on_damage(rival, P, HIT, {})
