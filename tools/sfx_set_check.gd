extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md).
##   1. every listed sound has a file (audio/<name>.wav or its takes <name>_1..4.wav)
##   2. every take sits at its category's loudness (content/rules/sfx_levels.json) and under the peak ceiling
##   3. a Hunter set has its wordless voice (hurt, down, death), its dash, footsteps on every surface,
##      at least one weapon "fire" sound and its listed signature sounds, and HeroSfx picks them up
##      and its signature weapon's JSON names one of them (no stock sound)
##   4. every cue that Hunter's kit emits (m.sfx, payoff and armed sounds, content/vfx moves, the charge-hold
##      tick and ping) is one of its own
##   5. a Hunter with no set falls back to the shared sounds
##   6. "reach" (metres a sound carries) names sounds of the set, between REACH_MIN and REACH_MAX;
##      every sound under "loops" repeats seamlessly (no fade at either end, the seam no bigger than a step)
##   7. every Hunter's ultimate has a positional cast cue (<arch>_ult_cue, with a reach past hearing range)
##      and the two team tags carry as far; HeroUlt.press plays it and the match plays it for other players' casts;
##      the rival telegraph wind-up (TellCue, tell_foe) exists, has a repeat gap, sits under the ult cues and is
##      wired into the telegraph systems (ArchKit.tele_circle/tele_lane, AimDraw.put)
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
##  12. held fire (docs/AUDIO.md): every weapon under FireSfx.HELD_RATE, and Neve's dart, fired every HELD_STEP_MS for
##      HELD_S seconds through FireSfx keeps at most FireSfx.VOICES voices sounding, opens on its base take and goes
##      round three or more others without repeating one
##  13. the rank HUD's cues (RankSfx) are in the ui set, play at least UNDER_COMBAT_DB under a weapon shot,
##      and the new-point chime is short
##  14. every Boki species' type has its cast cue k_<type> (KinLib.cue_of), and the six old k_ names are gone
##  15. a Boki type's ability impact ki_<type> (content/rules/boki_impact.json): all 19 types map to the take set of
##      their cast cue, Sfx loads it, only a Kin's k1/k2/zone hits play it
##  16. every breakable material breaks with its own sound in 3 takes or more, a powder keg has its own fuse hiss
##      (as long as its fuse) and blast, and every chest tier opens with its own lid creak (content/sfx/breakables.json)
##  17. the world's cues outside the kits (mobs, pickups, gloves, utilities, garden games, Ways Out):
##      tools/sfx_world_cues.gd
##  18. falloff sized to the match view: a cue at the screen's side edge is heard (full-ish level, not muffled),
##      one 10 m past it is quieter, one past ~30 m is silent
##  19. every Fusion type and form names a cue with a boki_fuse_<cue> sound; the end, tired and evolve cues exist;
##      every form file names its own cast, travel and hit sounds (MergeSfx), all on file
##  20. every Hunter with a meter has its own resource-full tell (<arch>_tell) that carries past hearing range,
##      and ArchKit._tells plays it; every kit file that emits a cue is walked by item 4
##  21. mobs and bosses: every kind that attacks has its own mob_<kind>_atk and _hit, each boss its _tell,
##      and no sound played by mob.gd, boss.gd or blight.gd is a Boki cue (k_*), so a Boki rename cannot silence them
##  22. footsteps: a Hunter walked over every surface of the Hollow Crown (the sky train's car deck; a plank
##      bridge tile laid on it) plays the cue for it: its own set on grass, stone, wood and snow, the
##      weight class's steps on metal, a little louder the heavier it is; farm wading has a set per class
##  23. the Training Grounds (TrainingSfx): every cue is a sound of the training set with its own file (a shared
##      fallback such as "revive" fails), the stations and the duel ring play them, the count-in plays 3-2-1 and
##      one horn, the expanse has the full wind and a sky island less of it under its own bed, the beds sit on
##      the Ambience bus, and the grounds never play the match's beds
##  24. the garden's moments (SFX_AUDIT row 22) each play their own cue, never the stock unlock: an egg laid or
##      ready, two Boki becoming friends (once, as the bond reaches friend_at), a lean's new fleck or a part, a
##      Crown cup on the result card, an evolution; the evolution scene, the Nook egg and the incubator name theirs
##  25. each of the 12 Hunters with its own voice has every callout (HunterBarks.KINDS, content/sfx/barks.json),
##      HeroSfx picks them, the Boki-down call carries past hearing range, and the match and KinNet report to it
## Reads the files only; never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MIN := 5.0         # m: below this a sound would not carry past its own source
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const FALL_TOL_S := 0.05       # s: how far a fall cue may differ from the fall it sounds under
const HELD_S := 3.0            # s of held fire per sound
const HELD_STEP_MS := 80       # ms a round: the source cadence of Vex's rifle (main has 0.12 s)
# m.sfx("x"), armed_fx(word, slot, "x") and payoff_fx(at, word, col, "x"): the sound is group 1 (empty = shared)
const CUE_CALLS := "(?:\\.sfx\\(|armed_fx\\([^,)]*,[^,)]*,\\s*|payoff_fx\\([^,]+,[^,]+,[^,]+,\\s*)\"([a-z0-9_]*)\""
# the Hunters whose weapon or kit winds up a charge: ArchKit plays <arch>_charge_tick and <arch>_charge_full
const CHARGERS := ["archer", "mage", "gunslinger", "juggernaut", "bulwark", "dolm", "ostra", "thief"]
const TELL_REACH_MAX := 30.0  # m: the resource-full tell is for foes nearby (12-25 m), not across the island
const SEAM_MAX := 0.05         # the jump at a loop's seam, as a share of full scale
const UNDER_COMBAT_DB := 10.0  # dB: a rank cue as played sits at least this far under a weapon shot ("fire")
const READY_SECS := 0.5        # s: the new-point chime's audible length at most

