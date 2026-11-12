extends RefCounted
## --in-combat-check: the one "in combat" rule (scripts/match/in_combat.gd, content/rules/combat.json).
## Hitting a foe, being hit, a monster's damage either way and a Boki's hit each start it and last the
## window; healing, falling, friendly fire and damage to yourself don't. The Hunter's shield refill, the
## drive music and the Boki's 10 Hz think all switch on the same frame, on and
## off. Never touches the save.

var bad := 0
var m: Match
var P: Hunter
var foe: Hunter

func ok(cond: bool, what: String) -> void:
	print("INCOMBAT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _step() -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.step(Match.DT)

func _run_for(secs: float) -> void:
	for i in int(round(secs / Match.DT)): _step()

## Out of every fight again (a fresh frame for the next case).
func _calm() -> void:
	_run_for(InCombat.window() + 0.5)

func _case(what: String, want: bool, act: Callable) -> void:
	_calm()
	act.call()
	_step()
	ok(InCombat.is_in(P) == want, "%s: %s" % [what, "in combat" if want else "stays calm"])

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	P = m.player
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team != P.team and foe == null: foe = o
	for o in m.hunters:
		if o != P: o.teleport(m.world.random_ground())
	var k: Kin = P.kin
	k.state = "active"
	k.cmd = "follow"
	k.settle = 1.0
	k.target = null
	k.pos = P.pos + Vector3(1.5, 0, 0)
	k.prev = k.pos
	var mob := m.spawn_mob("skitter", P.pos + Vector3(3, 0, 0))
	ok(InCombat.window() > 0.0, "the window is a row in content/rules/combat.json (%.1f s)" % InCombat.window())
	_case("you hit a foe", true, func(): foe.hurt(5.0, P))
	_case("a foe hits you", true, func(): P.hurt(5.0, foe))
	_case("you hit a monster", true, func(): mob.hurt(1.0, P))
	_case("a monster hits you", true, func(): P.hurt(5.0, mob, {"src": "mob"}))
	_case("Blight hits you", true, func(): P.hurt(5.0, null, {"src": "blight"}))
	_case("your Boki is hit", true, func(): k.hurt(3.0, foe))
	_case("your Boki hits a foe", true, func(): foe.hurt(3.0, k))
	_case("a foe hits another team's Hunter, not you", false, func(): foe.hurt(3.0, mob))
	P.hp = P.max_hp * 0.5
	_case("healing", false, func(): P.heal(10.0))
	_case("a fall", false, func(): P.hurt(5.0, null, {"src": "fall"}))
	_case("a wall slam", false, func(): P.hurt(5.0, foe, {"src": "wall"}))
	_case("damage to yourself", false, func(): P.hurt(5.0, P))
	_calm()
	_same_frame()
	print("INCOMBAT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Shield refill, drive music and the Boki's think, frame by frame from a hit until the window ends.
func _same_frame() -> void:
	P.kin_bonus = {"owner_shield": 40.0}
	P.kin_shield = 0.0
	var k: Kin = P.kin
	k.disengaged = false
	var md: MusicDir = m.music_dir
	foe.hurt(5.0, P)
	var first := {"shield": -1, "music": -1, "boki": -1}
	var window_frames := int(round(InCombat.window() / Match.DT))
	for i in window_frames + 30:
		var shield0 := P.kin_shield
		k.hp = k.max_hp
		k.target = null
		k.pos = P.pos + Vector3(1.5, 0, 0)
		_step()
		md.tick(m, Match.DT)
		var calm := {"shield": P.kin_shield > shield0, "music": md.goal < 1.0, "boki": k.think_t > 0.0}
		for key in first:
			if i == 0:
				ok(not calm[key], "%s is on the frame of the hit" % key)
			if first[key] < 0 and calm[key]:
				first[key] = i
	var frames: Array = first.values()
	ok(frames[0] > 0 and frames.count(frames[0]) == frames.size(),
		"shield, music and Boki think go calm on the same frame (%d, %d, %d)" % frames)
