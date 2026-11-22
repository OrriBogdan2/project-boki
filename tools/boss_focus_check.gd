extends RefCounted
## --boss-focus-check: a bot sealed in a boss fight focuses the boss (decision 0061). A rival bot and
## the player stand in a lair together. With the boss asleep the bot goes for the player (the control);
## once the boss wakes and the seal closes, the bot (and its Boki) fight only the boss, though the player
## hit it just before the seal and the player's Boki hits it inside; when the player hits it inside the
## seal, it turns on the player. Never touches the save.

const FIGHT_T := 6.0  # s of boss fight watched
const TURN_T := 1.5  # s the bot gets to turn on the player after the player's hit
const REPICK_T := 0.5  # s for the bot's next think to drop a target it had before the seal (a think is <= 0.5 s)

var bad := 0
var m: Match
var keep: Array = []


func ok(cond: bool, what: String) -> void:
	print("BOSSFOCUS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _step() -> void:
	for h in keep:
		h.hp = h.max_hp
		h.armor = h.max_armor
		if h.downed:
			m.revive_hunter(h, h)
	m.step(Match.DT)


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 21,
			"no_drop": true,
			"fresh_t": 0.0,
			"demo_kin": "cindle"
		}
	)
	m.set_process(false)
	var p: Hunter = m.player
	var b: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	keep = [p, b]
	for h in m.hunters:
		h.ctrl = "bot" if h == b else "idle"
		h.inp["move"] = Vector2.ZERO
		if not keep.has(h):
			h.out = true
	var diff: Dictionary = (b.ai["diff"] as Dictionary).duplicate()
	diff["aggro"] = 1.0  # (a timid roll would cut its reach under the 5 m the control stands at)
	b.ai["diff"] = diff
	for l in m.lairs.list:
		m.lairs.activate(l)
	var f: Dictionary = m.lairs.list[0]
	for g in f["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	m.lairs.open(f, p, "dial")
	var boss: Boss = m.lairs.boss_of(f)
	var side := Vector3(-f["out"].y, 0, f["out"].x)
	var outside: Vector3 = f["gate_c"] + Vector3(f["out"].x, 0, f["out"].y) * 6.0
	_spot(p, outside + side * 2.5)
	_spot(b, outside - side * 2.5)
	# ---- 1. the control: outside the lair, the player is fair game
	var went := false
	P.reveal_t = 2.5      # (seen whichever way the bot faces: it only sees what is in front of it)
	for i in int(2.0 / Match.DT):
		_step()
		if b.ai["tgt"] == p:
			went = true
	p.reveal_t = 0.0
	ok(
		boss.dormant and m.lairs.boss_fight(b).is_empty() and went,
		"outside the lair, boss asleep: the bot goes for the player 5 m away"
	)
	# ---- 2. sealed in: the boss only (a hit from before the seal doesn't count)
	b.hurt(2.0, p, {"src": "shot"})
	p.reveal_t = TURN_T  # (a shot gives the shooter away, whichever way the bot faces)
	# (off the bot's line to the boss: a shot through the boss would hit the player)
	_spot(p, f["c"] + Vector3(-side.z, 0.0, side.x) * 5.0)  # (5 m: a shot at the boss splashes 2.5 m)
	_spot(b, f["c"] - side * 2.5)
	_step()  # (stepping in wakes it)
	ok(
		not m.lairs.boss_fight(b).is_empty() and (f["sealed_in"] as Array).has(p),
		"the boss wakes and seals the bot in with the player"
	)
	var on_p := 0
	var on_boss := 0
	var n := 0
	for i in int(FIGHT_T / Match.DT):
		_step()
		boss.hp = maxf(boss.hp, boss.max_hp * 0.5)  # (the fight lasts the whole watch)
		if i == int(REPICK_T / Match.DT) and p.kin:
			b.hurt(2.0, p.kin, {"src": "melee"})  # (a Boki picks its own fights: not the player starting one)
		if i * Match.DT < REPICK_T:
			continue
		n += 1
		if b.ai["tgt"] == p:
			on_p += 1
		if b.ai["tgt"] == boss:
			on_boss += 1
	var hit_p := float(p.hit_by.get(b.get_instance_id(), -1e9)) > float(f["lock_at"]) + REPICK_T + 0.5
	ok(
		on_p == 0 and not hit_p and p.kin != null,
		(
			"%.0f s of boss fight: past its next think" % FIGHT_T
			+ " the bot never targets the player (%d ticks; the player's Boki hit it)" % on_p
			+ ", nor do it or its Boki hit them"
		)
	)
	ok(on_boss > n * 0.8, "it targets the boss %d%% of the fight" % (100 * on_boss / maxi(1, n)))
	# ---- 3. the player starts it inside the seal: the bot fights back
	# beside the bot, inside its near sense: the scripted hit has no shot to reveal where it came from, and a
	# bot only turns on a rival it can see (its sight wedge faces the boss; 11-21)
	_spot(p, m.lairs._floor_spot(f, b.pos - side * (Match.NEAR_SENSE * 0.8), 0.0))
	b.hurt(2.0, p, {"src": "shot"})
	var turned := false
	for i in int(TURN_T / Match.DT):
		_step()
		if b.ai["tgt"] == p:
			turned = true
			break
	ok(turned, "hit by the player inside the seal: the bot turns on them")
	print("BOSS FOCUS CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
