extends "res://tools/archetype_check.gd"
## --recast-buffer-check: one data-driven sweep over every recast slot of every kit (DECISIONS 2026-11-08: a recast
## press made a hair early is buffered ~0.15 s, and a window never closes silently). Per kit and slot, from a fresh
## setup: the first step, then the steps until the window arms (open); a press LEAD_IN steps before it arms must
## fire as it arms (the shared ArchKit.buffer_recast); a press LEAD_OUT steps before must not (past the buffer, the
## window opens untouched); left alone the slot shows EXPIRED and the closing tick / run-out click plays. Slots
## whose window arms with the first step itself have no early press to buffer (n/a). Prints RBCHECK lines and a
## per-kit table.

const LEAD_IN := 7             # steps (0.117 s) before the window arms: inside the 0.15 s buffer, it fires
const LEAD_OUT := 12           # steps (0.2 s) before: past the buffer, the press is dropped
const SETTLE := 2              # steps after the window arms before the result is read
const WAIT := 4.0              # s the first step gets to arm its window (Rimelock's late crack is the last, 2.55 s)
const RUN_OUT := 18.0          # s a window left alone gets to close (Brimseed: 6.5 s grow + 10 s at full)
const First = preload("res://tools/recast_cue_check.gd")

## [hero id, slot, the recast as the table names it, the target's distance (m), what a press past the buffer does]:
## every two-step slot in the kits. The last is "" (dropped: the window opens untouched) or the kit's stats key
## that counts its own early meaning (Rimelock: X before the crack window breaks the shell, "cancels").
## Kael's target stands far enough for the chain's flight to outlast the buffer.
const CASES := [
	["thief", "e", "Sable: Shadow Knife step", 6.0, ""],
	["tender", "e", "Meeko: Hearthlight throw", 6.0, ""],
	["ostra", "e", "Motley: Brimseed pop", 6.0, ""],
	["rimewright", "e", "Neve: Rink Wall freeze", 6.0, ""],
	["rimewright", "x", "Neve: Rimelock crack", 6.0, "cancels"],
	["juggernaut", "e", "Kael: Warchain pull", 12.0, ""],
	["mage", "x", "Sparkle: Kitefall drop", 6.0, ""],
	["ashwick", "x", "Cinder: Flue Flight landing", 6.0, ""],
	["bulwark", "lmb", "Albert: hammer recall", 6.0, ""],
	["dolm", "dash", "Tenzo: Rock Hop chain", 6.0, ""],
	["gil", "e", "Gil: waterspout release", 6.0, ""],
	["gil", "x", "Gil: wave leap", 6.0, ""],
]

var rows: Array[String] = []


