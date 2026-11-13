extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md).
##   1. every listed sound has a file (audio/<name>.wav or its takes <name>_1..4.wav)
##   2. every take sits at its category's loudness (content/rules/sfx_levels.json) and under the peak ceiling
##   3. a Hunter set has its wordless voice (hurt, down, death), its dash, footsteps on every surface,
##      at least one weapon "fire" sound and its listed signature sounds, and HeroSfx picks them up
##   4. every literal m.sfx("...") in that Hunter's kit (and its listed helper files) names a sound that exists
##   5. a Hunter with no set falls back to the shared sounds
##   6. "reach" (metres a sound carries) names sounds of the set, between REACH_MIN and REACH_MAX;
##      every sound under "loops" repeats seamlessly (no fade at either end, the seam no bigger than a step)
##   7. every Hunter's ultimate has a positional cast cue (<arch>_ult_cue, with a reach past hearing range)
##      and the two team tags carry as far; HeroUlt.press plays it and the match plays it for other players' casts
##   8. dash_air per Hunter and the no-charge tick
##   9. the garden's ambience (HomeAmbience): every bed has its file, the parts of the day and the rain each
##      pick their own, a change crossfades over 20 s, at most 2 loops sound at once through a day with rain
##      and a walk by a pond, the pond follows the distance to water, beds sit on the Ambience bus, and the
##      garden never plays amb_match
##  10. every hit class (HitClass) names a sound of the "targets" set that exists and fits under a weapon hit
##  11. every ambience loop the match and the title ask for (AmbBeds.BEDS, "title", ...) has its file
##  12. every belt item but the keys has its own row in content/rules/belt_sfx.json (cues named for the item,
##      files on disk, a channelled item also loop/end/cancel) and utility_use.gd plays no stock cue
##  13. every Boki species' type has its cast cue k_<type> (KinLib.cue_of), and the six old k_ names are gone
##  14. boki_voices: every rigged species (art/kin/*) has all five moods with two takes, KinVoice.cue picks them,
##      an unknown species falls back to the generic cues, and no two species share a happy take
##  15. the Boki downed/revive/eat/sleep and Fusion end/tired cues are in a set, exist and are played from
##      their event code (WIRED)
##  16. every Fusion type and form names a cue with a boki_fuse_<cue> sound; the end, tired and evolve cues exist
##  17. every sound named in UiSfx (menus, pickup, capture, extraction) has its file
##  18. the low-health heartbeat (LowHpCue, content/rules/low_hp.json) starts under the line, speeds up as health
##      drops, and stops on a heal, a down or out
##  19. the Blight rumble is played where it belongs (WIRED), is in a set, and exists
##  20. HomeVoice: at most 3 Boki voices at once, one Boki not twice inside its gap, a voice past earshot is dropped
##      without taking a slot, and a need falling to urgent sulks once
##  21. the build and decorate cues (BuildSfx): pick, rotate, place by material, move, store and blocked exist;
##      the knock plays once per attempt (not again on the same spot); a pick-up inside a turn or a store is quiet;
##      the farm's build mode and the house's decorating play them
## Reads the files only; never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MIN := 5.0         # m: below this a sound would not carry past its own source
const STOCK := ["heal", "build", "cloak", "ping", "throw", "pickup", "shield", "skill"]   # shared cues the belt used
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const SEAM_MAX := 0.05         # the jump at a loop's seam, as a share of full scale

