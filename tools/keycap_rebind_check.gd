extends RefCounted
## --keycap-rebind-check: every ability slot shows the key it is bound to, never a hard-coded letter
## (DECISIONS 2026-11-08 keybinds). Each slot's action (LMB, RMB, E, R, Q, V, Shift, the Boki key, the belt's 1 to 4) is
## moved to a new key, to mouse 4 and mouse 5, and to an alternate (first slot cleared, a second key set), one
## at a time. After each move the surfaces that name the slot's key are read and must show the new cap:
##   the ability bar's key pill (HudSlot.shown_keys) · the slot's tooltip · the recast call-outs ("<KEY> AGAIN":
##   the cue drawn on the slot, the one-time hint line, the practice drill's call-out) · the tutorial's key cap
##   and its %-tokens · the Hunter how-to lines.
## The old default's cap must be gone from every one of them. Last, an old settings dictionary with custom
## bindings goes through KeyMigrate and keeps them. Run with a temporary XDG_DATA_HOME: it rebinds keys.

## [action, bar slot id (shown_keys and tooltip id; "" none), recast slot (RecastCue.KEYS; "" none)]
const SLOTS := [
	["fire", "", "lmb"],
	["secondary", "sec", "sec"],
	["signature", "k1", "e"],
	["hunter_ult", "x", "x"],
	["gear1", "gear0", ""],
	["gear2", "gear1", ""],
	["dash", "dash", "dash"],
	["throw", "throw", ""],
	["util1", "util1", ""],
	["util2", "util2", ""],
	["util3", "util3", ""],
	["util4", "util4", ""],
]
## Keys no default binding uses, one per slot and variant.
const NEW_KEYS := [
	KEY_F13, KEY_F14, KEY_F15, KEY_F16, KEY_F17, KEY_F18, KEY_F19, KEY_F20, KEY_F21, KEY_F22, KEY_F23, KEY_F24
]
const ALT_KEYS := [
	KEY_KP_1,
	KEY_KP_2,
	KEY_KP_3,
	KEY_KP_4,
	KEY_KP_5,
	KEY_KP_6,
	KEY_KP_7,
	KEY_KP_8,
	KEY_KP_9,
	KEY_HOME,
	KEY_END,
	KEY_INSERT
]
const MOUSE_VARIANTS := {"M4": MOUSE_BUTTON_XBUTTON1, "M5": MOUSE_BUTTON_XBUTTON2}
const RECAST_RECT := Rect2(10, 10, 52, 52)


## A stand-in canvas: records every text a cue draws.
class StubHud:
	extends Node
	var c := Control.new()
	var big: Font = ThemeDB.fallback_font
	var texts: Array[String] = []

	func _arc(at: Vector2, rad: float, frac: float, col: Color, w: float) -> void:
		c.draw_arc(at, rad, 0.0, TAU * frac, 24, col, w, true)

	func _ctext(_at: Vector2, text: String, _size: int, _col: Color, _font: Font) -> void:
		texts.append(text)


var bad := 0
var main: Node
var m: Match
var p: Hunter
var checks := 0
var tut: Tutorial