var bad := 0
var walked := {}               # kit file -> true once item 4 has read it
var levels := {}

func ok(cond: bool, what: String) -> void:
	print("SFXSET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
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
	_fallback()
	_ult_cues()
	_nuke_fall()
	_garden_names()
	_garden()
	_build_cues()
	_strip_chime()
	await _held_fire(main)
	_rank_cues()
	_boki_cues()
	_boki_impacts()
	_breakables()
	preload("res://tools/sfx_world_cues.gd").new().run(ok)
	_falloff()
	_fusion_cues()
	_res_tells()
	_unwalked()
	await _steps(main)
	_training()
	_garden_moments()
	_barks()
	print("SFXSET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _boki_cues() -> void:
	var missing := []
	for id in KinLib.kin_ids():
		var cue := KinLib.cue_of(String(KinLib.species(id).get("type", "")))
		if _takes(cue).is_empty() and not missing.has(cue):
			missing.append(cue)
	ok(missing.is_empty(), "every Boki type has a cast cue file %s" % str(missing))
	var no_cue := KinLib.TYPES.filter(func(t): return _takes("k_" + t).is_empty())
	ok(KinLib.TYPES.size() == 19 and no_cue.is_empty(), "each of the 19 types has a cast cue %s" % str(no_cue))
	var mapped := KinLib.cue_of("shadow") == "k_dark" and KinLib.cue_of("ghost") == "k_ghost"
	ok(mapped, "shadow maps to k_dark, ghost to k_ghost")
	var types := {}
	for theme in KinLib.TYPE_OF_THEME:
		types[KinLib.TYPE_OF_THEME[theme]] = true
	ok(types.size() == KinLib.TYPE_OF_THEME.size(), "each theme maps to its own type (%d)" % types.size())

func _boki_impacts() -> void:
	var r := BokiImpact.rules()
	var types: Dictionary = r.get("types", {})
	var bad := KinLib.TYPES.filter(func(t): return not _impact_ok(types, t))
	ok(types.size() == 19 and bad.is_empty(), "each of the 19 types has impact ki_<type> on its cast set %s" % [bad])
	var gone := KinLib.kin_ids().filter(func(id): return BokiImpact.cue_of(_type_of(id)) == "")
	ok(gone.is_empty(), "every Boki species resolves to an impact %s" % str(gone))
	ok(BokiImpact.cue_of("no_such_type") == "ki_normal", "an unknown type takes the default impact")
	var kin := Kin.new()
	var yes := [{"src": "kin", "ab": "k1"}, {"src": "kin", "ab": "zone"}]
	var no := [{"src": "kin", "ab": "recall"}, {"src": "abil", "ab": "k1"}]
	ok(yes.all(func(o): return BokiImpact.is_boki_ability_hit(kin, o)), "a Boki's k1 and zone hits get a type impact")
	ok(not no.any(func(o): return BokiImpact.is_boki_ability_hit(kin, o)), "...its strike and a Hunter's do not")
	kin.free()
	var caps := [Sfx.IMPACT_GAP, Sfx.STACK_MAX]
	ok(caps[0] >= 60 and caps[1] <= 4, "impacts keep their own gap (%d ms) and the stack cap (%d)" % caps)

func _impact_ok(types: Dictionary, t: String) -> bool:
	return String(types.get(t, "")) == "ki_" + t and not _takes("k_" + t).is_empty() and Sfx.ensure("ki_" + t)

func _type_of(id: String) -> String:
	return String(KinLib.species(id).get("type", ""))

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
	_kit_names(arch, d.get("kit_files", []), sounds)

## 4. Every sound a kit emits is the Hunter's own, never a shared fallback (a typo plays silence, a stock name
## plays another game's sound). The cues are the literal names in <arch>_kit.gd plus the helper files the set
## lists under "kit_files" (paths under scripts/arch/kits/): m.sfx("..."), the sound of payoff_fx and armed_fx
## (an empty one falls back to the shared crit/ready), and the "sfx" of every move in content/vfx/<arch>.json.
func _kit_names(arch: String, extra: Array, own: Dictionary) -> void:
	var re := RegEx.create_from_string(CUE_CALLS)
	var holes := []
	for f in ["%s_kit.gd" % arch] + extra:
		walked[String(f)] = true
		var path := "res://scripts/arch/kits/" + String(f)
		if not FileAccess.file_exists(path):
			ok(false, "%s: kit file %s exists" % [arch, f])
			continue
		for hit in re.search_all(FileAccess.get_file_as_string(path)):
			_cue(hit.get_string(1), "%s:%s" % [f, hit.get_string(1)], own, holes)
	var vfx := "res://content/vfx/%s.json" % arch
	var moves := {}
	if FileAccess.file_exists(vfx):
		moves = JSON.parse_string(FileAccess.get_file_as_string(vfx)).get("moves", {})
	for mv in moves:
		for e in moves[mv].get("sfx", []):
			_cue(String(e["n"]), "move %s:%s" % [mv, e["n"]], own, holes)
	for w in (["_charge_tick", "_charge_full"] if arch in CHARGERS else []):
		_cue(arch + w, "charge hold " + w, own, holes)
	ok(holes.is_empty(), "%s: every cue its kit emits is its own sound and exists (holes: %s)" % [arch, holes])

func _cue(sname: String, what: String, own: Dictionary, holes: Array) -> void:
	if (not own.has(sname) or not Sfx.ensure(sname)) and not holes.has(what):
		holes.append(what)

## 11. Mob and boss attack sounds are their own (mob_*, boss_*), not borrowed Boki cues.
func _check_mobs(sounds: Dictionary) -> void:
	var gaps := []
	for kind in Data.MOBS:
		if Data.BOSSES.has(kind) or Data.MOBS[kind]["attack"] == "none": continue
		for part in ["atk", "hit"]:
			if not sounds.has("mob_%s_%s" % [kind, part]): gaps.append("mob_%s_%s" % [kind, part])
	for kind in Data.BOSSES:
		if not sounds.has("boss_%s_tell" % kind): gaps.append("boss_%s_tell" % kind)
	ok(gaps.is_empty(), "every attacking mob has a cue and impact, every boss a wind-up tell (missing %s)" % [gaps])
	var re := RegEx.create_from_string("sfx\\(\"([a-z0-9_]+)\"[,)]")
	var borrowed := []
	for f in ["mob.gd", "boss.gd", "blight.gd"]:
		for hit in re.search_all(FileAccess.get_file_as_string("res://scripts/match/" + f)):
			var sname := hit.get_string(1)
			if sname.begins_with("k_") or not Sfx.ensure(sname): borrowed.append(sname)
	ok(borrowed.is_empty(), "mob.gd, boss.gd and blight.gd play no k_ cue and only sounds that exist (%s)" % [borrowed])

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
	var re := RegEx.create_from_string("\"((?:garden|glint)_[a-z0-9_]+)\"|cue\\(\"([a-z0-9_]+)\"")
	var seen := []
	var silent := []
	for f in ["base_race.gd", "base_shove.gd", "base_seek.gd", "base_volley.gd", "base_tumble.gd", "echo_steps.gd",
			"show_ring.gd", "base_relay.gd", "garden_sfx.gd", "home_chimes.gd", "egg_sfx.gd", "glint_sfx.gd"]:
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
			"garden_chime_": HomeChimes.KINDS, "glint_catch_": ["small", "medium", "large"]}
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
	var arch_src := FileAccess.get_file_as_string("res://scripts/arch/arch_kit.gd")
	var draw_src := FileAccess.get_file_as_string("res://scripts/match/aim/aim_draw.gd")
	var tell_ok := Sfx.ensure("tell_foe") and Sfx.MIN_GAP.has("tell_foe") and TellCue.DB_BIG < UltCue.DB
	tell_ok = tell_ok and arch_src.count("TellCue.start(") == 2 and draw_src.contains("TellCue.aim(")
	ok(tell_ok, "the rival telegraph wind-up exists, has a gap, sits under the ult cues, wired to both systems")

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

## 19. Every Fusion type and form names a cue that has its sound; the release, timeout and evolution cues exist.
func _fusion_cues() -> void:
	var cues := {}
	var files := DirAccess.get_files_at("res://content/merge_forms")
	for t in (MergeForm.data()["types"] as Dictionary).values():
		cues[String(t["cue"])] = true
	for f in files:
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
	# every form names its own cast, travel and hit (MergeSfx), each on file and none shared with another form
	var named := {}
	var silent := []
	for f in files:
		for kind in ["cast", "travel", "hit"]:
			var sname := MergeSfx.name_of(f.get_basename(), kind)
			named[sname] = true
			if sname == "" or not Sfx.ensure(sname):
				silent.append("%s %s" % [f.get_basename(), kind])
	ok(silent.is_empty() and named.size() == files.size() * 3,
		"%d forms: own cast, travel and hit, %d sounds on file (silent %s)" % [files.size(), named.size(), silent])

## 20. The resource-full tell: a Hunter's own sting when its meter comes full (Lace's Hawk Sense has no meter).
func _res_tells() -> void:
	var wrong := []
	for arch in Arch.ids():
		if String((Arch.def(arch).get("resource", {}) as Dictionary).get("kind", "")) == "none":
			continue
		var sname: String = arch + "_tell"
		var reach: float = Sfx.sound_reach.get(sname, 0.0)
		if not (Sfx.ensure(sname) and reach > Sfx.hear_range and reach <= TELL_REACH_MAX):
			wrong.append("%s %.0f m" % [sname, reach])
	ok(wrong.is_empty(), "every Hunter with a meter has its own resource-full tell that carries (%s)" % [wrong])
	var kit := FileAccess.get_file_as_string("res://scripts/arch/arch_kit.gd")
	var own := kit.contains("m.sfx(id + \"_tell\"") and not kit.contains("\"unlock\"")
	ok(own, "ArchKit._tells plays the Hunter's own tell")

## 20. Every kit file that emits a cue is walked by item 4 (listed in its Hunter's "kit_files"), unless it is the
## kit of a Hunter with no set (item 5's fallback).
func _unwalked() -> void:
	var re := RegEx.create_from_string(CUE_CALLS)
	var loose := []
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if not f.ends_with(".gd") or walked.has(f) or Arch.ids().has(f.trim_suffix("_kit.gd")):
			continue
		if re.search(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)) != null:
			loose.append(f)
	ok(loose.is_empty(), "every kit file that plays a cue is walked (not walked: %s)" % [loose])

