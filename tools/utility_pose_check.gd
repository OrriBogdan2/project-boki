extends RefCounted
## --utility-pose-check: every belt item (content/utility) maps to one of UtilityPose's moves, and the
## move lasts the item's cast time. Data: each item names a move and a cast time; each move eases in
## and out of nothing. Play: for each of the 12 Hunters and each item the hunter uses it in a match and
## the animation state ("drink", or "util" with "util_move") runs as long as the cast (a drink or a
## kit channels and lands its effect on the last frame; a place also crouches the body when standing,
## and on the move no item touches the legs). Keys open a lock and an ember needs someone to wake, so
## those start their beat directly. Never touches the save.

const TOL := 2.0 * Match.DT    # the beat may be this far off the cast (frame rounding)
const SPACE := 16.0            # m between two plays' spots (Skyfall's blast is 6 m, a wall 6 m long)
const RUN_SPEED := 4.0         # m/s: a running hunter, well over UtilityPose.STILL

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
	for mv in UtilityPose.MOVES:
		ok(moves.has(mv), "some item uses " + mv)
		if mv == "drink":
			continue
		ok(UtilityPose.weight(mv, 0.0) == 0.0 and UtilityPose.weight(mv, 1.0) == 0.0, mv + " starts and ends at rest")
		var reach := UtilityPose.hand(mv, 0.5).length()
		ok(UtilityPose.weight(mv, 0.5) > 0.9 and reach > 0.2, mv + " peaks with the hand out")
	var played := 0
	for hero in Arch.ids():
		var m := _match(main)
		var P: Hunter = m.player
		P.set_arch(String(hero))
		var used: Array[Vector3] = []
		for id in UtilityBelt.ids():
			_play(m, P, String(hero), String(id), used)
			played += 1
		main.remove_child(m)
		m.queue_free()
	print("UTILITY POSE CHECK DONE, %d plays, failures: %d" % [played, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## A quiet match of idle hunters, no monsters: one per Hunter, so nothing an earlier Hunter left behind
## (a fuse still burning, a zone, a gate about to swap) lands on the next.
func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for k in m.kins: k.queue_free()      # a rival Boki's bite would stun the Hunter mid-move
	m.kins.clear()
	if m.biomes: m.biomes.hazards.clear()      # as would a lightning rod
	for h in m.hunters:
		h.ctrl = "idle"
	return m

## Open ground at least SPACE from every earlier play of this match (their pads, walls and blasts).
func _fresh_ground(m: Match, used: Array[Vector3]) -> Vector3:
	var at: Vector3 = m.world.random_ground()
	for t in 60:
		if used.all(func(u: Vector3) -> bool: return u.distance_to(at) > SPACE):
			break
		at = m.world.random_ground()
	used.append(at)
	return at

func _play(m: Match, P: Hunter, hero: String, id: String, used: Array[Vector3]) -> void:
	var tag := "%s/%s" % [hero, id]
	var mv := UtilityPose.move_of(id)
	var cast := UtilityPose.cast_time(id)
	UtilityBelt.clear(P)
	P.beat_t = 0.0
	P.hp = P.max_hp * 0.5
	P.armor = 0.0
	P.teleport(_fresh_ground(m, used))
	P.vel = Vector3.ZERO
	m.step(Match.DT)
	m.remove_meta("banner_%d" % P.team)      # one banner per squad at a time; each play is a fresh one
	if UtilityBelt.is_key(id) or not UtilityUse.can_use(P, id):
		UtilityPose.start(P, id)
	else:
		UtilityBelt.grant(P, id, 1)
		ok(UtilityBelt.use_id(P, id), tag + " starts")
	var steps := 0
	var crouched := 0.0
	var run_crouch := 0.0
	var kind_ok := true
	var heal_hp := UtilityUse.channel(id, "heal") if UtilityUse.use_of(id) == "drink" else 0.0
	while steps < int(cast / Match.DT) + 20:
		P._anim_state(0.0)
		var s := P.anim_s
		var p := maxf(float(s["drink"]), float(s["util"]))
		if p < 0.0:
			break
		kind_ok = kind_ok and (float(s["drink"]) >= 0.0 if mv == "drink" else String(s["util_move"]) == mv)
		crouched = maxf(crouched, float(s["crouch"]))
		P.vel = Vector3(RUN_SPEED, 0.0, 0.0)      # the same frame on the move: the legs stay the gait's
		P._anim_state(0.0)
		run_crouch = maxf(run_crouch, float(P.anim_s["crouch"]) - P.crouch_k)
		P.vel = Vector3.ZERO
		m.step(Match.DT)
		steps += 1
	ok(kind_ok, tag + " plays the " + mv + " state")
	ok(absf(steps * Match.DT - cast) <= TOL, "%s lasts %.2f s, the cast is %.2f s" % [tag, steps * Match.DT, cast])
	ok(mv != "place" or crouched > 0.6, tag + " crouches to place")
	ok(run_crouch < 0.01, tag + " leaves the legs free on the move")
	match UtilityUse.use_of(id):
		"drink": ok(heal_hp <= 0.0 or P.hp > P.max_hp * 0.5, tag + " heals when the drink lands")
		"repair": ok(P.armor >= P.max_armor - 0.5, tag + " repairs when the kit lands")
