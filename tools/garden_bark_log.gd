extends RefCounted
## --garden-bark-log: 10 minutes of farm time on the base demo (BaseDemo), stepped at DT per call like the soak,
## with the player patting one Boki every PAT_EVERY s. It logs every Boki voice that sounds (Sfx.played: a
## bk_<species>_<mood> clip or the shared kin_/boki_ cue) with its take and pitch step, and counts the repeats:
## a clip (voice, take and pitch step) that sounds again within REPEAT_S, and the same clip twice in a row.
## Then it reads the bed of every zone and the hub through HomeAmbience (the steps of --garden-audio-check) and
## counts the zones with none. Prints BARKLOG lines: a repeat count is a measurement, not a pass mark
## (--garden-sfx-check section 15 asserts the bound).

const RUN_S := 600.0  # s of farm time
const DT := 0.25  # s of farm time per step
const REPEAT_S := 20.0  # s: a clip heard again inside this is a repeat
const PAT_EVERY := 15.0  # s between the player's pats
const SPAWN_EVERY := 400  # steps between frames, so deferred frees and timers can run

var main: Node
var t := 0.0
var heard: Array = []  # [t, cue, take, step]


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(7)
	var d := BaseDemo.save()
	var home = await main._hb_home()
	BaseDemo.new().stage(home)
	Sfx.played.connect(_on_played)
	var pats := 0
	var steps := int(RUN_S / DT)
	for i in steps:
		t += DT
		HomeVoice.clock_ms = int(t * 1000.0)
		Sfx.last_played.clear()  # Sfx's gaps run on the wall clock, which a stepped run does not have
		Sfx.recent.clear()
		home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
		home._move_kin(DT)
		home._care_tick(DT)
		home.hecon.tick(DT)
		if fmod(t, PAT_EVERY) < DT:
			home._pet_kin(home.kins[pats % home.kins.size()])
			pats += 1
		if i % SPAWN_EVERY == 0:
			await main.get_tree().process_frame
	HomeVoice.clock_ms = -1
	Sfx.played.disconnect(_on_played)
	_report(pats)
	_beds()
	home.queue_free()
	await main.get_tree().process_frame
	main.get_tree().quit(0)


func _on_played(sname: String, _pos, _vol: float, _pitch: float) -> void:
	if not (sname.begins_with("bk_") or sname.begins_with("kin_") or sname.begins_with("boki_")):
		return
	var steps = Sfx.get("last_step")  # (null before the voice picks)
	var step := float(steps.get(sname, 1.0)) if steps != null and sname.begins_with("bk_") else 1.0
	heard.append([t, sname, int(Sfx.last_take.get(sname, 0)), step])


func _report(pats: int) -> void:
	var voices := heard.filter(func(h: Array) -> bool: return String(h[1]).begins_with("bk_"))
	var clip_rep := 0
	var cue_rep := 0
	var last_cue := {}
	var seen := {}  # "cue|take|step" -> when it last sounded
	var per := {}
	for h: Array in voices:
		var key := "%s|%d|%.2f" % [h[1], h[2], h[3]]
		if seen.has(key) and float(h[0]) - float(seen[key]) <= REPEAT_S:
			clip_rep += 1
		seen[key] = h[0]
		cue_rep += 1 if last_cue.get(h[1], "") == key else 0
		last_cue[h[1]] = key
		per[h[1]] = int(per.get(h[1], 0)) + 1
	print("BARKLOG %.0f s of farm time, %d pats, %d Boki voices sounded (%d species barks, %d shared cues)"
		% [t, pats, heard.size(), voices.size(), heard.size() - voices.size()])
	print("BARKLOG per voice: %s" % [per])
	print("BARKLOG repeated clip within %.0f s: %d of %d barks" % [REPEAT_S, clip_rep, voices.size()])
	print("BARKLOG same clip twice in a row: %d" % cue_rep)


func _beds() -> void:
	var none := []
	for z: String in GardenZones.ids() + [GardenZones.HUB]:
		GardenZones.here = z
		var amb := HomeAmbience.new()
		for i in 24:
			amb.tick(0.25, 0.5, false, {}, Vector3.ZERO)
			Sfx._process(0.25)
		var bed := HomeAmbience.zone_bed(z)
		var up := float(amb.levels.get(bed, 0.0)) >= 0.99 and Sfx.amb_layers.has(bed)
		print("BARKLOG bed %s: %s %s" % [z, bed, "plays" if up else "NONE"])
		if not up:
			none.append(z)
		Sfx.clear_amb_layers(0.0)
	print("BARKLOG zones with no ambience: %d %s" % [none.size(), none])
