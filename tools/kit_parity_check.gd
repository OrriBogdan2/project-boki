extends RefCounted
## --kit-parity-check: content/archetypes/<hero>.json against the sourced numbers in
## content/rules/kit_parity.json (docs/ARCHETYPES.md, "Kit parity lock"). Pure data, no match.
## Prints PARITY ok/FAIL lines and "PARITY DONE, failures: N".

## Albert/Mossy's CUT Guard meter and Shield Slam (DECISIONS 2026-11-07 'parity calls'; a stale merge brought them back
## on 11-15): none of these may be in his kit script again.
const BULWARK_CUT := ["func add_guard", "func full_ready", "func _shield_slam", "shield_slams"]

var bad := 0

## The number at a dotted path ("rmb.slam.dmg") in a hero's JSON, or NAN when it is missing.
func _num(hero: Dictionary, path: String) -> float:
	var cur: Variant = hero
	for key in path.split("."):         # a number key indexes an array (rank_dmg.sec.2: rank 3)
		if cur is Array and key.is_valid_int() and int(key) < (cur as Array).size():
			cur = cur[int(key)]
		elif cur is Dictionary and (cur as Dictionary).has(key):
			cur = cur[key]
		else:
			return NAN
	return float(cur) if (cur is float or cur is int) else NAN

func run(host: Node) -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/kit_parity.json"))
	var rows: Array = table.get("rows", [])
	for r in rows:
		var hero := Arch.def(String(r["hero"])).duplicate()
		hero["weapon"] = Content._load("weapons", String(hero.get("signature", "")))   # weapon.primary.dmg
		var got := _num(hero, String(r["field"]))
		var label := "%s %s %s" % [r["hero"], r["slot"], r["field"]]
		if r.has("per"):
			got /= _num(hero, String(r["per"]))
			label += "/" + String(r["per"])
		var good := not is_nan(got) and absf(got - float(r["value"])) <= float(r["tol"]) + 1e-6
		var verdict := "ok  " if good else "FAIL"
		print("PARITY %s %s: %s, source %s +-%s (%s)" % [verdict, label, got, r["value"], r["tol"], r["evidence"]])
		if not good: bad += 1
	bad += _bulwark_cut()
	print("PARITY DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 or rows.is_empty() else 0)

## Albert's kit has no meter resource, no Shield Slam block and none of the code for them; returns the failures.
func _bulwark_cut() -> int:
	var d := Arch.def("bulwark")
	var res: Dictionary = d.get("resource", {})
	var src := FileAccess.get_file_as_string("res://scripts/arch/kits/bulwark_kit.gd")
	var found: Array = BULWARK_CUT.filter(func(w): return src.contains(w))
	var has_slam: bool = (d["rmb"] as Dictionary).has("slam")
	var good: bool = String(res.get("kind", "")) == "none" and not has_slam and found.is_empty()
	var verdict := "ok  " if good else "FAIL"
	print("PARITY %s bulwark cut: kind %s, rmb.slam %s, code %s" % [verdict, res.get("kind"), has_slam, found])
	return 0 if good else 1