## Sound -> the scripts that must play it (a sound that exists but is never played is silence).
const WIRED := {"blight_rumble": ["match/blight.gd", "match/blight_dir.gd"],
	"boki_downed": ["match/kin_downed.gd", "match/kin_net.gd"],
	"boki_revive": ["match/kin_downed.gd", "match/kin_net.gd"],
	"boki_eat": ["home/base_feed.gd", "home/home_econ.gd", "home/home.gd"],
	"boki_sleep": ["home/base_life.gd", "home/home.gd", "home/kin_indoors.gd"],
	"boki_fuse_end": ["match/merge_xform.gd"], "boki_fuse_tired": ["match/merge_xform.gd"]}

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
	_dash_air()
	_cue_table()
	_wired()
	_fallback()
	_ult_cues()
	_garden_names()
	_garden()
	_hit_targets()
	_ambience()
	_belt()
	_boki_cues()
	_fusion_cues()
	_gloves()
	_ui_cues()
	_low_hp()
	_pickups()
	_voices()
	_build_cues()
	print("SFXSET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The ambience beds the match (AmbBeds) and the title ask for each have their loop file.
func _ambience() -> void:
	for bed in AmbBeds.BEDS + ["title", "match", "abyss", "ruins"]:
		ok(ResourceLoader.exists("res://audio/amb_%s.ogg" % bed), "ambience bed amb_%s.ogg" % bed)

func _boki_cues() -> void:
	var missing := []
	for id in KinLib.kin_ids():
		var cue := KinLib.cue_of(String(KinLib.species(id).get("type", "")))
		if _takes(cue).is_empty() and not missing.has(cue):
			missing.append(cue)
	ok(missing.is_empty(), "every Boki type has a cast cue file %s" % str(missing))
	var types := {}
	for theme in KinLib.TYPE_OF_THEME:
		types[KinLib.TYPE_OF_THEME[theme]] = true
	ok(types.size() == KinLib.TYPE_OF_THEME.size(), "each theme maps to its own type (%d)" % types.size())
## The mix pass's cue table (content/rules/sfx_cues.json): every named sound has a file and the dB is a sane trim.
func _cue_table() -> void:
	var mix = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_mix.json"))
	var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_cues.json"))["cues"]
	var off := []
	for sname in cues:
		var db := float(cues[sname])
		if _takes(String(sname)).is_empty() or db < -float(mix["max_trim_db"]) or db > float(mix["max_boost_db"]):
			off.append(sname)
	ok(not cues.is_empty() and off.is_empty(),
		"the cue table: %d sounds on file, each within the trim/boost caps %s" % [cues.size(), off])
	var d: Dictionary = mix["duck"]
	var dips := float(d["ult_db"]) < 0.0 and float(d["knock_db"]) < 0.0
	ok(dips and float(d["back_s"]) <= 1.2, "the ducking rules dip and come back in about a second")

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
	if group == "boki_voices":
		_boki_voices(d["sounds"])

## 7. A voice set per rigged species: five moods, two takes each, picked by KinVoice.cue, generic fallback.
func _boki_voices(sounds: Dictionary) -> void:
	var gaps := []
	var same := []
	var seen := {}
	for sp in DirAccess.get_directories_at("res://art/kin"):
		for mood in KinVoice.GENERIC_CUE:
			var want := "bk_%s_%s" % [sp, mood]
			if not sounds.has(want) or _takes(want).size() != 2 or KinVoice.cue(sp, mood) != want:
				gaps.append(want)
		var sig := hash(_data("res://audio/bk_%s_happy.wav" % sp))
		if seen.has(sig):
			same.append("%s = %s" % [sp, seen[sig]])
		seen[sig] = sp
	var what := "boki_voices: %d species, 5 moods, 2 takes (gaps %s)" % [seen.size(), gaps]
	ok(gaps.is_empty() and not seen.is_empty(), what)
	ok(same.is_empty(), "boki_voices: every species sounds different (same %s)" % [same])
	var fell := []
	for mood in KinVoice.GENERIC_CUE:
		fell.append(KinVoice.cue("no_such_species", mood))
	ok(fell == KinVoice.GENERIC_CUE.values(), "boki_voices: an unknown species falls back (%s)" % [fell])

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
		if not sounds.has(sname) or m < REACH_MIN or m > REACH_MAX:
			wrong.append("%s %.0f m" % [sname, m])
	ok(wrong.is_empty(), "%s: %d sounds with their own reach (wrong: %s)" % [group, reach.size(), wrong])
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

## The garden minigames play literal names (garden_ ones, and any name handed to GardenSfx.cue): a typo would
## play silence.
func _garden_names() -> void:
	var re := RegEx.create_from_string("\"(garden_[a-z0-9_]+)\"|cue\\(\"([a-z0-9_]+)\"")
	var seen := []
	var silent := []
	for f in ["base_race.gd", "base_shove.gd", "base_seek.gd", "base_volley.gd", "base_tumble.gd", "echo_steps.gd",
			"show_ring.gd", "base_relay.gd", "garden_sfx.gd", "home_chimes.gd"]:
		for hit in re.search_all(FileAccess.get_file_as_string("res://scripts/home/" + f)):
			var sname := hit.get_string(1) + hit.get_string(2)
			if sname.ends_with("_"):          # a prefix, completed below
				continue
			seen.append(sname)
			if not Sfx.ensure(sname):
				silent.append(sname)
	var sizes: Array = GardenSfx.SIZE.values()
	var prefixed := {"garden_cheer_": GardenSfx.GRADE.values(), "garden_win_": sizes, "garden_sulk_": sizes,
			"tumble_clash_": BaseTumble.rules()["moves"].keys(),
			"garden_chime_": HomeChimes.KINDS}
	for prefix in prefixed:
		for tail in prefixed[prefix]:
			seen.append(prefix + tail)
			if not Sfx.ensure(prefix + tail):
				silent.append(prefix + tail)
	var named := seen.size() >= 12 and silent.is_empty()
	ok(named, "garden minigames: %d sound names, all exist (silent: %s)" % [seen.size(), silent])

## 7. The ultimate cast cue: heard in range by everyone, ally or rival, from the ult's own position.
func _ult_cues() -> void:
	var names := ["ult_tag_ally", "ult_tag_foe"]
	for arch in Arch.ids():
		if not (Arch.def(arch).get("x", {}) as Dictionary).is_empty():
			names.append(arch + "_ult_cue")
	var wrong := []
	for sname in names:
		var reach: float = Sfx.sound_reach.get(sname, 0.0)
		var carries := reach > Sfx.hear_range and reach <= REACH_MAX and reach == float(Sfx.sound_reach["ult_tag_foe"])
		if not (Sfx.ensure(sname) and carries):
			wrong.append("%s %.0f m" % [sname, reach])
	ok(names.size() == Arch.ids().size() + 2 and wrong.is_empty(),
			"%d ult cues exist and carry (wrong: %s)" % [names.size(), wrong])
	var press := FileAccess.get_file_as_string("res://scripts/arch/hero_ult.gd")
	var cue := FileAccess.get_file_as_string("res://scripts/arch/ult_cue.gd")
	var match_src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var wired := press.contains("UltCue.cast(k)") and cue.contains("\"ucast\"")
	wired = wired and match_src.contains("\"ucast\": UltCue.net_in")
	ok(wired, "HeroUlt.press plays and sends the cue; the match plays others'")
	ok(cue.count("m.sfx(") == 2 and cue.count(", DB)") == 2, "ally and rival tags play at the one level")
## 7. Each target class has its own short layer (Juice plays HitClass.SOUND[class] under the weapon's hit).
func _hit_targets() -> void:
	var set_d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/targets.json"))
	var sounds: Dictionary = set_d.get("sounds", {}) if set_d is Dictionary else {}
	var names := HitClass.SOUND.values()
	var missing := names.filter(func(n): return not sounds.has(n) or not Sfx.ensure(n))
	var all := names.size() == HitClass.WALL + 1 and missing.is_empty()
	ok(all, "hit targets: all %d classes have a sound (missing %s)" % [names.size(), missing])
	var long := []
	for n in names:
		for t in _takes(n):
			if _data(t).size() / 2 > 0.25 * 44100:
				long.append(t.get_file())
	ok(long.is_empty(), "hit targets: every take is under 0.25 s, a layer not a hit (long: %s)" % [long])
## 7. Every Fusion type and form names a cue that has its sound; the release, timeout and evolution cues exist.
func _fusion_cues() -> void:
	var cues := {}
	for t in (MergeForm.data()["types"] as Dictionary).values():
		cues[String(t["cue"])] = true
	for f in DirAccess.get_files_at("res://content/merge_forms"):
		cues[String(MergeForm.kit_form(f.get_basename())["cue"])] = true
	var missing := []
	for c in cues:
		if not Sfx.ensure("boki_fuse_" + c):
			missing.append(c)
	for c in ["boki_fuse_end", "boki_fuse_tired", "boki_evolve"]:
		if not Sfx.ensure(c):
			missing.append(c)
	ok(missing.is_empty() and cues.size() >= 16,
		"%d Fusion cues and the end, tired, evolve sounds on file (missing %s)" % [cues.size(), missing])
## Each sound in WIRED is in a set and its script(s) play it by name.
func _wired() -> void:
	var listed := {}
	for f in DirAccess.get_files_at("res://content/sfx"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
			if d is Dictionary:
				listed.merge(d.get("sounds", {}))
	var unplayed := []
	for sname in WIRED:
		if not listed.has(sname) or not Sfx.ensure(sname):
			unplayed.append(sname + " (no set or file)")
		for f in WIRED[sname]:
			if not FileAccess.get_file_as_string("res://scripts/" + String(f)).contains('"%s"' % sname):
				unplayed.append("%s not in %s" % [sname, f])
	ok(unplayed.is_empty(), "%d warning and Boki sounds are wired %s" % [WIRED.size(), unplayed])

## 5. A Hunter without its own set plays the shared sounds.
func _fallback() -> void:
	var h := Hunter.new()
	h.arch = "no_such_hunter"
	var got := [HeroSfx.of(h, "dash", "dash"), HeroSfx.of(h, "hurt", "")]
	h.free()
	ok(got == ["dash", ""], "no set: the shared dash, and no voice line (%s)" % [got])

## 7. Every Hunter's dash has an air variant that HeroSfx picks with no floor under it, and the no-charge tick exists.
func _dash_air() -> void:
	var h := Hunter.new()
	var picked := {}
	for arch in Arch.ids():
		h.arch = arch
		h.grounded = false
		picked[arch] = HeroSfx.dash_name(h)
		h.grounded = true
		picked[arch] += " " + HeroSfx.dash_name(h)
	h.free()
	# (a Hunter with no dash of its own yet, as Gil, plays the shared dash both ways: item 5's fallback)
	var want := func(a): return "%s_dash_air %s_dash" % [a, a] if Sfx.ensure("%s_dash" % a) else "dash dash"
	var wrong := Arch.ids().filter(func(a): return picked[a] != want.call(a))
	ok(wrong.is_empty(), "%d Hunters: dash in the air and on the ground differ (wrong: %s)" % [picked.size(), wrong])
	ok(Sfx.ensure("dash_empty"), "the no-charge tick exists")
## 8. The garden's beds (docs/AUDIO.md): a simulated two days at 0.25 s steps, rain in the middle of the
## first, the player walking from the pond to far away and back.
func _garden() -> void:
	var beds := ["garden_morning", "garden_midday", "garden_evening", "garden_night", "pond"]
	var missing := []
	for b in beds + ["rain"]:
		if not ResourceLoader.exists("res://audio/amb_%s.ogg" % b):
			missing.append(b)
	ok(missing.is_empty(), "garden: every bed has its file %s" % [missing])
	var picked := {}
	for clock in [0.0, 0.3, 0.5, 0.7, 0.9]:
		picked[HomeAmbience.bed_for(clock, false)] = true
	var rain_bed := HomeAmbience.bed_for(0.5, true)
	ok(picked.size() == 4 and rain_bed == "rain", "garden: four day parts and rain pick beds %s" % [picked.keys()])
	var d := {"layout": {"water": {HomeLayout.key(10, 10): 1}}}
	var by_water := HomeAmbience.pond_level(d, Vector2(10.5, 11.5))
	var far_off := HomeAmbience.pond_level(d, Vector2(40, 40)) + HomeAmbience.pond_level({}, Vector2(10, 10))
	ok(is_equal_approx(by_water, 1.0) and far_off == 0.0, "garden: pond full by the water, silent far off or with none")
	var h := HomeAmbience.new()
	var dt := 0.25
	var t := 0.0
	var peak := 0
	var match_heard := false
	var off_bus := 0
	var pond_far := 0.0
	var pond_near := 0.0
	var watching := ""
	var started := -1.0
	var fade_len := 0.0
	var prev_bed := ""
	for i in int(2.0 * 300.0 / dt):
		t += dt
		var day_t := fmod(t / 300.0 + 0.3, 1.0)
		var raining := t > 100.0 and t < 150.0
		var by_pond := fmod(t, 200.0) < 100.0
		h.tick(dt, day_t, raining, d, Vector3(11.0, 0, 11.0) if by_pond else Vector3(40.0, 0, 40.0))
		Sfx._process(dt)
		var bed := HomeAmbience.bed_for(day_t, raining)
		var lvl := float(h.levels.get(bed, 0.0))
		if bed != prev_bed and prev_bed != "" and watching == "" and fade_len == 0.0:
			watching = bed
		if watching == bed:
			if started < 0.0 and lvl > 0.0:
				started = t
			if lvl >= 1.0:
				fade_len = t - started
				watching = ""
		prev_bed = bed
		peak = maxi(peak, maxi(h.levels.size(), Sfx.amb_layers.size() + (1 if Sfx.amb_name != "" else 0)))
		match_heard = match_heard or Sfx.amb_name == "match" or Sfx.amb_layers.has("match")
		for n in Sfx.amb_layers:
			off_bus += 0 if (Sfx.amb_layers[n]["p"] as AudioStreamPlayer).bus == "Ambience" else 1
		if t > 60.0 and t < 90.0: pond_near = maxf(pond_near, float(h.levels.get("pond", 0.0)))
		if t > 180.0 and t < 200.0: pond_far = maxf(pond_far, float(h.levels.get("pond", 0.0)))
	ok(peak == HomeAmbience.MAX_LOOPS, "garden: %d loops at most at once (peak %d)" % [HomeAmbience.MAX_LOOPS, peak])
	ok(absf(fade_len - HomeAmbience.BED_FADE_S) <= 1.0, "garden: a new day part fades in over 20 s (%.1f)" % fade_len)
	ok(pond_near >= 0.99 and pond_far == 0.0, "garden: pond up by water %.2f, off far %.2f" % [pond_near, pond_far])
	ok(off_bus == 0, "garden: every bed is on the Ambience bus, so the ambience volume setting governs it")
	ok(not match_heard, "garden: never plays amb_match")
	var src := ""
	for f in DirAccess.get_files_at("res://scripts/home"):
		if f.ends_with(".gd"):
			src += FileAccess.get_file_as_string("res://scripts/home/" + f)
	var asks_match := src.contains("amb_match") or src.contains("play_ambience(\"match\")")
	ok(not asks_match, "garden: no script of scripts/home asks for the match ambience")
	Sfx.clear_amb_layers(0.0)
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

## 7. Every sound a glove names in its content (cast, an effect's "sfx" / "hit_sfx") exists, and at least the
## first four gloves (Blink, Barrier, Hook, Rocket) have their own.
func _gloves() -> void:
	var names := {}
	var own := []
	for id in Gear.ALL:
		var g: Dictionary = Gear.ALL[id]
		if g.has("sfx"):
			own.append(id)
		_glove_names(g, names)
	var silent := names.keys().filter(func(n): return not Sfx.ensure(String(n)))
	ok(silent.is_empty(), "gloves: every named sound exists (silent: %s)" % [silent])
	var first := ["blink", "barrier", "grapple", "rocket"]
	var have_first: bool = first.all(func(id): return own.has(id))
	ok(have_first, "gloves: Blink, Barrier, Hook and Rocket have their own sounds (%d do)" % own.size())

func _glove_names(node, names: Dictionary) -> void:
	if node is Dictionary:
		for k in node:
			if k in ["sfx", "hit_sfx", "cast"] and node[k] is String and node[k] != "":
				names[node[k]] = true
			else:
				_glove_names(node[k], names)
	elif node is Array:
		for v in node:
			_glove_names(v, names)
## 6. Every sound UiSfx plays by name has a file, so a typo never plays silence.
func _ui_cues() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/ui_sfx.gd")
	var re := RegEx.create_from_string('"([a-z_]+)"')
	var names := {}
	for hit in re.search_all(src):
		names[hit.get_string(1)] = true
	var missing := []
	for n in names:
		if _takes(String(n)).is_empty():
			missing.append(n)
	ok(names.size() >= 8 and missing.is_empty(), "UiSfx: %d cues all have a file %s" % [names.size(), missing])
## 7. Pickups by item category (content/rules/pickup_sfx.json): every category, gear kind, treasure, belt
## item and ground kind maps to a sound that exists, and the key cue is kept.
func _pickups() -> void:
	var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PickupSfx.RULES))
	var cats: Dictionary = r["cues"]
	var cues := cats.values()
	for c in (r["gear_kind"] as Array) + [r["valuable"], r["belt"]] + (r["kinds"] as Dictionary).values():
		ok(cats.has(c), "pickup category %s has a cue" % c)
	var kinds := Gear.SLOT_NAMES.size()
	ok((r["gear_kind"] as Array).size() == kinds, "a pickup category for each of the %d gear kinds" % kinds)
	var silent := cues.filter(func(s): return not Sfx.ensure(String(s)))
	ok(silent.is_empty(), "every pickup category has its sound file (missing %s)" % [silent])
	ok(Sfx.ensure("key_get"), "the key cue key_get is kept")
	var wrong := []
	for gid in Gear.ALL:
		if not cues.has(PickupSfx.of_gear(String(gid))):
			wrong.append(gid)
	for vid in Loot.VALUABLES:
		if not cues.has(PickupSfx.of(Loot.valuable(String(vid)))):
			wrong.append(vid)
	for iid in UtilityBelt.ALL:
		if not cues.has(PickupSfx.of_kind(String(iid))):
			wrong.append(iid)
	ok(wrong.is_empty(), "every gear piece, treasure and belt item has a cue (%s)" % [wrong])
	ok(Sfx.ensure("use_tonic") and Sfx.ensure("use_armor_kit"), "tonic drink and armour-kit repair have own sounds")

