extends RefCounted
## --cd-gate-check (the owner's "I can do RMB when it's on cooldown and the animation goes"): for every hero and
## every slot with a cooldown (RMB tap and hold, E, R, X, Shift, Q), a press while that slot is on cooldown plays no
## kit move or cast pose, deals no damage to a foe standing in front, moves the hunter not at all, spends nothing
## and raises one deny (PressDeny) instead. LMB has no cooldown (its rate is the weapon's): not a row here.
## Reuses the dash-flow check's training match. Never touches the save.

const WATCH_S := 1.0          # s watched after the press (an RMB hold is held for all of it)
const FOE_AT := 3.0           # m in front of the hunter the foe stands
const MOVED_MAX := 0.05       # m of planar drift that still counts as standing still
const LEFT_S := 4.0           # s of cooldown the slot has when pressed (longer than the watch)
const BAR_ID := {"rmb_tap": "sec", "rmb_hold": "sec", "e": "k1", "r": "r", "x": "x", "dash": "dash", "q": "gear0"}
const SLOTS := ["none", "rmb_tap", "rmb_hold", "e", "r", "x", "dash", "q"]

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()
var foe: Hunter
var still := 0.0              # m the hunter drifts in the same window with no press (the foe's nearness)

func ok(cond: bool, what: String) -> void:
	print("CDGATE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(flow._on_used)
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		for o in m.hunters:
			if o != flow.hunter:
				foe = o
		for slot in SLOTS:
			_trial(m, hero, slot)
		m.queue_free()
		await main.get_tree().process_frame
	print("CDGATE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _trial(m: Match, hero: String, slot: String) -> void:
	var h: Hunter = flow.hunter
	var k: ArchKit = h.ak
	flow._ready_up(m)
	h.lvl = 10
	h.merge_cd = 0.0
	var ahead := Vector3(0, 0, -FOE_AT)
	h.inp["aim"] = h.pos + ahead
	foe.teleport(h.pos + ahead)
	for kin in m.kins:
		if kin.owner_h != h: kin.teleport(h.pos + Vector3(40, 0, 40))      # (a rival Boki walking up would shove you)
	foe.hp = foe.max_hp
	foe.vel = Vector3.ZERO
	_cool(h, k, slot)
	for i in 3:
		m.step(Match.DT)
	var at := h.pos
	var before := {"anim": k.anim_at, "cast": h.cast_at, "swing": h.swing_n, "foe": foe.hp,
		"casts": flow.cast_n.duplicate(), "used": h.used.duplicate(), "deny": PressDeny.raised}
	PressDeny.last.clear()
	var posed := false
	_press(h, slot)
	for i in int(WATCH_S / Match.DT):
		m.step(Match.DT)
		h.inp["sec_hold"] = slot == "rmb_hold"
		posed = posed or k.rmb_down or h.roll_t > 0.0 or h.mel_hold > 0.15 or k.dash_left() > 0.0
	h.inp["sec_hold"] = false
	m.step(Match.DT)
	var drift := Vector2(h.pos.x - at.x, h.pos.z - at.z).length()
	if slot == "none":
		still = drift
		return
	var what := "%s %s on cooldown:" % [hero, slot]
	var still_body := k.anim_at == float(before["anim"]) and h.cast_at == float(before["cast"]) \
			and h.swing_n == int(before["swing"]) and not posed
	ok(still_body, "%s no move or pose (anim %s)" % [what, k.anim_id])
	ok(foe.hp >= float(before["foe"]) - 0.01, "%s no damage (foe %.0f -> %.0f)" % [what, float(before["foe"]), foe.hp])
	ok(absf(drift - still) <= MOVED_MAX, "%s no displacement (%.2f m, %.2f with no press)" % [what, drift, still])
	ok(flow.cast_n == before["casts"] and h.used == before["used"], "%s nothing cast or spent" % what)
	var fx: Dictionary = m.hud.slot_fx.get(BAR_ID[slot], {}) if m.hud else {}
	ok(PressDeny.raised > int(before["deny"]) and bool(fx.get("cooling", false)),
		"%s the bar shakes its slot with \"On cooldown\" (%s)" % [what, fx])

## Puts `slot` ("none": the no-press control) on LEFT_S of cooldown with no charge left; the rest stay ready.
func _cool(h: Hunter, k: ArchKit, slot: String) -> void:
	match slot:
		"rmb_tap", "rmb_hold":
			k.ch_rmb = 0.0
			k.cd["rmb"] = LEFT_S
			if k.cd.has("air"): k.cd["air"] = LEFT_S
		"e": k.cd["e"] = LEFT_S
		"r": h.merge_cd = LEFT_S
		"x": k.cd["x"] = LEFT_S
		"dash":
			h.dashes = 0.0
			h.ex_cd = LEFT_S
		"q": h.gear_cd[0] = LEFT_S

## The slot's key goes down for one step (RMB's hold key too: the trial lets it go or keeps it held).
func _press(h: Hunter, slot: String) -> void:
	match slot:
		"rmb_tap", "rmb_hold":
			h.inp["sec"] = true
			h.inp["sec_hold"] = true
		"e": h.inp["sig"] = true
		"r": h.inp["ult"] = true
		"x": HunterKeys.ult_pressed(h)
		"dash": h.inp["dash"] = true
		"q": h.inp["gear1"] = true
