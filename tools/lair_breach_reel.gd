extends RefCounted
## --lair-breach-reel: the owner's video of a lair's gate being broken down, at the match camera. You and
## your two squadmates (all three played by the bot brain, so it's what bots really do) come up to the
## Sunken Forge, batter its Gate Seal crack by crack while the guards each crack calls come at you, and
## walk in when it breaks: the boss wakes and the gate slams behind you. Run it under the movie writer:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 60 \
##       --write-movie <dir>/breach.avi -- --lair-breach-reel
## Prints LAIR_BREACH_REEL lines with the movie frame filming starts on, then (counted from there) the
## frame of each crack, the break and the boss waking. Never writes the save.

const AFTER_S := 7.0            # s of film after the boss wakes
const LIMIT_S := 90.0           # s: give up if the gate hasn't broken by then

func run(main: Node) -> void:
	main.set_meta("lair_breach_reel", self)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "blight": false})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var L: Dictionary = m.lairs.list.filter(func(x): return x["boss"] == "colossus")[0]
	m.lairs.activate(L)
	var out := Vector3(L["out"].x, 0, L["out"].y)
	var side := Vector3(-out.z, 0, out.x)
	var crew: Array = m.hunters.filter(func(x): return x.team == P.team)
	var spots: Array = []
	for i in crew.size():
		spots.append(LairBreach.stand(L) + out * 6.0 + side * (i - 1) * 1.6)
	for mb in m.mobs:
		if not mb.dead and mb.mkind != "gate" and not (mb is Boss) and mb.flat_dist(L["seal_at"]) < 25.0:
			mb.dead = true
			mb.visible = false
	# bots plan no lairs in a match's first 25 s: play those off camera, everyone standing still and whole
	m.set_process(false)
	while m.time < 26.0:
		for h in m.hunters:
			h.ctrl = "idle"
			h.hp = h.max_hp
		m.step(Match.DT)
	m.set_process(true)
	for i in crew.size():
		var h: Hunter = crew[i]
		if h.ai.is_empty(): h.ai = m.bot_brain.new_mind(m.rng, 0.8)
		h.ctrl = "bot"
		h.lvl = maxi(h.lvl, 8)
		h.ai["boss_hunt"] = true
		h.teleport(Vector3(spots[i].x, m.world.ground_at(spots[i].x, spots[i].z), spots[i].z))
	for h in m.hunters:
		if h.team != P.team:
			h.teleport(m.world.spawns[-1])
	m.cam.snap(P.pos)
	print("LAIR_BREACH_REEL filming from movie frame %d" % Engine.get_process_frames())
	var frame := 0
	var stage := 0
	var woke := -1
	while frame < int((LIMIT_S + AFTER_S) * 60.0):
		for h in crew:
			h.hp = maxf(h.hp, h.max_hp * 0.5)      # (a film of the breach, not of a wipe)
		if frame == 0:
			print("LAIR_BREACH_REEL crew %s" % str(crew.map(func(h): return "%s out %s" % [h.pname, h.out])))
		var now := int(L.get("seal_stage", 0))
		if now > stage:
			stage = now
			var what := "broken" if now >= LairBreach.STAGES else "crack %d" % now
			print("LAIR_BREACH_REEL %s at frame %d (t %.1f)" % [what, frame, frame / 60.0])
		if woke < 0 and L["state"] == "awake":
			woke = frame
			print("LAIR_BREACH_REEL boss awake at frame %d (t %.1f)" % [frame, frame / 60.0])
		if woke >= 0 and frame - woke > int(AFTER_S * 60.0):
			break
		if woke < 0 and frame > int(LIMIT_S * 60.0):
			print("LAIR_BREACH_REEL gave up: the gate is %s" % L["state"])
			break
		frame += 1
		await main.get_tree().process_frame
	print("LAIR_BREACH_REEL done, %d frames" % frame)
	main.get_tree().quit(0)
