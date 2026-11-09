extends RefCounted
## --kit-parity-check: content/archetypes/<hero>.json against the sourced numbers in
## content/rules/kit_parity.json (docs/ARCHETYPES.md, "Kit parity lock"). Pure data, no match.
## Prints PARITY ok/FAIL lines and "PARITY DONE, failures: N".

var bad := 0

## The number at a dotted path ("rmb.slam.dmg") (dict keys, array indices) in a hero's JSON, or NAN when it is missing.
func _num(hero: Dictionary, path: String) -> float:
	var cur: Variant = hero
	for key in path.split("."):
		if cur is Array and key.is_valid_int() and int(key) < (cur as Array).size():
			cur = cur[int(key)]     # a per-rank table ("rank_dmg.sec.2")
			continue
		if not (cur is Dictionary) or not (cur as Dictionary).has(key): return NAN
		cur = cur[key]
	return float(cur) if (cur is float or cur is int) else NAN

func run(host: Node) -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/kit_parity.json"))
	var rows: Array = table.get("rows", [])
	for r in rows:
		var hero := Arch.def(String(r["hero"]))
		var got := _num(hero, String(r["field"]))
		var label := "%s %s %s" % [r["hero"], r["slot"], r["field"]]
		if r.has("per"):
			got /= _num(hero, String(r["per"]))
			label += "/" + String(r["per"])
		var good := not is_nan(got) and absf(got - float(r["value"])) <= float(r["tol"]) + 1e-6
		var verdict := "ok  " if good else "FAIL"
		print("PARITY %s %s: %s, source %s +-%s (%s)" % [verdict, label, got, r["value"], r["tol"], r["evidence"]])
		if not good: bad += 1
	print("PARITY DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 or rows.is_empty() else 0)
