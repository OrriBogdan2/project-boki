extends RefCounted
## --sfx-priority-check: enemy wind-ups cut through your own fire (docs/AUDIO.md, enemy priority). A seeded 3v3 bot
## brawl at one spot (you on the Rimewright's held fire and two squadmates against three rival kits), every
## sound that starts logged as "ms name rank dB duck" (rank: SfxVoices.YOU, SQUAD or metres; dB the voice's final
## level, the duck included; duck the dB the priority rule took off it).
## `python3 tools/sfx_loudness.py --brawl <log>` mixes the log offline from the wavs and
## reports each wind-up's level over the rest of the mix. Asserts the rule: a held shot of yours sounds
## Sfx.fire_duck_db lower while a rival's cue sounds and returns to its level after it; a rival's cue never ducks
## on an ally's cast; one sound never fills more than Sfx.SAME_CAP pool voices unless it is yours or a rival's cue.
##   godot --headless -- --sfx-priority-check [--priority-secs=40] [--priority-db=0] [--brawl-out=<file>]

const SECS := 40.0
const SEED := 3011
const YOURS := "rimewright"  # your kit: its hoar fan shoots held fire (rime_shard, 0.24 s takes), seeded to autoplay
const CAST_S := 1.5  # s between rival casts
const RING_M := 7.0  # m: the rival trio stands this far from you, so it is one brawl

var main: Node
var bad := 0
var log_lines := PackedStringArray()
var t0 := 0
var casts := 0
var same_peak := {}  # sound -> most pool voices it filled at once


