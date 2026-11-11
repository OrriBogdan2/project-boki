extends RefCounted
## --ready-cue-check: the quiet "it's back" cues (ReadyCues, hooked into HudSlot). With the real match HUD:
## E, the ultimate (R), the Boki's ability and a dash charge after all were spent each fire their cue exactly
## once when the cooldown ends (CombatBus.ready_cue and the sound); not for a dash charge coming back while
## another is left, not on first sight, not in the first 5 s of a match, not while downed, not in the first
## second back from the dead; two slots back together play one cue, the other GAP later; a cooldown running
## on a teammate or an enemy never cues; and every cue sound is quiet. Never touches the save.

var bad := 0
var main: Node
var cues: Array = []

func ok(cond: bool, what: String) -> void:
	print("READYCUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _drawn(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

func _count(cue: String) -> int:
	return cues.count(cue)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	Save.d = d
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	P.ctrl = "local"
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(40, 0, 40))
	P.lvl = int(Hunter.ULT_AT[0])
	P.unlock_all()
	CombatBus.ready_cue.connect(func(h, c): cues.append(c if h == P else "wrong hunter " + c))
	ok(P.ak != null and not P.ak.x_def().is_empty(), "the hero has an ultimate on R")
	ok(P.kin != null and P.kin.runner != null and P.kin.runner.has_slot("k1"), "the hero has a Boki with an ability")
	m.time = 2.0
	await _drawn(m.hud)
	await _cooldown_quiet(m, P)
	ok(cues.is_empty(), "no cue in the first 5 s of a match")
	m.time = 30.0
	await _cycle(m, P)
	await _together(m, P)
	await _gates(m, P)
	await _others(m, P)
	_quiet()
	print("READY CUE CHECK DONE, failures: ", bad)
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)

## A cooldown starts and ends on `slot`: the cue fires once and only at the end, however many frames follow.
func _cooldown(m: Match, set_cd: Callable, cue: String, what: String) -> void:
	set_cd.call(true)
	await _drawn(m.hud)
	m.time += 1.0           # (it cools a while: more than GAP after the cue before)
	await _drawn(m.hud)
	var before := _count(cue)
	var t0: int = int(Sfx.last_played.get(cue, -1000))
	set_cd.call(false)
	await _drawn(m.hud)
	for i in 3:
		await _drawn(m.hud)
	ok(_count(cue) == before + 1, "%s: one cue (%d new)" % [what, _count(cue) - before])
	ok(int(Sfx.last_played.get(cue, -1000)) > t0 or Sfx.streams.is_empty(), "%s: the sound played" % what)

func _e(P: Hunter, cooling: bool) -> void:
	P.ak.cd["e"] = 6.0 if cooling else 0.0

func _ult(P: Hunter, cooling: bool) -> void:
	P.ak.cd["x"] = 6.0 if cooling else 0.0

func _boki(P: Hunter, cooling: bool) -> void:
	var s: Dictionary = P.kin.runner.slots["k1"]
	s["charges"] = 0.0 if cooling else 1.0
	s["cd"] = 6.0 if cooling else 0.0

func _dash(P: Hunter, cooling: bool) -> void:
	P.dashes = 0.0 if cooling else 1.0

func _cycle(m: Match, P: Hunter) -> void:
	await _drawn(m.hud)
	await _cooldown(m, func(c): _e(P, c), "ready_e", "E")
	await _cooldown(m, func(c): _ult(P, c), "ready_ult", "ultimate")
	await _cooldown(m, func(c): _boki(P, c), "ready_boki", "Boki ability")
	await _cooldown(m, func(c): _dash(P, c), "ready_dash", "dash after all were spent")
	var n := cues.size()
	P.dashes = 1.0
	await _drawn(m.hud)
	P.dashes = 1.2
	await _drawn(m.hud)
	P.dashes = 2.0
	await _drawn(m.hud)
	ok(cues.size() == n, "a dash charge coming back while another is left doesn't cue")
	ok(not cues.any(func(c): return c.begins_with("wrong")), "every cue is for the local hunter")