func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("RBCHECK %-58s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for c in CASES:
		await _case(String(c[0]), String(c[1]), String(c[2]), float(c[3]), String(c[4]))
	print("RBCHECK TABLE %-30s %-5s %-7s %-9s %-9s %s" % ["recast", "slot", "arms", "buffered", "dropped", "expires"])
	for r in rows:
		print(r)
	print("RBCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## The slot's own press, the way the key reaches the kit. Returns the steps it took (LMB is read in a step).
func _press(m: Match, p: Hunter, slot: String) -> int:
	match slot:
		"e": p.ak.use_e()
		"x": HunterKeys.ult_pressed(p)
		"dash": p.do_dash()
		"lmb":
			p.inp["fire"] = true
			m.step(DT)
			p.inp["fire"] = false
			return 1
	return 0


func _armed(p: Hunter, slot: String) -> bool:
	var w := p.ak.recast_window()
	return String(w.get("slot", "")) == slot and bool(w.get("armed", true))


func _open(p: Hunter, slot: String) -> bool:
	return String(p.ak.recast_window().get("slot", "")) == slot


## The closing tick (the hunter's own or the stock click) or the run-out click: Sfx.last_played moved for one.
func _ticked(p: Hunter, before: Dictionary) -> bool:
	for snd in ["click", HeroSfx.of(p, "recast_tick", "")]:
		if snd != "" and int(Sfx.last_played.get(snd, -1)) != int(before.get(snd, -1)):
			return true
	return false


func _case(hero: String, slot: String, label: String, dist: float, cancel: String) -> void:
	var got := await _measure(hero, slot, label, dist)
	var open_i := int(got["open_i"])
	var cells := ["n/a", "n/a"]
	if open_i >= 0:
		cells[0] = await _early(hero, slot, label, dist, open_i, LEAD_IN, true)
		cells[1] = await _early(hero, slot, label, dist, open_i, LEAD_OUT, false, cancel)
	var arms := "%.2fs" % (open_i * DT) if open_i >= 0 else "never"
	rows.append("RBCHECK TABLE %-30s %-5s %-7s %-9s %-9s %s" % [label, slot, arms, cells[0], cells[1], got["expire"]])


## The first step, the steps until the window arms (open_i, -1: never), then the window left alone until it closes.
func _measure(hero: String, slot: String, label: String, dist: float) -> Dictionary:
	var s := setup(hero, dist)
	var m: Match = s[0]
	var p: Hunter = s[1]
	aim_at(p, (s[2] as Hunter).pos)
	First.first(m, p, slot)
	var open_i := -1
	var i := 0
	while i * DT < WAIT:
		if _armed(p, slot):
			open_i = i
			break
		m.step(DT)
		i += 1
	ok("%s: the window arms" % label, open_i >= 0, "after %d steps (%.2fs)" % [open_i, open_i * DT])
	var expire := "FAIL"
	if open_i >= 0:
		expire = await _expire(m, p, slot, label)
	await done(m)
	return {"open_i": open_i, "expire": expire}


## Left alone: the slot shows EXPIRED as it closes and a tick or the run-out click played. A window with no timer
## (Albert's hammer lies until called back) is n/a.
func _expire(m: Match, p: Hunter, slot: String, label: String) -> String:
	var before := Sfx.last_played.duplicate()
	var t := 0.0
	while t < RUN_OUT and _open(p, slot):
		m.step(DT)
		t += DT
	if _open(p, slot):
		var w := p.ak.recast_window()
		if float(w["left"]) >= float(w["total"]):
			return "n/a"
		ok("%s: left alone, the window closes" % label, false, "still open after %.0fs: %s" % [t, str(w)])
		return "FAIL"
	m.step(DT)
	var cue: Dictionary = p.ak.cue
	var expired: bool = String(cue.get("exp_slot", "")) == slot and float(cue.get("exp_t", 0.0)) > 0.0
	var ticked := _ticked(p, before)
	ok("%s: left alone, the slot shows EXPIRED after %.2fs" % [label, t], expired, str(cue.get("exp_slot", "-")))
	ok("%s: left alone, the closing tick / run-out click plays" % label, ticked)
	return "PASS" if expired and ticked else "FAIL"


## A press `lead` steps before the window arms: `fires` says whether it must go as the window arms; else it is
## dropped and the window opens untouched, or (`cancel` names the kit's counter) it is the kit's own early meaning.
func _early(hero: String, slot: String, label: String, dist: float, open_i: int, lead: int, fires: bool,
		cancel := "") -> String:
	if open_i - lead < 0:
		return "n/a"
	var s := setup(hero, dist)
	var m: Match = s[0]
	var p: Hunter = s[1]
	aim_at(p, (s[2] as Hunter).pos)
	First.first(m, p, slot)
	for i in open_i - lead:
		m.step(DT)
	var armed_before := _armed(p, slot)
	var took := _press(m, p, slot)
	for i in lead + SETTLE - took:
		m.step(DT)
	var cue: Dictionary = p.ak.cue
	var went := not _open(p, slot) and String(cue.get("exp_slot", "")) != slot and p.ak.recast_buf.is_empty()
	var good: bool
	var what: String
	if fires:
		what = "fires as it arms"
		good = went
	elif cancel != "":
		what = "is its own early press (%s), the window never opens" % cancel
		var counters = p.ak.get("stats")
		good = went and counters is Dictionary and int(counters.get(cancel, 0)) == 1
	else:
		what = "is dropped, the window opens untouched"
		good = _armed(p, slot)
	good = good and not armed_before
	ok("%s: a press %.2fs before it arms %s" % [label, lead * DT, what], good,
			"went %s open %s buf %s" % [went, _open(p, slot), str(p.ak.recast_buf)])
	await done(m)
	return "PASS" if good else "FAIL"
