extends RefCounted
## --card-numbers-check: every number a Hunter's kit card states (the one line and the detail page of
## each ability, as KitCard.slot_text builds them from content/archetypes/<hero>.json) matches a field
## of that hero's data. A number with a unit (s, m, %, damage, push, stun...) must be a field, a
## percent of one (0.35 for 35%, 1.25 for +25%) or a field rounded to the decimals written
## (0.65 for 0.648; after "about" an integer too); "A -> B" must be a field pair. The field must be
## the one the number describes: each field has a kind from its key path (KINDS: push, stun, slow,
## damage, time, distance; else unknown) and a number written as "push N", "stuns N", "N damage",
## "slowed N%", "Ns" or "Nm" only matches a field of its kind or of unknown kind. _derived lists the
## few numbers a card works out from fields (a product) or a code constant.
## Pure data, no match. Prints CARDNUM FAIL lines and "CARDNUM DONE, ... failures: N".

const UNIT_NUM := ("(?:(push|stuns?|roots?|damage|spends|slowed|slows?) )?(?<![\\w.])"
	+ "(\\d+(?:\\.\\d+)?)(s|m|%| damage| seconds)?\\b")
## Field kind by key path, first match wins; a field of no kind matches any written number.
const KINDS := [["push", "push|kb|knock|shove|fling"], ["stun", "stun|daze"], ["slow", "slow"],
	["damage", "dmg|damage|dps"],
	["time", "(^|_|\\.)(cd|cooldown|t|time|dur|tick|every|delay|window|windup|hold|life|linger)(_|$|\\.)|_t($|\\.)"],
	["distance", "range|reach|radius|(^|_|\\.)(r|len|length|dist|width|w)(_|$|\\.)"]]
## Kinds a field must really be (a field of unknown kind does not pass for them).
const STRICT := ["push", "stun", "slow"]    # damage keys vary too much (char, per_stack...)
## What kinds a written word or unit accepts (besides unknown).
const WANT := {"push": ["push"], "stun": ["stun"], "root": ["time"], "damage": ["damage"],
	"slow": ["slow"], "s": ["time", "stun", "slow"], "m": ["distance"]}
const NUM_ROW_SKIP := ["Ranks", "Bond"]    # ranks are their own rows of text; the Bond line is generic

var bad := 0
var _num := RegEx.new()
var _pair := RegEx.new()
var _kinds: Array = []    # [kind, RegEx]

