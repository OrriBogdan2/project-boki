extends RefCounted
## --anim-coverage-check: which animation states each Hunter and Boki has as an authored clip, as a
## procedural pose, or not at all (docs/ANIM_COVERAGE.md). Read from content/rules/warden_anim/*.json, the .glb
## clip lists and BokiRig. Regenerates the table between the markers in the doc; fails (and leaves the doc alone)
## when a cell that was clip or proc goes to missing, or a row disappears. The Boki garden rows (every rigged .glb)
## are tools/anim_coverage_boki.gd.
## Never touches the save.

const DOC := "res://docs/ANIM_COVERAGE.md"
const Shots := preload("res://tools/boki_rig_shots.gd")
const Garden := preload("res://tools/anim_coverage_boki.gd")
const ANIM_DIR := "res://content/rules/warden_anim/"
const NATIVE := "res://content/rules/warden_native.json"
const BEGIN := "<!-- table:begin -->"
const END := "<!-- table:end -->"
const HUNTER_COLS := ["idle", "walk", "run", "attack", "hit", "death", "jump", "land", "glide", "dash", "cast", "stomp",
	"strafe", "crouch", "upper", "note"]
const BOKI_COLS := ["idle", "walk", "run", "attack", "hit", "death", "jump", "land", "glide", "dash", "cast", "stomp"]
## A kit move key with one of these words is that state's clip (HunterAnim poses the rest); a move whose name says
## something else ("ostra_swap", "dr_lunge") is the dash when its warden_anim entry has "dash": true.
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

## Whether a kit move whose key matches the pattern, or that carries `flag`, has its clip in the .glb.
func _move(d: Dictionary, clips: Array, pattern: String, flag := "") -> bool:
	var re := RegEx.create_from_string(pattern)
	for k in d.get("kmoves", {}):
		var mv: Dictionary = d["kmoves"][k]
		var named := re.search(String(k)) != null or bool(mv.get(flag, false))
		if named and clips.has(String(mv["clip"])):
			return true
	return false

## Stomp: the clip WardenClips plays on the game's phase (states.stomp) when the glb has it; "proc"
## (HunterAnim.stomp_k) when nothing is mapped; "missing" (and a FAIL line) when the mapped clip is not in the glb.
func _stomp(art: String, st: Dictionary, clips: Array) -> String:
	var v: Variant = st.get("stomp", "")
	if not (v is String) or v == "":
		return "proc"
	if clips.has(v):
		return "clip"
	print("MISSING stomp clip '%s' in art/wardens/%s/%s.glb" % [v, art, art])
	return "missing"

## A Hunter on Meshy's skeleton (warden_native.json, WardenNative) plays Meshy's clips, not the contract .glb's: its
## idle, walk, run, jump (Jump_Run) and crouch are its own `clip`s, attack is Meshy's Attack; every kit move (dash,
## cast, stomp, upper) plays that Attack and glide and land fall back to Jump_Run/the ground loop, so they read `shared`
## (when the contract row had one: a state it only posed stays `proc`). Hit and land are the flinch layer (`proc`);
## no death clip (the extract beat plays); strafe has no 4-way ring (the forward loop).
func _native_row(_art: String, row: Array, nat: Dictionary) -> Array:
	var c: Dictionary = nat.get("clips", {})
	var own := func(k: String) -> String: return "clip" if c.has(k) else "missing"
	var sh := func(i: int) -> String: return "shared" if row[i] != "proc" else "proc"
	var i := HUNTER_COLS
	return [own.call("idle"), own.call("walk"), own.call("run"), own.call("attack"), "proc", "shared",
		own.call("jump"), "proc", sh.call(i.find("glide")), sh.call(i.find("dash")), sh.call(i.find("cast")),
		sh.call(i.find("stomp")), "shared", own.call("crouch"), sh.call(i.find("upper")), "native: Meshy clips"]

func _hunter_row(art: String) -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ANIM_DIR + art + ".json"))
	var src := String(d.get("clips_from", art)) if _glb_clips("res://art/wardens/%s/%s.glb" % [art, art]).is_empty() \
			else art     # (data "clips_from": a .glb with no clips plays another Hero's, WardenClips._borrow)
	var clips := _glb_clips("res://art/wardens/%s/%s.glb" % [src, src])
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
	var procs: Array = d.get("procedural", [])     # (states the rig poses although a clip is named for them)
	var nat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NATIVE)).get(art, {})
	var row := [
		_cell(clips.has(loco.get("idle", ""))), _cell(walk_ok), _cell(run_ok),
		_cell(attacks > 0), _cell(hit_ok),
		_cell(clips.has(st.get("dead", "")), false), _cell(clips.has(air.get("rise", ""))), _cell(clips.has(land_clip)),
		_cell(clips.has(air.get("glide", "")) and not "gliding" in procs), _cell(_move(d, clips, DASH_RE, "dash")),
		_cell(_move(d, clips, CAST_RE)), _stomp(src, st, clips), _cell(walk_ok and run_ok),
		_cell(_has(clips, crouch.get("idle", ""))),
		_cell(upper), ""]
	return _native_row(art, row, nat) if bool(nat.get("meshy_native", false)) else row

