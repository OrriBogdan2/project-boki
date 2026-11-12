extends RefCounted
## --utility-sfx-check: the belt items' own sounds (BeltSfx, content/rules/belt_sfx.json, docs/AUDIO.md).
##  1. every belt item but the keys names a start sound that is a file of its own (belt_<id>_start): not a
##     stock cue, not shared with another item; every other cue the item names is one too
##  2. using each item plays its start cue; the drinks (Deep Draught, Lostway Scroll, Omen Draught) loop while
##     they channel, end with their end cue and spill with their cancel cue
##  3. a placed item keeps its loop going at its spot, then stops it and plays its end cue when its time is up
##  4. Skyfall's fuse is audible to everyone near: it lasts the 5 s fuse, reaches at least 55 m, and its boom
##     plays when the fuse runs out
## Prints UTILSFX ok/FAIL lines and "UTILSFX DONE, failures: N". Never touches the save file.

const STOCK := ["heal", "build", "cloak", "ping", "throw", "pickup", "shield", "skill", "jump", "blink"]
const FAR_M := 55.0           # a fuse must carry at least this far

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("UTILSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	_files()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	var P: Hunter = m.player
	P.inv_t = 1e9         # a camp's hit would spill a long drink before its end cue
	var ids: Array = BeltSfx.items().keys()
	# drinks first, before any patch can burn the user
	ids.sort_custom(func(a, b): return UtilityUse.use_of(a) == "drink" and UtilityUse.use_of(b) != "drink")
	for id in ids:
		if id != "skyfall_charge":
			_use(m, P, id)
	_skyfall(m, P)
	print("UTILSFX DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _step(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT): m.step(Match.DT)

## 1. Every item's cues are named for it and exist on disk; no two items share one.
func _files() -> void:
	var seen := {}
	var wrong := []
	var n := 0
	for id in UtilityBelt.ids():
		if UtilityBelt.is_key(id):
			continue
		var start := BeltSfx.cue(id, "start")
		if start != "belt_%s_start" % id or start in STOCK:
			wrong.append("%s start '%s'" % [id, start])
		for kind in ["start", "loop", "end", "cancel", "hit"]:
			var c := BeltSfx.cue(id, kind)
			if c == "":
				continue
			n += 1
			if c != "belt_%s_%s" % [id, kind] or seen.has(c) or not FileAccess.file_exists("res://audio/%s.wav" % c):
				wrong.append("%s %s '%s'" % [id, kind, c])
			seen[c] = true
	ok(wrong.is_empty(), "%d cues, one start per item, each its own file %s" % [n, wrong])

func _use(m: Match, P: Hunter, id: String) -> void:
	P.hp = 20.0
	P.armor = 0.0
	P.stun_t = 0.0
	P.downed = false
	P.out = false
	Sfx.listener = P.pos          # a Warp Seed or Lostway Scroll earlier in the loop may have moved the user
	var start := BeltSfx.cue(id, "start")
	Sfx.last_played.erase(start)
	UtilityBelt.set_slot(P, 0, id, 3, 0)
	UtilityUse.start(P, 0, id)
	ok(Sfx.last_played.has(start), "%s: using it plays %s" % [id, start])
	if UtilityUse.use_of(id) == "drink":
		_drink(m, P, id)
	elif UtilityUse.use_of(id) != "repair" and BeltSfx.bed_time(id) > 0.0 and BeltSfx.cue(id, "loop") != "":
		_bed(m, id)
	_step(m, 0.2)

func _drink(m: Match, P: Hunter, id: String) -> void:
	if id == "tonic":
		return          # the tonic and the armour kit are --match-audio-check's
	var key := BeltSfx.loop_key(P, id)
	_step(m, 0.1)
	ok(Sfx.loop_on(key), "%s: loops while it channels" % id)
	P.stun_t = 1.0
	Sfx.last_played.erase(BeltSfx.cue(id, "cancel"))
	_step(m, 0.1)
	ok(not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "cancel")), "%s: a spill plays its cancel cue" % id)
	P.stun_t = 0.0
	UtilityBelt.set_slot(P, 0, id, 3, 0)
	UtilityUse.start(P, 0, id)
	Sfx.last_played.erase(BeltSfx.cue(id, "end"))
	_step(m, UtilityUse.channel(id, "time") + 0.3)
	ok(not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "end")), "%s: finishing plays its end cue" % id)

## 3. The bed started by the use above is held, then ended by running its clock out.
func _bed(m: Match, id: String) -> void:
	_step(m, 0.1)
	var held := Sfx.loops.keys().filter(func(k): return String(k).begins_with("bed"))
	ok(not held.is_empty(), "%s: its loop is going while it stands" % id)
	var end := BeltSfx.cue(id, "end")
	Sfx.last_played.erase(end)
	BeltSfx.tick(m, BeltSfx.bed_time(id) + 1.0)
	var left := Sfx.loops.keys().filter(func(k): return String(k).begins_with("bed"))
	var ended: bool = end == "" or Sfx.last_played.has(end)
	ok(left.is_empty() and ended, "%s: the loop stops and %s plays at the end" % [id, end])

## 4. The fuse is a 5 s loop that carries far, and the boom lands when it runs out.
func _skyfall(m: Match, P: Hunter) -> void:
	var fuse := BeltSfx.cue("skyfall_charge", "loop")
	ok(is_equal_approx(BeltSfx.bed_time("skyfall_charge"), 5.0), "skyfall: the fuse bed lasts the 5 s fuse")
	for kind in ["start", "loop", "end"]:
		var reach := float(Sfx.sound_reach.get(BeltSfx.cue("skyfall_charge", kind), 0.0))
		ok(reach >= FAR_M, "skyfall %s carries %.0f m (at least %.0f)" % [kind, reach, FAR_M])
	Sfx.listener = P.pos
	Sfx.last_played.erase(BeltSfx.cue("skyfall_charge", "end"))
	Sfx.last_played.erase(BeltSfx.cue("skyfall_charge", "start"))
	UtilityBelt.set_slot(P, 0, "skyfall_charge", 3, 0)
	UtilityUse.start(P, 0, "skyfall_charge")
	ok(Sfx.last_played.has(BeltSfx.cue("skyfall_charge", "start")), "skyfall: using it plays its start")
	_step(m, 4.5)
	var early := Sfx.last_played.has(BeltSfx.cue("skyfall_charge", "end"))
	var sounding := Sfx.loops.keys().any(func(k): return String(k).begins_with("bed"))
	ok(not early and sounding, "skyfall: fuse %s still sounding at 4.5 s" % fuse)
	_step(m, 0.8)
	ok(Sfx.last_played.has(BeltSfx.cue("skyfall_charge", "end")), "skyfall: boom after the fuse")
