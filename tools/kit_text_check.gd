extends RefCounted
## --kit-text-check: the hand-written ability text in content/archetypes/<id>.json (desc, card,
## clip.lines, variants and the rank texts) must state the numbers its slot's data fields hold.
## For every slot (lmb, rmb, e, x, dash, passive) the numbers with a unit are pulled out of the
## text and sorted by what they claim: cooldown (s near "cooldown"/"recharge"), duration (other s),
## range (m), damage ("N damage", "N every"), slow (% near "slow"), charges, multipliers ("3.5
## times") and push. A stated number must be within 5% of a data field of the same kind (or of a
## rank or multiplier derived from one). A cooldown or push with no match is a mismatch; any other
## number is one only when a same-kind field lies within 15% of it (a drifted figure). Numbers
## with no field to compare with (values that live in code, such as a cast time) are listed as
## unmatched with --kit-text-verbose, never guessed. Rank texts "A -> B" check A only.
## Data wins over text: fix the text. Prints KITTEXT lines and quits non-zero on a mismatch.

const TOL := 0.05      # relative tolerance between a stated number and its data field
const STRICT := ["cooldown", "push"]      # kinds where any miss against a same-kind field is a mismatch
const NEAR := 0.15      # other kinds: a miss is a drift (not unmatched) when a field is this close
const SLOTS := ["lmb", "rmb", "e", "x", "dash", "passive"]
const RANK_KEYS := {"sec": "rmb", "kin": "e", "dash": "dash"}
const NUM := "(\\d+(?:\\.\\d+)?)"
const KEYS := {
	"cooldown": "^(cooldown|cd|recharge|rank_cut)",
	"range": "(^|_)(range|reach|radius|dist|rmin|rmax|width|wall|gap|len|core)$|_(r|w)$",
	"duration": "(^|_)(t|time|tell|window|every|tick|delay|linger|stun|hold|full|nock|recover|duration|rate"
		+ "|wind|windup|rise|grounded|drag_max|fuse|dur|grow|root|daze|recast)$|_(t|time|for)$",
	"damage": "(^|_)(dmg|dps|damage)(_|$)",
	"slow": "(^|_)slow(?!_(for|t|after))",
	"charges": "charges$",
	"mult": "mult|_k$",
	"push": "(^|_)push$",
}

var main: Node
var re_num := RegEx.new()
var mismatches := 0
var unmatched := 0
var checked := 0

func run(main_node: Node) -> void:
	main = main_node
	var units := "%|m\\b|s\\b|x\\b|\\s+(?:damage|dmg|charges?|every|times)\\b"
	re_num.compile(NUM + "(?:\\s*(?:->|-|to)\\s*" + NUM + ")?(" + units + ")?")
	var verbose := "--kit-text-verbose" in OS.get_cmdline_user_args()
	for f in DirAccess.get_files_at("res://content/archetypes"):
		if not String(f).ends_with(".json"): continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/" + f))
		var fixed := mismatches
		for slot in SLOTS:
			_check_slot(String(d.get("id", f)), d, slot, verbose)
		print("KITTEXT %-12s %d mismatches" % [d.get("id", f), mismatches - fixed])
	var verdict := "FAIL" if mismatches > 0 else "PASS"
	print("KITTEXT %d checked, %d unmatched (no data), %d mismatches: %s" % [checked, unmatched, mismatches, verdict])
	main.get_tree().quit(1 if mismatches > 0 else 0)

## Every text of a slot as [where, text]: card, clip.lines, desc, variants.
func _texts(d: Dictionary, slot: String) -> Array:
	var out: Array = []
	var card: Dictionary = d.get("card", {})
	if card.has(slot): out.append(["card." + slot, String(card[slot])])
	if slot == "lmb":
		for w in card.get("weapons", {}): out.append(["card.weapons." + w, String(card["weapons"][w])])
	var lines: Dictionary = d.get("clip", {}).get("lines", {})
	if lines.has(slot): out.append(["clip.lines." + slot, String(lines[slot])])
	for rk in ["rank2", "rank3", "rank_next"]:      # rank texts name their slot as sec (RMB), kin (E) or dash
		for key in RANK_KEYS:
			if RANK_KEYS[key] == slot and d.get(rk, {}).has(key): out.append([rk + "." + key, String(d[rk][key])])
	var s: Dictionary = d.get(slot, {})
	if s.has("desc"): out.append([slot + ".desc", String(s["desc"])])
	for v in s.get("variants", {}): out.append([slot + ".variants." + v, String(s["variants"][v])])
	return out