## nums and pairs hold [value, kind]; path is the key path down to the value.
func _collect(v: Variant, nums: Array, pairs: Array, path := "") -> void:
	if v is Dictionary:
		for k in (v as Dictionary): _collect(v[k], nums, pairs, ("%s.%s" % [path, k]).trim_prefix("."))
	elif v is Array:
		var a := v as Array
		if a.size() == 2 and (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			pairs.append([[float(a[0]), float(a[1])], _kind(path)])
		for x in a: _collect(x, nums, pairs, path)
	elif v is float or v is int:
		nums.append([float(v), _kind(path)])

func _kind(path: String) -> String:
	for k in _kinds:
		if (k[1] as RegEx).search(path.to_lower()): return k[0]
	return ""

## The kind a written number names: its word, else its unit ("" accepts any field).
func _want(word: String, unit: String) -> Array:
	for w in ["push", "stun", "root", "damage", "slow"]:
		if word.begins_with(w): return WANT[w]
	if unit == " damage": return WANT["damage"]
	if unit == "s" or unit == " seconds": return WANT["s"]
	if unit == "m": return WANT["m"]
	return []

func _fits(kind: String, want: Array) -> bool:
	return want.is_empty() or kind in want or (kind == "" and not want[0] in STRICT)

## Numbers the card works out from fields (a product, a quotient) or a code constant, per hero:
## extra numbers its card may state, and the pair of the pinned Heavy Shot.
func _derived(a: String, d: Dictionary) -> Dictionary:
	var dash: Dictionary = d.get("dash", {})
	var e: Dictionary = d.get("e", {})
	var x: Dictionary = d.get("x", {})
	var seed: Dictionary = d.get("rmb", {}).get("seed", {})
	var pin: Dictionary = d.get("rmb", {}).get("pin", {})
	match a:
		"archer":
			var w := float(pin["wall_mult"])
			return {"about_pairs": [[float(pin["dmg"][0]) * w, float(pin["dmg"][1]) * w]],
				"nums": [4.0]}    # PinSpirit.ORB_T, the spirit orb's time (a code constant)
		"ashwick":      # Char 31 needs 8 ticks of x.char
			return {"nums": [ceilf(31.0 / float(x["char"])) * float(x["tick"])]}
		"bulwark":      # the dash's time over its distance; the lane is cells x cell_len
			var lane := float(x["cells"]) * float(x["cell_len"])
			return {"nums": [float(dash["whirl"]) / float(dash["whirl_speed"]), lane]}
		"dolm":         # Stone Row: three rocks gap apart span twice the gap
			return {"nums": [float(e["gap"]) * 2.0]}
		"gunslinger":   # an air tap slides air_k of the slide; the beam is twice its half-width
			return {"nums": [float(dash["slide"]) * float(dash["air_k"]), float(e["width"]) * 2.0]}
		"mage":         # a returned run charges in reset_charge of the hold
			return {"nums": [float(dash["hold"]) * float(dash["reset_charge"])]}
		"tender":       # the rank 3 burst is r3_k times the radius
			return {"nums": [float(seed["burst_r"]) * float(seed["r3_k"])]}
		"rimewright":   # SHATTER_R in rimewright_kit.gd (a code constant, not data)
			return {"nums": [2.7]}
	return {}

func _close(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

## A written pair is a field pair (within tol: the card says 80 -> 148 for 79.04 -> 148.2).
func _is_pair(pr: Array, pairs: Array, tol: float, want: Array) -> bool:
	for e in pairs:
		var p: Array = e[0]
		if _close(pr[0], p[0], tol) and _close(pr[1], p[1], tol) and _fits(e[1], want):
			return true
	return false

func _is_field(v: float, nums: Array, written: String, about: bool, want: Array) -> bool:
	var tol := 0.5 * pow(10.0, -float(written.length() - written.find(".") - 1)) if written.contains(".") else 0.5
	for e in nums:
		if not _fits(e[1], want):
			continue
		var n: float = e[0]
		var as_percent := _close(v, n * 100.0, 1e-3) or _close(v, (n - 1.0) * 100.0, 1e-3)
		if _close(v, n, 1e-4) or as_percent or _close(v / 100.0, n, 1e-4):
			return true
		if (about or written.contains(".")) and _close(v, n, tol + 1e-4):
			return true
	return false


func _texts(a: String) -> Array:
	var out: Array = []
	for slot in KitCard.card_slots(a):
		var st := KitCard.slot_text(a, slot)
		out.append(String(st["line"]))
		for row in st["detail"]:
			if not String(row[0]) in NUM_ROW_SKIP:
				out.append(String(row[1]))
	return out

func run(host: Node) -> void:
	_num.compile(UNIT_NUM)
	_pair.compile("(\\d+(?:\\.\\d+)?) -> (\\d+(?:\\.\\d+)?)")
	for k in KINDS:
		var re := RegEx.new()
		re.compile(k[1])
		_kinds.append([k[0], re])
	var checked := 0
	for a in Arch.ids():
		var d := Arch.def(a)
		var dv := _derived(a, d)
		var about_pairs: Array = dv.get("about_pairs", []).map(func(p): return [p, ""])
		var nums: Array = []
		var pairs: Array = []
		_collect(_data_only(d), nums, pairs)
		for w in Arch.weapons(a):
			_collect(Data.weapon_stats(w), nums, pairs)
		for v in dv.get("nums", []): nums.append([v, ""])
		for t: String in _texts(a):
			for m in _pair.search_all(t):
				var pr := [float(m.get_string(1)), float(m.get_string(2))]
				var want := _pair_want(t, m)
				var ok := _is_pair(pr, pairs, 1e-4, want) or _is_pair(pr, about_pairs, 1.0, want)
				_report(a, m.get_string(), ok, t, m.get_start())
			for m in _num.search_all(t):
				if m.get_string() == m.get_string(2) or _in_pair(t, m):
					continue
				var about := t.substr(maxi(0, m.get_start() - 6), 6) == "about "
				var want := _want(m.get_string(1), m.get_string(3))
				var ok := _is_field(float(m.get_string(2)), nums, m.get_string(2), about, want)
				_report(a, m.get_string(), ok, t, m.get_start())
				checked += 1
	print("CARDNUM DONE, numbers checked: %d, failures: %d" % [checked, bad])
	host.get_tree().quit(1 if bad > 0 or checked == 0 else 0)

## A pair's kind: the word just before it ("push 8 -> 12", "stuns 1 -> 2") or " damage" after it.
func _pair_want(t: String, m: RegExMatch) -> Array:
	var head := t.substr(0, m.get_start()).strip_edges()
	var w := head.get_slice(" ", head.get_slice_count(" ") - 1)
	var unit := " damage" if t.substr(m.get_end(), 7) == " damage" else t.substr(m.get_end(), 1)
	return _want(w, unit if unit in [" damage", "s", "m"] else "")

## The match sits next to an " -> " (a pair checks as a whole).
func _in_pair(t: String, m: RegExMatch) -> bool:
	return t.substr(m.get_end(), 4) == " -> " or t.substr(maxi(0, m.get_start() - 4), 4) == " -> "

func _data_only(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	for k in ["card", "rank2", "rank3", "rank_next"]:
		out.erase(k)
	return out

func _report(a: String, what: String, good: bool, text: String, at: int) -> void:
	if not good:
		bad += 1
		var near := text.substr(maxi(0, at - 60), 110)
		print("CARDNUM FAIL %s: '%s' is no field of its kind in the data: ...%s..." % [a, what, near])
