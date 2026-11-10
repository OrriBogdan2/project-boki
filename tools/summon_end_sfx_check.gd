extends RefCounted
## --summon-end-sfx-check: the end of a Boki summon is heard (KinSummon.warn, render). The soft two-note warning
## plays once, WARN_S (2 s) before the window ends and not before; the shrink back into the wisp plays its own
## cue when the window runs out (the fold starts); a summon sent back early or knocked down never warns (a
## knock-down keeps its own "killed" cue) and a knock-down mid-warning drops the second note. Prints PASS/FAIL.
## Never touches the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var k: Kin
var s: KinSummon

func ok(cond: bool, what: String) -> void:
	print("SUMEND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	k = m.player.kin
	s = k.summon
	_window()
	_early_and_knocked()
	m.queue_free()
	print("SUMMONEND %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## One step of the match and of the Boki's drawing.
func _step() -> void:
	m.step(DT)
	k.render(DT, 1.0)

func _summon() -> void:
	s.cd = 0.0
	ok(KinSummon.press(m.player) and s.left > 0.0 and not s.warned, "a fresh window has not warned")

func _window() -> void:
	_summon()
	var window := s.left
	var warn_at := -1.0
	var fold_at := -1.0
	var t := 0.0
	while t < window + 1.0 and fold_at < 0.0:
		_step()
		t += DT
		if warn_at < 0.0 and s.warned:
			warn_at = t
		if s._folding:
			fold_at = t
	ok(absf((window - warn_at) - KinSummon.WARN_S) < 2.0 * DT,
		"the warning comes %.2f s before the end (want %.1f)" % [window - warn_at, KinSummon.WARN_S])
	ok(absf(fold_at - window) < 2.0 * DT,
		"the shrink-back cue starts when the window runs out (%.2f of %.1f s)" % [fold_at, window])
	ok(warn_at < fold_at, "...after the warning, not instead of it")
	if not Sfx.streams.is_empty():
		var chirp := KinSummon.chirp_name(k.ks)
		ok(int(Sfx.last_played.get(chirp, -1000)) > 0 and Sfx.has("summon_end_" + (k.ks.size if k.ks else "small")),
			"the species chirp and the shrink cue are real sounds")
	for i in int(KinSummon.SHRINK_S / DT) + 5:
		_step()
	ok(k.wisp, "it is a wisp again")

func _early_and_knocked() -> void:
	_summon()
	for i in 30:
		_step()
	ok(KinSummon.press(m.player) and s.left <= 0.0 and not s.warned, "sent back early with time left: no warning")
	for i in int(KinSummon.SHRINK_S / DT) + 5:
		_step()
	_summon()
	while s.left > KinSummon.WARN_S + 1.0:
		_step()
	k.hurt(k.max_hp * 5.0, null)
	_step()
	ok(k.wisp and not s.warned, "knocked down before the warning: it turns into a wisp and never warns")
	for i in 240:
		_step()
	ok(not s.warned, "...and does not warn later")
	_summon()
	while not s.warned:
		_step()
	k.hurt(k.max_hp * 5.0, null)
	ok(k.wisp and s.left <= 0.0, "knocked down just after the warning: nothing is out when the second note falls due")