## 11. Hunter callouts: every Hunter with its own voice has every bark, and the game reports what it barks on.
func _barks() -> void:
	var h := Hunter.new()
	var voiced := []
	var missing := []
	for arch in Arch.ids():
		h.arch = arch
		if HeroSfx.of(h, "hurt", "") == "":
			continue
		voiced.append(arch)
		for kind in HunterBarks.KINDS:
			if HeroSfx.of(h, "call_" + kind, "") != "%s_call_%s" % [arch, kind]:
				missing.append("%s_call_%s" % [arch, kind])
	h.free()
	ok(voiced.size() == 12 and missing.is_empty(), "%d Hunters with a voice have all %d callouts (missing %s)" % [
			voiced.size(), HunterBarks.KINDS.size(), missing])
	var far := voiced.filter(func(a): return float(Sfx.sound_reach.get("%s_call_boki" % a, 0.0)) <= Sfx.hear_range)
	ok(far.is_empty(), "the squad's Boki-down call carries past %d m (short: %s)" % [int(Sfx.hear_range), far])
	var match_src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var net_src := FileAccess.get_file_as_string("res://scripts/match/kin_net.gd")
	var wired := match_src.contains("barks.tick(self)") and match_src.contains("barks.knock_landed(self)")
	wired = wired and match_src.contains("barks.boki_down(self, k)")
	wired = wired and net_src.contains("m.barks.boki_down(m, e as Kin)")
	ok(wired, "the match ticks the callouts and reports knocks and Boki downs, here and from other games")

