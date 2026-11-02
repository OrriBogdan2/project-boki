class_name KeyMigrate
extends RefCounted
## Moves saved key bindings to the current default kit. Runs on the settings dictionary, once per step (versions
## keys2_v, keys3_v). Genuine custom bindings are kept; only the old defaults move.
##   step 1  "Separate from the drop" leaves X for Z.
##   step 2  Merge was R and X: it is T now. R reloads and X is the hunter's ultimate, unless the player had put
##           R or X on something else (then that action keeps it and the new action starts unbound).

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
	s["keys3_v"] = 1
