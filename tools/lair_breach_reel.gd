extends RefCounted
## --lair-breach-reel: the owner's video of a lair's gate being broken down, at the match camera. You
## stand at the Sunken Forge's Gate Seal firing into it (scripted, so the camera keeps the gate in view)
## while your two squadmates (the bot brain: what bots really do) batter it with you and fight the
## guards each crack calls; when it breaks you walk in, the boss wakes and the gate slams behind you.
## Run it under the movie writer:
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
	# ("tut_test": the match reads no keys for you; this drives you, as the tutorial test does)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "blight": false,
		"tut_test": true})
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
			h.inp["move"] = Vector2.ZERO      # (an idle hunter keeps its last input: walking off the edge)
			h.hp = h.max_hp
		m.step(Match.DT)
	m.set_process(true)
	for i in crew.size():
		var h: Hunter = crew[i]
		h.teleport(Vector3(spots[i].x, m.world.ground_at(spots[i].x, spots[i].z), spots[i].z))
		if h == P:
			continue
		h.ctrl = "bot"
		h.lvl = maxi(h.lvl, 8)
		h.ai["boss_hunt"] = true
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
		_drive(P, L)
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

## You, scripted: at the seal firing into it while the gate is shut, then in through it.
func _drive(P: Hunter, L: Dictionary) -> void:
	var seal: Mob = P.m.lairs.breach.seal_of(L)
	var goal: Vector3 = LairBreach.stand(L) if seal else L["c"]
	var to := Vector2(goal.x - P.pos.x, goal.z - P.pos.z)
	P.inp["move"] = to.normalized() if to.length() > 0.8 else Vector2.ZERO
	P.inp["fire"] = seal != null
	P.inp["aim"] = seal.pos + Vector3(0, 1.2, 0) if seal else goal
	P.inp["aim_y"] = P.pos.y
