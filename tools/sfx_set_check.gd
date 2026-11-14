extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md), and every menu control's sound
## (_menus: Settings, the inventory and the Field Book).
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
##   8. dash_air per Hunter (listed in dash.json and picked in the air) and the no-charge tick
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
##  12. every lair boss move has its own cue, no shared fallback: wake, phase, stagger, fall, defeat, and per attack a
##      wind-up and a strike (the thrown ones also a landing); boss.gd names no shared sound of its own
##  13. one row per crowd-control kind (CcSfx): the Hunter it lands on hears its cue, a squadmate in reach a
##      quieter one, a rival or a far squadmate nothing; stacked CC plays once
##  14. the inventory cues (InvSfx): grab, drop, equip, swap and take exist and each plays its own sound,
##      at least INV_UNDER_DB under a hit or a shot; the inventory and loot code plays them, never hud.gd
##  15. Meeko's Hearth Call channel loop (tend_call_loop): it plays on her and quieter on the ally, one of each
##      even when X is pressed again, and it is gone within one frame of every way the channel can end
##  16. Sable's Encore: the blade whirr is a keyed loop that starts once the ring has grown, follows her
##      through a dash and is gone in the frame the ring ends
##  17. the rarity stings (RaritySting): rare and very rare each have a sound, quieter than the scan chime,
##      a common Boki has none, and the match (first sight), Capture (claim) and EggHatch (hatch) play them
##  18. held fire (docs/AUDIO.md): every weapon under FireSfx.HELD_RATE, and Neve's dart, fired every HELD_STEP_MS for
##      HELD_S seconds through FireSfx keeps at most FireSfx.VOICES voices sounding, opens on its base take and goes
##      round three or more others without repeating one
##  19. the hit ticks by weapon family (content/sfx/hit.json): every Hunter's left-click weapon names one in "hit",
##      each family is used, and HeroSfx.hit_tick plays it for the weapon's own hits (a shot, a primary swing),
##      the shared `hit` for an ability's hit and a Hunter with no weapon tick
##  20. the rival-cast layer (HostileCue): every Hunter's E and R start it once; a rival's cast plays it, an ally's
##      does not, nor a rival's past its 30 m; E, R and X (UltCue) and other games' casts are wired to it
##  21. Sparkle's Kitefall: a cue on every beat (crouch, lift-off, hover hum loop, drop, strike) within 50 ms of the
##      state change, the hum off by the drop (tools/ult_beat_sfx_check.gd; runs one short training match)
##  22. footsteps: a Hunter walked over every surface of the Hollow Crown (the sky train's car deck; a plank
##      bridge tile laid on it) plays the cue for it: its own set on grass, stone, wood and snow, the
##      weight class's steps on metal, a little louder the heavier it is; farm wading has a set per class
##  23. the rank HUD's cues (RankSfx) are in the ui set, play at least UNDER_COMBAT_DB under a weapon shot,
##      and the new-point chime is short
##  24. each of the 12 Hunters with its own voice has every callout (HunterBarks.KINDS, content/sfx/barks.json),
##      HeroSfx picks them, the Boki-down call carries past hearing range, and the match and KinNet report to it
## Reads the files (and, for 15 and 16, one short training match); never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MIN := 5.0         # m: below this a sound would not carry past its own source
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const FALL_TOL_S := 0.05       # s: how far a fall cue may differ from the fall it sounds under
const FRAME := 1.0 / 60.0      # s: one simulation frame
const HELD_S := 3.0            # s of held fire per sound
const HELD_STEP_MS := 80       # ms a round: the source cadence of Vex's rifle
const SEAM_MAX := 0.05         # the jump at a loop's seam, as a share of full scale
const INV_UNDER_DB := 10.0     # dB: an inventory cue sits at least this far under the quietest hit or shot
const UNDER_COMBAT_DB := 10.0  # dB: a rank cue as played sits at least this far under a weapon shot ("fire")
const READY_SECS := 0.5        # s: the new-point chime's audible length at most

var bad := 0
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
	await _menus(main)
	_dash_air()
	_fallback()
	_ult_cues()
	_nuke_fall()
	_garden_names()
	_garden()
	_build_cues()
	_strip_chime()
	_boss_moves()
	_cc_cues()
	_inv_cues()
	await _call_loop(main)
	await _encore_loop(main)
	_rarity_stings()
	await _held_fire(main)
	_hit_ticks()
	_hostile()
	load("res://tools/ult_beat_sfx_check.gd").new().run(main, ok)
	await _steps(main)
	_rank_cues()
	_barks()

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

