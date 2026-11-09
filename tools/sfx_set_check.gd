extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md).
##   1. every listed sound has a file (audio/<name>.wav or its takes <name>_1..4.wav)
##   2. every take sits at its category's loudness (content/rules/sfx_levels.json) and under the peak ceiling
##   3. a Hunter set has its wordless voice (hurt, down, death), its dash, footsteps on every surface,
##      at least one weapon "fire" sound and its listed signature sounds, and HeroSfx picks them up
##   4. every literal m.sfx("...") in that Hunter's kit (and its listed helper files) names a sound that exists
##   5. a Hunter with no set falls back to the shared sounds
##   6. "reach" (metres a heavy sound carries) names sounds of the set, between hear_range and REACH_MAX;
##      every sound under "loops" repeats seamlessly (no fade at either end, the seam no bigger than a step)
##   7. every belt item but the keys has its own row in content/rules/belt_sfx.json (cues named for the item,
##      files on disk, a channelled item also loop/end/cancel) and utility_use.gd plays no stock cue
## Reads the files only; never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const STOCK := ["heal", "build", "cloak", "ping", "throw", "pickup", "shield", "skill"]   # shared cues the belt used
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const SEAM_MAX := 0.05         # the jump at a loop's seam, as a share of full scale

var bad := 0
var levels := {}