## E and R back on the same draw: one cue at once, the other GAP later (it waits, it isn't dropped).
func _together(m: Match, P: Hunter) -> void:
	_e(P, true)
	_ult(P, true)
	await _drawn(m.hud)
	m.time += 1.0
	var n := cues.size()
	_e(P, false)
	_ult(P, false)
	await _drawn(m.hud)
	await _drawn(m.hud)
	ok(cues.size() == n + 1, "two slots back together: one cue at once (%d)" % (cues.size() - n))
	m.time += ReadyCues.GAP + 0.05        # (the next panel redraw past GAP)
	await _drawn(m.hud)
	ok(cues.slice(n) == ["ready_e", "ready_ult"], "the other plays GAP later: %s" % [cues.slice(n)])

func _gates(m: Match, P: Hunter) -> void:
	var n := cues.size()
	m.time += 1.0
	P.downed = true
	await _cooldown_quiet(m, P)
	ok(cues.size() == n, "no cue while downed")
	P.downed = false
	await _drawn(m.hud)
	await _drawn(m.hud)
	ok(cues.size() == n, "the cooldown that ended while muted doesn't cue later")
	await _cooldown(m, func(c): _ult(P, c), "ready_ult", "ultimate again once play is open")
	await _back_from_out(m, P)

## Out (the bar hidden) and back: what came back meanwhile, and anything in the first second back, stays
## quiet; after that the cues are on again.
func _back_from_out(m: Match, P: Hunter) -> void:
	var n := cues.size()
	_e(P, true)
	_ult(P, true)
	await _drawn(m.hud)
	P.out = true
	await _drawn(m.hud)
	await _drawn(m.hud)
	m.time += 5.0
	_e(P, false)
	P.out = false
	await _drawn(m.hud)
	m.time += ReadyCues.MUTE_BACK * 0.5
	_ult(P, false)
	await _drawn(m.hud)
	await _drawn(m.hud)
	ok(cues.size() == n, "back from the dead: no cue in the first second (%d)" % (cues.size() - n))
	m.time += ReadyCues.MUTE_BACK
	await _cooldown(m, func(c): _e(P, c), "ready_e", "E once the first second back is over")

func _cooldown_quiet(m: Match, P: Hunter) -> void:
	for set_cd in [func(c): _e(P, c), func(c): _ult(P, c), func(c): _boki(P, c), func(c): _dash(P, c)]:
		set_cd.call(true)
		await _drawn(m.hud)
		set_cd.call(false)
		await _drawn(m.hud)

## A teammate's or an enemy's cooldowns ending never cue; neither does the bar while another hunter is the one shown.
func _others(m: Match, P: Hunter) -> void:
	m.time += 1.0
	var n := cues.size()
	var tm := 0
	var en := 0
	for o in m.hunters:
		if o == P:
			continue
		if o.team == P.team:
			tm += 1
		else:
			en += 1
		o.dashes = 0.0
		if o.ak:
			o.ak.cd["x"] = 5.0
		await _drawn(m.hud)
		o.dashes = 2.0
		if o.ak:
			o.ak.cd["x"] = 0.0
		await _drawn(m.hud)
	ok(tm > 0 and en > 0, "the match has teammates (%d) and enemies (%d)" % [tm, en])
	ok(cues.size() == n, "a teammate's or an enemy's cooldown never cues")
	P.ctrl = "idle"
	await _cooldown_quiet(m, P)
	ok(cues.size() == n, "a hunter that isn't the local player never cues")
	P.ctrl = "local"

func _quiet() -> void:
	for sname in ReadyCues.CUE_OF.values():
		var loaded: bool = Sfx.streams.has(sname) or Sfx.streams.is_empty()
		ok(ReadyCues.QUIET_DB <= -6.0 and loaded, "%s is loaded, played quietly" % sname)
