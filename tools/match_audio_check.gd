extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## And the abyss (tools/gen_sfx_abyss.py, AbyssSfx): a scripted walk off a Hollow Crown rim plays the whoosh
## then, with the glider, the catch (and the strain loop while it is overheated), or, without it, the fall-out;
## yours is 2D (heard with the listener 80 m away), a teammate's is positional (the fall-out carries further).

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)
const WALK_S := 8.0            # s: the longest an abyss walk is run
const ABYSS_NAMES := ["abyss_whoosh", "abyss_catch", "abyss_fallout"]

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MATCHAUDIO %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	await _abyss()
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"demo_kin": "cindle"})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	var k: Kin = P.kin
	ok(k != null, "setup: the player has a Boki")
	if k == null:
		main.get_tree().quit(1)
		return
	var key := "rescue%d" % k.get_instance_id()
	# the Boki goes down beside you and you run into it: the rescue's hum starts and follows the carry
	k.pos = P.pos + Vector3(0.6, 0, 0)
	k.state = "active"
	k.fly = {}
	k.go_down()
	_step(m, 0.4)
	ok(k.rescue_on and Sfx.loop_on(key), "a rescue under way has its hum (rescue_on %s)" % k.rescue_on)
	# the owner stops ticking mid-channel (frozen, or its node gone): the held loop stops by itself
	await main.get_tree().create_timer(0.5).timeout
	ok(not Sfx.loop_on(key), "a held loop nobody asks for any more stops within %d ms" % Sfx.HOLD_MS)
	_step(m, 0.2)
	ok(k.rescue_on and Sfx.loop_on(key), "...and comes back while the rescue goes on")
	# the old leak: a looping file through the one-shot pool plays once now
	Sfx.play("revive_hum", P.pos)
	var once := Sfx.players.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	# extract mid-channel and go home
	m.result = {"extracted": true, "why": "extract"}
	m._finish()
	for i in 6:
		await main.get_tree().process_frame
	if not _on_farm():
		Game.goto("home")
		for i in 6:
			await main.get_tree().process_frame
	ok(_on_farm(), "back on the farm (%s)" % main.current)
	ok(not Sfx.loop_on(key) and not Sfx.loop_on("boxhum_check"), "no keyed match loop is left")
	await main.get_tree().create_timer(SETTLE).timeout
	ok(Sfx.match_voices() == 0, "after the fades nothing the match started is playing (%d)" % Sfx.match_voices())
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")

# ---------------------------------------------------------------- the abyss
func _abyss() -> void:
	var am := Match.new()
	main.add_child(am)
	await am.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	am.set_process(false)
	for i in 30:
		am.step(Match.DT)
	var P: Hunter = am.player
	var other: Hunter = null
	for o in am.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(Vector3(-500, 50, -500))
			other = o
	for mb in am.mobs:
		mb.queue_free()
	am.mobs.clear()
	var rim := _rim(am.world)
	ok(am.map_name == "The Hollow Crown" and not rim.is_empty(), "abyss: a rim on %s" % am.map_name)
	if not rim.is_empty():
		var jump := _walk(am, P, rim, false, false)
		ok(jump.find("abyss_whoosh") == 0 and jump.has("abyss_fallout") and not jump.has("abyss_catch"),
			"a walk off the rim: whoosh, then the fall-out %s" % [jump])
		var glide := _walk(am, P, rim, true, false)
		ok(glide.find("abyss_whoosh") == 0 and glide.find("abyss_catch") == 1 and not glide.has("abyss_fallout"),
			"...gliding: whoosh, then the catch %s" % [glide])
		var hot := _walk(am, P, rim, true, true)
		ok(hot.find("abyss_catch") == 1 and hot.has("strain"),
			"...an overheated glider lifting: the catch and the strain loop %s" % [hot])
		_teammate(am, other, rim)
	am.queue_free()
	for i in 3:
		await main.get_tree().process_frame

