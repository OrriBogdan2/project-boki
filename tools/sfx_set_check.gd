extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md).
##   1. every listed sound has a file (audio/<name>.wav or its takes <name>_1..4.wav)
##   2. every take sits at its category's loudness (content/rules/sfx_levels.json) and under the peak ceiling
##   3. a Hunter set has its wordless voice (hurt, down, death), its dash, footsteps on every surface,
##      at least one weapon "fire" sound and its listed signature sounds, and HeroSfx picks them up
##      and its signature weapon's JSON names one of them (no stock sound)
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
##  11. boki_voices: every species the game can show (Data.KIN: the wild, the starters, the mystery egg's pool,
##      the rare boss kin) has all five moods with two takes and KinVoice.cue picks them (a shown species on a
##      shared cue fails), an unknown species falls back to the shared cues, and no two species share a happy take
##  11. the farm's chop and mine sounds (axe, creak, tree fall, pick, crack, break) exist and are wired in HomeGather
##  11. the rarity stings (RaritySting): rare and very rare each have a sound, quieter than the scan chime,
##      a common Boki has none, and the match (first sight), Capture (claim) and EggHatch (hatch) play them
##  11. Meeko's Hearth Call channel loop (tend_call_loop): it plays on her and quieter on the ally, one of each
##      even when X is pressed again, and it is gone within one frame of every way the channel can end
## Reads the files (and, for the Hearth Call loop, one short training match); never touches the save.
##  11. the rival-cast layer (HostileCue): every Hunter's E and R start it once; a rival's cast plays it, an ally's
##      does not, nor a rival's past its 30 m; E, R and X (UltCue) and other games' casts are wired to it

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MIN := 5.0         # m: below this a sound would not carry past its own source
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const FALL_TOL_S := 0.05       # s: how far a fall cue may differ from the fall it sounds under
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
	_nuke_fall()
	_garden_names()
	_garden()
	_build_cues()
	_strip_chime()
	_chop_mine()
	_rarity_stings()
	await _call_loop(main)
	_hostile()
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
	if group == "boki_voices":
		_boki_voices(d["sounds"])

## 11. A voice set per shown species (Data.KIN): five moods, two takes each, picked by KinVoice.cue; a shown
## species on a shared cue fails, an unknown one falls back.
func _boki_voices(sounds: Dictionary) -> void:
	var gaps := []
	var same := []
	var seen := {}
	for sp in Data.KIN:
		for mood in KinVoice.GENERIC_CUE:
			var want := "bk_%s_%s" % [sp, mood]
			if not sounds.has(want) or _takes(want).size() != 2 or KinVoice.cue(sp, mood) != want:
				gaps.append(want)
		var sig := hash(_data("res://audio/bk_%s_happy.wav" % sp))
		if seen.has(sig):
			same.append("%s = %s" % [sp, seen[sig]])
		seen[sig] = sp
	var what := "boki_voices: %d shown species, 5 moods, 2 takes, none on a shared cue" % Data.KIN.size()
	ok(gaps.is_empty() and not Data.KIN.is_empty(), "%s (gaps %s)" % [what, gaps])
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
	var wid := Arch.signature(arch)
	var wdef: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/weapons/%s.json" % wid))
	var wsfx := String((wdef["primary"] as Dictionary).get("sfx", ""))
	ok(sounds.has(wsfx), "%s: signature weapon %s plays its own %s, not a stock sound" % [arch, wid, wsfx])
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
			"show_ring.gd", "base_relay.gd", "garden_sfx.gd", "home_chimes.gd", "egg_sfx.gd"]:
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

## Cinderfall's whistle runs the whole fall: its length matches x.delay from the archetype data within FALL_TOL_S,
## it carries past hearing range, and the kit plays it where the shell will land.
func _nuke_fall() -> void:
	var delay := float(Arch.def("gunslinger")["x"]["delay"])
	var b := FileAccess.get_file_as_bytes("res://audio/vn_nuke_fall.wav")
	var secs := float(_data("res://audio/vn_nuke_fall.wav").size() / 2) / float(b.decode_u32(24))
	var what := "vn_nuke_fall is %.3f s, the fall is %.2f s (within %.0f ms)"
	ok(absf(secs - delay) <= FALL_TOL_S, what % [secs, delay, FALL_TOL_S * 1000.0])
	ok(float(Sfx.sound_reach.get("vn_nuke_fall", 0.0)) > Sfx.hear_range, "vn_nuke_fall carries past hearing range")
	var ult := FileAccess.get_file_as_string("res://scripts/arch/kits/gunslinger_ult.gd")
	ok(ult.contains("m.sfx(\"vn_nuke_fall\", at"), "the kit plays vn_nuke_fall at the landing point on the cast")

