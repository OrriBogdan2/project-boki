extends RefCounted
## Claire's (rimewright) animation timing, measured in game against the source footage
## (briefs/hero-ref/tamsin.md, one frame 0.2 s; the ult strip 0.1 s) and docs/heroes/rimewright.md "Animation timing":
## when the kit's hit or release happens after a move starts, and whether the hand-keyed clip (claire.json, "lead")
## shows its hit pose on that same frame. Runs on tools/support_check.gd's setup (--rimewright-combo-check).

const DT := 1.0 / 60.0
const TOL := 0.03          # s: two frames at 60 fps
const SOURCE_FRAME := 0.2  # s: the footage's resolution (tamsin.md)
## The clip's hit pose (s into the clip; tools/art1/claire_clips.py): the flick, the sling, the thrust, the palms
## fully out, the shove, the stamp, the clench.
const HIT_KEY := {
	"tm_dart_r": 0.07, "tm_dart_l": 0.07, "tm_dart_heavy": 0.08, "tm_beam": 0.08, "tm_spear": 0.1,
	"tm_wall": 0.27, "tm_freeze": 0.13, "tm_clench": 0.1}

var sc        # the SupportCheck running us

func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)

func step(m: Match, secs: float) -> void:
	sc.step(m, secs)

## Seconds the move `id` has run, or -1 when `K` is not playing it.
func _into(m: Match, K: RimewrightKit, id: String) -> float:
	return m.time - K.anim_at if K.anim_id == id else -1.0

## Steps until `done` is true (at most `cap` s); returns how far into `id` the kit was at that step.
func _event(m: Match, K: RimewrightKit, id: String, done: Callable, cap := 2.0) -> float:
	var t := 0.0
	while not done.call() and t < cap:
		step(m, DT)
		t += DT
	return _into(m, K, id) if done.call() else 99.0

## The pose lag (s) of `id`'s hit pose behind the kit's hit at `event` s into the move, with the clip's "lead".
func _lag(id: String, event: float) -> float:
	var lead := float(WardenClips.data("claire")["kmoves"][id].get("lead", 0.0))
	return float(HIT_KEY[id]) - lead - event

func _line(id: String, event: float, what: String) -> void:
	var lag := _lag(id, event)
	var what_s := "anim %s: %s at %.2f s, the clip's hit pose lands with it" % [id, what, event]
	ok(what_s, absf(lag) <= TOL, "lag %.2f s" % lag)

func rimewright() -> void:
	_stream()
	_spear()
	_wall()
	_skate()
	await _rime()

func _stream() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	sc.aim_at(P, r[3].pos)
	P.inp["fire"] = true
	var spawn := _event(m, K, "tm_dart_r", func(): return K.stats["darts"] >= 1)
	var spawn_l := _into(m, K, "tm_dart_l")
	_line("tm_dart_r" if spawn >= 0.0 else "tm_dart_l", maxf(spawn, spawn_l), "the first dart leaves")
	_event(m, K, "tm_dart_heavy", func(): return K.stats["heavies"] >= 1)
	_line("tm_dart_heavy", _into(m, K, "tm_dart_heavy"), "a large dart leaves")
	var n0: int = K.stats["darts"]
	step(m, 3.0)
	var gap := 3.0 / float(K.stats["darts"] - n0)
	ok("anim darts: a dart every 0.15-0.2 s (footage 0005-0090)", gap >= 0.15 and gap <= 0.2, "%.3f s" % gap)
	P.inp["fire"] = false

func _spear() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	sc.aim_at(P, P.pos + Vector3(6.0, 0, 0))
	step(m, 0.05)
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	_line("tm_spear", _event(m, K, "tm_spear", func(): return K.stats["spears"] >= 1), "the spear leaves her palms")
	var t := 0.0
	while K.zones.is_empty() and t < 2.0:
		step(m, DT)
		t += DT
	var landed := m.time
	var boom := _event(m, K, "tm_clench", func(): return K.stats["detonations"] >= 1, 3.0)
	var delay := m.time - landed
	ok("anim spear: it detonates 1.8-2.0 s after landing (footage 0098 -> 0107, 0130 -> 0140)",
		delay >= 1.78 and delay <= 2.02, "%.2f s" % delay)
	_line("tm_clench", boom, "the burst")

func _wall() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	sc.aim_at(P, P.pos + Vector3(7.0, 0, 0))
	step(m, 0.05)
	P.inp["sig"] = true
	step(m, DT)
	P.inp["sig"] = false
	var erupt := _event(m, K, "tm_wall", func(): return not K.wall.is_empty())
	ok("anim wall: the tell is the footage's 0.2 s sparkle (0300 -> 0301)",
		absf(erupt - SOURCE_FRAME) <= 0.04, "%.2f s" % erupt)
	_line("tm_wall", erupt, "the ice erupts")
	step(m, 0.3)
	P.inp["sig"] = true
	step(m, DT)
	P.inp["sig"] = false
	_line("tm_freeze", _into(m, K, "tm_freeze"), "the freeze lands")

func _skate() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var dd: Dictionary = K.dash_def()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	P.inp["fire"] = true
	sc.aim_at(P, r[3].pos)
	step(m, DT)
	P.inp["dash"] = false
	var t := 0.0
	var full := float(dd["speed"]) * 0.99
	while P.roll_speed < full and t < 1.0:
		step(m, DT)
		t += DT
	ok("anim skate: full speed within 0.2 s of the push-off (footage: 124 -> 479 px/s in one 0.2 s step)",
		t <= SOURCE_FRAME + TOL, "%.2f s" % t)
	var beams: int = K.stats["beams"]
	_event(m, K, "tm_beam", func(): return K.stats["beams"] > beams)
	_line("tm_beam", _into(m, K, "tm_beam"), "a skating beam leaves")
	P.inp["fire"] = false
	step(m, 0.3)
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	t = 0.0
	while Vector2(P.vel.x, P.vel.z).length() > 0.5 and t < 1.0:
		step(m, DT)
		t += DT
	ok("anim skate: it stops within 0.2 s of letting go (footage: 0.1-0.2 s)", t <= SOURCE_FRAME + TOL, "%.2f s" % t)
	var go := KMovesCare.length("tm_skate_go")
	ok("anim skate: the push-off clip is as long as the ramp", absf(go - float(dd["ramp"])) <= 0.05)

func _rime() -> void:
	var r: Array = sc.setup("rimewright", 4.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var xd: Dictionary = K.x_def()
	ok("anim rime: the rink snaps out in 0.2 s and the seal clip is 0.2 s (footage f25 -> f27)",
		absf(float(xd["snap_t"]) - 0.2) < 0.001 and absf(KMovesCare.length("tm_rime") - 0.2) < 0.001)
	HunterKeys.ult_pressed(P)
	var t := 0.0
	while K.stats["crashes"] < 1 and t < 5.0:
		step(m, DT)
		t += DT
	ok("anim rime: it cracks open by itself at 3.2-3.5 s (footage: f25 -> f57 on the 0.1 s strip)",
		t >= 3.2 and t <= 3.55, "%.2f s" % t)
	ok("anim rime: the crash clip is the footage's 0.4 s from the burst to her recovery (f57 -> f61)",
		K.anim_id == "tm_rime_crash" and absf(KMovesCare.length("tm_rime_crash") - 0.4) < 0.001)
