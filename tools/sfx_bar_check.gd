extends RefCounted
## --sfx-set-check section 16: a Hunter set's "bar" (content/sfx/<arch>.json, docs/AUDIO.md "Ability bar"): per
## ability (lmb, rmb, e, shift, r) the sound of its cast, travel, hit and end ("" where the move has no such beat).
## Every named sound is in the set (or the kits' table, SfxKits.NAMES) with a file and is played by the kit (a
## literal in scripts/arch/, the weapon's shot in content/archetypes/<arch>.json, or the dash HeroSfx picks); the
## hit is what HeroSfx.hit_sound plays for a hit of that ability's "ab"; every ability has a cast, and no two
## abilities of a Hunter share a hit.

const BEATS := ["cast", "travel", "hit", "end"]

var ok: Callable
var src := ""  # every script under scripts/arch/, and the archetype files, for the literal names


func run(check_ok: Callable) -> void:
	ok = check_ok
	_read_dir("res://scripts/arch")
	for f in DirAccess.get_files_at("res://content/archetypes"):
		src += FileAccess.get_file_as_string("res://content/archetypes/" + f)
	var sets := 0
	for f in DirAccess.get_files_at("res://content/sfx"):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
		if d is Dictionary and d.has("bar"):
			_bar(String(d["group"]), d)
			sets += 1
	ok.call(sets >= 2, "ability bar: %d Hunter sets list one (Tenzo, Grimble at least)" % sets)


func _bar(arch: String, d: Dictionary) -> void:
	var sounds: Dictionary = d["sounds"]
	var bar: Dictionary = d["bar"]
	var h := Hunter.new()
	h.arch = arch
	var wrong := []
	var hits := {}
	var have := 0
	for slot in ["lmb", "rmb", "e", "shift", "r"]:
		var row: Dictionary = bar.get(slot, {})
		if String(row.get("cast", "")) == "":
			wrong.append("%s: no cast" % slot)
		for beat in BEATS:
			var sname := String(row.get(beat, ""))
			if sname == "":
				continue
			have += 1
			if not (sounds.has(sname) or SfxKits.NAMES.has(sname)) or not Sfx.ensure(sname):
				wrong.append("%s %s %s: in no set or no file" % [slot, beat, sname])
			elif beat != "hit" and not _played(arch, sname):
				wrong.append("%s %s %s: the kit never plays it" % [slot, beat, sname])
		var hit := String(row.get("hit", ""))
		if hit == "":
			continue
		var o := {"src": "abil", "ab": String(row.get("ab", ""))}
		var heard := HeroSfx.hit_sound(h, o)
		if heard != hit:
			wrong.append("%s hit: HeroSfx plays %s, the bar says %s" % [slot, heard, hit])
		if hits.has(hit):
			wrong.append("%s hit %s: shared with %s" % [slot, hit, hits[hit]])
		hits[hit] = slot
	h.free()
	var what := "ability bar %s: %d beats sounded, %d distinct hits %s" % [arch, have, hits.size(), wrong]
	ok.call(wrong.is_empty(), what)


func _played(arch: String, sname: String) -> bool:
	return sname == arch + "_dash" or src.contains('"%s"' % sname)


func _read_dir(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			src += FileAccess.get_file_as_string(dir + "/" + f)
	for sub in DirAccess.get_directories_at(dir):
		_read_dir(dir + "/" + sub)
