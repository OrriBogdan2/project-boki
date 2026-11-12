extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel),
## and movement sounds (MoveSfx): a remote Hunter's footstep plays placed at it (panned), an enemy's louder than yours,
## quieter in a fight, out to the step reach and silent past it or while crouched; landings are placed.
## Water (WaterSfx): a Hunter's and a Boki's landing splash, dash spray and wading loop (louder and higher
## the faster) play on the map's water and none of them on dry ground; back on the farm, a swim stroke
## plays in a pond's deep water and not on land.
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MATCHAUDIO %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
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
	_footsteps(m, P)
	_water(m, P, k)
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
	var once := Sfx.voices().filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	_ult_cues(m, P)
	await _glider(P, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	other.remote = true
	other.pos = P.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	other.remote = false
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
	_strokes(main.current)
	ok(not Sfx.loop_on(key) and not Sfx.loop_on("boxhum_check"), "no keyed match loop is left")
	await main.get_tree().create_timer(SETTLE).timeout
	var farm_beds := 0      # HomeAmbience's own beds, still up on the farm
	for n in Sfx.amb_layers:
		if not n in ["abyss", "ruins"] and (Sfx.amb_layers[n]["p"] as AudioStreamPlayer).playing:
			farm_beds += 1
	var left := Sfx.match_voices() - farm_beds
	ok(left == 0, "after the fades nothing the match started is playing (%d, %d farm beds)" % [left, farm_beds])
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _footsteps(m: Match, P: Hunter) -> void:
	var e: Hunter = null
	for h in m.hunters:
		if h.team != P.team and e == null: e = h
	ok(e != null and _cam(m) != null, "setup: an enemy Hunter and a camera to hear from")
	if e == null:
		return
	var reach := float(MoveSfx.rules()["step_reach_m"])
	e.unseen = false
	e.crouch = false
	var mine = _probe(P, P.pos, func(): MoveSfx.footstep(P))
	var theirs = _step_of(P, e, Vector3(6.0, 0, 0))
	ok(theirs is AudioStreamPlayer3D, "an enemy's footstep 6 m away plays placed at it, so it pans (%s)" % theirs)
	if theirs is AudioStreamPlayer3D and mine != null:
		var want := MoveSfx.pitch(e.arch)
		var off := absf(theirs.pitch_scale / want - 1.0)
		ok(off < 0.09, "...at its height's pitch (%.2f vs %.2f)" % [theirs.pitch_scale, want])
	var base := float(MoveSfx.rules()["step_db"])
	var calm_e := MoveSfx.level(e, base)
	var own := MoveSfx.level(P, base)
	ok(calm_e > own, "an enemy's step is set louder than yours so you hear it coming (%.1f vs %.1f dB)" % [calm_e, own])
	e.hurt_at = m.time
	ok(MoveSfx.level(e, base) < calm_e, "...and drops while it fights (%.1f dB)" % MoveSfx.level(e, base))
	e.hurt_at = -9.0
	ok(_step_of(P, e, Vector3(0, 0, reach - 1.0)) != null, "...heard just inside the step reach (%.0f m)" % reach)
	ok(_step_of(P, e, Vector3(0, 0, reach + 1.0)) == null, "...silent past it")
	e.crouch = true
	ok(_step_of(P, e, Vector3(3.0, 0, 0)) == null, "...and silent while it sneaks (crouched)")
	e.crouch = false
	var landed = _probe(P, P.pos + Vector3(-8.0, 0, 0), func(): MoveSfx.land(e, -12.0), e)
	ok(landed is AudioStreamPlayer3D, "an enemy's landing plays placed at it")
	var kael := MoveSfx.pitch("juggernaut")
	var neve := MoveSfx.pitch("rimewright")
	ok(kael < neve, "height: Kael (2.05 m) sounds lower than Neve (1.56 m): %.2f vs %.2f" % [kael, neve])

func _water(m: Match, P: Hunter, k: Kin) -> void:
	var wet := _water_spot(m)
	var dry := P.pos
	ok(wet != Vector3.INF and WaterSfx.wet(m, wet), "setup: the map has water to wade in (%s)" % wet)
	ok(not WaterSfx.wet(m, dry), "setup: the Hunter's spawn is dry ground")
	if wet == Vector3.INF:
		return
	var splash := "water_land_" + StepSurface.weight_of(P)
	var boki_splash := "water_land_" + WaterSfx.kin_weight(k)
	P.grounded = true
	P.unseen = false
	P.crouch = false
	k.state = "active"
	k.fly = {}
	k.grounded = true
	for spot: Vector3 in [wet, dry]:
		var on := "on water" if spot == wet else "on dry ground"
		var want := spot == wet
		var got := _water_heard(P, spot, func(): MoveSfx.land(P, -8.0))
		ok((got == [splash]) == want, "a Hunter landing %s: %s" % [on, got])
		got = _water_heard(P, spot, func(): P.dash_with({"speed": 0.01, "time": 0.01}))
		ok((got == ["water_dash"]) == want, "a Hunter dashing %s: %s" % [on, got])
		got = _water_heard(k, spot, func(): _leap(m, k, spot))
		ok((got == [boki_splash]) == want, "a Boki landing from a leap %s: %s" % [on, got])
		got = _water_heard(k, spot, func(): k.start_rush(Vector2(1, 0), {"distance": 0.5}, {}))
		ok((got == ["water_dash"]) == want, "a Boki charging %s: %s" % [on, got])
		k.fly = {}
		k.state = "active"
		var loop := "holds its loop" if want else "has no loop"
		var hunter_wades := _wade_vol(P, P, spot, 1.0, func(): WaterSfx.wade(P)) != -INF
		ok(hunter_wades == want, "a Hunter wading %s %s" % [on, loop])
		var boki_wades := _wade_vol(P, k, spot, 1.0, func(): WaterSfx.kin_wade(k)) != -INF
		ok(boki_wades == want, "a Boki wading %s %s" % [on, loop])
	P.roll_t = 0.0
	var run := _wade_vol(P, P, wet, 1.0, func(): WaterSfx.wade(P))
	var run_pitch: float = Sfx.loops[WaterSfx.wade_key(P.get_instance_id())]["p"].pitch_scale
	var walk := _wade_vol(P, P, wet, 0.4, func(): WaterSfx.wade(P))
	var walk_pitch: float = Sfx.loops[WaterSfx.wade_key(P.get_instance_id())]["p"].pitch_scale
	ok(run > walk and run_pitch > walk_pitch, "the wading loop follows speed: run %.1f dB x%.2f, walk %.1f dB x%.2f"
			% [run, run_pitch, walk, walk_pitch])
	ok(_wade_vol(P, P, wet, 0.0, func(): WaterSfx.wade(P)) == -INF, "...and is silent standing still in water")
	Sfx.loop_stop(WaterSfx.wade_key(P.get_instance_id()))

## The first tile of the map's first "water" surface, or INF if it has none.
func _water_spot(m: Match) -> Vector3:
	for tag: Dictionary in World.load_layout(m.world.layout_id).get("surfaces", []):
		if tag["kind"] == "water":
			var b: Array = tag["rect"]
			var x := floorf((float(b[0]) + float(b[2])) * 0.5) + 0.5
			var z := floorf((float(b[1]) + float(b[3])) * 0.5) + 0.5
			return Vector3(x, m.world.ground_at(x, z), z)
	return Vector3.INF

## The water sounds `make` plays with `who` (a Hunter or a Boki) at `at` and the listener there.
func _water_heard(who: Ent, at: Vector3, make: Callable) -> Array:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	Sfx.listener = at
	var home := who.pos
	who.pos = at
	make.call()
	who.pos = home
	return Sfx.last_played.keys().filter(func(n: String): return n.begins_with("water_"))

## A Boki's short leap from beside `at` onto it, stepped until it lands.
func _leap(m: Match, k: Kin, at: Vector3) -> void:
	k.pos = at + Vector3(0.8, 0, 0)
	k.start_leap(at, {"time": 0.05, "height": 0.2}, {})
	_step(m, 0.1)

## The level of `who`'s wading loop after `make` with it at `at` moving at `k` of its run speed (-INF: none).
func _wade_vol(P: Hunter, who: Ent, at: Vector3, k: float, make: Callable) -> float:
	var key := WaterSfx.wade_key(who.get_instance_id())
	Sfx.loop_stop(key)
	var run := P.base_speed if who == P else (who as Kin).speed
	who.vel = Vector3(run * k, 0, 0)
	_water_heard(who, at, make)
	who.vel = Vector3.ZERO
	return float(Sfx.loops[key]["vol"]) if Sfx.loop_on(key) else -INF

## The farm's pond: a swim stroke in deep water, none on land.
func _strokes(home: Node) -> void:
	var w: HomeWater = home.water
	for deep in [true, false]:
		Sfx.last_played.clear()
		w.stroke_t = 0.0
		w.step(2 if deep else 0, 0.016, Vector2(1, 0), false)
		var where := "in deep water" if deep else "on land"
		var heard: Array = Sfx.last_played.keys()
		ok(heard.has("water_stroke") == deep, "a swim stroke on the farm %s (%s)" % [where, heard])

## The voice e's footstep starts with e standing `off` from P (null if none).
func _step_of(P: Hunter, e: Hunter, off: Vector3):
	return _probe(P, P.pos + off, func(): MoveSfx.footstep(e), e)

func _cam(m: Match) -> Camera3D:
	return m.get_viewport().get_camera_3d()

## Runs `make` with `who` standing at `at` (the listener on P) and returns the one-shot voice it started
## at that spot, or null if nothing played there. (A voice reads as playing only once the audio server has
## mixed it, a frame later, so the probe clears every voice's stream and looks for the one given a sound.)
func _probe(P: Hunter, at: Vector3, make: Callable, who: Hunter = P):
	for p in Sfx.voices():
		p.stop()
		p.stream = null
	Sfx.last_played.clear()
	Sfx.recent.clear()
	Sfx.listener = P.pos
	var home := who.pos
	who.pos = at
	make.call()
	who.pos = home
	for p in Sfx.voices():
		if p.stream != null and (p is AudioStreamPlayer or (p as AudioStreamPlayer3D).position.is_equal_approx(at)):
			return p
	return null

## An ultimate is heard before it is seen: a rival's cue carries 40 m (not 70) with the rival tag, yours has the
## ally tag, all through the match's own pool voices (so the match leaving tears them down with the rest).
func _ult_cues(m: Match, P: Hunter) -> void:
	var rivals := m.hunters.filter(func(x): return x != P and x.team != P.team and x.ak != null)
	ok(not rivals.is_empty(), "setup: a rival Hunter with a kit")
	if rivals.is_empty():
		return
	var R: Hunter = rivals[0]
	Sfx.listener = P.pos
	R.pos = P.pos + Vector3(40, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(R.ak)
	var heard := Sfx.last_played.has(R.arch + "_ult_cue") and Sfx.last_played.has("ult_tag_foe")
	ok(heard and not Sfx.last_played.has("ult_tag_ally"),
			"a rival's ultimate 40 m away is heard, with the rival tag (%s)" % [Sfx.last_played.keys()])
	R.pos = P.pos + Vector3(70, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(R.ak)
	ok(Sfx.last_played.is_empty(), "...and 70 m away it is out of earshot")
	Sfx.last_played.clear()
	UltCue.cast(P.ak)
	heard = Sfx.last_played.has("ult_tag_ally") and Sfx.last_played.has(P.arch + "_ult_cue")
	ok(heard, "your own team's cue has the ally tag")

## Walks one hunter's glider through open, fast glide, dive, overheat and fold, setting the state a
## step at a time and ticking its GliderSfx directly. A cue plays once: its last-played stamp is set on
## the change of state and stays clear while the state just goes on.
func _glider(h: Hunter, who: String) -> void:
	var g := h.glider_snd
	var wind := "glider_wind%d" % h.get_instance_id()
	var burn := "glider_burn%d" % h.get_instance_id()
	h.gliding = false
	h.dropping = false
	h.glide_fuel = 1.0
	_set_speed(h, 0.0, 0.0)
	g.tick(h)
	for cue in ["glider_snap", "glider_dive", "glider_crackle", "glider_fold", "glider_hiss"]:
		ok(Sfx.ensure(cue), "%s: %s is a sound on file" % [who, cue])
	h.gliding = true
	_once(g, h, "glider_snap", who + " glider: opening plays the snap once")
	ok(Sfx.loop_on(wind), "%s glider: the wind loop runs" % who)
	var slow_pitch := _pitch(wind)
	var slow_vol := float(Sfx.loops[wind]["vol"])
	_set_speed(h, 24.0, -5.0)
	g.tick(h)
	var swells := _pitch(wind) > slow_pitch and float(Sfx.loops[wind]["vol"]) > slow_vol
	ok(swells, "%s glider: the wind pitches and swells with speed" % who)
	if h.remote:
		ok(Sfx.loops[wind]["pos"] != null, "another player's glider: the wind is positional")
	_set_speed(h, 6.0, -HunterMove.dive_vy)
	h.glide_dive.on = true
	_once(g, h, "glider_dive", who + " glider: the dive plays its whoosh once")
	h.glide_dive.on = false
	_set_speed(h, 6.0, -5.0)
	g.tick(h)
	var hiss := "glider_hiss%d" % h.get_instance_id()
	h.glide_fuel = 0.3
	g.tick(h)
	var faint := float(Sfx.loops[hiss]["vol"]) if Sfx.loop_on(hiss) else 0.0
	h.glide_fuel = 0.05
	g.tick(h)
	var near := float(Sfx.loops[hiss]["vol"]) if Sfx.loop_on(hiss) else 0.0
	var swelled := faint != 0.0 and near > faint
	ok(h.remote or swelled, "%s glider: the heat hiss swells toward overheat (%.1f -> %.1f dB)" % [who, faint, near])
	ok(not h.remote or not Sfx.loop_on(hiss), "another player's glider: no heat hiss (the heat is not synced)")
	h.glide_fuel = 0.0
	g.net_hot = true
	_once(g, h, "glider_crackle", who + " glider: overheating plays the crackle once")
	ok(Sfx.loop_on(burn), "%s glider: the burn loop runs while overheated" % who)
	h.glide_fuel = 1.0
	g.net_hot = false
	g.tick(h)
	ok(not g.hot, "%s glider: cooled, no longer burning" % who)
	h.gliding = false
	_once(g, h, "glider_fold", who + " glider: folding plays the fold once")
	await main.get_tree().create_timer(0.5).timeout
	var running := Sfx.loop_on(wind) or Sfx.loop_on(burn) or Sfx.loop_on(hiss)
	ok(not running, "%s glider: all loops stop once the glider is folded" % who)

func _set_speed(h: Hunter, flat: float, vy: float) -> void:
	h.vel = Vector3(flat, vy, 0)
	h.net_vel = h.vel

func _pitch(key: String) -> float:
	return (Sfx.loops[key]["p"] as AudioStreamPlayer).pitch_scale

## The state just changed: one tick plays `cue`; a second tick in the same state does not play it again.
func _once(g: GliderSfx, h: Hunter, cue: String, what: String) -> void:
	Sfx.last_played.erase(cue)
	g.tick(h)
	var first := Sfx.last_played.has(cue)
	Sfx.last_played.erase(cue)
	g.tick(h)
	ok(first and not Sfx.last_played.has(cue), what)

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