## Does calling play() make the named sound start (it stamps Sfx.last_played)?
func _plays(sname: String, act: Callable) -> bool:
	Sfx.last_played.erase(sname)
	act.call()
	return Sfx.last_played.has(sname)

## 10. The build and decorate cues.
func _build_cues() -> void:
	var names := ["build_pick", "build_rotate", "build_place_wood", "build_place_stone", "build_store",
			"build_move", "build_blocked"]
	var silent := names.filter(func(n): return not Sfx.ensure(n))
	ok(silent.is_empty(), "build cues: %d sounds exist (silent: %s)" % [names.size(), silent])
	var made := [BuildSfx.placed_name("fence", false), BuildSfx.placed_name("stone_wall", false),
			BuildSfx.placed_name("stone_wall", true)]
	ok(made == ["build_place_wood", "build_place_stone", "build_move"],
			"build cues: wood or stone by material, a move is its own (%s)" % [made])
	var stone_ids: Array = BuildSfx.rules()["stone"]
	var unknown := stone_ids.filter(func(i): return not HomeLayout.CATALOG.has(i))
	ok(unknown.is_empty(), "build cues: every stone piece is in the catalog (unknown: %s)" % [unknown])
	var knock := func(spot): return _plays("build_blocked", func(): BuildSfx.blocked(spot))
	var spots := [knock.call("check_a"), knock.call("check_a"), knock.call("check_b"), knock.call("check_b")]
	ok(spots == [true, false, true, false], "build cues: one knock per attempt, then silent on that spot %s" % [spots])
	BuildSfx.quiet = true
	var hushed := [_plays("build_pick", BuildSfx.picked), _plays("build_store", BuildSfx.stored),
			_plays("build_rotate", BuildSfx.rotated)]
	BuildSfx.quiet = false
	ok(hushed == [false, false, true], "build cues: quiet mutes pick and store, not the turn %s" % [hushed])
	var wired := []
	for f in ["home_build.gd", "decorate.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/home/" + f)
		for cue in ["picked()", "rotated()", "placed(", "stored()", "blocked("]:
			var needle: String = "BuildSfx." + cue
			if not src.contains(needle):
				wired.append("%s %s" % [f, needle])
	ok(wired.is_empty(), "build cues: farm and house play them all (missing %s)" % [wired])

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