## 5. A Hunter without its own set plays the shared sounds.
## 18. What you can see you can hear: the cue at the side edge of the wide match view (half of CamRig.style_across)
## is within -12 dB and on the clear bus, 10 m further is at least 6 dB quieter, past 30 m nothing plays.
func _falloff() -> void:
	var edge := CamRig.style_across("supervive") * 0.5
	var at_edge := Sfx._distance_db(Vector3(edge, 0, 0))
	var off := Sfx._distance_db(Vector3(edge + 10.0, 0, 0))
	var gone := Sfx._distance_db(Vector3(31.0, 0, 0))
	print("SFXSET falloff: edge %.1f m %.1f dB, +10 m %.1f dB, 31 m %s" % [edge, at_edge, off, gone])
	var clear := at_edge > -12.0 and edge < Sfx.FAR
	ok(clear, "a cue at the screen edge (%.1f m) is heard clearly (%.1f dB, clear bus)" % [edge, at_edge])
	ok(off < at_edge - 6.0 and not is_nan(off), "...one 10 m off screen is still there but quieter (%.1f dB)" % off)
	ok(is_nan(gone), "...and past ~30 m it is silent")

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

## 11. The tutorial strip's new-objective chime: a sound of the UI set, with its two levels in the table.
func _strip_chime() -> void:
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))["sounds"]
	var has_it: bool = ui.has(TutorialStrip.CHIME) and Sfx.ensure(TutorialStrip.CHIME)
	ok(has_it, "strip chime: %s is in the UI set and has its file" % TutorialStrip.CHIME)
	var cue: Dictionary = levels.get("cue_db", {})
	ok(cue.has("objective") and cue.has("objective_fight") and float(cue["objective_fight"]) < float(cue["objective"]),
			"strip chime: sfx_levels has the calm and the ducked level %s" % [cue])
	ok(_plays(TutorialStrip.CHIME, TutorialStrip.chime), "strip chime: plays through Sfx")