## 14. Crowd control landing on a Hunter: who hears which cue, and stacked CC plays once (CcSfx).
func _cc_cues() -> void:
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar player: Node\nvar time := 0.0\n"
	stub.reload()
	var m: Node = stub.new()
	var me := _cc_body(m, 0, Vector3.ZERO)
	var mate := _cc_body(m, 0, Vector3(6, 0, 0))
	var far_mate := _cc_body(m, 0, Vector3(20, 0, 0))
	var rival := _cc_body(m, 1, Vector3(3, 0, 0))
	m.set("player", me)
	Sfx.listener = me.pos
	for kind: String in CcSfx.KINDS:
		var own := "cc_" + kind
		var quiet := own + "_mate"
		var gap := _rms(own) - (_rms(quiet) + CcSfx.MATE_DB)
		m.set("time", float(m.get("time")) + 1.0)
		var heard := []
		for h in [me, mate, rival, far_mate]:
			heard.append(_cc_heard(h, kind))
		var want := [[own], [quiet], [], []]
		var who := "cc %s: you hear %s, a squadmate 6 m off %s (%.1f dB under), " % [kind, own, quiet, gap]
		ok(heard == want and gap >= 6.0, who + "a rival and a squadmate 20 m off nothing (%s)" % [heard])
	m.set("time", float(m.get("time")) + 1.0)
	var first := _cc_heard(me, "stun")
	m.set("time", float(m.get("time")) + 0.1)
	var stacked := _cc_heard(me, "root")
	m.set("time", float(m.get("time")) + CcSfx.CAP_S)
	var later := _cc_heard(me, "slow")
	ok(first.size() == 1 and stacked.is_empty() and later.size() == 1, "stacked CC plays once: a root 0.1 s after "
			+ "a stun is silent, a slow %.1f s later plays (%s %s %s)" % [CcSfx.CAP_S, first, stacked, later])
	var all := {"stun": 1.0, "root": 1.0, "slow": 1.0}
	var pick := CcSfx.fresh_on_hit(me, all)
	var nudge := CcSfx.fresh_on_hit(me, {"slow": 0.2})
	me.stun_t = 1.0
	var refresh := CcSfx.fresh_on_hit(me, {"stun": 1.0})
	ok(pick == "stun" and nudge == "" and refresh == "", "a hit with stun, root and slow plays the stun; "
			+ "a 0.2 s slow and a stun refresh play nothing (%s/%s/%s)" % [pick, nudge, refresh])
	var ent := FileAccess.get_file_as_string("res://scripts/match/ent.gd")
	var ks := FileAccess.get_file_as_string("res://scripts/arch/kit_status.gd")
	ok(ent.count("CcSfx.") == 2 and ks.count("CcSfx.play(e, ") == 3,
			"Ent.hurt and KitStatus.apply play the cues where the status lands")
	for h in [me, mate, far_mate, rival]:
		h.free()
	m.free()

func _cc_body(m: Node, team: int, at: Vector3) -> Hunter:
	var h := Hunter.new()
	h.m = m
	h.team = team
	h.pos = at
	return h

## The cc sounds that `kind` landing on `h` plays here (Sfx.last_played, cleared first).
func _cc_heard(h: Hunter, kind: String) -> Array:
	for k in Sfx.last_played.keys():
		if String(k).begins_with("cc_"):
			Sfx.last_played.erase(k)
			Sfx.recent.erase(k)
	CcSfx.play(h, kind)
	return Sfx.last_played.keys().filter(func(k): return String(k).begins_with("cc_"))

func _rms(sname: String) -> float:
	var takes := _takes(sname)
	return float(_measure(takes[0])["rms"]) if not takes.is_empty() else 0.0
## 20. A rival's cast is heard as a threat; yours and your allies' are not.
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
## 24. Hunter callouts: every Hunter with its own voice has every bark, and the game reports what it barks on.
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
func _fallback() -> void:
	var h := Hunter.new()
	h.arch = "no_such_hunter"
	var got := [HeroSfx.of(h, "dash", "dash"), HeroSfx.of(h, "hurt", "")]
	h.free()
	ok(got == ["dash", ""], "no set: the shared dash, and no voice line (%s)" % [got])

