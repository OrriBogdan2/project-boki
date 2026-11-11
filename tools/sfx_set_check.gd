extends RefCounted
## --sfx-set-check: the sound sets in content/sfx/*.json (docs/AUDIO.md).
##   1. every listed sound has a file (audio/<name>.wav or its takes <name>_1..4.wav)
##   2. every take sits at its category's loudness (content/rules/sfx_levels.json) and under the peak ceiling
##   3. a Hunter set has its wordless voice (hurt, down, death), its dash, footsteps on every surface,
##      at least one weapon "fire" sound and its listed signature sounds, and HeroSfx picks them up
##   4. every literal m.sfx("...") in that Hunter's kit (and its listed helper files) names a sound that exists
##   5. a Hunter with no set falls back to the shared sounds
##   7. mobs and bosses: every kind that attacks has its own mob_<kind>_atk and _hit, each boss its _tell,
##      and no sound played by mob.gd or boss.gd is a Boki cue (k_*), so a Boki rename cannot silence them
##   7. footsteps: a Hunter walked over every surface of the Hollow Crown (and the sky train's deck on
##      Skyreach) plays the cue for it: its own set on grass, stone, wood and snow, the weight class's
##      steps on sand, water and metal, a little louder the heavier it is
##   6. "reach" (metres a heavy sound carries) names sounds of the set, between hear_range and REACH_MAX;
##      every sound under "loops" repeats seamlessly (no fade at either end, the seam no bigger than a step)
##   7. every Hunter's ultimate has a positional cast cue (<arch>_ult_cue, with a reach past hearing range)
##      and the two team tags carry as far; HeroUlt.press plays it and the match plays it for other players' casts
##   7. every hit class (HitClass) names a sound of the "targets" set that exists and fits under a weapon hit
##   7. every ambience loop the match and the title ask for (AmbBeds.BEDS, "title", ...) has its file
##   7. boki_voices: every rigged species (art/kin/*) has all five moods with two takes, KinVoice.cue picks them,
##      an unknown species falls back to the generic cues, and no two species share a happy take
##   7. the warning and Boki-moment sounds are played where they belong (WIRED), are in a set, and exist
## Reads the files only; never touches the save.

const SURFACES := ["grass", "stone", "wood", "snow"]
const VOICE := ["hurt", "down", "death"]
const REACH_MAX := 80.0        # m: past this a sound would carry over most of the island
const SEAM_MAX := 0.05         # the jump at a loop's seam, as a share of full scale