## 13. The rank HUD's three cues, as RankSfx plays them.
func _rank_cues() -> void:
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))["sounds"]
	var fire := float(levels["cats"]["fire"])
	for cue in RankSfx.DB:
		var takes := _takes(cue)
		var played := float(RankSfx.DB[cue]) + (float(_measure(takes[0])["rms"]) if not takes.is_empty() else 0.0)
		ok(ui.has(cue) and not takes.is_empty() and played <= fire - UNDER_COMBAT_DB,
			"%s is a ui sound playing at %.1f dBFS, %.1f dB under a weapon shot" % [cue, played, fire - played])
	var secs := _audible_secs("res://audio/rank_ready.wav")
	ok(secs > 0.0 and secs <= READY_SECS, "the new-point chime is short (%.2f s)" % secs)

## 16. The props you smash and the chests you open play their own sounds, never a shared stand-in.
func _breakables() -> void:
	var set_src := FileAccess.get_file_as_string("res://content/sfx/breakables.json")
	var own: Dictionary = JSON.parse_string(set_src)["sounds"]
	var rules := Breakables.rules()
	var used := {}
	var wrong := []
	for mat in rules["debris"]:
		var sname := String(rules["debris"][mat]["sound"])
		if not own.has(sname) or _takes(sname).size() < 3 or used.has(sname):
			wrong.append("%s: %s" % [mat, sname])
		used[sname] = true
	ok(wrong.is_empty(), "%d materials break with their own sound in 3 takes (wrong: %s)" % [used.size(), wrong])
	for kind_s in rules["kinds"]:
		var ex: Dictionary = rules["kinds"][kind_s].get("explosive", {})
		if ex.is_empty():
			continue
		var secs := _length(String(ex["fuse_sound"]))
		var mine := own.has(String(ex["fuse_sound"])) and own.has(String(ex["blast_sound"]))
		ok(mine and absf(secs - float(ex["fuse"])) < 0.01,
				"%s: its own fuse hiss (%.2f s for a %.2f s fuse) and blast" % [kind_s, secs, ex["fuse"]])
	var lids: Array = ChestLoot.R()["creak"]
	var odd := lids.filter(func(s): return not own.has(s) or lids.count(s) > 1)
	var ends: bool = ChestLoot.creak(0) == lids[0] and ChestLoot.creak(lids.size() + 2) == lids[-1]
	ok(lids.size() >= 2 and odd.is_empty() and ends,
			"%d chest tiers open with their own lid creak, the last for richer (wrong: %s)" % [lids.size(), odd])

