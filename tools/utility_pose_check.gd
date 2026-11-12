extends RefCounted
## --utility-pose-check: every belt item (content/utility) maps to one of UtilityPose's moves, and the
## move lasts the item's cast time. Data: each item names a move and a cast time; each move eases in
## and out of nothing. Play: for each of the 12 Hunters and each item the hunter uses it in a match and
## the animation state ("drink", or "util" with "util_move") runs as long as the cast (a tonic and an
## armor kit channel and land their effect on the last frame; a place also crouches the body). Keys
## open a lock, so they start their beat directly. Never touches the save.

const TOL := 2.0 * Match.DT    # the beat may be this far off the cast (frame rounding)

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("UPCHECK FAIL ", what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var moves := {}
	for id in UtilityBelt.ids():
		var mv := UtilityPose.move_of(id)
		ok(mv in UtilityPose.MOVES, "%s names a move (%s)" % [id, mv])
		ok(UtilityPose.cast_time(id) > 0.0, "%s has a cast time" % id)
		moves[mv] = true
	for mv in ["throw", "place", "read", "drink"]:
		ok(moves.has(mv), "some item uses " + mv)
		if mv == "drink":
			continue
		ok(UtilityPose.weight(mv, 0.0) == 0.0 and UtilityPose.weight(mv, 1.0) == 0.0, mv + " starts and ends at rest")
		var reach := UtilityPose.hand(mv, 0.5).length()
		ok(UtilityPose.weight(mv, 0.5) > 0.9 and reach > 0.2, mv + " peaks with the hand out")
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	var P: Hunter = m.player
	var played := 0
	for hero in Arch.ids():
		P.set_arch(String(hero))
		for id in UtilityBelt.ids():
			_play(m, P, String(hero), String(id))
			played += 1
	print("UTILITY POSE CHECK DONE, %d plays, failures: %d" % [played, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _play(m: Match, P: Hunter, hero: String, id: String) -> void:
	var tag := "%s/%s" % [hero, id]
	var mv := UtilityPose.move_of(id)
	var cast := UtilityPose.cast_time(id)
	UtilityBelt.clear(P)
	P.beat_t = 0.0
	P.hp = P.max_hp * 0.5
	P.armor = 0.0
	P.teleport(m.world.random_ground())
	P.vel = Vector3.ZERO
	m.step(Match.DT)
	if UtilityBelt.is_key(id):
		UtilityPose.start(P, id)
	else:
		UtilityBelt.grant(P, id, 1)
		ok(UtilityBelt.use_id(P, id), tag + " starts")
	var steps := 0
	var crouched := 0.0
	var kind_ok := true
	while steps < 200:
		P._anim_state(0.0)
		var s := P.anim_s
		var p := maxf(float(s["drink"]), float(s["util"]))
		if p < 0.0:
			break
		kind_ok = kind_ok and (float(s["drink"]) >= 0.0 if mv == "drink" else String(s["util_move"]) == mv)
		crouched = maxf(crouched, float(s["crouch"]))
		m.step(Match.DT)
		steps += 1
	ok(kind_ok, tag + " plays the " + mv + " state")
	ok(absf(steps * Match.DT - cast) <= TOL, "%s lasts %.2f s, the cast is %.2f s" % [tag, steps * Match.DT, cast])
	ok(mv != "place" or crouched > 0.6, tag + " crouches to place")
	match UtilityUse.use_of(id):
		"drink": ok(P.hp > P.max_hp * 0.5, tag + " heals when the drink lands")
		"repair": ok(P.armor >= P.max_armor - 0.5, tag + " repairs when the kit lands")