## 7. The heartbeat: silent at the line, beating just under it (the first beat at once), faster the lower the
## share, and silent again on a heal over the line, a down or out. Beats counted over 10 s of 60 fps frames.
func _low_hp() -> void:
	var cue := LowHpCue.new()
	var line := float(Content.rules(LowHpCue.RULES)["start_share"])
	var at_line := _beats(cue, line, 10.0)
	ok(at_line == 0 and not cue.active, "heartbeat: silent at the line (%.2f of max health and armour)" % line)
	var just := _beats(cue, line - 0.01, 10.0)
	var want := int(ceil(10.0 * cue.bpm(line - 0.01) / 60.0))
	ok(cue.active and just == want, "heartbeat: starts just under the line, %d beats in 10 s" % just)
	var low := _beats(cue, line * 0.2, 10.0)
	ok(low > just, "heartbeat: faster as health drops (%d beats in 10 s near empty)" % low)
	ok(_beats(cue, line + 0.01, 10.0) == 0 and not cue.active, "heartbeat: stops when you heal back over the line")
	_beats(cue, 0.1, 1.0)
	var was := cue.active
	ok(was and _beats(cue, 1.0, 1.0) == 0 and not cue.active, "heartbeat: stops when downed or out (a full share)")
	var wav := "res://audio/%s.wav" % LowHpCue.SOUND
	var on: bool = Settings.DEFAULTS["low_hp_pulse"]
	ok(on and FileAccess.file_exists(wav), "heartbeat: on by default, sound on file")

