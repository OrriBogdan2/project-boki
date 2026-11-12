extends RefCounted
## --sfx-set-check section 11: the world's sounds outside the kits (content/rules/sfx_world.json, docs/SFX_WORLD.md).
## For each system (mobs, pickups and loot, gloves, utilities, garden games, Ways Out and the Heartspark) every
## cue it plays is one of its own sounds (a sound of the system's sets in content/sfx) and exists, never a
## shared stock sound or a borrowed Boki k_* cue. The cues are the literal names in the system's files
## (m.sfx("x"), Sfx.play("x"), cue("x"), _cue("x"), the stock fallback of e.get("sfx", "x") and of
## HeroSfx.of(h, kind, "x")), labelled by function and match arm, and for gloves the stock sound Effects plays
## for each effect type a glove uses. A hole is "<label>:<cue>". The table's "holes" are the known ones
## (a ratchet): a hole not listed fails, and a listed hole that is gone fails too, so the list only shrinks.

const TABLE := "res://content/rules/sfx_world.json"
# group 1 a played name, group 2 the stock fallback of an "sfx" key, group 3 HeroSfx.of's fallback
const CUE_CALLS := "(?:^|[^a-z_])(?:sfx|cue|_cue|Sfx\\.play)\\(\\s*\"([a-z0-9_]*)\"" \
		+ "|\\.get\\(\"sfx\",\\s*\"([a-z0-9_]+)\"\\)|HeroSfx\\.of\\([^,]+,\\s*\"[a-z_]+\",\\s*\"([a-z0-9_]+)\"\\)"
const ARM := "^(\\t+)\"([a-z0-9_]+)\"(?:,\\s*\"[a-z0-9_]+\")*:"
const FUNC := "^(?:static )?func ([a-z0-9_]+)"
const EFFECTS := "res://scripts/combat/effects.gd"

var ok: Callable

func run(check_ok: Callable) -> void:
	ok = check_ok
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	var systems: Dictionary = table["systems"]
	for sys in systems:
		var row: Dictionary = systems[sys]
		var own := _own(row.get("sets", []))
		var holes := []
		for f in row.get("files", []):
			for c in cues_in(String(f)):
				_hole(c[0], c[1], own, holes)
		if row.get("gloves", false):
			_glove_holes(own, holes)
		if row.get("mob_voices", false):
			for k in Data.MOBS.keys().filter(_winds_up):
				_hole("mob voice", "v_" + String(k), {"v_" + String(k): true}, holes)
		_ratchet(String(sys), holes, row.get("holes", []))

## Mob._begin_attack plays "v_" + kind as a mob winds up; a boss runs its own attacks and some kinds never attack.
static func _winds_up(kind: String) -> bool:
	return not ["none", "boss"].has(String(Data.MOBS[kind].get("attack", "none")))

## The sounds of the system's own sets in content/sfx (a set not on file yet owns nothing).
func _own(sets: Array) -> Dictionary:
	var own := {}
	for s in sets:
		var path := "res://content/sfx/%s.json" % s
		if FileAccess.file_exists(path):
			own.merge(JSON.parse_string(FileAccess.get_file_as_string(path)).get("sounds", {}))
	return own

## [label, cue] for every literal cue in a file ("path" or "path#func" for one function's cues).
## The label is the file (without .gd), the function and, inside a match, the arm: "mob _strike/spit".
static func cues_in(entry: String) -> Array:
	var parts := entry.split("#")
	var src := FileAccess.get_file_as_string("res://" + parts[0])
	var only := parts[1] if parts.size() > 1 else ""
	var re := RegEx.create_from_string(CUE_CALLS)
	var arm_re := RegEx.create_from_string(ARM)
	var func_re := RegEx.create_from_string(FUNC)
	var out := []
	var fn := ""
	var arm := ""
	var arm_indent := 0
	for line in src.split("\n"):
		var f := func_re.search(line)
		if f:
			fn = f.get_string(1)
			arm = ""
		var a := arm_re.search(line)
		var indent := line.length() - line.lstrip("\t").length()
		if a:
			arm = a.get_string(2)
			arm_indent = indent
		elif arm != "" and line.strip_edges() != "" and indent <= arm_indent:
			arm = ""
		if only != "" and fn != only:
			continue
		for hit in re.search_all(line):
			var sname := hit.get_string(1) + hit.get_string(2) + hit.get_string(3)
			if sname != "" and not sname.ends_with("_"):     # a name built from a prefix is not a literal
				var where := "%s/%s" % [fn, arm] if arm != "" else fn
				out.append(["%s %s" % [parts[0].get_file().get_basename(), where], sname])
	return out

func _hole(label: String, sname: String, own: Dictionary, holes: Array) -> void:
	var hole := "%s:%s" % [label, sname]
	if (not own.has(sname) or not Sfx.ensure(sname)) and not holes.has(hole):
		holes.append(hole)

## An active glove built from effect blocks plays, per block, the stock sound Effects plays for that type
## (an effect's own "sfx" replaces the fallback).
func _glove_holes(own: Dictionary, holes: Array) -> void:
	var by_type := {}
	for c in cues_in(EFFECTS.trim_prefix("res://") + "#_one"):
		var arm := String(c[0]).get_slice("/", 1)
		if arm != "":
			by_type[arm] = by_type.get(arm, []) + [c[1]]
	for gid in Gear.ALL:
		if not Gear.active(gid):
			continue
		for e in (Gear.ALL[gid] as Dictionary).get("effects", []):
			var t := String(e.get("type", ""))
			for sname in by_type.get(t, []):
				_hole("glove %s %s" % [gid, t], String(e.get("sfx", sname)), own, holes)

## Prints every hole; fails on a hole the table does not list, and on a listed one that is gone.
func _ratchet(sys: String, holes: Array, known: Array) -> void:
	var fresh := holes.filter(func(h): return not known.has(h))
	var gone := known.filter(func(h): return not holes.has(h))
	for h in holes:
		print("SFXSET hole %s: %s" % [sys, h])
	ok.call(fresh.is_empty(), "%s: no new shared or missing cue (%d known holes; new: %s)" % [sys, holes.size(), fresh])
	var why := "gone, drop from %s: %s" % [TABLE.get_file(), gone]
	ok.call(gone.is_empty(), "%s: every listed hole is still one (%s)" % [sys, why])