## 7. Every Hunter's dash has an air variant listed in dash.json that HeroSfx picks with no floor under it, and the
## no-charge tick exists.
func _dash_air() -> void:
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/dash.json"))["sounds"]
	var unlisted := Arch.ids().filter(func(a): return not listed.has("%s_dash_air" % a))
	ok(unlisted.is_empty(), "every roster Hunter has a <arch>_dash_air in dash.json (missing: %s)" % [unlisted])
	var h := Hunter.new()
	var picked := {}
	for arch in Arch.ids():
		h.arch = arch
		h.grounded = false
		picked[arch] = HeroSfx.dash_name(h)
		h.grounded = true
		picked[arch] += " " + HeroSfx.dash_name(h)
	h.free()
	# (a Hunter with no ground dash of its own, as Gil, plays the shared dash on the ground: item 5's fallback)
	var want := func(a): return "%s_dash_air %s" % [a, "%s_dash" % a if Sfx.ensure("%s_dash" % a) else "dash"]
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

## 15. Meeko's channel loop, one training match per end path.
const END_PATHS := ["time", "ally out of reach", "stun", "knock", "dead", "ally dead", "merge"]

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

## 12. The inventory cues.
func _inv_cues() -> void:
	var cues := {"inv_grab": InvSfx.grab, "inv_drop": InvSfx.drop, "inv_equip": InvSfx.equip,
			"inv_swap": InvSfx.swap, "inv_take": InvSfx.take}
	var silent := cues.keys().filter(func(n): return not Sfx.ensure(n))
	ok(silent.is_empty(), "inventory cues: %d sounds exist (silent: %s)" % [cues.size(), silent])
	var mute := cues.keys().filter(func(n): return not _plays(n, cues[n]))
	ok(mute.is_empty(), "inventory cues: each plays its own sound (not: %s)" % [mute])
	var cats: Dictionary = levels["cats"]
	var cue_db := float(cats["ui"]) + InvSfx.CUE_DB
	var fight_db := minf(float(cats["fire"]), float(cats["impact"]))
	ok(cue_db <= fight_db - INV_UNDER_DB, "inventory cues: %.0f dB, under a hit or shot (%.0f dB)" % [cue_db, fight_db])
	var wiring := {"scripts/ui/loadout_panel.gd": ["drop()", "equip()"], "scripts/ui/slot_drag.gd": ["grab()"],
			"scripts/match/loot_full.gd": ["swap()"], "scripts/match/life.gd": ["swap()", "take()"]}
	var missing := []
	for f in wiring:
		var src := FileAccess.get_file_as_string("res://" + f)
		for cue in wiring[f]:
			if not src.contains("InvSfx." + cue):
				missing.append("%s InvSfx.%s" % [f.get_file(), cue])
	ok(missing.is_empty(), "inventory cues: the inventory and loot code plays them (missing %s)" % [missing])
	var hud := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	var in_hud := cues.values().filter(func(c): return hud.contains("InvSfx.%s(" % (c as Callable).get_method()))
	ok(in_hud.is_empty(), "inventory cues: none played from hud.gd")

## 17. Rare and very rare Boki have a sting each; a common one plays nothing; each is under the scan chime.
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
## 23. The rank HUD's three cues, as RankSfx plays them.
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