func ok(cond: bool, what: String) -> void:
	print("SFXPRIO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	var secs := SECS
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--priority-secs="):
			secs = float(a.substr(16))
		elif a.begins_with("--priority-db="):
			Sfx.fire_duck_db = float(a.substr(14))
		elif a.begins_with("--brawl-out="):
			out = a.substr(12)
	Save.no_write = true
	Engine.max_fps = 60
	var m := await _brawl()
	m.player.max_hp *= 20.0
	t0 = Time.get_ticks_msec()
	Sfx.play_jitter_db = 0.0  # the levels below are compared exactly
	Sfx.played.connect(_on_played)
	var start := m.time
	while is_instance_valid(m) and m.time - start < secs:
		m.player.hp = m.player.max_hp
		await main.get_tree().process_frame
		_count_same()
		_cast(m, m.time - start)
	var cues := log_lines.size()
	print("SFXPRIO brawl: %d sounds in %.0f s, fire duck %.1f dB" % [cues, secs, Sfx.fire_duck_db])
	var worst := 0
	for k: String in same_peak:
		if k != HostileCue.NAME and k != "ult_tag_foe" and int(same_peak[k]) > worst:
			worst = int(same_peak[k])
			print("SFXPRIO most voices: %s %d" % [k, worst])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(log_lines) + "\n")
	m.set_process(false)
	if Sfx.fire_duck_db != 0.0:
		await _duck_rule()
	ok(worst <= Sfx.SAME_CAP, "no rival or squadmate sound passes %d voices: peak %d" % [Sfx.SAME_CAP, worst])
	print("SFXPRIO_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## You and two squadmates against a rival trio, all round one spot.
func _brawl() -> Match:
	var archs: Array = Arch.ids()
	archs.erase(YOURS)
	archs.push_front(YOURS)
	var o := Match.demo_opts()
	o.merge(
		{
			"teams": 1,
			"squad": 3,
			"total": 3,
			"no_drop": true,
			"autoplay": true,
			"sim_keep": true,
			"seed": SEED,
			"arch": archs[0],
			"cls": Arch.weight(archs[0]),
			"mates": [1, 2].map(func(i): return {"name": Arch.name_of(archs[i], true), "arch": archs[i]})
		},
		true
	)
	o.erase("demo_match")
	o.erase("fresh_t")
	var old = main.current
	Game.goto("match", o)
	var m: Match = null
	while m == null:
		await main.get_tree().process_frame
		var c = main.current
		if c != old and c is Match and (c as Match).is_processing() and (c as Match).hud != null:
			m = c
	var at := m.player.pos
	for i in range(3, 6):
		var arch: String = archs[i % archs.size()]
		m.make_bot(1, at, [], {"name": Arch.name_of(arch, true), "arch": arch})
	for h: Hunter in m.hunters:
		var i := m.hunters.find(h)
		var spot := at + (Vector3(1.5 * (i % 3), 0, 1.0) if h.team == 0 else Vector3(RING_M, 0, 1.5 * (i % 3)))
		h.teleport(Vector3(spot.x, m.world.ground_at(spot.x, spot.z), spot.z))
		if h.kin:
			(h.kin as Kin).teleport(h.pos + Vector3(1.0, 0, 0.7))
	return m


## The rival trio casts in turn: one E every CAST_S, an R every third (cooldowns cleared, as a scripted fight).
func _cast(m: Match, t: float) -> void:
	var n := int(t / CAST_S)
	if n == casts:
		return
	casts = n
	var rivals := m.hunters.filter(func(h: Hunter): return h.team != m.player.team and h.ak != null)
	if rivals.is_empty():
		return
	var k: ArchKit = (rivals[n % rivals.size()] as Hunter).ak
	k.cd["e"] = 0.0
	k.cd["r"] = 0.0
	k.h.slot_lv["ult"] = maxi(1, int(k.h.slot_lv.get("ult", 0)))
	if n % 3 == 0:
		k.use_r()
	else:
		k.use_e()


func _voice_db() -> float:
	return Sfx.players[(Sfx.next - 1 + Sfx.POOL) % Sfx.POOL].volume_db


func _on_played(sname: String, _at: Variant, _vol_db: float, _pitch: float) -> void:
	var i := (Sfx.next - 1 + Sfx.POOL) % Sfx.POOL
	var now := Time.get_ticks_msec()
	var duck := Sfx.priority_duck(sname) if Sfx.voices.rank[i] == SfxVoices.YOU else 0.0
	var line := "%d %s %.1f %.1f %.1f" % [now - t0, sname, Sfx.voices.rank[i], Sfx.players[i].volume_db, duck]
	log_lines.append(line)


func _count_same() -> void:
	var n := {}
	for i in Sfx.POOL:
		if Sfx.players[i].playing and Sfx.voices.rank[i] != SfxVoices.YOU:
			var s: String = Sfx.voices.sound[i]
			n[s] = int(n.get(s, 0)) + 1
	for s: String in n:
		same_peak[s] = maxi(int(same_peak.get(s, 0)), int(n[s]))


## One held shot of yours before, during and after a rival's cue.
func _duck_rule() -> void:
	Sfx.reset_scene_audio(0.0)
	var shot := func() -> float:
		FireSfx.shot(1, "rime_shard", null, -2.0, 0.12)
		return _voice_db()
	await main.get_tree().create_timer(0.35).timeout
	var base: float = shot.call()
	await main.get_tree().create_timer(0.35).timeout
	Sfx.priority_cue(HostileCue.NAME)
	var ducked: float = shot.call()
	var cue_s := Sfx.take_len(HostileCue.NAME, 0)
	await main.get_tree().create_timer(cue_s + 0.4).timeout
	var after: float = shot.call()
	ok(is_equal_approx(ducked - base, Sfx.fire_duck_db), "your shot sits %.1f dB under a rival's cue" % (ducked - base))
	ok(is_equal_approx(after, base), "back at its level after the cue (%.2f s): %.1f vs %.1f" % [cue_s, after, base])
	# a sound of yours that repeats (a hit confirm) ducks too; a one-off of yours does not
	await main.get_tree().create_timer(0.5).timeout
	Sfx.play("ab_hit", null, -2.0)
	var one := _voice_db()
	await main.get_tree().create_timer(0.1).timeout
	Sfx.priority_cue(HostileCue.NAME)
	Sfx.play("ab_hit", null, -2.0)
	var rep := _voice_db()
	await main.get_tree().create_timer(0.6).timeout
	Sfx.priority_cue(HostileCue.NAME)
	Sfx.play("ab_hit", null, -2.0)
	var lone := _voice_db()
	var d := rep - one
	ok(is_equal_approx(d, Sfx.fire_duck_db), "a repeating hit confirm of yours ducks too: %.1f dB" % d)
	ok(is_equal_approx(lone, one), "a one-off of yours is not ducked: %.1f vs %.1f" % [lone, one])