## Every number in the slot's data as [key, value]; lmb also reads the weapon's primary table and
## the passive its resource.
func _data(d: Dictionary, slot: String) -> Array:
	var out: Array = []
	_flatten(d.get(slot, {}), "", out)
	if slot == "lmb":
		var wp := "res://content/weapons/%s.json" % d.get("signature", "")
		if FileAccess.file_exists(wp):
			_flatten(JSON.parse_string(FileAccess.get_file_as_string(wp)).get("primary", {}), "", out)
	if slot == "passive": _flatten(d.get("resource", {}), "", out)
	if slot == "dash":      # Bulwark's Shield Charge runs on the RMB's cooldown
		_flatten({"cooldown": d.get("rmb", {}).get("cooldown", 0.0)}, "", out)
	return out

func _flatten(v: Variant, key: String, out: Array) -> void:
	if v is Dictionary:
		for k in v: _flatten(v[k], String(k), out)
	elif v is Array:
		for x in v: _flatten(x, key, out)
	elif v is float or v is int:
		out.append([key, float(v)])

## The values a kind may state: its matching fields, and with `derived` also what rank and
## multiplier fields make of them (and, for durations, the sums of two stages).
func _values(data: Array, kind: String, derived := false) -> Array:
	var rx := RegEx.create_from_string(KEYS[kind])
	var fields: Array = data.filter(func(kv): return rx.search(String(kv[0])) != null)
	var vals: Array = fields.map(func(f): return f[1])
	if derived:
		var rx_mult := RegEx.create_from_string(KEYS["mult"])
		var mult_fields: Array = data.filter(func(kv): return rx_mult.search(String(kv[0])) != null)
		var mult: Array = mult_fields.map(func(kv): return kv[1])
		var per_rank := 0.0
		for kv in data:
			if kv[0] == "cd_per_rank": per_rank = kv[1]
		for f in fields:
			for m in mult: vals.append(f[1] * m)
			if kind == "cooldown": vals.append_array([f[1] - per_rank, f[1] - 2.0 * per_rank])
			for kv in data:
				if kv[0] == f[0] + "_rank3": vals.append(f[1] + kv[1])
			if kind == "duration":
				for g in fields:
					if g != f: vals.append(f[1] + g[1])
	if kind == "slow": vals = vals.map(func(x): return x * 100.0)
	return vals

func _kind(text: String, m: RegExMatch) -> String:
	var unit := m.get_string(3).strip_edges()
	var before := text.substr(maxi(0, m.get_start() - 24), mini(24, m.get_start())).to_lower()
	var after := text.substr(m.get_end(), 16).to_lower()
	var next := after.strip_edges()
	if next.begins_with("shorter") or next.begins_with("off"): return ""      # "3s off" is a change, not a value
	if unit == "" and before.ends_with("push "): return "push"      # "push 8 -> 12" (no unit)
	match unit:
		"s":
			var cd_word := RegEx.create_from_string("cooldown|recharge")
			var is_cd := cd_word.search(before) != null or cd_word.search(after.substr(0, 10)) != null
			return "cooldown" if is_cd else "duration"
		"m": return "range"
		"x", "times": return "mult"
		"damage", "dmg", "every": return "damage"
		"charge", "charges": return "charges"
		"%":
			var near := before.substr(maxi(0, before.length() - 14)) + " " + after.substr(0, 12)
			return "slow" if near.contains("slow") else ""
	return ""

func _near(a: float, b: float) -> bool:
	return absf(a - b) <= TOL * absf(b) + 1e-6

func _check_slot(id: String, d: Dictionary, slot: String, verbose: bool) -> void:
	var data := _data(d, slot)
	for t in _texts(d, slot):
		var text: String = t[1]
		for m in re_num.search_all(text):
			var kind := _kind(text, m)
			var follows_arrow := text.substr(maxi(0, m.get_start() - 4), 4).contains("->")
			var rank_result := String(t[0]).begins_with("rank") and follows_arrow      # "16s -> 13s": base only
			if kind == "" or rank_result: continue
			var nums: Array = [float(m.get_string(1))]
			if m.get_string(2) != "": nums.append(float(m.get_string(2)))
			for x in nums:
				var label := "%s %s [%s] %s %s" % [id, slot, t[0], kind, m.get_string(0).strip_edges()]
				_judge(x, kind, data, label, verbose)

## One stated number: matched, unmatched (nothing close to compare) or a mismatch.
func _judge(x: float, kind: String, data: Array, label: String, verbose: bool) -> void:
	var vals := _values(data, kind)
	var near := vals.any(func(v): return absf(x - v) <= NEAR * absf(v))
	if _values(data, kind, true).any(func(v): return _near(x, v)):
		checked += 1
	elif vals.is_empty() or (not kind in STRICT and not near):
		unmatched += 1
		if verbose: print("KITTEXT unmatched  %s" % label)
	else:
		mismatches += 1
		print("KITTEXT MISMATCH   %s: text %s, data %s" % [label, x, _fields(data, kind)])

func _fields(data: Array, kind: String) -> String:
	var rx := RegEx.create_from_string(KEYS[kind])
	var out: Array = []
	for kv in data:
		if rx.search(String(kv[0])): out.append("%s=%s" % [kv[0], kv[1]])
	return " ".join(out)