## 11. A rival's cast is heard as a threat; yours and your allies' are not.
func _hostile() -> void:
	var reach: float = Sfx.sound_reach.get(HostileCue.NAME, 0.0)
	var near_30 := reach >= 25.0 and reach <= 35.0
	ok(Sfx.ensure(HostileCue.NAME) and near_30, "the rival-cast layer exists, reach %.0f m" % reach)
	var h := Hunter.new()
	var once := []
	for arch in Arch.ids():
		var k := ArchKit.new()
		k.d = Arch.def(arch)
		h.ak = k
		var r_slots := ["ult_fuse", "ult"] if k.fuse_time() > 0.0 else ["ult"]
		var r_n := r_slots.filter(func(s): return HostileCue.starts_threat(h, s)).size()
		var others := ["secondary", "dodge", "primary", "ultimate"]
		var quiet := others.all(func(s): return not HostileCue.starts_threat(h, s))
		if HostileCue.starts_threat(h, "kin") and (k.r_def().is_empty() or r_n == 1) and quiet:
			once.append(arch)
	h.ak = null
	ok(once.size() == Arch.ids().size(),
			"%d Hunters: E and R each start the layer once, RMB and dash never (%s)" % [Arch.ids().size(), once])
	var you := Hunter.new()
	you.team = 1
	Sfx.listener = Vector3.ZERO
	var heard := func(team: int, at: Vector3) -> bool:
		var before := int(Sfx.last_played.get(HostileCue.NAME, -1))
		h.team = team
		h.pos = at
		HostileCue.play(you, h)
		return int(Sfx.last_played.get(HostileCue.NAME, -1)) != before
	var ally: bool = heard.call(1, Vector3(5, 0, 0))
	var far: bool = heard.call(2, Vector3(40, 0, 0))
	var rival: bool = heard.call(2, Vector3(5, 0, 0))
	ok(rival and not ally, "a rival's cast at 5 m plays the layer, an ally's does not (%s, %s)" % [rival, ally])
	ok(not far, "a rival's cast at 40 m does not")
	h.free()
	you.free()
	var hunter_src := FileAccess.get_file_as_string("res://scripts/match/hunter.gd")
	var cue_src := FileAccess.get_file_as_string("res://scripts/arch/ult_cue.gd")
	var match_src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var used := hunter_src.contains("HostileCue.on_used(self, slot)")
	var x := cue_src.contains("HostileCue.play(m.player, h)")
	var net := match_src.contains("\"hcast\": HostileCue.net_in")
	ok(used and x and net, "E and R (ability_used), X (UltCue) and other games' casts (hcast) play it")

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

## 11. Meeko's channel loop, one training match per end path.
const END_PATHS := ["time", "ally out of reach", "stun", "knock", "dead", "ally dead", "merge"]
const FRAME := 1.0 / 60.0

func _call_loop(main: Node) -> void:
	for path in END_PATHS:
		var m := Match.new()
		main.add_child(m)
		m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"cls": Arch.weight("tender"), "arch": "tender", "weapon": Arch.signature("tender")})
		m.set_process(false)
		var P: Hunter = m.player
		P.set_arch("tender")
		P.lvl = 6
		var mate_at := P.pos + Vector3(-2.5, 0, 1.5)
		var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, mate_at, {"arch": "none"})
		var K: TenderKit = P.ak
		P.inp["aim"] = A.pos
		HunterKeys.ult_pressed(P)
		m.step(FRAME)
		var key := "call%d" % P.get_instance_id()
		var up := not K.hearth_call.is_empty() and Sfx.loop_on(key) and Sfx.loop_on(key + "_ally")
		ok(up, "channel loop (%s): it sounds on her and the ally once the call starts" % path)
		if up:
			var quieter := float(Sfx.loops[key]["vol"]) > float(Sfx.loops[key + "_ally"]["vol"])
			ok(quieter, "channel loop (%s): the ally's is quieter" % path)
			HunterKeys.ult_pressed(P)
			m.step(FRAME)
			var n := Sfx.loops.keys().filter(func(k): return String(k).begins_with(key)).size()
			ok(n == 2, "channel loop (%s): X again does not stack a second loop (%d)" % [path, n])
		match path:
			"ally out of reach": A.teleport(P.pos + Vector3(-30.0, 0, 0))
			"stun": P.stun_t = 0.5
			"knock": m.knock(P, null, {})
			"dead": m.eliminate(P, null, "test", true)
			"ally dead": A.out = true
			"merge": K.drop_holds()
		var frames := 0
		while not K.hearth_call.is_empty() and frames < 600:
			m.step(FRAME)
			frames += 1
		ok(frames < 600 and not Sfx.loop_on(key) and not Sfx.loop_on(key + "_ally"),
			"channel loop (%s): both loops are gone the frame the channel ends (%d frames in)" % [path, frames])
		m.queue_free()
		await main.get_tree().process_frame

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