## The menus (UiSfx, Ui.button), walked tab by tab: Settings, the inventory and the Field Book. Every
## tab plays the tab sound; a slider ticks once for a burst of steps; a toggle sounds higher turning on
## than off; a dropdown sounds; a Field Book tile sounds when pointed at and when picked, and its page's
## way back sounds. Each control is put back as it was and the save is never written.
func _menus(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var spk := String(FieldBook.entries()[0])
	Save.d["dex"] = {spk: {"seen": true, "caught": true, "forms": [], "shimmer": false, "mutations": []}}
	var seen := {"slider": 0, "toggle": 0, "dropdown": 0}
	var off := []
	Overlay.open_settings()
	for t in Overlay.SETTINGS_TABS:
		await _settle(main)
		if not _press_tab(t):
			off.append("tab %s silent" % t)
		await _settle(main)
		_walk("settings > " + t, seen, off)
	var said := "settings: all %d tabs sound, %d sliders tick once a burst, %d toggles sound higher on than off," % [
		Overlay.SETTINGS_TABS.size(), seen["slider"], seen["toggle"]]
	var all_found: bool = seen.values().all(func(n): return n > 0)
	ok(off.is_empty() and all_found, "%s %d dropdowns sound %s" % [said, seen["dropdown"], off])
	Overlay.close()
	off.clear()
	Overlay.inv_tab = "Items"
	await _settle(main)
	Overlay.open_inventory()
	var inv_tabs := Overlay.root.find_children("*", "Button", true, false).map(func(b): return b.get_meta("tab", ""))
	inv_tabs = inv_tabs.filter(func(t): return t != "")
	for t in inv_tabs:
		await _settle(main)
		if not _press_tab(t):
			off.append("tab %s silent" % t)
		await _settle(main)
		_walk("inventory > " + t, seen, off)
	ok(off.is_empty() and inv_tabs.has("Field Book"), "inventory: all %d tabs sound %s" % [inv_tabs.size(), off])
	await _field_book(main)
	Overlay.close()

## The Field Book tab is open: its met Boki's tile, then that Boki's page and the way back.
func _field_book(main: Node) -> void:
	var tile: Control = null
	for g in Overlay.root.find_children("*", "GridContainer", true, false):
		for t in g.get_children():
			if tile == null and t is PanelContainer and t.focus_mode == Control.FOCUS_ALL:
				tile = t
	var pointed := tile != null and _heard("hover", tile.mouse_entered.emit) > 0.0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var picked := tile != null and _heard("click", func(): tile.gui_input.emit(click)) > 0.0
	await _settle(main)
	var opened := Overlay.page == "dex"
	var back: Button = Overlay.root.find_child("Close", true, false)
	var went_back := back != null and _heard("click", back.pressed.emit) > 0.0 and Overlay.page == "inventory"
	ok(pointed and picked and opened and went_back,
		"field book: a tile sounds pointed at (%s) and picked (%s), its page opens (%s), Back sounds and returns (%s)"
		% [pointed, picked, opened, went_back])

## Presses the tab named `t` in the open menu; true when it played the tab sound.
func _press_tab(t: String) -> bool:
	for b in Overlay.root.find_children("*", "Button", true, false):
		if b.get_meta("tab", "") == t:
			return _heard("ui_tab", b.pressed.emit) > 0.0
	return false

## One frame, so the page a menu just replaced is gone before the next look.
func _settle(main: Node) -> void:
	await main.get_tree().process_frame

## Moves every slider, toggle and dropdown in the open menu and back, counting each in `seen`; what
## stayed silent (or ticked twice in a burst, or sounded no higher on than off) goes in `off`.
func _walk(where: String, seen: Dictionary, off: Array) -> void:
	for c in Overlay.root.find_children("*", "Control", true, false):
		if c is Slider:
			var s: Slider = c
			var was := s.value
			var ticked := _heard("hover", func(): s.value = s.max_value if was < s.max_value else s.min_value) > 0.0
			var again := _heard("hover", func(): s.value = was) > 0.0       # inside SLIDER_GAP_MS
			seen["slider"] += 1
			if not ticked or again:
				off.append("%s: slider %s" % [where, "silent" if not ticked else "ticks every step"])
		elif c is CheckButton or c is CheckBox:
			var b: BaseButton = c
			var was_on := b.button_pressed
			var first := _heard("click", func(): b.button_pressed = not was_on)
			var second := _heard("click", func(): b.button_pressed = was_on)
			var on_pitch := second if was_on else first
			var off_pitch := first if was_on else second
			seen["toggle"] += 1
			if off_pitch <= 0.0 or on_pitch <= off_pitch:
				off.append("%s: toggle %s on %.2f off %.2f" % [where, b.text, on_pitch, off_pitch])
		elif c is OptionButton and (c as OptionButton).selected >= 0:
			var ob: OptionButton = c
			seen["dropdown"] += 1
			if _heard("ui_tab", func(): ob.item_selected.emit(ob.selected)) <= 0.0:
				off.append("%s: dropdown silent" % where)

## Runs `act` with every sound's repeat gap cleared: the pitch `sname` played at, or 0 when it was silent.
func _heard(sname: String, act: Callable) -> float:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	act.call()
	if not Sfx.last_played.has(sname):
		return 0.0
	return Sfx.players[(Sfx.next + Sfx.POOL - 1) % Sfx.POOL].pitch_scale

## 12. Each boss move has a cue in the boss set, and boss.gd plays only BossSfx cues.
func _boss_moves() -> void:
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/boss.json"))["sounds"]
	var missing := []
	for kind in BossAnim.ATTACKS:
		var cues := ["wake", "phase", "stagger", "fall", "defeat"]
		for atk in BossAnim.ATTACKS[kind]:
			cues += [atk + "_wind", atk + "_hit"]
			if atk in ["boulders", "lob"]:
				cues.append(atk + "_land")
		for c in cues:
			if not boss.has("boss_%s_%s" % [kind, c]):
				missing.append("%s %s" % [kind, c])
	ok(missing.is_empty(), "every boss move has its own cue (missing %s)" % [missing])
	var own := FileAccess.get_file_as_string("res://scripts/match/boss.gd")
	ok(not own.contains("m.sfx("), "boss.gd plays no shared sound: its moves go through BossSfx")
## 16. Encore's whirr is held at Sable: off while the ring grows, on after, riding with her through a dash,
## and stopped in the frame the ring ends (ThiefUlt.tick/drop, Sfx.loop_hold).
func _encore_loop(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"cls": Arch.weight("thief"), "arch": "thief", "weapon": Arch.signature("thief")})
	m.set_process(false)
	var p: Hunter = m.player
	p.lvl = 6
	p.slot_lv["ult"] = 1
	p.ak.cd["x"] = 0.0
	var ring: ThiefUlt = (p.ak as ThiefKit).encore
	var key := ring.whirr_key()
	var grow := float(ring.data()["grow"])
	HunterKeys.ult_pressed(p)
	var cast_at := p.pos
	_run(m, grow * 0.5)
	ok(ring.running() and not Sfx.loop_on(key), "encore: no whirr while the ring is still growing")
	_run(m, grow * 0.5 + 0.1)
	ok(Sfx.loop_on(key), "encore: the whirr starts once the ring has grown")
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(1, 0)
	p.do_dash()
	_run(m, 0.5)
	p.inp["move"] = Vector2.ZERO
	var away := Vector2(p.pos.x - cast_at.x, p.pos.z - cast_at.z).length()
	var at_her: Vector3 = Sfx.loops[key]["pos"]
	var off := Vector2(at_her.x - p.pos.x, at_her.z - p.pos.z).length()
	ok(away > 2.0 and off < 0.3, "encore: dashed %.1f m off the cast point, the whirr %.2f m from her" % [away, off])
	var late := 0
	while ring.running() and late < 600:
		m.step(FRAME)
		late += 1
	ok(not ring.running() and not Sfx.loop_on(key), "encore: the whirr is gone as the ring ends (%d frames in)" % late)
	m.queue_free()
	await main.get_tree().process_frame

