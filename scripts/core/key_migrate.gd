class_name KeyMigrate
extends RefCounted
## Moves saved key bindings to the current default kit. Runs on the settings dictionary, once per step (versions
## keys2_v, keys3_v). Genuine custom bindings are kept; only the old defaults move.
##   step 1  "Separate from the drop" leaves X for Z.
##   step 2  Merge was R and X: it is T now. R reloads and X is the hunter's ultimate, unless the player had put
##           R or X on something else (then that action keeps it and the new action starts unbound). The Emote wheel
##           moved from T to Y, and Merge/Emote start unbound the same way if T/Y is already someone's custom key.

static func _code(k: int) -> String:
	return "key:%d" % k

static func _used_elsewhere(ks: Dictionary, code: String, skip: Array) -> bool:
	for a in ks:
		if not skip.has(a) and (ks[a] as Array).has(code):
			return true
	return false

## The saved Merge binding after the move: erased when it was the old default (R and/or X), else the custom keys kept.
static func _merge_binding(ks: Dictionary) -> void:
	if not ks.has("ultimate"):
		return
	var old: Array = ks["ultimate"]
	if old.is_empty():
		return          # unbound on purpose
	var kept: Array = old.filter(func(c): return c != "" and c != _code(KEY_R) and c != _code(KEY_X))
	if kept.is_empty():
		ks.erase("ultimate")
	else:
		ks["ultimate"] = kept

## Brings `s` (the settings dictionary: keys, keys2_v, keys3_v) up to date.
static func run(s: Dictionary) -> void:
	var ks: Dictionary = s["keys"]
	if int(s.get("keys2_v", 0)) < 1:
		if ks.has("separate") and (ks["separate"] as Array).has(_code(KEY_X)):
			ks["separate"] = [_code(KEY_Z)]
		s["keys2_v"] = 1
	if int(s.get("keys3_v", 0)) >= 1:
		return
	_merge_binding(ks)
	var skip := ["ultimate", "rotate"]
	if not ks.has("reload") and _used_elsewhere(ks, _code(KEY_R), skip):
		ks["reload"] = []
	if not ks.has("hunter_ult") and _used_elsewhere(ks, _code(KEY_X), skip):
		ks["hunter_ult"] = []
	_emote_and_merge_keys(ks)
	s["keys3_v"] = 1

## Emote moved T -> Y and Merge took T: a default that lands on a key another saved action uses starts unbound.
static func _emote_and_merge_keys(ks: Dictionary) -> void:
	if ks.get("emote", []) == [_code(KEY_T)]:
		ks.erase("emote")          # the old default, saved: it moves to the new one
	var merge_keys: Array = ks.get("ultimate", [_code(KEY_T)])
	if not ks.has("emote") and (merge_keys.has(_code(KEY_Y)) or _used_elsewhere(ks, _code(KEY_Y), ["emote"])):
		ks["emote"] = []
	if not ks.has("ultimate") and _used_elsewhere(ks, _code(KEY_T), ["ultimate", "talk", "emote"]):
		ks["ultimate"] = []
