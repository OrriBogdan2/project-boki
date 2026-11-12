extends RefCounted
## --card-numbers-check: every number a Hunter's kit card states (the one line and the detail page of
## each ability, as KitCard.slot_text builds them from content/archetypes/<hero>.json) matches a field
## of that hero's data. A number with a unit (s, m, %, damage, push, stun...) must be a field, a
## percent of one (0.35 for 35%, 1.25 for +25%) or a field rounded to the decimals written
## (0.65 for 0.648; after "about" an integer too); "A -> B" must be a field pair. _derived lists the
## few numbers a card works out from fields (a product) or a code constant.
## Pure data, no match. Prints CARDNUM FAIL lines and "CARDNUM DONE, ... failures: N".

const UNIT_NUM := "(?:(?:push|stun|root|damage|spends) )?(\\d+(?:\\.\\d+)?)(?:s|m|%| damage| seconds)?\\b"
const NUM_ROW_SKIP := ["Ranks", "Bond"]    # ranks are their own rows of text; the Bond line is generic

var bad := 0
var _num := RegEx.new()
var _pair := RegEx.new()

func _collect(v: Variant, nums: Array, pairs: Array) -> void:
	if v is Dictionary:
		for x in (v as Dictionary).values(): _collect(x, nums, pairs)
	elif v is Array:
		var a := v as Array
		if a.size() == 2 and (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			pairs.append([float(a[0]), float(a[1])])
		for x in a: _collect(x, nums, pairs)
	elif v is float or v is int:
		nums.append(float(v))

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
			return {"about_pairs": [[float(pin["dmg"][0]) * w, float(pin["dmg"][1]) * w]]}
		"ashwick":      # Char 31 needs 8 ticks of x.char
			return {"nums": [ceilf(31.0 / float(x["char"])) * float(x["tick"])]}
		"bulwark":      # the dash's time over its distance; the lane is cells x cell_len
			var lane := float(x["cells"]) * float(x["cell_len"])
			return {"nums": [float(dash["whirl"]) / float(dash["whirl_speed"]), lane]}
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
func _is_pair(pr: Array, pairs: Array, tol: float) -> bool:
	for p in pairs:
		if _close(pr[0], p[0], tol) and _close(pr[1], p[1], tol):
			return true
	return false

func _is_field(v: float, nums: Array, written: String, about: bool) -> bool:
	var tol := 0.5 * pow(10.0, -float(written.length() - written.find(".") - 1)) if written.contains(".") else 0.5
	for n in nums:
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
	var checked := 0
	for a in Arch.ids():
		var d := Arch.def(a)
		var nums: Array = []
		var pairs: Array = []
		_collect(_data_only(d), nums, pairs)
		for w in Arch.weapons(a):
			_collect(Data.weapon_stats(w), nums, pairs)
		var dv := _derived(a, d)
		nums.append_array(dv.get("nums", []))
		for t: String in _texts(a):
			for m in _pair.search_all(t):
				var pr := [float(m.get_string(1)), float(m.get_string(2))]
				_report(a, m.get_string(), _is_pair(pr, pairs, 1e-4) or _is_pair(pr, dv.get("about_pairs", []), 1.0), t)
			for m in _num.search_all(t):
				if m.get_string() == m.get_string(1) or _in_pair(t, m):
					continue
				var about := t.substr(maxi(0, m.get_start() - 6), 6) == "about "
				_report(a, m.get_string(), _is_field(float(m.get_string(1)), nums, m.get_string(1), about), t)
				checked += 1
	print("CARDNUM DONE, numbers checked: %d, failures: %d" % [checked, bad])
	host.get_tree().quit(1 if bad > 0 or checked == 0 else 0)

## The match sits next to an " -> " (a pair checks as a whole).
func _in_pair(t: String, m: RegExMatch) -> bool:
	return t.substr(m.get_end(), 4) == " -> " or t.substr(maxi(0, m.get_start() - 4), 4) == " -> "

func _data_only(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	for k in ["card", "rank2", "rank3", "rank_next"]:
		out.erase(k)
	return out

func _report(a: String, what: String, good: bool, text: String) -> void:
	if not good:
		bad += 1
		print("CARDNUM FAIL %s: '%s' is no field of the data: ...%s" % [a, what, text.substr(0, 90)])
