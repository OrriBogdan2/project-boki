extends RefCounted
## --sfx-voice-check: the voice limits in Sfx (content/rules/sfx_voices.json, docs/AUDIO.md).
##   1. a scripted 30-Hunter brawl (steps, hits, hurts, casts and ult cues every tick): the pool never goes
##      over POOL and no sound over its class cap, and not one ult cue is dropped
##   2. a full pool: an ult cue and your own hit still play (taking the oldest lower-priority voice),
##      and a footstep cannot take a voice from a higher priority
##   3. an enemy ult near you ducks the music and ambience about 4 dB, a far one or your own does not

var main: Node
var fails := 0
const TICKS := 240              # brawl length in frames
const CUES := ["ult", "warn", "pin_ult_cast"]
const ULT_EVERY := 10           # frames between ult cues; each plays one cue per Hunter within range of you
const ABILITIES := ["ab_blast", "ab_slam", "ab_throw", "ab_charge", "ab_blink", "ab_wall", "ab_leap", "ab_whirr",
	"ab_stun", "ab_plant", "ab_tether", "ab_slow", "ab_guard", "ab_parry", "ab_rail", "ab_ready"]
const HEARD_M := 12.0           # m: where the brawl's Hunters stand around the listener

func ok(cond: bool, what: String) -> void:
	print("SFXVOICE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", {"autoplay": true, "teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 77,
		"no_drop": true})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	ok(m.hunters.size() >= 30, "setup: a 30-Hunter match (%d)" % m.hunters.size())
	for c in CUES:
		Sfx.ensure(c)
	_clear()
	await _brawl(m)
	await _full_pool(m)
	await _duck(m)
	print("SFXVOICE DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _clear() -> void:
	for p in Sfx.players:
		p.stop()
	Sfx.last_played.clear()
	Sfx.recent.clear()

## Voices playing now, per sound.
func _active() -> Dictionary:
	var by := {}
	for i in Sfx.POOL:
		if Sfx.players[i].playing and Sfx._vname[i] != "":
			by[Sfx._vname[i]] = int(by.get(Sfx._vname[i], 0)) + 1
	return by

func _brawl(m: Match) -> void:
	Sfx.listener = m.player.pos
	var worst := 0
	var worst_over := 0
	var cues := 0
	var cues_played := 0
	var steps := 0
	var steps_played := 0
	for t in TICKS:
		for j in m.hunters.size():
			var h: Hunter = m.hunters[j]
			var at := Sfx.listener + Vector3(cos(j) * HEARD_M, 0.0, sin(j) * HEARD_M)
			steps += 1
			steps_played += int(Sfx.play(HeroSfx.of(h, "step_stone", "step_stone"), at, -16.0, 0.12))
			Sfx.play(HeroSfx.of(h, "hit", "hit"), at)
			if (t + j) % 6 == 0:
				Sfx.play(HeroSfx.of(h, "hurt", "hurt"), at)
				Sfx.play("ab_blast", at)
			if t % ULT_EVERY == 0:
				cues += 1
				cues_played += int(Sfx.play(CUES[j % CUES.size()], at))
		var by := _active()
		var total := 0
		for sname in by:
			total += by[sname]
			worst_over = maxi(worst_over, int(by[sname]) - int(Sfx.voice_class(sname)["cap"]))
		worst = maxi(worst, total)
		await main.get_tree().process_frame
	ok(worst <= Sfx.POOL, "brawl: at most %d voices at once (%d)" % [Sfx.POOL, worst])
	ok(worst_over <= 0, "brawl: no sound over its class cap (worst over by %d)" % worst_over)
	ok(cues > 0 and cues_played == cues, "brawl: no ult cue dropped (%d of %d played)" % [cues_played, cues])
	ok(steps_played < steps, "brawl: the footsteps were thinned (%d of %d played)" % [steps_played, steps])

func _pool_full() -> bool:
	return Sfx.players.all(func(p): return p.playing)

## Distinct sounds of one class, so no repeat gap or per-sound cap gets in the way.
func _fill(names: Array) -> int:
	var n := 0
	for s in names:
		n += int(Sfx.play(s, null, 0.0, 0.0))
	return n

## (no awaits in here: the voices must still be sounding when it asserts)
func _full_pool(m: Match) -> void:
	var steps: Array = []
	var hurts: Array = []
	for k in ["step_grass", "step_stone", "step_snow", "step_wood"]:
		steps.append(k)
	for h in m.hunters:
		for kind in ["step_stone", "step_grass", "step_snow", "step_wood"]:
			var s := HeroSfx.of(h, kind, "")
			if s != "" and not s in steps:
				steps.append(s)
		var hu := HeroSfx.of(h, "hurt", "")
		if hu != "" and not hu in hurts:
			hurts.append(hu)
	_clear()
	_fill(steps)
	_fill(steps)
	_fill(steps)
	ok(_pool_full(), "a pool full of footsteps (%d sounds)" % steps.size())
	ok(Sfx.play("ult"), "...an ult cue still plays, taking a footstep's voice")
	ok(Sfx.play("hit"), "...and so does your own hit")
	_clear()
	_fill(hurts)
	_fill(ABILITIES)
	ok(_pool_full(), "a pool full of hurt sounds and abilities (%d hurt sounds)" % hurts.size())
	ok(not Sfx.play("step_stone"), "...a footstep cannot take a voice from them")

func _duck(m: Match) -> void:
	var foe: Hunter = null
	for h in m.hunters:
		if h != m.player:
			foe = h
			break
	var home := foe.pos
	Sfx.listener = home + Vector3(float(Sfx.voice_rules["duck"]["range_m"]) + 20.0, 0.0, 0.0)
	CombatBus.ability_used.emit(foe, "x_r", "ult")
	await main.get_tree().create_timer(0.4).timeout
	ok(Sfx._duck_fx[0].volume_db > -0.1, "an enemy ult far away does not duck the music")
	Sfx.listener = home + Vector3(8.0, 0.0, 0.0)
	m.player.ctrl = "local"
	CombatBus.ability_used.emit(m.player, "x_r", "ult")
	await main.get_tree().create_timer(0.4).timeout
	ok(Sfx._duck_fx[0].volume_db > -0.1, "your own ult does not duck")
	CombatBus.ability_used.emit(foe, "x_r", "ult")
	await main.get_tree().create_timer(0.4).timeout
	var want := float(Sfx.voice_rules["duck"]["db"])
	ok(is_equal_approx(Sfx._duck_fx[0].volume_db, want) and is_equal_approx(Sfx._duck_fx[1].volume_db, want),
		"an enemy ult near you ducks music and ambience %.0f dB" % want)
	await main.get_tree().create_timer(float(Sfx.voice_rules["duck"]["seconds"]) + 1.2).timeout
	ok(Sfx._duck_fx[0].volume_db > -0.1, "...and it comes back within a second or two")
