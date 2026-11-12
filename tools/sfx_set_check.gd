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
##  10. the build and decorate cues (BuildSfx): pick, rotate, place by material, move, store and blocked exist;
##      the knock plays once per attempt (not again on the same spot); a pick-up inside a turn or a store is quiet;
##      the farm's build mode and the house's decorating play them
##  11. mobs and bosses: every kind that attacks has its own mob_<kind>_atk and _hit, each boss its _tell,
##      and no sound played by mob.gd or boss.gd is a Boki cue (k_*), so a Boki rename cannot silence them
## Reads the files only; never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MIN := 5.0         # m: below this a sound would not carry past its own source
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
	_dash_air()
	_fallback()
	_ult_cues()
	_wisp_cues()
	_garden_names()
	_garden()
	_build_cues()
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
	if group == "mob":
		_check_mobs(sounds)

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

## 11. Mob and boss attack sounds are their own (mob_*, boss_*), not borrowed Boki cues.
func _check_mobs(sounds: Dictionary) -> void:
	var gaps := []
	for kind in Data.MOBS:
		if kind.begins_with("bl_") or Data.BOSSES.has(kind) or Data.MOBS[kind]["attack"] == "none": continue
		for part in ["atk", "hit"]:
			if not sounds.has("mob_%s_%s" % [kind, part]): gaps.append("mob_%s_%s" % [kind, part])
	for kind in Data.BOSSES:
		if not sounds.has("boss_%s_tell" % kind): gaps.append("boss_%s_tell" % kind)
	ok(gaps.is_empty(), "every attacking mob has a cue and impact, every boss a wind-up tell (missing %s)" % [gaps])
	var re := RegEx.create_from_string("sfx\\(\"([a-z0-9_]+)\"[,)]")
	var borrowed := []
	for f in ["mob.gd", "boss.gd"]:
		for hit in re.search_all(FileAccess.get_file_as_string("res://scripts/match/" + f)):
			var sname := hit.get_string(1)
			if sname.begins_with("k_") or not Sfx.ensure(sname): borrowed.append(sname)
	ok(borrowed.is_empty(), "mob.gd and boss.gd play no k_ cue and only sounds that exist (%s)" % [borrowed])

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

## 7. The Boki wisp cues (KinSummon): a chirp for every body size, higher for a smaller one, and the
## summon burst, end and killed cue per size (audible at 25 m), ready and grab, all in the boki set.
func _wisp_cues() -> void:
	var boki: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/boki.json"))["sounds"]
	var sizes := {}
	for row in (KinSummon.rules()["table"] as Dictionary).values():
		for size in row:
			sizes[size] = true
	var missing := []
	for size in sizes:
		var ks := KinSpec.new()
		ks.size = size
		if not boki.has(KinSummon.chirp_name(ks)):
			missing.append(size)
	for cue in ["wisp_ready", "wisp_grab"]:
		if not boki.has(cue):
			missing.append(cue)
	for what in ["burst", "end", "killed"]:
		for size in sizes:
			var cue := "summon_%s_%s" % [what, size]
			if not boki.has(cue):
				missing.append(cue)
			elif not _carries(cue):
				missing.append(cue + " at 25 m")
	var what := "wisp cues: a chirp per body size, summon burst/end/killed per size, ready, grab (missing %s)"
	ok(missing.is_empty() and sizes.size() == 3, what % [missing])
	var weight := []
	for what_cue in ["burst", "end", "killed"]:
		weight.append(_data("res://audio/summon_%s_small.wav" % what_cue).size())
		weight.append(_data("res://audio/summon_%s_large.wav" % what_cue).size())
	var longer := "a large summon cue runs longer than a small one (bytes %s)"
	ok(weight[1] > weight[0] and weight[3] > weight[2] and weight[5] > weight[4], longer % [weight])
	var pitch := []
	for size in ["small", "medium", "large"]:
		pitch.append(_zero_crossings(_data("res://audio/wisp_chirp_%s.wav" % size)))
	var order := "wisp chirps rise as the body gets smaller (zero crossings %s)"
	ok(pitch[0] > pitch[1] and pitch[1] > pitch[2], order % [pitch])

## The sound is in a set's reach and still audible (not NAN, above -24 dB) 25 m from the listener: a rival's summon.
func _carries(cue: String) -> bool:
	var db: float = Sfx._distance_db(Vector3(25, 0, 0), float(Sfx.sound_reach.get(cue, 0.0)))
	return not is_nan(db) and db > -24.0

## Sign changes in a wav's samples: a cheap stand-in for its pitch.
func _zero_crossings(data: PackedByteArray) -> int:
	var n := 0
	var prev := 0
	for k in data.size() / 2:
		var v := data.decode_s16(k * 2)
		if (v < 0) != (prev < 0):
			n += 1
		prev = v
	return n

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
## 7. The garden's beds (docs/AUDIO.md): a simulated two days at 0.25 s steps, rain in the middle of the
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