func _run(m: Match, secs: float) -> void:
	for i in int(ceil(secs / FRAME)):
		m.step(FRAME)
## 18. Held fire at the source cadence, by the plain one-shot path (before) and by FireSfx (after).
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
	for voice in Sfx.players:
		voice.stop()          # the earlier sections' sounds are still ringing in the shared pool
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
## 19. One hit tick per weapon family; each Hunter's weapon names one; ability hits keep the shared tick.
func _hit_ticks() -> void:
	var set_d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/hit.json"))
	var family: Array = (set_d["sounds"] as Dictionary).keys()
	ok(family.size() == 6, "hit ticks: six families (%s)" % [family])
	var used := {}
	var unmapped := []
	var h := Hunter.new()
	for arch in Arch.ids():
		var w := Data.weapon_stats(Arch.signature(arch))
		var tick := String(w.get("hit", ""))
		used[tick] = true
		if not family.has(tick):
			unmapped.append("%s (%s)" % [arch, tick])
	ok(unmapped.is_empty(), "hit ticks: every Hunter's weapon names one of them (%s)" % [unmapped])
	var idle := family.filter(func(f): return not used.has(f))
	ok(idle.is_empty(), "hit ticks: every family is some Hunter's weapon (unused %s)" % [idle])
	h.wpn = Data.weapon_stats("longbow")
	var shot := HeroSfx.hit_tick(h, {"src": "shot"})
	var swing := HeroSfx.hit_tick(h, {"src": "abil", "ab": "primary"})
	var cast := HeroSfx.hit_tick(h, {"src": "abil", "ab": "e"})
	var picks := [shot, swing, cast]
	ok(picks == ["hit_bow", "hit_bow", "hit"], "hit ticks: shot, primary, ability %s" % [picks])
	h.wpn = Data.weapon_stats("rifle")
	var bare := [HeroSfx.hit_tick(h, {"src": "shot"}), HeroSfx.hit_tick(null, {})]
	ok(bare == ["hit", "hit"], "hit ticks: no weapon tick or no Hunter, the shared one %s" % [bare])
	h.free()
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
			_step_on(m, m.player, surf, spots[surf])
		else:
			ok(false, "the Hollow Crown has %s to step on" % surf)
	for cls in WEIGHT_ARCH:
		var wade := "step_water_" + StepSurface.weight_of(WEIGHT_ARCH[cls])
		ok(wade == "step_water_" + cls and Sfx.ensure(wade), "farm wading: %s plays %s" % [cls, wade])
	m.queue_free()

## One Hunter per weight class steps on `p` (a surface `surf`): the cue played is the expected one, the
## shared steps get quieter to heavier, and the sound has its takes loaded.
func _step_on(m: Match, h: Hunter, surf: String, p: Vector3) -> void:
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
