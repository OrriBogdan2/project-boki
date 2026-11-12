extends RefCounted
## --anim-coverage-check: which animation states each Hunter and starter Boki has as an authored clip, as a
## procedural pose, or not at all (docs/ANIM_COVERAGE.md). Read from content/rules/warden_anim/*.json, the .glb
## clip lists and BokiRig. Regenerates the table between the markers in the doc; fails (and leaves the doc alone)
## when a cell that was clip or proc goes to missing, or a row disappears.
## Never touches the save.

const DOC := "res://docs/ANIM_COVERAGE.md"
const Shots := preload("res://tools/boki_rig_shots.gd")
const ANIM_DIR := "res://content/rules/warden_anim/"
const BEGIN := "<!-- table:begin -->"
const END := "<!-- table:end -->"
const HUNTER_COLS := ["idle", "walk", "run", "attack", "hit", "death", "jump", "land", "glide", "dash", "cast", "stomp",
	"strafe", "crouch", "upper"]
const BOKI_COLS := ["idle", "walk", "run", "attack", "hit", "death", "jump", "land", "glide", "dash", "cast", "stomp"]
## A kit move key with one of these words is that state's clip (HunterAnim poses the rest).
const DASH_RE := "dash|skate|vault"
const CAST_RE := "_e$|_e_|aim|call|seed|well|swap|wall|freeze|beam|spear|roar|cloak|mend|flare|hearth|raise|sense" \
	+ "|spine|encore|bola|ult|rime|stoke|xform"

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
		print("FAIL ", what)

func _glb_clips(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	f.seek(12)
	var n := f.get_32()
	f.seek(20)
	var j: Dictionary = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	var out: Array = []
	for a in j.get("animations", []):
		out.append(String(a["name"]))
	return out

func _has(clips: Array, v: Variant) -> bool:
	if v is Dictionary:
		for k in v:
			if not clips.has(String(v[k])):
				return false
		return not (v as Dictionary).is_empty()
	return v is String and clips.has(v)

func _cell(clip_ok: bool, proc_ok: bool = true) -> String:
	if clip_ok:
		return "clip"
	return "proc" if proc_ok else "missing"

## Clip names of the kit moves (not the fusion one) whose key matches the pattern, all present in the .glb.
func _move(d: Dictionary, clips: Array, pattern: String) -> bool:
	var re := RegEx.create_from_string(pattern)
	for k in d.get("kmoves", {}):
		if re.search(String(k)) != null and clips.has(String(d["kmoves"][k]["clip"])):
			return true
	return false

func _hunter_row(art: String) -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ANIM_DIR + art + ".json"))
	var clips := _glb_clips("res://art/wardens/%s/%s.glb" % [art, art])
	var loco: Dictionary = d.get("loco", {})
	var st: Dictionary = d.get("states", {})
	var air: Dictionary = d.get("air", {})
	var hit: Variant = st.get("hit", {})
	var hit_clips: Array = []
	if hit is Dictionary:
		for k in ["front", "back"]:
			hit_clips.append(hit.get(k, ""))
	var moves: Dictionary = d.get("kmoves", {})
	var attacks := 0
	for k in moves:
		if k != "mf_xform" and clips.has(String(moves[k]["clip"])):
			attacks += 1
	var upper := false
	for k in moves:
		upper = upper or moves[k].has("upper")
	var crouch: Dictionary = d.get("crouch", {})
	var hit_ok: bool = not hit_clips.is_empty() and hit_clips.all(func(c): return clips.has(c))
	var walk_ok := _has(clips, loco.get("walk"))
	var run_ok := _has(clips, loco.get("run"))
	var land_clip: String = d.get("land", {}).get("clip", "")
	return [
		_cell(clips.has(loco.get("idle", ""))), _cell(walk_ok), _cell(run_ok),
		_cell(attacks > 0), _cell(hit_ok),
		_cell(clips.has(st.get("dead", "")), false), _cell(clips.has(air.get("rise", ""))), _cell(clips.has(land_clip)),
		_cell(clips.has(air.get("glide", ""))), _cell(_move(d, clips, DASH_RE)), _cell(_move(d, clips, CAST_RE)),
		"proc", _cell(walk_ok and run_ok), _cell(_has(clips, crouch.get("idle", ""))), _cell(upper)]

