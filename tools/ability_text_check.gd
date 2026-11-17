extends RefCounted
## --ability-text-check: every slot of the 12 kits says the same name and the same numbers wherever it is
## shown (AbilityText is the one reader): the kit card and its strip, the viewer, the HUD slot and its
## tooltip, the E hint. Keys come from the player's bindings (rebound here to prove it) and no ability
## text carries a key letter; every {slot.field} number token points at a real number in the same JSON.
## Prints ABTEXT ok/FAIL, never touches the save.

var bad := 0
var main: Node
const KEY_WORD := "\\b(LMB|RMB|MMB|Shift|Space|Ctrl)\\b|\\b[EQRFXCVZ]\\b"      # a key named in words, in a text
const NUMBER := "\\d+(?:\\.\\d+)?"
## Where the slots sit in the HUD (Hunter.slot_info) and in the card.
const HUD_SLOT := {"dash": "dash", "rmb": "sec", "e": "k1", "x": "x", "r": "r"}
const REBOUND := {"dash": KEY_J, "secondary": KEY_K, "signature": KEY_L, "fire": KEY_N,
		"hunter_ult": KEY_M, "ultimate": KEY_B}

func ok(cond: bool, what: String) -> void:
	print("ABTEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _numbers(t: String) -> Array:
	var re := RegEx.create_from_string(NUMBER)
	return re.search_all(t).map(func(m): return float(m.get_string()))

## Every string in an archetype's ability JSON (the personality is story, not ability text).
func _texts(o: Variant, out: Array) -> Array:
	if o is Dictionary:
		for k in o:
			if k != "personality":
				_texts(o[k], out)
	elif o is Array:
		for v in o:
			_texts(v, out)
	elif o is String:
		out.append(o)
	return out

func _leaves(o: Variant, out: Array) -> Array:
	if o is Dictionary:
		for k in o:
			_leaves(o[k], out)
	elif o is Array:
		for v in o:
			_leaves(v, out)
	elif o is float or o is int:
		out.append(float(o))
	return out

func _rebind() -> Dictionary:
	var saved := {}
	for a in REBOUND:
		saved[a] = InputMap.action_get_events(a)
		InputMap.action_erase_events(a)
		var e := InputEventKey.new()
		e.physical_keycode = REBOUND[a]
		InputMap.action_add_event(a, e)
	return saved

func _restore(saved: Dictionary) -> void:
	for a in saved:
		InputMap.action_erase_events(a)
		for e in saved[a]:
			InputMap.action_add_event(a, e)

## The data and its tokens: no key letter in a text, every token resolves, every one-line text keeps to
## the numbers its slot's full text and JSON give.
func _data(a: String) -> void:
	var d := Arch.def(a)
	var word := RegEx.create_from_string(KEY_WORD)
	var tok := RegEx.create_from_string("\\{([^}]+)\\}")
	var keyed := 0
	var lone := ""
	for t in _texts(d, []):
		var s := String(t)
		for m in tok.search_all(s):
			var p := m.get_string(1)
			if p.begins_with("key:"):
				keyed += 1
				if not InputMap.has_action(p.substr(4)):
					lone += " {%s}" % p
			else:
				var v: Variant = d
				for part in p.split("."):
					v = v.get(part) if v is Dictionary else null
				if not (v is float or v is int):
					lone += " {%s}" % p
		var bare := tok.sub(s, "", true)
		if word.search(bare) != null and not bare.begins_with("Rank"):
			lone += " '%s'" % word.search(bare).get_string()
	ok(lone == "", "%s: key words and number tokens in the data are only tokens%s" % [a, lone])
	for slot in ["dash", "rmb", "e", "x", "r"]:
		if not d.has(slot):
			continue
		var sd: Dictionary = d[slot]
		var allowed := _numbers(AbilityText.full(a, slot))
		allowed.append_array(_leaves(sd, []))
		allowed.append_array(_leaves(d.get("resource", {}), []))
		allowed.append(float(Hunter.ULT_AT[0]))
		var stray: Array = _numbers(AbilityText.line(a, slot)).filter(func(n): return not n in allowed)
		ok(stray.is_empty(), "%s %s: the one line's numbers are in the full text or the JSON %s" % [a, slot, stray])

func _rendered(a: String) -> void:
	var saved := _rebind()
	var all := ""
	for slot in ["passive", "lmb", "dash", "rmb", "e", "x", "r"]:
		if slot in ["x", "r"] and not Arch.def(a).has(slot):
			continue
		all += AbilityText.line(a, slot) + "\n" + AbilityText.full(a, slot) + "\n"
		all += "\n".join(KitCard.slot_text(a, slot)["detail"].map(func(r): return String(r[1]))) + "\n"
	all += AbilityText.loop(a)
	_restore(saved)
	var word := RegEx.create_from_string(KEY_WORD)
	ok(not all.contains("{") and not all.contains("}"), "%s: no token is left unfilled" % a)
	var hit := word.search(all)
	var left := "" if hit == null else " ('%s')" % hit.get_string()
	ok(hit == null, "%s: rebound to J K L N M B, no key letter is left in any ability text%s" % [a, left])

## The card, the viewer, the HUD slot and tooltip and the E hint against the helper, with the real HUD.
func _contexts(m: Match, a: String) -> void:
	var P: Hunter = m.player
	P.reclass(Arch.weight(a), a, Arch.signature(a))
	P.unlock_all()
	P.lvl = 6
	for slot in ["dash", "rmb", "e", "x", "r"]:
		if not Arch.def(a).has(slot):
			continue
		var card := KitCard.slot_text(a, slot)
		var hud := P.slot_info(HUD_SLOT[slot])
		var tag := "%s %s" % [a, slot]
		var nm := AbilityText.name_of(a, slot)
		var same: bool = nm != "" and nm == hud["name"] and nm == HunterViewer.slot_info(a, slot)["name"]
		ok(same and (nm == card["name"] or slot == "r"), "%s: one name '%s' on card, viewer and HUD slot" % [tag, nm])
		var short_ok: bool = hud["short"] == AbilityText.short_name(a, slot)
		short_ok = short_ok and (slot == "r" or card["short"] == hud["short"])
		ok(short_ok, "%s: one short name '%s'" % [tag, hud["short"]])
		if slot != "r":
			var from_helper: bool = card["line"] == AbilityText.line(a, slot)
			from_helper = from_helper and hud["desc"] == AbilityText.full(a, slot)
			ok(from_helper, "%s: the card line and the HUD description come from the helper" % tag)
		if slot != "x":
			var tip: Array = m.hud._arch_tip(HUD_SLOT[slot], P)
			var tip_text := "\n".join(tip.map(func(l): return String(l[0])))
			var tip_ok: bool = String(tip[0][0]) == nm and tip_text.contains(AbilityText.full(a, slot))
			ok(tip_ok, "%s: the HUD tooltip heads with the name and carries the full text" % tag)
	var hint := TutorialText.ability_tip(P)
	var hint_ok: bool = hint.contains(AbilityText.name_of(a, "e")) and hint.contains(AbilityText.line(a, "e").right(24))
	ok(hint_ok, "%s: the E hint is the helper's name and line" % a)
	var passive := KitCard.slot_text(a, "passive")
	var passive_ok: bool = passive["name"] == AbilityText.name_of(a, "passive")
	passive_ok = passive_ok and passive["detail"][0][1] == AbilityText.full(a, "passive")
	ok(passive_ok, "%s: the passive is the helper's too" % a)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	m.player.ctrl = "local"
	ok(Arch.ORDER.size() == 12, "twelve kits")
	for a in Arch.ORDER:
		_data(a)
		_rendered(a)
		_contexts(m, a)
	m.queue_free()
	print("ABILITY TEXT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
