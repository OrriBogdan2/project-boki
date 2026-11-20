extends RefCounted
## --key-caps-check: every place a key is drawn follows a rebind (DECISIONS 2026-11-08). Each action is
## moved to a mouse button (Mouse 4, Mouse 5, the wheel, the middle button), then a second key is added
## as an alternate; the new cap must read right in Settings and on the kit card, the recast badge, the
## class tooltip and the Fusion form text, and the old default letter must be gone from them.
## Run with a temporary XDG_DATA_HOME: it rebinds keys (Settings writes its config file).

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KEYCAPS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _mouse(btn: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = true
	return e

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e

func run(main: Node) -> void:
	var S = Settings
	S.reset_all()
	_caps(S)
	_surfaces(S)
	S.reset_all()
	print("KEYCAPS DONE, failures: %d" % bad)
	main.get_tree().quit()

## cap_text, key_cap and key_caps: mouse buttons and alternates read as one short, space-free cap.
func _caps(S) -> void:
	var want := {MOUSE_BUTTON_XBUTTON1: "M4", MOUSE_BUTTON_XBUTTON2: "M5", MOUSE_BUTTON_WHEEL_UP: "WHEEL-UP",
		MOUSE_BUTTON_WHEEL_DOWN: "WHEEL-DN", MOUSE_BUTTON_MIDDLE: "MMB", MOUSE_BUTTON_LEFT: "LMB",
		MOUSE_BUTTON_RIGHT: "RMB"}
	for btn in want:
		S.rebind("interact", _mouse(btn), 0)
		var cap: String = S.key_cap("interact")
		ok(cap == want[btn], "mouse button %d draws as %s (%s)" % [btn, want[btn], cap])
	S.rebind("interact", _mouse(MOUSE_BUTTON_XBUTTON1), 0)
	S.rebind("interact", _key(KEY_KP_1), 1)
	ok(S.key_caps("interact") == "M4 / KP1", "an alternate shows beside the main cap (%s)" % S.key_caps("interact"))
	S.clear_bind("interact", 0)
	ok(S.key_cap("interact") == "KP1", "main key cleared: the alternate is the cap shown (%s)" % S.key_cap("interact"))
	S.clear_bind("interact", 1)
	ok(S.key_cap("interact") == "?" and S.key_caps("interact") == "?", "nothing bound reads ?")
	S.reset_all()

## Rebind each ability action to a mouse button, then look at the surfaces that draw it.
func _surfaces(S) -> void:
	var btn := {"dash": MOUSE_BUTTON_XBUTTON1, "fire": MOUSE_BUTTON_XBUTTON2, "secondary": MOUSE_BUTTON_MIDDLE,
		"signature": MOUSE_BUTTON_WHEEL_UP, "ultimate": MOUSE_BUTTON_WHEEL_DOWN, "hunter_ult": MOUSE_BUTTON_XBUTTON1}
	var gone := {"dash": "SHIFT", "fire": "LMB", "secondary": "RMB", "signature": "E", "ultimate": "X",
		"hunter_ult": "R"}
	for a in btn:
		S.rebind(a, _mouse(btn[a]), 0)
	var tile := {"dash": "dash", "lmb": "fire", "rmb": "secondary", "e": "signature", "r": "ultimate",
		"x": "hunter_ult"}
	for slot in tile:
		var cap: String = KitCard._cap(slot)
		ok(cap == S.key_cap(tile[slot]) and cap != "", "kit card %s tile reads %s" % [slot, cap])
	ok(KitCard._cap("passive") == "", "the passive tile has no cap")
	var rc := {"e": "signature", "x": "hunter_ult", "dash": "dash", "lmb": "fire", "sec": "secondary"}
	for slot in rc:
		var cap: String = RecastCue.key_of(slot)
		ok(cap == S.key_cap(rc[slot]), "recast badge %s reads %s" % [slot, cap])
	var tip: String = ClassCard.kit_tip(Arch.ids()[0])
	for a in ["secondary", "signature", "ultimate"]:
		ok(tip.contains("%s: " % S.key_cap(a)), "class tooltip names %s (%s)" % [S.key_cap(a), a])
	ok(not tip.contains("RMB:") and not tip.contains(" E: "), "class tooltip lost the default letters")
	var forms := 0
	for ms_id in ["titan", "stormwing", "tidal_shell"]:
		var ms: MergeSpec = KinLib.merge(ms_id)
		if ms == null or Content.merge_form(ms.id).is_empty(): continue
		forms += 1
		var text := "\n".join(PackedStringArray(KinText.merge(ms)))
		for a in ["fire", "secondary", "signature", "dash"]:
			ok(text.contains("%s, " % S.key_cap(a)), "%s Fusion form text shows %s" % [ms_id, S.key_cap(a)])
		ok(text.contains(S.key_cap("ultimate") + " again"), "%s Fusion form text shows the Fuse key" % ms_id)
		var old := ["Left click,", "Right click,", "\nE, ", "Shift,"]
		ok(not old.any(func(t): return text.contains(t)), "%s form text lost the default names" % ms_id)
	ok(forms > 0, "a Fusion form was checked")
	for a in gone:
		ok(S.key_cap(a) != gone[a], "%s no longer draws %s" % [a, gone[a]])