## 23. The Training Grounds' cues and beds.
func _training() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/training.json"))
	var shared := FileAccess.get_file_as_string("res://scripts/core/sfx.gd")
	var off := []
	for c in TrainingSfx.CUES:
		if not (d["sounds"] as Dictionary).has(c) or _takes(c).is_empty() or shared.contains("\"%s\"," % c):
			off.append(c)
	ok(off.is_empty(), "training: %d cues of its own set, each with its own file (off: %s)"
			% [TrainingSfx.CUES.size(), off])
	var arena := FileAccess.get_file_as_string("res://scripts/match/arena.gd")
	var duel := FileAccess.get_file_as_string("res://scripts/match/duel.gd")
	var wired := arena.contains("cue(TrainingSfx.RESET)") and arena.contains("cue(TrainingSfx.DUMMY_HIT")
	wired = wired and arena.contains("cue(TrainingSfx.BOT_SPAWN") and duel.contains("cue(TrainingSfx.BOT_SPAWN")
	wired = wired and duel.contains("TrainingSfx.count_start()") and duel.contains("TrainingSfx.count_in(")
	var borrowed := arena.contains("m.sfx(\"revive\"") or duel.contains("m.sfx(\"revive\"")
	ok(wired and not borrowed, "training: the stations and the duel ring play their own cues, not the shared revive")
	TrainingSfx.heard.clear()
	TrainingSfx.count_start()
	var left := TrainingSfx.COUNT_S
	while left > -1.0:
		TrainingSfx.count_in(left, left - 0.25)
		left -= 0.25
	var heard := [int(TrainingSfx.heard.get(TrainingSfx.COUNT, 0)), int(TrainingSfx.heard.get(TrainingSfx.HORN, 0))]
	ok(heard == [3, 1], "training: the duel ring counts 3-2-1 and sounds the horn once %s" % [heard])
	var missing := [TrainingSfx.WIND, TrainingSfx.ISLAND].filter(
			func(b): return not ResourceLoader.exists("res://audio/amb_%s.ogg" % b))
	ok(missing.is_empty(), "training: both beds have their file %s" % [missing])
	var w := World.new()
	w.generate(4242, 64, 7)
	var big := TrainingSfx.expanse_of(w)
	var other := (big + 1) % w.islands.size()
	var on_big: Vector2i = w.islands[big]["cells"][0]
	var on_other: Vector2i = w.islands[other]["cells"][0]
	var t := TrainingSfx.new()
	var at_big := t.beds_at(w, on_big.x + 0.5, on_big.y + 0.5)
	var at_isle := t.beds_at(w, on_other.x + 0.5, on_other.y + 0.5)
	var big_wind := float(at_big[TrainingSfx.WIND])
	var quieter := float(at_isle[TrainingSfx.WIND]) < big_wind and float(at_isle[TrainingSfx.ISLAND]) > 0.0
	ok(big_wind == 1.0 and quieter, "training: full wind on the expanse, less on an island %s %s" % [at_big, at_isle])
	var h := Hunter.new()
	h.pos = Vector3(on_other.x + 0.5, 0, on_other.y + 0.5)
	Sfx.play_ambience("")
	t.ambience(w, h)
	var on_bus := Sfx.amb_layers.size() == 2
	for n in Sfx.amb_layers:
		on_bus = on_bus and (Sfx.amb_layers[n]["p"] as AudioStreamPlayer).bus == "Ambience"
	ok(on_bus, "training: both beds play on the Ambience bus %s" % [Sfx.amb_layers.keys()])
	var match_src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var music := FileAccess.get_file_as_string("res://scripts/match/music_dir.gd")
	var own := match_src.contains("Sfx.play_ambience(\"\" if o.get(\"training\", false) else \"match\")")
	own = own and music.contains("training.ambience(w, p)\n\t\treturn\n\tvar voids")
	var none_borrowed := not (Sfx.amb_layers.has("abyss") or Sfx.amb_layers.has("ruins") or Sfx.amb_name == "match")
	ok(own and none_borrowed, "training: never the match's wind, abyss or ruins beds")
	h.free()
	w.free()
	Sfx.clear_amb_layers(0.0)