func _beats(cue: LowHpCue, s: float, secs: float) -> int:
	var n := 0
	for i in int(secs * 60.0):
		if cue.step(s, 1.0 / 60.0):
			n += 1
	return n
## 9. The garden's Boki voices: the cap, the self gap, earshot and the sulk edge.
func _voices() -> void:
	HomeVoice._until.clear()
	HomeVoice._last.clear()
	var at := Sfx.listener + Vector3(2, 0, 0)
	var far := Sfx.listener + Vector3(Sfx.hear_range + 5.0, 0, 0)
	var recs := []
	for i in 6:
		recs.append({"uid": "voice_test_%d" % i, "species": "no_such_species", "name": "T%d" % i})
	HomeVoice.say(recs[5], "happy", far)
	ok(HomeVoice._until.is_empty(), "voices: a Boki past earshot takes no slot")
	for i in 5:
		HomeVoice.say(recs[i], "happy", at)
	ok(HomeVoice._until.size() == HomeVoice.MAX_VOICES, "voices: five Bokis at once sound %d" % HomeVoice._until.size())
	HomeVoice._until.clear()
	HomeVoice.say(recs[0], "happy", at)
	ok(HomeVoice._until.is_empty(), "voices: the same Boki twice inside its gap speaks once")
	recs[1]["needs"] = {"food": 5.0, "energy": 80.0, "joy": 70.0, "clean": 75.0}
	var k := {"rec": recs[1], "pos": at}
	HomeVoice._last.clear()
	HomeVoice.sulk_edge(k, "food")
	var sulked := HomeVoice._until.size()
	HomeVoice._until.clear()
	HomeVoice._last.clear()
	HomeVoice.sulk_edge(k, "food")
	ok(sulked == 1 and HomeVoice._until.is_empty(), "voices: a need gone urgent sulks once (%d, then none)" % sulked)
	HomeVoice._until.clear()
	HomeVoice._last.clear()
