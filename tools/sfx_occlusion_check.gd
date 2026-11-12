extends RefCounted
## --sfx-occlusion-check: a sound behind a cliff goes through the muffled bus (low-pass plus a gain
## drop); the same sound in sight, UI sounds and your own Hunter do not. Also the cost of the test
## for a 30-Hunter fight (30 sources, 10 Hz). Runs on a small hand-made map: a high terrace, a flat floor.

const FIGHT_VOICES := 30
## us per 100 ms of a 30-voice fight with every test uncached: a few % of that window
const BUDGET_US := 2000.0

var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("SFXOCCLUSION %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main: Node) -> void:
	var wd := World.new()
	wd.w = 40
	wd.h = 12
	wd.kind.resize(wd.w * wd.h)
	wd.level.resize(wd.w * wd.h)
	wd.kind.fill(World.T_GROUND)
	for z in wd.h:
		for x in range(20, wd.w):          # the right half is a terrace three levels up (2.4 m): a cliff at x = 20
			wd.level[wd.idx(x, z)] = 3
	var occ := SfxOcclusion.new()
	occ.world = wd
	var low := Vector3(8.5, 0.0, 5.5)
	var high := Vector3(30.5, 2.4, 5.5)
	var floor_mate := Vector3(14.5, 0.0, 5.5)
	ok(occ.blocked(high, low), "behind a cliff: a sound on the terrace, the listener on the floor, is blocked")
	ok(not occ.blocked(floor_mate, low), "in sight: the same floor, no cliff between, is not blocked")
	ok(not occ.blocked(low + Vector3(1.0, 0, 0), low), "your own Hunter (beside the listener) is never blocked")
	var heard := Vector3(25.5, 2.4, 5.5)
	ok(not occ.blocked(heard, Vector3(30.5, 2.4, 7.5)), "both on the terrace: not blocked")
	_buses(occ, low, high, floor_mate)
	_cost(occ, low)
	wd.free()
	print("SFXOCCLUSION %d checks, %d fail" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The pool voice's bus: muffled behind the cliff and at the plain bus in sight; UI sounds (no position) too.
func _buses(occ: SfxOcclusion, low: Vector3, high: Vector3, floor_mate: Vector3) -> void:
	var was := Sfx.occlusion
	var heard := Sfx.listener
	Sfx.occlusion = occ
	Sfx.listener = low
	ok(Sfx._bus_for(high) == "SFXMuffled", "the voice behind the cliff plays on the muffled bus")
	ok(Sfx._bus_for(floor_mate) == "SFXWorld", "the voice in sight stays on the plain world bus")
	ok(Sfx._bus_for(null, true) == "SFX", "a clear sound (no position) skips the world buses")
	var bus := AudioServer.get_bus_index("SFXMuffled")
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0)
	var far_lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("SFXFar"), 0)
	ok(lp.cutoff_hz < far_lp.cutoff_hz, "the muffled bus is duller than the far bus (%.0f < %.0f Hz)"
		% [lp.cutoff_hz, far_lp.cutoff_hz])
	var gain := AudioServer.get_bus_volume_db(bus)
	ok(gain < 0.0, "...and a little quieter (%.1f dB)" % gain)
	Sfx.occlusion = was
	Sfx.listener = heard

func _cost(occ: SfxOcclusion, low: Vector3) -> void:
	occ.cache.clear()
	var t0 := Time.get_ticks_usec()
	for i in FIGHT_VOICES:
		occ.blocked(Vector3(21.5 + i * 0.5, 2.4, 2.5 + i % 7), low)
	var us := float(Time.get_ticks_usec() - t0)
	ok(us < BUDGET_US, "%d uncached tests take %.0f us (budget %.0f)" % [FIGHT_VOICES, us, BUDGET_US])
	t0 = Time.get_ticks_usec()
	for i in FIGHT_VOICES:
		occ.blocked(Vector3(21.5 + i * 0.5, 2.4, 2.5 + i % 7), low)
	ok(float(Time.get_ticks_usec() - t0) < us, "the repeat inside 100 ms is cached (cheaper)")