## 24. The garden's moments: own cues, counted through GardenSfx.heard, and no "unlock" where they play.
func _garden_moments() -> void:
	var cues := ["garden_egg", "garden_friends", "garden_chime_part", "garden_cup", "garden_evolve"]
	ok(cues.all(func(c): return Sfx.ensure(c) and not _takes(c).is_empty()), "moments: all five cues have files")
	var a := {"uid": "moment_a"}
	var b := {"uid": "moment_b"}
	BaseLife.befriended.clear()
	var step := float(Content.rules("base_life")["friend_at"]) * 0.6
	for i in 3:
		BaseLife.add_bond(a, b, step)
	ok(BaseLife.befriended == [["moment_a", "moment_b"]], "moments: friends once, as the bond reaches friend_at %s"
			% [BaseLife.befriended])
	BaseLife.befriended.clear()
	var build: Dictionary = FarmUnlocks.rules()
	var was_base: bool = build["base_mode"]
	build["base_mode"] = true                   # leans only show on the Boki base
	var rec := Save.new_kin("zapple", "Moment")
	var tinted: Array = Lean.rules()["types"].keys().filter(func(t): return Lean.rules()["types"][t].has("tint"))
	rec["lean"] = {tinted[0]: Evo.LEAN_FULL * 0.2}
	var one := Lean.flecks(rec)
	rec["lean"][tinted[0]] = Evo.LEAN_FULL
	ok((one == 1 and Lean.flecks(rec) == int(Lean.rules()["marks"])),
			"moments: a lean shows one fleck from its first meal, all at full (%d)" % one)
	var home := {"kins": [{"rec": rec, "pos": Vector3.ZERO}]}
	var chimes := HomeChimes.new(home)
	chimes.tick(1.0)
	rec["lean"][tinted[0]] = Evo.LEAN_FULL * 0.2
	chimes.tick(1.0)
	rec["lean"][tinted[0]] = Evo.LEAN_FULL
	var before := int(GardenSfx.heard.get("garden_chime_part", 0))
	chimes.tick(1.0)
	ok(int(GardenSfx.heard.get("garden_chime_part", 0)) == before + 1,
			"moments: a lean that shows more flecks chimes garden_chime_part once")
	build["base_mode"] = was_base
	var res := {"game": GardenPrizes.ids()[0], "items": [], "first": false, "round": "", "ribbon": false,
			"reset": false}
	var cups := int(GardenSfx.heard.get("garden_cup", 0))
	GardenPrizes.rows(res.merged({"round": "Sprout"}, true))
	GardenPrizes.rows(res.merged({"round": "Crown", "ribbon": true}, true))
	ok(int(GardenSfx.heard.get("garden_cup", 0)) == cups + 1, "moments: the Crown card plays garden_cup, a round not")
	var sites := {"base_life.gd": "garden_friends", "home_incubator.gd": "garden_egg", "garden_prizes.gd": "garden_cup",
			"kin_bond_moment.gd": "garden_friends", "home.gd": "garden_evolve"}
	var off := []
	for f in sites:
		var src := FileAccess.get_file_as_string("res://scripts/home/" + f)
		if not src.contains("\"%s\"" % sites[f]):
			off.append(f)
		elif f != "home.gd" and src.contains("Sfx.play(\"unlock\""):
			off.append(f + " unlock")
	for fn in ["func _make_egg(", "func _play_evolutions("]:
		var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
		var body := src.substr(src.find(fn), src.find("\nfunc ", src.find(fn) + 1) - src.find(fn))
		if body.contains("\"unlock\""):
			off.append(fn)
	ok(off.is_empty(), "moments: every site names its cue and none plays unlock %s" % [off])

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

## Seconds to the last sample above 2% of the peak, in a mono 44.1 kHz wav (as tools/sfx_lib.py writes them).
func _audible_secs(path: String) -> float:
	var data := _data(path)
	var n := data.size() / 2
	var pk := 0.0
	for k in n:
		pk = maxf(pk, absf(data.decode_s16(k * 2)))
	var last := 0
	for k in n:
		if absf(data.decode_s16(k * 2)) > pk * 0.02:
			last = k
	return last / 44100.0

## A 16-bit mono wav's length in seconds (the sample rate from its header).
func _length(sname: String) -> float:
	var path := "res://audio/%s.wav" % sname
	var rate := FileAccess.get_file_as_bytes(path).decode_u32(24)
	return _data(path).size() / 2.0 / maxf(1.0, rate)

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

## Held fire at the source cadence, by the plain one-shot path (before) and by FireSfx (after).
func _held_fire(main: Node) -> void:
	var sounds := {}       # shot sound -> weapon
	for f in DirAccess.get_files_at("res://content/weapons"):
		var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/weapons/" + f))
		var p: Dictionary = w["primary"]
		if float(p["rate"]) < FireSfx.HELD_RATE or w["id"] == "hoar_fan":      # (hoar_fan: Neve's darts go held)
			sounds[String(p["sfx"])] = w["id"]
	ok(sounds.size() >= 4, "held-fire weapons found: %s" % str(sounds.values()))
	for sname in sounds:
		var before: Dictionary = await _hold(main, sname, false)
		await main.get_tree().create_timer(1.0).timeout
		var after: Dictionary = await _hold(main, sname, true)
		var takes: Array = after["takes"]
		var run := takes.slice(1)
		var repeats := 0
		for i in range(1, run.size()):
			repeats += 1 if run[i] == run[i - 1] else 0
		var shown := "%s (%s) %.0f s at %d ms: voices %d plain -> %d held, cap %d" % [
			sname, sounds[sname], HELD_S, HELD_STEP_MS, before["peak"], after["peak"], FireSfx.VOICES]
		ok(int(after["peak"]) <= FireSfx.VOICES, "%s, %d of %d shots sound" % [shown, takes.size(), before["shots"]])
		var opens: bool = not takes.is_empty() and takes[0] == 0 and not run.has(0)
		var others := _distinct(run)
		ok(opens and repeats == 0 and others >= 3,
			"%s: first shot is the base take, the rest go round %d other takes without repeating (%s)" % [
				sname, others, str(takes.slice(0, 8))])
		await main.get_tree().create_timer(1.0).timeout

func _distinct(a: Array) -> int:
	var seen := {}
	for t in a:
		seen[t] = true
	return seen.size()