## Boki: the glb carries idle, walk, run, attack, ability, hop (see BokiRig._state_clip). Hits, landings and dashes
## spring KinFlinch's Flex over the clip (found by the call in the source); a downed Boki topples onto its side
## (Kin.render).
## Jump is the hop clip only when Kin.render asks for it in the air (kact hop): without that a leap runs.
## Glide: a carried Boki spreads its legs (BokiHomeClips' glide, played when Kin.render sets kact glide); `_boki_air`
## checks the live rig plays it.
func _boki_row(id: String) -> Array:
	var clips := _glb_clips("res://art/kin/%s/%s.glb" % [id, id])
	var flinch := func(file: String, call: String) -> String:
		return "proc" if FileAccess.get_file_as_string(file).contains(call) else "missing"
	var kin_src := FileAccess.get_file_as_string("res://scripts/match/kin.gd")
	var jump := _cell(clips.has("hop") and kin_src.contains('var act := "hop" if airborne'), false)
	return [_cell(clips.has("idle")), _cell(clips.has("walk")), _cell(clips.has("run")), _cell(clips.has("attack")),
		flinch.call("res://scripts/arch/oomph.gd", "KinFlinch.hit("), "proc", jump,
		flinch.call("res://scripts/match/kin.gd", "KinFlinch.land("),
		_cell(clips.has("glide"), kin_src.contains('act = "glide"')),
		flinch.call("res://scripts/match/kin.gd", "KinFlinch.dash("),
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
	k.set_meta("kact", "glide")
	ok(rig._state_clip() == "glide" and rig.player.has_animation("glide"), "%s plays glide through a glide: %s" % [
		id, rig._state_clip()])
	k.free()

## The live rig's munch and nap are its own eat and sleep clips when those pass BokiClipCover, else the built ones.
func _boki_eat_sleep(main: Node, id: String) -> void:
	var k: Node3D = Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var player := (k.get_node("Body/Flex/BokiRig") as BokiRig).player
	var idle := player.get_animation("idle")
	for pair in [["munch", "eat", false], ["nap", "sleep", true]]:
		var played := player.get_animation(pair[0])
		var baked := player.get_animation(pair[1])
		var own := BokiClipCover.passes(baked, idle, pair[2])
		var same := played.length == baked.length and is_equal_approx(
			BokiClipCover.motion(BokiClipCover.sample(played)), BokiClipCover.motion(BokiClipCover.sample(baked)))
		ok(same == own, "%s: %s is %s as it is: %s, passes: %s" % [id, pair[0], pair[1], same, own])
	k.free()

func _table(cols: Array, rows: Dictionary) -> String:
	var s := "| | %s |\n|---|%s\n" % [" | ".join(cols), "---|".repeat(cols.size())]
	for r in rows:
		s += "| %s | %s |\n" % [r, " | ".join(rows[r])]
	return s

## The rows of a table body: {"table/row name": [cells]}, header and rule lines skipped.
func _parse(text: String) -> Dictionary:
	var out := {}
	var table := ""
	for line in text.split("\n"):
		if line.begins_with("### "):
			table = line.substr(4).strip_edges()
		var c := line.split("|")
		if c.size() < 4 or not line.begins_with("| ") or line.begins_with("| |"):
			continue
		out[table + "/" + c[1].strip_edges()] = Array(c.slice(2, c.size() - 1)).map(func(x): return x.strip_edges())
	return out

func _cols(key: String) -> Array:
	if key.begins_with("Hunters/"):
		return HUNTER_COLS
	return Garden.COLS if key.begins_with("Boki garden") else BOKI_COLS

func run(main: Node) -> void:
	Save.no_write = true
	var hunters := {}
	for f in DirAccess.get_files_at(ANIM_DIR):
		if f.ends_with(".json"):
			hunters[f.get_basename()] = _hunter_row(f.get_basename())
	var garden: Dictionary = await Garden.rows(main)    # before _boki_air takes the starters' hop clip away
	var bokis := {}
	for id in ["burrlet", "cindle", "puddlet"]:
		bokis[id] = _boki_row(id)
		await _boki_eat_sleep(main, id)
		await _boki_air(main, id)
	hunters.sort()
	var ranked := {}
	for id in Garden.worst(garden):
		ranked[id] = garden[id]
	var block := "%s\n### Hunters\n\n%s\n### Starter Boki\n\n%s\n### Boki garden states\n\n%s\n" % [
		BEGIN, _table(HUNTER_COLS, hunters), _table(BOKI_COLS, bokis), _table(Garden.COLS, ranked)] \
		+ "Worst five, backlog-ready:\n\n%s%s" % [Garden.backlog(garden, 5), END]
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
				"%s: %s went from %s to missing" % [r, _cols(r)[i], before[r][i]])
	if bad == 0 and a >= 0 and b > a:
		var f := FileAccess.open(DOC, FileAccess.WRITE)
		f.store_string(old.substr(0, a) + block + old.substr(b + END.length()))
		f.close()
	print("ANIM_COVERAGE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
