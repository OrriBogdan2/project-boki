extends RefCounted
## --kit-parity-check: content/archetypes/<hero>.json (or another content file) against the sourced
## numbers in content/rules/kit_parity.json (docs/ARCHETYPES.md, "Kit parity lock"). Pure data, no match.
## Prints PARITY ok/OWNER/FAIL lines and "PARITY DONE, failures: N".

var bad := 0

## The number at a dotted path ("rmb.slam.dmg", "smash_dmg.1") in a dictionary, or NAN when it is missing.
func _num(root: Variant, path: String) -> float:
	var cur: Variant = root
	for key in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(key): cur = cur[key]
		elif cur is Array and key.is_valid_int() and int(key) < (cur as Array).size(): cur = cur[int(key)]
		else: return NAN
	if cur is bool: return 1.0 if cur else 0.0
	return float(cur) if (cur is float or cur is int) else NAN

## A row path: "rmb.cooldown" reads the hero's archetype, "weapons/quill_rifle:primary.mag" reads content/<file>.json.
func _read(hero: Dictionary, spec: String) -> float:
	if not spec.contains(":"): return _num(hero, spec)
	var parts := spec.split(":")
	return _num(JSON.parse_string(FileAccess.get_file_as_string("res://content/%s.json" % parts[0])), parts[1])

## "ok" on the source value, "OWNER" on the row's `owner` note with `ours` still pinned, else "FAIL".
func _verdict(r: Dictionary, got: float) -> String:
	if not is_nan(got) and absf(got - float(r["value"])) <= float(r["tol"]) + 1e-6: return "ok"
	if r.has("owner") and not is_nan(got) and absf(got - float(r["ours"])) <= 1e-6: return "OWNER"
	return "FAIL"

func run(host: Node) -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/kit_parity.json"))
	var rows: Array = table.get("rows", [])
	for r in rows:
		var hero := Arch.def(String(r["hero"]))
		var got := _read(hero, String(r["field"]))
		var label := "%s %s %s" % [r["hero"], r["slot"], r["field"]]
		if r.has("per"):
			got /= _read(hero, String(r["per"]))
			label += "/" + String(r["per"])
		var verdict := _verdict(r, got)
		var note := " owner: " + String(r["owner"]) if verdict == "OWNER" else ""
		var src := "source %s +-%s (%s)" % [r["value"], r["tol"], r["evidence"]]
		print("PARITY %s %s: %s, %s%s" % [verdict, label, got, src, note])
		if verdict == "FAIL": bad += 1
	print("PARITY DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 or rows.is_empty() else 0)