## Boki: the glb carries idle, walk, run, attack, ability, hop (see BokiRig._state_clip). Hits and landings spring
## KinFlinch's Flex over the clip (found by the call in the source); a downed Boki topples onto its side (Kin.render).
## Jump is the hop clip only when Kin.render asks for it in the air (kact hop): without that a leap runs.
func _boki_row(id: String) -> Array:
	var clips := _glb_clips("res://art/kin/%s/%s.glb" % [id, id])
	var flinch := func(file: String, call: String) -> String:
		return "proc" if FileAccess.get_file_as_string(file).contains(call) else "missing"
	var kin_src := FileAccess.get_file_as_string("res://scripts/match/kin.gd")
	var jump := _cell(clips.has("hop") and kin_src.contains('set_meta("kact", "hop" if airborne'), false)
	return [_cell(clips.has("idle")), _cell(clips.has("walk")), _cell(clips.has("run")), _cell(clips.has("attack")),
		flinch.call("res://scripts/arch/oomph.gd", "KinFlinch.hit("), "proc", jump,
		flinch.call("res://scripts/match/kin.gd", "KinFlinch.land("), "missing", "missing",
		_cell(clips.has("ability")), "missing"]

## The live rig: a Boki in the air (kact hop) plays its hop clip, and the run clip once the hop clip is gone.
func _boki_air(main: Node, id: String) -> void:
	var k: Node3D = Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	k.set_meta("kact", "hop")
	ok(rig._state_clip() == "hop", "%s plays hop in the air, not %s" % [id, rig._state_clip()])
	rig.player.get_animation_library("").remove_animation("hop")
	ok(rig._state_clip() == "run", "%s without a hop clip runs in the air, not %s" % [id, rig._state_clip()])
	k.free()

func _table(cols: Array, rows: Dictionary) -> String:
	var s := "| | %s |\n|---|%s\n" % [" | ".join(cols), "---|".repeat(cols.size())]
	for r in rows:
		s += "| %s | %s |\n" % [r, " | ".join(rows[r])]
	return s

## The rows of a table body: {row name: [cells]}, header and rule lines skipped.
func _parse(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		var c := line.split("|")
		if c.size() < 4 or not line.begins_with("| ") or line.begins_with("| |"):
			continue
		out[c[1].strip_edges()] = Array(c.slice(2, c.size() - 1)).map(func(x): return x.strip_edges())
	return out

func run(main: Node) -> void:
	Save.no_write = true
	var hunters := {}
	for f in DirAccess.get_files_at(ANIM_DIR):
		if f.ends_with(".json"):
			hunters[f.get_basename()] = _hunter_row(f.get_basename())
	var bokis := {}
	for id in ["burrlet", "cindle", "puddlet"]:
		bokis[id] = _boki_row(id)
		await _boki_air(main, id)
	hunters.sort()
	var block := "%s\n### Hunters\n\n%s\n### Starter Boki\n\n%s%s" % [
		BEGIN, _table(HUNTER_COLS, hunters), _table(BOKI_COLS, bokis), END]
	var old := FileAccess.get_file_as_string(DOC)
	var a := old.find(BEGIN)
	var b := old.find(END)
	ok(a >= 0 and b > a, "the doc has the table markers")
	var before := _parse(old.substr(a, b - a)) if a >= 0 and b > a else {}
	var now := _parse(block)
	for r in before:
		ok(now.has(r), "%s is gone from the table" % r)
		if not now.has(r):
			continue
		for i in mini(before[r].size(), now[r].size()):
			ok(not (before[r][i] != "missing" and now[r][i] == "missing"),
				"%s: %s went from %s to missing" % [r, (HUNTER_COLS if hunters.has(r) else BOKI_COLS)[i], before[r][i]])
	if bad == 0 and a >= 0 and b > a:
		var f := FileAccess.open(DOC, FileAccess.WRITE)
		f.store_string(old.substr(0, a) + block + old.substr(b + END.length()))
		f.close()
	print("ANIM_COVERAGE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
