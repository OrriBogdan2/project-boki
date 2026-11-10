extends RefCounted
## --first-fuse-hint-check: the first-Fuse hints (MatchHints, FirstTimeHint "bond" group). A fresh save in
## a match with a full bond: the prompt shows once with the live Fuse key; the Fuse runs without slowing
## the match; when it ends one line on the rest timer; a second full bond and a second Fuse say nothing.
## A save that has fused (after a save round-trip) and a migrated save that knew the bond tip see neither.

const SETTLE_S := 3.0     # s of play for a hint to show or to stay quiet
const FORM_S := 1.5       # s for the Fuse transformation to finish

var bad := 0
var main: Node
var m: Match
var p: Hunter

func ok(cond: bool, what: String) -> void:
	print("FFH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	_first_fuse()
	_after_reload()
	_migration()
	print("FFH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _start() -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle", "no_drop": true})
	m.set_process(false)
	p = m.player
	for i in 4000:
		if p.riding and m.time > 1.0:
			m.ship_jump(p, true)
		m.step(Match.DT)
		if not p.riding and not p.dropping and p.grounded:
			break
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.hud.msgs.clear()

func _secs(s: float) -> void:
	for i in int(s / Match.DT):
		p.hp = p.max_hp
		m.step(Match.DT)
		m.hud.msgs._process(Match.DT)

func _lines(id: String) -> int:
	var line := FirstTimeHint.text(id)
	return m.hud.msgs.texts().filter(func(t): return t.contains(line)).size()

## Plays `secs` and counts how many frames the hint was on the lane as a new line (0 or 1 for a one-time hint).
func _watch(id: String, secs: float) -> int:
	var n := 0
	var up := false
	for i in int(secs / Match.DT):
		_secs(Match.DT)
		var on := _lines(id) > 0
		if on and not up:
			n += 1
		up = on
	return n

func _fill_bond() -> void:
	p.slot_lv["ult"] = maxi(1, int(p.slot_lv.get("ult", 0)))
	p.ult = 1.0

func _first_fuse() -> void:
	_start()
	ok(_watch("fuse", SETTLE_S) == 0, "bond not full: no Fuse prompt")
	_fill_bond()
	var t0 := m.time
	ok(KinMerge.can_cast(p), "the bond allows a Fusion")
	var n := _watch("fuse", SETTLE_S)
	ok(n == 1, "the prompt shows once when the Fusion is allowed (%d)" % n)
	var cap := Settings.key_cap("ultimate")
	ok(FirstTimeHint.text("fuse").contains(cap), "the prompt carries the live key cap (%s)" % cap)
	ok(FirstTimeHint.seen("fuse"), "the prompt is saved as shown")
	var played := m.time - t0
	ok(absf(played - SETTLE_S) < 0.1, "the match clock was not slowed (%.2f s in %.2f s)" % [played, SETTLE_S])
	ok(_lines("fuse_rest") == 0, "no rest line before the Fuse ends")
	m.hud.msgs.clear()
	ok(KinMerge.press(p), "the Fuse key fuses")
	_secs(FORM_S)
	ok(KinMerge.active(p), "the Fuse is live")
	ok(_lines("fuse_rest") == 0, "no rest line while fused")
	KinMerge.end(p, "ult")
	n = _watch("fuse_rest", SETTLE_S)
	ok(n == 1, "one rest line after the Fuse ends (%d)" % n)
	ok(p.kin.rest_t > 0.0 or p.kin.state != "fused", "the Boki is resting or back (rest %.1f s)" % p.kin.rest_t)
	m.hud.msgs.clear()
	p.merge_cd = 0.0
	_fill_bond()
	ok(_watch("fuse", SETTLE_S) == 0, "a second full bond: no prompt")
	ok(KinMerge.press(p), "the second Fuse")
	_secs(FORM_S)
	KinMerge.end(p, "ult")
	ok(_watch("fuse_rest", SETTLE_S) == 0, "the second Fuse ends: no rest line")

## A save that has fused, reloaded: a full bond and a Fuse show nothing.
func _after_reload() -> void:
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	ok(FirstTimeHint.seen("fuse") and FirstTimeHint.seen("fuse_rest"), "both flags survive the save round-trip")
	_start()
	_fill_bond()
	var n := _watch("fuse", SETTLE_S)
	ok(KinMerge.press(p), "fusing again on that save")
	_secs(FORM_S)
	KinMerge.end(p, "ult")
	n += _watch("fuse_rest", SETTLE_S)
	ok(n == 0, "a save that has fused sees neither line (%d)" % n)

## Save v12 -> v13: a save that saw the old "Bond full" tip has both flags; one that did not has neither.
func _migration() -> void:
	var old := {"tutorial": {"ult": true}}
	FirstTimeHint.migrate(old)
	var marked: Dictionary = old["tutorial"]["hints"]
	var both: bool = marked.get("fuse", false) and marked.get("fuse_rest", false)
	ok(both, "migration: a save that knew the bond tip is marked")
	var fresh := {"tutorial": {"match": true}}
	FirstTimeHint.migrate(fresh)
	ok(not bool(fresh["tutorial"]["hints"].get("fuse", false)), "migration: a save that never saw it keeps the prompt")