## The player on the island 2 m in from the lip, walking out and falling; scripts the glider when asked
## (cold: overheated). Returns the abyss sounds in the order first heard ("strain" if its loop ran).
## The listener is 80 m away, so only a 2D sound is heard.
func _walk(am: Match, P: Hunter, rim: Dictionary, glide: bool, cold: bool) -> Array:
	var dv: Vector2 = rim["dir"]
	var start: Vector2 = rim["lip"] - dv * 2.0
	P.out = false
	P.teleport(Vector3(start.x, rim["y"], start.y))
	P.grounded = true
	P.vel = Vector3.ZERO
	P.gliding = false
	P.glide_fuel = 1.0
	P.hp = P.max_hp
	Sfx.listener = P.pos + Vector3(80, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	am.opts["god"] = true          # a fall-out puts you back instead of ending the run
	var heard := []
	var key := "abyss_strain%d" % P.get_instance_id()
	var t := 0.0
	var done := func() -> bool:
		return heard.has("abyss_fallout") or (heard.has("abyss_catch") and (not cold or heard.has("strain")))
	while t < WALK_S and not done.call():
		P.inp["move"] = dv
		if glide and heard.has("abyss_whoosh"):
			P.inp["glide"] = true
			P.inp["glide_btn"] = true
			if cold:
				P.glide_fuel = 0.0
		am.step(Match.DT)
		t += Match.DT
		for n in ABYSS_NAMES:
			if Sfx.last_played.has(n) and not heard.has(n):
				heard.append(n)
		if Sfx.loop_on(key) and not heard.has("strain"):
			heard.append("strain")
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	P.inp["move"] = Vector2.ZERO
	Sfx.loop_stop(key)
	return heard

## A teammate (a remote hunter, its fall in the snapshots) falling past the lip: positional,
## and the fall-out carries further.
func _teammate(am: Match, o: Hunter, rim: Dictionary) -> void:
	var out_at: Vector2 = rim["lip"] + Vector2(rim["dir"]) * 3.0
	var heard := {}
	for case in [["whoosh", 5.0], ["whoosh", 30.0], ["fallout", 30.0], ["fallout", 60.0]]:
		o.remote = true
		o.out = false
		o.net_t = -1.0
		o.pos = Vector3(out_at.x, rim["y"] - 3.0, out_at.y)
		o.vel = Vector3(0, -8, 0)
		o.grounded = false
		o.update_lip()
		o.abyss_sfx = AbyssSfx.new()
		Sfx.listener = o.pos + Vector3(case[1], 0, 0)
		Sfx.last_played.clear()
		Sfx.recent.clear()
		o.abyss_sfx.tick(o, Match.DT)
		if case[0] == "fallout":
			o.out = true
			o.below_lip = false
			o.abyss_sfx.tick(o, Match.DT)
		heard["%s %d" % case] = Sfx.last_played.has("abyss_" + String(case[0]))
	o.remote = false
	ok(heard["whoosh 5"] and not heard["whoosh 30"],
		"a teammate's whoosh is positional: heard at 5 m, not at 30 m %s" % [heard])
	ok(heard["fallout 30"] and not heard["fallout 60"],
		"...their fall-out carries further: heard at 30 m, not at 60 m")

## A lipped rim: {lip: the lip's edge (x, z), dir: out over the void, y: the island's height there};
## a tile with void for two tiles beyond it and three tiles of flat ground behind it.
func _rim(w: World) -> Dictionary:
	for z in range(4, w.h - 4):
		for x in range(4, w.w - 4):
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _flat(w, x, z, d, -3, 0) and _void(w, x, z, d, 1, 2):
					var lip := Vector2(x + 0.5 + 0.5 * d.x, z + 0.5 + 0.5 * d.y)
					return {"lip": lip, "dir": Vector2(d), "y": w.ground_at(x + 0.5, z + 0.5)}
	return {}

func _flat(w: World, x: int, z: int, d: Vector2i, from: int, to: int) -> bool:
	var y := w.ground_at(x + 0.5, z + 0.5)
	for k in range(from, to + 1):
		var i := w.idx(x + d.x * k, z + d.y * k)
		var gy := w.ground_at(x + 0.5 + d.x * k, z + 0.5 + d.y * k)
		if w.kind[i] != World.T_GROUND or w.sheer.has(i) or w.stairs.has(i) or absf(gy - y) > 0.01:
			return false
	return true

func _void(w: World, x: int, z: int, d: Vector2i, from: int, to: int) -> bool:
	for k in range(from, to + 1):
		if w.kind[w.idx(x + d.x * k, z + d.y * k)] != World.T_VOID:
			return false
	return true