func ok(cond: bool, what: String) -> void:
	print("SFXSET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_levels.json"))
	ok(levels is Dictionary and (levels.get("cats", {}) as Dictionary).size() >= 8, "the loudness table loads")
	var sets := 0
	for f in DirAccess.get_files_at("res://content/sfx"):
		if f.ends_with(".json"):
			_check_set("res://content/sfx/" + f)
			sets += 1
	print("SFXSET %d sound sets" % sets)
	_fallback()
	_belt()
	print("SFXSET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _check_set(path: String) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary and d.has("group") and d.has("sounds")):
		ok(false, "%s has a group and sounds" % path)
		return
	var group := String(d["group"])
	var sounds: Dictionary = d["sounds"]
	var cats: Dictionary = levels["cats"]
	var off := []
	for sname in sounds:
		var cat := String(sounds[sname])
		var takes := _takes(String(sname))
		if takes.is_empty() or not cats.has(cat):
			off.append("%s (%s)" % [sname, "no file" if takes.is_empty() else "unknown category " + cat])
			continue
		for t in takes:
			var m := _measure(t)
			var far := absf(float(m["rms"]) - float(cats[cat])) > float(levels["tolerance_db"])
			if far or float(m["peak"]) > float(levels["peak_db"]) + 0.1:
				off.append("%s rms %.1f / %.1f, peak %.1f" % [t.get_file(), m["rms"], cats[cat], m["peak"]])
	var why := "" if off.is_empty() else str(off)
	ok(off.is_empty(), "%s: %d sounds on file and at level %s" % [group, sounds.size(), why])
	_reach_and_loops(group, d)
	if Arch.ids().has(group):
		_check_hunter(group, d)

func _check_hunter(arch: String, d: Dictionary) -> void:
	var sounds: Dictionary = d["sounds"]
	var need := ["dash"] + VOICE
	for s in SURFACES:
		need.append("step_" + s)
	var missing := need.filter(func(k): return not sounds.has("%s_%s" % [arch, k]))
	ok(missing.is_empty(), "%s: voice, dash and footsteps on every surface (missing %s)" % [arch, missing])
	ok(sounds.values().has("fire") or sounds.values().has("heavy_fire"), "%s: a weapon fire sound" % arch)
	var sig: Array = d.get("signature", [])
	var sig_missing := sig.filter(func(s): return not sounds.has(s))
	ok(not sig.is_empty() and sig_missing.is_empty(), "%s: signature sounds %s (missing %s)" % [arch, sig, sig_missing])
	var h := Hunter.new()
	h.arch = arch
	var picked := []
	for kind in ["dash", "step_wood", "hurt"]:
		picked.append(HeroSfx.of(h, kind, kind))
	h.free()
	var want := [arch + "_dash", arch + "_step_wood", arch + "_hurt"]
	ok(picked == want, "%s: HeroSfx picks its own (%s)" % [arch, picked])
	_kit_names(arch, d.get("kit_files", []))

## 4. Every literal sound name the kit plays exists (a typo plays silence): <arch>_kit.gd plus the helper
## files the set lists under "kit_files" (paths under scripts/arch/kits/).
func _kit_names(arch: String, extra: Array) -> void:
	var re := RegEx.create_from_string("\\.sfx\\(\"([a-z0-9_]+)\"")
	var silent := []
	for f in ["%s_kit.gd" % arch] + extra:
		var path := "res://scripts/arch/kits/" + String(f)
		if not FileAccess.file_exists(path):
			ok(false, "%s: kit file %s exists" % [arch, f])
			continue
		for hit in re.search_all(FileAccess.get_file_as_string(path)):
			var sname := hit.get_string(1)
			if not Sfx.ensure(sname) and not silent.has(sname):
				silent.append(sname)
	ok(silent.is_empty(), "%s: every sound its kit plays exists (silent: %s)" % [arch, silent])

## 6. Heavy sounds that carry, and held sounds that loop.
func _reach_and_loops(group: String, d: Dictionary) -> void:
	var sounds: Dictionary = d["sounds"]
	var reach: Dictionary = d.get("reach", {})
	var wrong := []
	for sname in reach:
		var m := float(reach[sname])
		if not sounds.has(sname) or m < Sfx.hear_range or m > REACH_MAX:
			wrong.append("%s %.0f m" % [sname, m])
	ok(wrong.is_empty(), "%s: %d sounds carry further (wrong: %s)" % [group, reach.size(), wrong])
	var rough := []
	for sname in d.get("loops", []):
		var takes := _takes(String(sname))
		if not sounds.has(sname) or takes.is_empty():
			rough.append("%s (not in the set)" % sname)
			continue
		var data := _data(takes[0])
		var n := data.size() / 2
		var first := data.decode_s16(0) / 32768.0
		var last := data.decode_s16((n - 1) * 2) / 32768.0
		var mid := 0.0
		for k in range(n / 2, n / 2 + 200):
			mid = maxf(mid, absf(data.decode_s16(k * 2) / 32768.0))
		if absf(last - first) > SEAM_MAX or absf(last) < mid * 0.02:
			rough.append("%s seam %.3f, end %.3f of %.3f" % [sname, absf(last - first), absf(last), mid])
	ok(rough.is_empty(), "%s: %d loops repeat seamlessly %s" % [group, (d.get("loops", []) as Array).size(), rough])

## 5. A Hunter without its own set plays the shared sounds.
func _fallback() -> void:
	var h := Hunter.new()
	h.arch = "no_such_hunter"
	var got := [HeroSfx.of(h, "dash", "dash"), HeroSfx.of(h, "hurt", "")]
	h.free()
	ok(got == ["dash", ""], "no set: the shared dash, and no voice line (%s)" % [got])

## 7. Every belt item has its own cues (BeltSfx), none of them a stock one.
func _belt() -> void:
	var rows := BeltSfx.items()
	var seen := {}
	var wrong := []
	for id in UtilityBelt.ids():
		if UtilityBelt.is_key(id):
			continue
		var kinds := ["start"] + (["loop", "end", "cancel"] if UtilityUse.use_of(id) in ["drink", "repair"] else [])
		for kind in kinds:
			var c := BeltSfx.cue(id, kind)
			if c != "belt_%s_%s" % [id, kind] or c in STOCK or seen.has(c) or _takes(c).is_empty():
				wrong.append("%s %s '%s'" % [id, kind, c])
			seen[c] = true
		if (rows.get(id, {}) as Dictionary).size() != kinds.size():
			wrong.append("%s has the wrong set of cues" % id)
	ok(wrong.is_empty(), "belt: %d items with their own start/loop/end/cancel cues %s" % [rows.size(), wrong])
	var src := FileAccess.get_file_as_string("res://scripts/match/utility_use.gd")
	var stock_left := STOCK.filter(func(c): return src.contains('sfx("%s"' % c))
	ok(stock_left.is_empty(), "belt: utility_use.gd plays no stock cue %s" % [stock_left])

func _takes(sname: String) -> Array:
	var out := []
	var paths: Array = ["res://audio/%s.wav" % sname]
	for i in range(1, 5):
		paths.append("res://audio/%s_%d.wav" % [sname, i])
	for p in paths:
		if FileAccess.file_exists(p):
			out.append(p)
	return out

## Peak and RMS (dBFS) of a 16-bit PCM wav; RMS over samples above 2% of the peak, as tools/sfx_lib.py levels.
func _measure(path: String) -> Dictionary:
	var data := _data(path)
	var n := data.size() / 2
	var pk := 0.0
	for k in n:
		pk = maxf(pk, absf(data.decode_s16(k * 2) / 32768.0))
	var sum := 0.0
	var cnt := 0
	for k in n:
		var v := data.decode_s16(k * 2) / 32768.0
		if absf(v) > pk * 0.02:
			sum += v * v
			cnt += 1
	var rms := sqrt(sum / maxf(1.0, cnt))
	return {"peak": linear_to_db(maxf(pk, 1e-6)), "rms": linear_to_db(maxf(rms, 1e-6))}

## The 16-bit PCM samples of a wav file (its "data" chunk).
func _data(path: String) -> PackedByteArray:
	var b := FileAccess.get_file_as_bytes(path)
	var i := 12
	while i + 8 <= b.size():
		var id := b.slice(i, i + 4).get_string_from_ascii()
		var chunk := b.decode_u32(i + 4)
		if id == "data":
			return b.slice(i + 8, i + 8 + chunk)
		i += 8 + chunk + (chunk & 1)
	return PackedByteArray()