## Sound -> the scripts that must play it (a sound that exists but is never played is silence).
const WIRED := {
	"warn_heartbeat": ["match/warn_sfx.gd"], "warn_tick": ["match/exit_sfx.gd"],
	"board_hum": ["match/exit_sfx.gd"], "board_cancel": ["match/exit_sfx.gd"], "depart_sting": ["match/exit_sfx.gd"],
	"blight_rumble": ["match/blight.gd", "match/blight_dir.gd"],
	"boki_downed": ["match/kin_downed.gd", "match/kin_net.gd"],
	"boki_revive": ["match/kin_downed.gd", "match/kin_net.gd"],
	"boki_fuse": ["match/merge_xform.gd"], "boki_unfuse": ["match/merge_xform.gd", "match/kin_net.gd"],
	"boki_eat": ["home/home.gd"], "boki_sleep": ["home/home.gd", "home/kin_indoors.gd"],
}

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
	_wired()
	_fallback()
	_ult_cues()
	_boki_cues()
	_pickups()
	_hit_targets()
	_ambience()
	_wisp_cues()
	await _steps(main)
	print("SFXSET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The ambience beds the match (AmbBeds) and the title ask for each have their loop file.
func _ambience() -> void:
	for bed in AmbBeds.BEDS + ["title", "match", "abyss", "ruins"]:
		ok(ResourceLoader.exists("res://audio/amb_%s.ogg" % bed), "ambience bed amb_%s.ogg" % bed)

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

## 7. Mob and boss attack sounds are their own (mob_*, boss_*), not borrowed Boki cues.
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
	ok(names.size() == 14 and wrong.is_empty(), "%d ult cues exist and carry (wrong: %s)" % [names.size(), wrong])
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

## 7. The Boki wisp cues (KinSummon): a chirp for every body size, higher for a smaller one, and the
## bloom, shrink, ready and grab cues, all in the boki set.
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
	for cue in ["wisp_bloom", "wisp_shrink", "wisp_ready", "wisp_grab"]:
		if not boki.has(cue):
			missing.append(cue)
	var what := "wisp cues: a chirp per body size, bloom, shrink, ready, grab (missing %s)"
	ok(missing.is_empty() and sizes.size() == 3, what % [missing])
	var pitch := []
	for size in ["small", "medium", "large"]:
		pitch.append(_zero_crossings(_data("res://audio/wisp_chirp_%s.wav" % size)))
	var order := "wisp chirps rise as the body gets smaller (zero crossings %s)"
	ok(pitch[0] > pitch[1] and pitch[1] > pitch[2], order % [pitch])

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

## 7. Each sound in WIRED is in a set and its script(s) play it by name; the warning thresholds are sane.
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
	ok(WarnSfx.LOW_HP > 0.0 and WarnSfx.LOW_HP <= 0.3 and WarnSfx.BEAT_S.y < WarnSfx.BEAT_S.x and ExitSfx.COUNT_S == 10,
		"the heartbeat is under 30% health, quicker as health falls; the exit countdown is the last 10 s")
	_warn_behaviour()
## The heartbeat starts under LOW_HP, and is silent when healed, downed or at full health.
func _warn_behaviour() -> void:
	var h := Hunter.new()
	h.max_hp = 100.0
	var seen := []
	for st in [[100.0, false], [20.0, false], [20.0, true], [0.0, false]]:
		h.hp = st[0]
		h.downed = st[1]
		WarnSfx.beat_in = 0.0
		WarnSfx.low_hp(h, 0.016)
		seen.append(WarnSfx.beat_in > 0.0)
	h.free()
	WarnSfx.beat_in = 0.0
	ok(seen == [false, true, false, false], "heartbeat only when hurt and up (full, 20 pct, downed, 0: %s)" % [seen])
## 5. A Hunter without its own set plays the shared sounds.
func _fallback() -> void:
	var h := Hunter.new()
	h.arch = "no_such_hunter"
	var got := [HeroSfx.of(h, "dash", "dash"), HeroSfx.of(h, "hurt", "")]
	h.free()
	ok(got == ["dash", ""], "no set: the shared dash, and no voice line (%s)" % [got])

## Each Boki cue is played by the code for its event (kin_downed, the fuse flow, home eat and sleep).
func _boki_cues() -> void:
	var wired := {"boki_downed": "scripts/match/kin_downed.gd", "boki_revive": "scripts/match/kin_downed.gd",
		"boki_fuse": "scripts/match/kin.gd", "boki_unfuse": "scripts/match/kin.gd",
		"boki_eat": "scripts/home/home_econ.gd", "boki_sleep": "scripts/home/home.gd"}
	for cue in wired:
		var src := FileAccess.get_file_as_string("res://" + String(wired[cue]))
		ok(src.contains('"%s"' % cue), "%s is played from %s" % [cue, wired[cue]])

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

## 7. Footsteps on every surface: a ground tile for each, a Hunter of each weight class on it.
const WEIGHT_ARCH := {"light": "archer", "medium": "dolm", "heavy": "ashwick"}
const STEP_VOL := -13.0       # dB: the player's own step in Juice.footstep

func _steps(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var w: World = m.world
	var h: Hunter = m.player
	var tiles := _surface_tiles(w, m.skytrain)
	ok(w.layout_id == "hollowcrown", "step check runs on the Hollow Crown (%s)" % w.layout_id)
	for surf in ["grass", "stone", "wood", "snow", "sand", "water", "metal"]:
		if tiles.has(surf):
			_walk(m, h, surf, tiles[surf])
		else:
			ok(false, "the Hollow Crown has a %s tile to step on" % surf)
	m.queue_free()
	var sky := Match.new()
	main.add_child(sky)
	sky.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "map": "skyreach"})
	sky.set_process(false)
	var car: Transform3D = sky.skytrain.cur[1]
	var deck := Vector3(car.origin.x, sky.skytrain.deck_y(car.origin + Vector3(0, 0.3, 0)), car.origin.z)
	ok(sky.skytrain.on_deck(deck), "a point on a sky train car is on its deck")
	_walk(sky, sky.player, "metal", deck)
	sky.queue_free()

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

## A walkable ground tile centre per surface (the last rect's tile wins, as in StepSurface.at).
func _surface_tiles(w: World, train: SkyTrain) -> Dictionary:
	var out := {}
	for z in w.h:
		for x in w.w:
			var i := w.idx(x, z)
			if w.kind[i] != World.T_GROUND and not w.bridge.has(i):
				continue
			var p := Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
			var surf := StepSurface.at(w, train, p)
			if not out.has(surf):
				out[surf] = p
	return out