## Fires `sname` every HELD_STEP_MS for HELD_S s; {peak: most pool voices sounding at once, takes: the take of each
## shot that sounded (FireSfx drops some), shots: rounds fired}.
func _hold(main: Node, sname: String, held: bool) -> Dictionary:
	var peak := 0
	var shots := 0
	var takes := []
	var t0 := Time.get_ticks_msec()
	var due := t0
	while Time.get_ticks_msec() - t0 < int(HELD_S * 1000.0):
		var now := Time.get_ticks_msec()
		if now >= due:
			due += HELD_STEP_MS
			shots += 1
			var seen: int = Sfx.last_played.get(sname, -1)
			if held:
				FireSfx.shot(7, sname, null, -2.0, 0.08)
			else:
				Sfx.play(sname, null, -2.0)
			if int(Sfx.last_played.get(sname, -1)) != seen:
				takes.append(int(Sfx.last_take.get(sname, 0)))
		var live := 0
		for pl in Sfx.players:
			live += 1 if pl.playing else 0
		peak = maxi(peak, live)
		await main.get_tree().process_frame
	return {"peak": peak, "takes": takes, "shots": shots}

## 22. Footsteps on every surface: a ground tile for each, a Hunter of each weight class on it.
const WEIGHT_ARCH := {"light": "archer", "medium": "dolm", "heavy": "ashwick"}
const STEP_VOL := -13.0       # dB: the player's own step in Juice.footstep

func _steps(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	ok(m.world.layout_id == "hollowcrown", "step check runs on the Hollow Crown (%s)" % m.world.layout_id)
	var spots := _surface_tiles(m)
	ok(m.world.bridge.is_empty(), "the Hollow Crown has no plank bridges (its docks are gone)")
	ok(m.skytrain != null, "the Hollow Crown has a sky train")
	if m.skytrain != null:
		var car: Transform3D = m.skytrain.cur[1]
		var deck := Vector3(car.origin.x, m.skytrain.deck_y(car.origin + Vector3(0, 0.3, 0)), car.origin.z)
		ok(StepSurface.at(m, deck) == "metal", "a sky train car's deck is metal")
		spots["metal"] = deck
	var plank: Vector3 = spots.get("grass", Vector3.ZERO)
	for surf in ["grass", "stone", "snow", "metal", "wood"]:
		if surf == "wood":      # last: lays a plank tile on the grass one
			m.world.bridge[m.world.idx(int(plank.x), int(plank.z))] = true
			ok(StepSurface.at(m, plank) == "wood", "a plank bridge tile is wood")
			spots["wood"] = plank
		if spots.has(surf):
			_walk(m, m.player, surf, spots[surf])
		else:
			ok(false, "the Hollow Crown has %s to step on" % surf)
	for cls in WEIGHT_ARCH:
		var wade := "step_water_" + StepSurface.weight_of(WEIGHT_ARCH[cls])
		ok(wade == "step_water_" + cls and Sfx.ensure(wade), "farm wading: %s plays %s" % [cls, wade])
	m.queue_free()

## One Hunter per weight class steps on `p` (a surface `surf`): the cue played is the expected one, the
## shared steps get quieter to heavier, and the sound has its takes loaded.
func _walk(m: Match, h: Hunter, surf: String, p: Vector3) -> void:
	var arch0 := h.arch
	var vols := []
	for cls in WEIGHT_ARCH:
		h.arch = WEIGHT_ARCH[cls]
		h.teleport(p)
		var want := "step_%s_%s" % [surf, cls] if surf in StepSurface.SHARED else "%s_step_%s" % [h.arch, surf]
		Sfx.last_played.clear()
		Sfx.recent.clear()
		Sfx.listener = p
		Juice.footstep(h)
		var got: Array = Sfx.last_played.keys()
		ok(got == [want] and Sfx.streams.has(want), "%s on %s: %s plays %s (%s)" % [cls, surf, h.arch, want, got])
		vols.append(StepSurface.vol_db(h, surf, STEP_VOL))
	var spread: bool = vols[0] < vols[1] and vols[1] < vols[2]
	ok(spread == (surf in StepSurface.SHARED) and (surf in StepSurface.SHARED or vols[0] == vols[2]),
			"%s: shared steps are louder the heavier the Hunter (%s)" % [surf, vols])
	h.arch = arch0

## A walkable ground tile centre per ground surface (grass, stone, snow).
func _surface_tiles(m: Match) -> Dictionary:
	var w: World = m.world
	var out := {}
	for z in w.h:
		for x in w.w:
			if w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			var p := Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
			var surf := StepSurface.at(m, p)
			if not out.has(surf):
				out[surf] = p
	return out
