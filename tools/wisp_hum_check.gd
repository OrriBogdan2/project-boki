extends RefCounted
## --wisp-hum-check: the Hunter Wisp's hum (scripts/match/wisp_hum.gd, DECISIONS 2026-11-09 outline rule).
## A downed Hunter starts a keyed hum loop; a teammate's is louder than a rival's; its pitch rises while the
## revive channel fills; it is silent past reach_m; a revive or a bleed-out ends it with a fall-away; and in a
## 30-Hunter fight with everybody down only max_voices hum, the nearest ones. The loop file is low (nothing
## like a Boki chirp). Prints PASS/FAIL.

const DT := 1.0 / 60.0
const HOLD_WAIT := 0.4      # s: longer than Sfx.HOLD_MS, so a loop nobody holds is gone

var bad := 0
var m: Match
var main: Node
var here := Vector3.ZERO

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	here = m.player.pos
	ok(m.hunters.size() == 30, "setup: 30 Hunters (%d)" % m.hunters.size())
	_sound_file()
	var mate: Hunter = m.hunters.filter(func(x): return x.team == m.player.team and x != m.player)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != m.player.team)
	_frames(0.1)
	ok(_hums().is_empty(), "nobody down: no hum")
	_down(mate, 6.0)
	_down(foes[0], 6.0)
	_frames(0.5)
	ok(Sfx.loop_on(WispHum.key(mate)) and Sfx.loop_on(WispHum.key(foes[0])), "a downed Hunter starts its hum")
	var levels := [_vol(mate), _vol(foes[0])]
	ok(levels[0] > levels[1], "a teammate's Wisp is louder than a rival's (%.1f vs %.1f dB)" % levels)
	ok(_pitch(mate) == 1.0, "the pitch is the base while no revive is under way (%.2f)" % _pitch(mate))
	mate.revive = 0.8
	_frames(0.1)
	ok(_pitch(mate) > 1.2, "the pitch rises while the revive fills (%.2f)" % _pitch(mate))
	_stomped_and_carried(mate, foes[1])
	await _far_away(mate)
	m.revive_hunter(mate, null)
	_frames(0.1)
	ok(not Sfx.loop_on(WispHum.key(mate)), "a revive ends the hum")
	ok(_falling_away(), "...with a soft fall-away")
	m.eliminate(foes[0], mate, "finished")
	_frames(0.1)
	ok(not Sfx.loop_on(WispHum.key(foes[0])), "a bleed-out ends the hum too")
	_cap(foes)
	_end()

## The loop file (a canonical 44-byte wav header, mono) crosses zero a few hundred times a second
## at most; a Boki chirp, 1 to 2.3 kHz, a few thousand. (That it loops seamlessly: --sfx-set-check.)
func _sound_file() -> void:
	var file := FileAccess.get_file_as_bytes("res://audio/wisp_hum.wav")
	var b := file.slice(44)
	var n := b.size() / 2
	var crossings := 0
	for i in range(1, n):
		if (b.decode_s16(i * 2 - 2) < 0) != (b.decode_s16(i * 2) < 0):
			crossings += 1
	var hz := crossings / 2.0 / (float(n) / float(file.decode_u32(24)))
	ok(n > 0 and hz < 400.0, "the hum is low, not a Boki chirp (%.0f Hz mean)" % hz)

## The hum follows the Wisp's own states, with none of its own: a foe's stomp drains the revive and the pitch
## falls back with it, and a teammate's carry takes the hum along with the Wisp.
func _stomped_and_carried(mate: Hunter, foe: Hunter) -> void:
	_place(foe, 6.0)
	foe.pos.z = mate.pos.z + 1.0      # on the Wisp, close enough that nothing pushes them apart
	foe.prev = foe.pos
	_frames(0.3)
	var low := bool(mate.get_meta("stomped", false)) and _pitch(mate) < 1.25
	ok(low, "a stomp lock drains the revive: the pitch falls (%.2f)" % _pitch(mate))
	_place(foe, 40.0)
	var carrier: Hunter = m.hunters.filter(func(x): return x.team == mate.team and x != mate and x != m.player)[0]
	_place(carrier, 12.0)
	mate.set_meta("carried_by", carrier.nid)
	_frames(0.2)
	var at: Vector3 = Sfx.loops[WispHum.key(mate)]["pos"]
	var gap := at.distance_to(carrier.position)
	var rides := Sfx.loop_on(WispHum.key(mate)) and gap < 1.0
	ok(rides, "carried by a teammate: the hum rides with the carrier (%.2f m)" % gap)
	mate.remove_meta("carried_by")
	_place(mate, 6.0)

## Teammate far from the listener: the hum goes (the loop is held only inside reach_m).
func _far_away(mate: Hunter) -> void:
	_place(mate, 40.0)
	_frames(0.1)
	await main.get_tree().create_timer(HOLD_WAIT).timeout
	ok(not Sfx.loop_on(WispHum.key(mate)), "past %.0f m there is no hum" % float(WispHum.rules()["reach_m"]))
	_place(mate, 6.0)
	_frames(0.1)
	ok(Sfx.loop_on(WispHum.key(mate)), "...and it comes back inside it")

## Everybody down at once, spread 3 to 17 m out: only max_voices hum, the nearest ones.
func _cap(foes: Array) -> void:
	for h in m.hunters:
		if h != m.player and not h.out:
			if not h.downed:
				_down(h, 3.0)
			_place(h, 3.0 + 14.0 * float(m.hunters.find(h)) / m.hunters.size())
	_frames(0.6)
	var cap := int(WispHum.rules()["max_voices"])
	var live := _hums()
	ok(live.size() == cap, "30 Hunters down: exactly %d hums (%d)" % [cap, live.size()])
	var downed: Array = m.hunters.filter(func(h): return h.downed and not h.out)
	downed.sort_custom(func(a, b): return a.pos.distance_to(here) < b.pos.distance_to(here))
	var nearest := downed.slice(0, cap).all(func(h): return Sfx.loop_on(WispHum.key(h)))
	ok(downed.size() >= 20 and nearest, "...and they are the nearest Wisps (%d down)" % downed.size())

func _end() -> void:
	m.queue_free()
	print("WISPHUM %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WISPHUM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _down(h: Hunter, dist: float) -> void:
	var foe: Hunter = m.hunters.filter(func(x): return x.team != h.team)[0]
	m.knock(h, foe, {})
	h.down_hp = 1e6
	_place(h, dist)

func _place(h: Hunter, dist: float) -> void:
	h.pos = here + Vector3(dist, 0, 0)
	h.prev = h.pos

func _hums() -> Array:
	return Sfx.loops.keys().filter(func(k): return String(k).begins_with("wisphum"))

func _vol(h: Hunter) -> float:
	return float(Sfx.loops[WispHum.key(h)]["vol"])

func _pitch(h: Hunter) -> float:
	return (Sfx.loops[WispHum.key(h)]["p"] as AudioStreamPlayer).pitch_scale

func _falling_away() -> bool:
	return Sfx.players.any(func(p): return p.playing and p.stream == Sfx.streams.get(WispHum.HUM_END))

func _frames(secs: float) -> void:
	Sfx.listener = here
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			h.render(DT, 1.0)
