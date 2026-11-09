extends RefCounted
## --recast-cue-check: every recast kit answers ArchKit.recast_left() / recast_slot() from its own state: 0 before
## the first cast, open (> 0, on the right HUD slot) once the ability is out, 0 again after the recast press. Each
## kit then shows the owner's recast rule (RecastBuffer): a press kept 0.15 s fires when its window is open, and a
## window that runs out unused leaves the slot EXPIRED for 0.6 s (one that has no time limit never does).
## DECISIONS 2026-11-08 "two-step abilities must be obvious"; the cue itself is scripts/ui/recast_cue.gd.

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("RECASTCHECK %-50s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _e_kits()
	await _x_kits()
	await _lmb_and_dash()
	await _kept_presses()
	print("RECASTCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Opens the window with `open` (a Callable on the kit), waits `wait` s, then asserts open on `slot`; `close` ends it.
func _cycle(arch: String, label: String, slot: String, open: Callable, wait: float,
		close: Callable, wait2 := 0.3) -> void:
	var r: Array = ak.setup(arch, 8.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: ArchKit = P.ak
	ok("%s: closed before the cast" % label, K.recast_left() == 0.0)
	open.call(P, K, m)
	ak.step(m, wait)
	ok("%s: open on slot %s" % [label, slot], K.recast_left() > 0.0 and K.recast_slot() == slot,
			"left %.2f slot %s" % [K.recast_left(), K.recast_slot()])
	close.call(P, K, m)
	ak.step(m, wait2)
	ok("%s: closed after the recast" % label, K.recast_left() == 0.0, "left %.2f" % K.recast_left())
	m.queue_free()
	await _rule(arch, label, slot, open, wait)

## The owner's recast rule on a fresh copy of the kit: a kept press fires into the open window, and a window left
## alone either expires on the clock (flash for expired_s, then gone) or, with no time limit, never does.
func _rule(arch: String, label: String, slot: String, open: Callable, wait: float) -> void:
	var r: Array = ak.setup(arch, 8.0, "", false)
	var m: Match = r[0]
	var K: ArchKit = r[1].ak
	open.call(r[1], K, m)
	ak.step(m, wait)
	K.rb.early(slot)
	ak.step(m, 0.1)
	ok("%s: a kept press fires into the open window" % label, not K.rb.held.has(slot), "held %s" % K.rb.held)
	m.queue_free()
	r = ak.setup(arch, 8.0, "", false)
	m = r[0]
	K = r[1].ak
	open.call(r[1], K, m)
	ak.step(m, wait)
	var left := K.recast_left()
	if left == INF:
		ak.step(m, 3.0)
		ok("%s: a window with no time limit never expires" % label, K.rb.expired.is_empty() and K.recast_left() > 0.0)
	else:
		while K.recast_left() > 0.0:
			ak.step(m, 0.05)
		ok("%s: a window left alone expires on its slot" % label, K.rb.expired.has(slot), "%s" % K.rb.expired)
		ak.step(m, float(Content.rules("recast")["expired_s"]) + 0.05)
		ok("%s: and the flash is gone after 0.6s" % label, K.rb.expired.is_empty())
	m.queue_free()

func _e(_P: Hunter, K: ArchKit, _m: Match) -> void:
	K.cd["e"] = 0.0
	K.use_e()

func _x(P: Hunter, K: ArchKit, _m: Match) -> void:
	K.cd["x"] = 0.0
	ak.aim_at(P, P.pos + Vector3(8, 0, 0))
	HunterKeys.ult_pressed(P)

func _again(P: Hunter, _K: ArchKit, _m: Match) -> void:
	HunterKeys.ult_pressed(P)

func _e_kits() -> void:
	var press_e := func(_P, K, _m): K.use_e()
	await _cycle("thief", "thief Shadow Knife", "k1", _e, 1.0, press_e)
	await _cycle("ostra", "ostra Brimseed", "k1", _e, 1.0, press_e)
	await _cycle("tender", "tender Hearthlight", "k1", _e, 1.0, press_e)
	await _cycle("rimewright", "rimewright Rink Wall", "k1", _e, 1.0, press_e)

func _x_kits() -> void:
	await _cycle("mage", "mage Kitefall", "x", _x, 1.0, _again)
	await _cycle("ashwick", "ashwick Flue Flight", "x", _x, 0.3, _again)
	await _cycle("rimewright", "rimewright Rimelock", "x", _x, 0.6, _again)

## A press of the attack key, released after 0.1 s.
func _lmb(P: Hunter, _K: ArchKit, m: Match) -> void:
	P.inp["fire"] = true
	ak.step(m, 0.1)
	P.inp["fire"] = false

func _hop(_P: Hunter, K: ArchKit, _m: Match) -> void:
	K.on_dash(false)

func _lmb_and_dash() -> void:
	await _cycle("bulwark", "bulwark hammer recall", "primary", _lmb, 1.0, _lmb, 1.5)
	await _cycle("dolm", "dolm Rock Hop", "dash", _hop, 0.35, _hop, 1.5)

## A press that finds nothing to do is kept: E and X in cooldown, Shift with no dash left, LMB while a throw recovers.
func _kept_presses() -> void:
	for arch in ["thief", "ostra", "tender", "rimewright"]:
		var r: Array = ak.setup(arch, 8.0, "", false)
		var K: ArchKit = r[1].ak
		K.cd["e"] = 5.0
		K.use_e()
		ok("%s: E pressed in cooldown is kept" % arch, K.rb.held.has("k1"))
		r[0].queue_free()
	for arch in ["mage", "ashwick", "rimewright"]:
		var r: Array = ak.setup(arch, 8.0, "", false)
		var K: ArchKit = r[1].ak
		K.cd["x"] = 5.0
		HunterKeys.ult_pressed(r[1])
		ok("%s: X pressed in cooldown is kept" % arch, K.rb.held.has("x"))
		r[0].queue_free()
	var r: Array = ak.setup("dolm", 8.0, "", false)
	r[1].dashes = 0.0
	r[1].ak.on_dash(false)
	ok("dolm: Shift with no dash left is kept", r[1].ak.rb.held.has("dash"))
	r[0].queue_free()
	r = ak.setup("bulwark", 8.0, "", false)
	_lmb(r[1], r[1].ak, r[0])
	ak.step(r[0], 0.2)
	_lmb(r[1], r[1].ak, r[0])
	ok("bulwark: LMB while the throw recovers is kept", r[1].ak.rb.held.has("primary"), "held %s" % r[1].ak.rb.held)
	r[0].queue_free()
