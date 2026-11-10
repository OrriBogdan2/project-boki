extends RefCounted
## --wisp-proc-sfx-check: a carried Boki's on-shot passive makes one quiet chirp from its species' own voice
## (KinWispProc). One cue per proc through the real Hunter._kin_riders, at most one per 0.8 s per wisp, the
## species' own bank (bk_<species>_happy), pitched by size, a rival's quieter than yours, both under an ability
## cast, silent when the Boki walks. Prints PASS/FAIL. Never touches the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("WISPPROC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	_run(0.5)
	var p: Hunter = m.player
	var k: Kin = p.kin
	ok(k != null and k.wisp and p.kin_carry_on(), "your Boki rides as a wisp with its passives on")
	ok(not k.ks.carry_on_shot.is_empty(), "%s has an on-shot passive" % k.species)
	_proc_rules(p, k)
	_levels(p)
	_pitch(k)
	KinWisp.set_wisp(k, false)
	k.proc_at = -9.0
	ok(KinWispProc.proc(p) == "", "a walking Boki (not a wisp) stays silent")
	m.queue_free()
	print("WISPPROCSFX %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## One cue per proc, the species' own bank, and the 0.8 s limit per wisp.
func _proc_rules(p: Hunter, k: Kin) -> void:
	var own := "bk_%s_happy" % k.species
	var picked := Sfx.ensure(own) and KinVoice.cue(k.species, "happy") == own
	ok(picked, "the species' own bank exists and is the one picked (%s)" % own)
	k.proc_at = -9.0
	var t0 := m.time
	for i in 5:
		p._kin_riders({})            # five shots in the same instant: one proc cue
	ok(k.proc_at == t0 and KinWispProc.proc(p) == "", "five shots at once chirp once")
	_run(0.5)
	ok(KinWispProc.proc(p) == "", "0.5 s later it is still held back")
	_run(0.35)
	var cue := KinWispProc.proc(p)
	ok(cue == own, "past 0.8 s it chirps again with the species' voice (%s)" % cue)
	ok(is_equal_approx(k.proc_at, m.time), "that chirp restarted the 0.8 s")

## Yours over a rival's, and both give way under an ability cast.
func _levels(p: Hunter) -> void:
	var rival: Hunter = m.hunters.filter(func(h: Hunter): return h != p and h.kin != null)[0]
	p.cast_at = -9.0
	rival.cast_at = -9.0
	var yours := KinWispProc.level_db(p) == KinWispProc.OWN_DB
	ok(yours and KinWispProc.level_db(rival) == KinWispProc.RIVAL_DB, "yours -20 dB, a rival's -26 dB")
	ok(KinWispProc.OWN_DB <= -18.0, "quiet: below -18 dB (ability sounds sit at -6 to 0)")
	p.cast_at = m.time
	rival.cast_at = m.time
	ok(KinWispProc.level_db(p) == KinWispProc.OWN_DB + KinWispProc.DUCK_DB, "your chirp ducks under your ability cast")
	ok(KinWispProc.level_db(rival) < KinWispProc.RIVAL_DB, "a rival's chirp ducks under their cast")
	rival.kin.proc_at = -9.0
	var k: Kin = rival.kin
	k.ks = p.kin.ks          # (the rival's Boki gets the same on-shot passive: its own species has none)
	ok(rival.kin.wisp and KinWispProc.proc(rival) != "", "a rival's wisp chirps too")

## Small bodies chirp higher than big ones.
func _pitch(k: Kin) -> void:
	var s: Dictionary = KinWispProc.SIZE_PITCH
	ok(float(s["small"]) > float(s["medium"]) and float(s["medium"]) > float(s["large"]), "pitch falls with body size")
	ok(s.has(k.ks.size), "%s's size (%s) has a pitch" % [k.species, k.ks.size])