## 11. The tutorial strip's new-objective chime: a sound of the UI set, with its two levels in the table.
func _strip_chime() -> void:
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))["sounds"]
	var has_it: bool = ui.has(TutorialStrip.CHIME) and Sfx.ensure(TutorialStrip.CHIME)
	ok(has_it, "strip chime: %s is in the UI set and has its file" % TutorialStrip.CHIME)
	var cue: Dictionary = levels.get("cue_db", {})
	ok(cue.has("objective") and cue.has("objective_fight") and float(cue["objective_fight"]) < float(cue["objective"]),
			"strip chime: sfx_levels has the calm and the ducked level %s" % [cue])
	ok(_plays(TutorialStrip.CHIME, TutorialStrip.chime), "strip chime: plays through Sfx")


## 11. Rare and very rare Boki have a sting each; a common one plays nothing; each is under the scan chime.
func _rarity_stings() -> void:
	var rare: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	var common: String = Data.common_kin()[0]
	var tiers := [RaritySting.tier(common, {}), RaritySting.tier(rare[0], {}) if not rare.is_empty() else -1,
			RaritySting.tier(common, {"shimmer": true})]
	ok(tiers == [0, 1, 2], "rarity tiers: common 0, a rare species 1, a shimmer 2 %s" % [tiers])
	var names: Array = RaritySting.NAMES.slice(1)
	var quiet := RaritySting.DB.slice(1).all(func(db): return db < 0.0) and RaritySting.DB[1] <= RaritySting.DB[2]
	ok(names.all(func(n): return Sfx.ensure(n)) and quiet, "rarity stings exist, under the scan chime %s" % [names])
	var src := {"scripts/match/music_dir.gd": "stings.tick(", "scripts/match/capture.gd": "RaritySting.claim(",
			"scripts/ui/egg_hatch.gd": "RaritySting.play("}
	var unwired := src.keys().filter(func(f): return not FileAccess.get_file_as_string("res://" + f).contains(src[f]))
	ok(unwired.is_empty(), "rarity stings: first sight, claim and hatch play them (unwired %s)" % [unwired])
	ok(RaritySting.SIGHT_M == 30.0 and RaritySting.LOUD_HEAT < 1.0, "rarity stings: within 30 m, held in a loud fight")

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

## 11. The farm's chop and mine: the set has the axe and pick in several takes, and every sound HomeGather
## plays by literal name exists (the old stand-ins, break_wood / armor_hit / thump, are not used there).
func _chop_mine() -> void:
	ok(_takes("axe_bite").size() >= 3 and _takes("pick_strike").size() >= 3,
			"chop: the axe bite and pick strike come in 3 takes")
	var re := RegEx.create_from_string("Sfx\\.play\\(\"([a-z0-9_]+)\"")
	var src := FileAccess.get_file_as_string("res://scripts/home/home_gather.gd")
	var played := []
	for hit in re.search_all(src):
		played.append(hit.get_string(1))
	var silent := played.filter(func(n): return not Sfx.ensure(n))
	ok(silent.is_empty(), "chop: every sound HomeGather plays exists (silent: %s)" % [silent])
	var own := ["axe_bite", "trunk_creak", "tree_down", "pick_strike", "rock_crack", "rock_break"]
	var wired: bool = own.all(func(n): return src.contains('"%s"' % n))
	ok(wired and not src.contains("break_wood") and not src.contains("armor_hit"),
			"chop: the axe, creak, fall, pick, crack and break are wired; no stand-ins")
