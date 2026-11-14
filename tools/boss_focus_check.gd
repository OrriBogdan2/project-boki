extends RefCounted
## --boss-focus-check: a bot sealed in a boss fight focuses the boss (decision 0061). A rival bot and
## the player stand in a lair together. With the boss asleep the bot goes for the player (the control);
## once the boss wakes and the seal closes, the bot (and its Boki) fight only the boss, though the player
## hit it just before the seal and the player's Boki hits it inside; when the player hits it inside the
## seal, it turns on the player. Never touches the save.

const FIGHT_T := 6.0      # s of boss fight watched
const TURN_T := 1.5       # s the bot gets to turn on the player after the player's hit
const REPICK_T := 0.5     # s for the bot's next think to drop a target it had before the seal (a think is <= 0.5 s)

var bad := 0
var m: Match
var keep: Array = []

func ok(cond: bool, what: String) -> void:
	print("BOSSFOCUS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _step() -> void:
	for h in keep:
		h.hp = h.max_hp
		h.armor = h.max_armor
		if h.downed: m.revive_hunter(h, h)
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
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "fresh_t": 0.0,
		"demo_kin": "cindle"})
	m.set_process(false)
	var P: Hunter = m.player
	var B: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	keep = [P, B]
	for h in m.hunters:
		h.ctrl = "bot" if h == B else "idle"
		h.inp["move"] = Vector2.ZERO
		if not keep.has(h): h.out = true
	for L in m.lairs.list: m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for g in F["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	m.lairs.open(F, P, "dial")
	var boss: Boss = m.lairs.boss_of(F)
	var side := Vector3(-F["out"].y, 0, F["out"].x)
	var outside: Vector3 = F["gate_c"] + Vector3(F["out"].x, 0, F["out"].y) * 6.0
	_spot(P, outside + side * 2.5)
	_spot(B, outside - side * 2.5)
	# ---- 1. the control: outside the lair, the player is fair game
	var went := false
	for i in int(2.0 / Match.DT):
		_step()
		if B.ai["tgt"] == P: went = true
	ok(boss.dormant and m.lairs.boss_fight(B).is_empty() and went,
		"outside the lair, boss asleep: the bot goes for the player 5 m away")
	# ---- 2. sealed in: the boss only (a hit from before the seal doesn't count)
	B.hurt(2.0, P, {"src": "shot"})
	_spot(P, F["c"] + Vector3(-side.z, 0.0, side.x) * 2.5)      # (off the bot's line to the boss: a shot through the boss would hit it)
	_spot(B, F["c"] - side * 2.5)
	_step()      # (stepping in wakes it)
	ok(not m.lairs.boss_fight(B).is_empty() and (F["sealed_in"] as Array).has(P),
		"the boss wakes and seals the bot in with the player")
	var on_p := 0
	var on_boss := 0
	var n := 0
	for i in int(FIGHT_T / Match.DT):
		_step()
		boss.hp = maxf(boss.hp, boss.max_hp * 0.5)      # (the fight lasts the whole watch)
		if i == int(REPICK_T / Match.DT) and P.kin:
			B.hurt(2.0, P.kin, {"src": "melee"})      # (a Boki picks its own fights: not the player starting one)
		if i * Match.DT < REPICK_T: continue
		n += 1
		if B.ai["tgt"] == P: on_p += 1
		if B.ai["tgt"] == boss: on_boss += 1
	var hit_p := float(P.hit_by.get(B.get_instance_id(), -1e9)) > float(F["lock_at"]) + REPICK_T + 0.5
	ok(on_p == 0 and not hit_p and P.kin != null, "%.0f s of boss fight: past its next think" % FIGHT_T
		+ " the bot never targets the player (%d ticks; the player's Boki hit it)" % on_p
		+ ", nor do it or its Boki hit them")
	ok(on_boss > n * 0.8, "it targets the boss %d%% of the fight" % (100 * on_boss / maxi(1, n)))
	# ---- 3. the player starts it inside the seal: the bot fights back
	_spot(P, m.lairs._floor_spot(F, B.pos + side * 3.0, 0.0))      # (within a provoked bot's reach)
	B.hurt(2.0, P, {"src": "shot"})
	var turned := false
	for i in int(TURN_T / Match.DT):
		_step()
		if B.ai["tgt"] == P:
			turned = true
			break
	ok(turned, "hit by the player inside the seal: the bot turns on them")
	print("BOSS FOCUS CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