func ok(cond: bool, what: String) -> void:
	checks += 1
	print("KEYCAP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.reset_all()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 12,
			"no_drop": true,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief"),
			"demo_kin": "cindle"
		}
	)
	m.set_process(false)
	p = m.player
	p.ctrl = "local"
	for o in m.hunters:
		if o != p:
			o.ctrl = "idle"
			o.teleport(p.pos + Vector3(40, 0, 40))
	_equip()
	ok(p.kin != null, "the player has a Boki out (the Boki key's slot is drawn)")
	var tm := Match.new()
	main.add_child(tm)
	tm.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	tm.set_process(false)
	tut = tm.tut
	for s in SLOTS:
		await _slot(s)
	tm.free()
	m.free()
	_migration()
	Settings.reset_all()
	print("KEYCAP CHECK DONE, %d checks, failures: %d" % [checks, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## The slots' contents: a hunter with every ability open, four belt items, two active gloves, the ultimate level.
func _equip() -> void:
	p.reclass(Arch.weight("juggernaut"), "juggernaut", Arch.signature("juggernaut"))
	p.unlock_all()
	p.lvl = int(Hunter.ULT_AT[0])
	p.grounded = true
	p.dashes = p.max_dashes()
	var belt_ids: Array = ["tonic", "armor_kit"]
	for id in UtilityBelt.ALL:
		if not belt_ids.has(id) and not BeltKeys.is_key(String(id)) and belt_ids.size() < 4:
			belt_ids.append(id)
	for i in 4:
		UtilityBelt.set_slot(p, i, String(belt_ids[i]), 2)
	var active: Array = Gear.ALL.keys().filter(func(g): return Gear.active(String(g)))
	for i in 2:
		p.gear[i] = {"id": active[i], "rar": 1}
		p.gear_cd[i] = 0.0


func _slot(s: Array) -> void:
	var action: String = s[0]
	var idx := SLOTS.find(s)
	var default: Array = Settings.slots(action)
	var old_cap := Settings.key_cap(action)
	var variants := {}
	var nk := InputEventKey.new()
	nk.physical_keycode = NEW_KEYS[idx]
	variants["key"] = [nk, nk, Settings.cap_text("key:%d" % NEW_KEYS[idx])]
	for cap in MOUSE_VARIANTS:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_VARIANTS[cap]
		variants[cap] = [mb, mb, cap]
	var ak := InputEventKey.new()
	ak.physical_keycode = ALT_KEYS[idx]
	variants["alt"] = [null, ak, Settings.cap_text("key:%d" % ALT_KEYS[idx])]
	for v in variants:
		var pair: Array = variants[v]
		if pair[0] == null:
			Settings.clear_bind(action, 0)
		else:
			Settings.rebind(action, pair[0], 0)
		Settings.rebind(action, pair[1], 1 if pair[0] == null else 0)
		var want: String = pair[2]
		ok(
			Settings.key_cap(action) == want,
			"%s -> %s (%s): key_cap says '%s'" % [action, v, want, Settings.key_cap(action)]
		)
		await _surfaces(s, want, "%s as %s" % [action, v])
	# a primary and an alternate together: the primary is the one every surface shows
	Settings.rebind(action, nk, 0)
	Settings.rebind(action, ak, 1)
	await _surfaces(s, variants["key"][2], "%s with an alternate" % action)
	# restore the shipped binding
	Settings.clear_bind(action, 0)
	Settings.clear_bind(action, 1)
	for i in 2:
		if default[i] != "":
			var ev := _event(String(default[i]))
			Settings.rebind(action, ev, i)
	ok(Settings.key_cap(action) == old_cap, "%s: back to '%s' (got '%s')" % [action, old_cap, Settings.key_cap(action)])


func _event(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	var mb := InputEventMouseButton.new()
	mb.button_index = int(parts[1]) as MouseButton
	return mb


## True when `cap` stands in `text` as a whole word (F13 is not F1).
func _has(text: String, cap: String) -> bool:
	return RegEx.create_from_string("(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % cap.replace("-", "\\-")).search(text) != null


func _surfaces(s: Array, want: String, tag: String) -> void:
	var action: String = s[0]
	var id: String = s[1]
	var recast: String = s[2]
	if id != "":
		HudSlot.shown_keys.clear()
		await _drawn()
		await _drawn()
		ok(
			HudSlot.shown_keys.get(id, "") == want,
			"%s: the bar shows '%s' on slot %s" % [tag, HudSlot.shown_keys.get(id, ""), id]
		)
		var tip := _tip(id)
		ok(_has(tip, want), "%s: the %s tooltip names '%s' (%s)" % [tag, id, want, tip.left(70)])
	if recast != "":
		await _recast(recast, want, tag)
	if action == "fire" or action in ["secondary", "signature", "hunter_ult", "dash"]:
		var lines := " ".join(ClassCard.howto_lines("juggernaut")) + " ".join(ClassCard.howto_lines("thief"))
		ok(not lines.contains("{"), "%s: how-to lines leave no {token} behind" % tag)
	_drill(action, want, tag)
	_tutorial(action, want, tag)


func _drawn() -> void:
	await m.hud.panels.draw
	await main.get_tree().process_frame


func _tip(id: String) -> String:
	var texts: Array = []
	for line in m.hud.hover.tip_lines(id, p):
		texts.append(String(line[0]))
	return " | ".join(texts)


## "<KEY> AGAIN": the cue the HUD draws on the slot, the first-time hint line, the key of the call-out.
func _recast(slot_v: String, want: String, tag: String) -> void:
	ok(
		RecastCue.key_of(slot_v) == want,
		"%s: the recast key of slot %s is '%s'" % [tag, slot_v, RecastCue.key_of(slot_v)]
	)
	var line := RecastHint.line(p.ak, slot_v)
	ok(line.begins_with("%s AGAIN" % want), "%s: the recast hint reads '%s'" % [tag, line])
	if slot_v == "sec":
		return  # (the RMB recast has no cue on the slot: it is the hint line)
	var hud := StubHud.new()
	main.add_child(hud)
	hud.add_child(hud.c)
	p.ak.cue["w"] = RecastCue.window(slot_v, 2.0, 3.0, Vector3.ZERO)
	hud.c.draw.connect(func(): RecastCue.slot(hud, p, slot_v, RECAST_RECT))
	hud.c.queue_redraw()
	for i in 3:
		await main.get_tree().process_frame
	ok(hud.texts.has("%s AGAIN" % want), "%s: the cue on slot %s says %s" % [tag, slot_v, hud.texts])
	p.ak.cue["w"] = {}
	hud.queue_free()


## The practice drill's step for the slot: its key and its "AGAIN" / "HOLD" call-out.
func _drill(action: String, want: String, tag: String) -> void:
	for st in KitDrill.steps(p.arch):
		if st["action"] != action:
			continue
		ok(st["key"] == want, "%s: the drill step %s shows '%s'" % [tag, st["slot"], st["key"]])
		var call := KitDrill.callout({"how": "again", "key": st["key"]}, 1)
		ok(call == "%s AGAIN" % want, "%s: the drill call-out reads '%s'" % [tag, call])


## The tutorial's key cap for each step on this action, and its %-token lines.
func _tutorial(action: String, want: String, tag: String) -> void:
	for i in Tutorial.steps().size():
		tut.step = i
		var sid: String = Tutorial.steps()[i][0]
		if Tutorial.KEYS.get(sid, "") != action:
			continue
		tut._words()
		ok(tut.key_cap == want, "%s: tutorial step %s cap is '%s'" % [tag, sid, tut.key_cap])


## An old save's custom bindings survive KeyMigrate (and its default moves still happen).
func _migration() -> void:
	var old := {"keys": {"signature": ["key:%d" % KEY_F13], "fire": ["mouse:8"], "util1": ["key:%d" % KEY_F14, ""]}}
	for k in ["keys2_v", "keys3_v", "keys4_v", "keys5_v", "keys6_v", "keys7_v"]:
		old[k] = 0
	KeyMigrate.run(old)
	var ks: Dictionary = old["keys"]
	ok(
		ks["signature"] == ["key:%d" % KEY_F13] and ks["fire"] == ["mouse:8"] and ks["util1"][0] == "key:%d" % KEY_F14,
		"migration: custom signature, fire and util1 bindings kept (%s)" % str(ks)
	)
	var again := old.duplicate(true)
	KeyMigrate.run(again)
	ok(again == old, "migration: a second run changes nothing")
