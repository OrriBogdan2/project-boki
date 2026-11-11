extends RefCounted
## --utility-parity-check: the belt items that changed to match the source (docs/SOURCE_UTILITIES.md
## section 4). Tonic, armor kit and slot rules are --equal-check; this one covers the field items:
##  1. Bounty Banner: knocked under it you go straight out (no wisp), and the knocker pockets the gems.
##  2. Skyfall Charge: the blast kills a full-health hunter, then the ground burns for 3 s.
##  3. Blight Flask: the patch lasts 40 s and blights whoever stands in it (healing barely takes).
##  4. Using an item and moving (MOVES): cast length, speed, starting in the air or mid-dash, a hit.
##  5. Cloud Raft: open air only, and you hang in the air for its 0.3 s cast.
## Prints UTIL ok/FAIL lines and "UTIL DONE, failures: N". Never touches the save file.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("UTIL %s %s" % ["ok  " if cond else "FAIL", what])
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
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()         # the camps stay out of it: only the belt items hurt anyone here
	m.mobs.clear()
	var P: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	foe.ctrl = "idle"                        # a bot would walk out of the blast and the patch
	_banner(m, P, foe)
	_skyfall(m, P, foe)
	_blight(m, P, foe)
	_moves(m, P, foe)
	_raft_cast(m, P)
	print("UTIL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

## Fields the belt put down: the biome's own lava vents come and go on their own clock.
func _patches(m: Match) -> int:
	return m.fields.list.filter(func(f): return f["ctx"]["slot"] != "lava").size()

func _steps(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT): m.step(Match.DT)

func _banner(m: Match, P: Hunter, foe: Hunter) -> void:
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "bounty_banner", 1)
	P.lives = 3
	foe.gems = 0
	var gems0 := foe.gems
	ok(UtilityBelt.use_id(P, "bounty_banner"), "a Bounty Banner starts")
	_steps(m, 1.0)
	ok(P.reveal_t > 100.0 and bool(m.get_meta("banner_%d" % P.team, false)), "...and shows you to everyone")
	P.hurt(P.hp + P.armor + 50.0, foe, {"src": "shot"})
	ok(P.downed or P.out, "a rival knocks you under it")
	_steps(m, 1.0)
	ok(P.out and P.lives == 3, "...and you go straight out: no wisp, no spare life spent")
	ok(foe.gems == gems0 + int(UtilityBelt.def("bounty_banner").get("reward", 0)),
			"the knocker pockets the bounty (%d gems)" % (foe.gems - gems0))
	ok(not bool(m.get_meta("banner_%d" % P.team, false)), "the banner is over, the squad may raise another")

func _skyfall(m: Match, P: Hunter, foe: Hunter) -> void:
	P.out = false
	P.downed = false
	P.dead = false
	P.hp = P.max_hp
	P.armor = P.max_armor
	foe.out = false
	foe.downed = false
	foe.dead = false
	foe.hp = foe.max_hp
	foe.armor = foe.max_armor
	foe.inv_t = 0.0
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "skyfall_charge", 1)
	foe.teleport(P.pos + Vector3(6.0, 0, 0))
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "skyfall_charge"), "a Skyfall Charge is called")
	_steps(m, 4.5)
	ok(foe.hp >= foe.max_hp - 0.5, "...nothing lands for 5 s")
	_steps(m, 1.0)
	ok(foe.downed or foe.out or foe.dead, "the blast knocks a full-health rival outright (hp %.0f)" % foe.hp)
	ok(_patches(m) >= 1, "then the ground burns (a fire patch)")
	_steps(m, 3.5)
	ok(_patches(m) == 0, "...for 3 s")

func _blight(m: Match, P: Hunter, foe: Hunter) -> void:
	foe.out = false
	foe.downed = false
	foe.dead = false
	foe.hp = foe.max_hp
	foe.armor = foe.max_armor
	foe.blight_t = 0.0
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "blight_flask", 1)
	foe.teleport(P.pos + Vector3(4.0, 0, 0))
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "blight_flask"), "a Blight Flask is thrown")
	_steps(m, 2.5)
	ok(foe.blight_t > 0.0 and foe.hp + foe.armor < foe.max_hp + foe.max_armor,
			"a rival in the patch is blighted and hurt")
	_steps(m, 35.0)
	ok(_patches(m) >= 1, "the patch is still there after 37 s")
	_steps(m, 4.0)
	ok(_patches(m) == 0, "...and gone after 40 s")

## 4. The table in docs/SOURCE_UTILITIES.md "Using an item and moving", one row per belt item (keys aside:
## they need a lock; the Cloud Raft is 5). [cast s, speed while it runs, starts mid-air, starts mid-dash,
## a hit spills it]. The drinks and the kit channel; everything else lands at once.
const MOVES := {
	"tonic": [1.0, 1.0, true, false, true], "deep_draught": [5.0, 0.4, true, false, true],
	"lostway_scroll": [4.0, 1.0, true, false, true], "omen_draught": [1.0, 1.0, true, false, true],
	"armor_kit": [1.6, 0.45, true, false, true],
	"thorn_wall": [0.0, 1.0, true, true, false], "pilfer_pouch": [0.0, 1.0, true, true, false],
	"medkit": [0.0, 1.0, true, true, false], "smoke": [0.0, 1.0, true, true, false],
	"scanner": [0.0, 1.0, true, true, false], "hawk_whistle": [0.0, 1.0, true, true, false],
	"jump_pad": [0.0, 1.0, true, true, false], "gust_fan": [0.0, 1.0, true, true, false],
	"shatter_charge": [0.0, 1.0, true, true, false], "blight_flask": [0.0, 1.0, true, true, false],
	"skyfall_charge": [0.0, 1.0, true, true, false], "shield_cell": [0.0, 1.0, true, true, false],
	"stim": [0.0, 1.0, true, true, false], "lookout_lantern": [0.0, 1.0, true, true, false],
	"toss_satchel": [0.0, 1.0, true, true, false], "twin_gate": [0.0, 1.0, true, true, false],
	"warp_seed": [0.0, 1.0, true, true, false], "bounty_banner": [0.0, 1.0, true, true, false],
	"hearth_lamp": [0.0, 1.0, true, true, false], "revive_ember": [0.0, 1.0, true, true, false],
}

func _moves(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	var ground := P.pos
	var team := foe.team
	foe.team = P.team           # a fallen squadmate for the ember
	var rows := UtilityBelt.stock_ids().filter(func(id): return not UtilityBelt.def(id).get("float", false))
	ok(rows.all(func(id): return MOVES.has(id)), "every belt item has a movement row (missing: %s)"
			% str(rows.filter(func(id): return not MOVES.has(id))))
	for id in rows:
		if not MOVES.has(id):
			continue
		var row: Array = MOVES[id]
		var cast := float(row[0])
		# on the ground, running: the cast and your speed
		_ready_for(m, P, foe, id, ground)
		ok(UtilityBelt.use_id(P, id), "%s starts on the ground" % id)
		var held := P.drink_t + P.kit_t
		ok(absf(held - cast) < 0.05, "...%s cast %.1f s (expected %.1f)" % [id, held, cast])
		var spd := UtilityUse.channel_move(P)
		ok(is_equal_approx(spd, float(row[1])), "...%s speed %.2f while it runs (expected %.2f)" % [id, spd, row[1]])
		# a drink or a repair spends its charge when it ends; the rest at once
		ok(UtilityBelt.count(P, id) == (1 if held > 0.0 else 0), "...%s spends its charge when it lands" % id)
		# a hit
		P.inv_t = 0.0
		P.hurt(5.0, null, {"src": "shot"})
		P.inv_t = 99.0
		if bool(row[4]):
			ok(P.drink_t <= 0.0 and P.kit_t <= 0.0 and UtilityBelt.count(P, id) == 1,
					"...%s: a hit spills it, nothing spent (%d left)" % [id, UtilityBelt.count(P, id)])
		else:
			ok(UtilityBelt.count(P, id) == 0, "...%s: a hit does not undo it" % id)
		# in the air (not gliding)
		_ready_for(m, P, foe, id, ground)
		P.teleport(ground + Vector3(0, 4.0, 0))
		P.grounded = false
		var started := UtilityBelt.use_id(P, id)
		var going := P.drink_t + P.kit_t > 0.0 or UtilityBelt.count(P, id) == 0
		ok(started == bool(row[2]) and going == bool(row[2]),
				"...%s mid-air: %s" % [id, "starts" if row[2] else "waits"])
		# mid-dash
		_ready_for(m, P, foe, id, ground)
		P.roll_t = 0.15
		P.roll_dir = Vector2.RIGHT
		P.move_kind = "dash"
		started = UtilityBelt.use_id(P, id)
		going = P.drink_t + P.kit_t > 0.0 or UtilityBelt.count(P, id) == 0
		ok(started == bool(row[3]) and going == bool(row[3]),
				"...%s mid-dash: %s" % [id, "starts" if row[3] else "denied, nothing spent"])
		P.roll_t = 0.0
	foe.team = team
	P.inv_t = 0.0
	_ready_for(m, P, foe, "", ground)

## One fresh charge of `id` on an otherwise empty belt, the caster hurt and bare so a drink or a repair has
## work to do, the squadmate down for the ember, and nothing of the last item left: no channel, no pending
## fuse or raid, no open gate or banner.
func _ready_for(m: Match, P: Hunter, ally: Hunter, id: String, ground: Vector3) -> void:
	for z in m.fields.list:
		z["t"] = 0.0
	m._later.clear()
	m.step(Match.DT)
	m.remove_meta("banner_%d" % P.team)
	_live(P)
	P.teleport(ground)
	P.grounded = true
	P.vel = Vector3.ZERO
	P.drink_t = 0.0
	P.kit_t = 0.0
	P.inv_t = 99.0
	P.hp = P.max_hp * 0.3
	P.armor = 0.0
	P.inp["aim"] = ground + Vector3(6.0, 0, 0)
	ally.out = true
	ally.gone = false
	if id != "":
		UtilityBelt.grant(P, id, 1)

func _live(x: Hunter) -> void:
	x.out = false
	x.downed = false
	x.dead = false
	x.gone = false
	x.hp = x.max_hp
	x.armor = x.max_armor
	x.inv_t = 0.0
	x.blight_t = 0.0
	x.roll_t = 0.0
	x.shield = 0.0
	x.belt = UtilityBelt.empty()

## Both on open flat ground, the rival 6 m off.
func _stage(m: Match, P: Hunter, foe: Hunter) -> void:
	_live(P)
	_live(foe)
	var found := false
	for i in 300:
		var p: Vector3 = m.world.random_ground()
		if p != Vector3.INF and _open(m, p):
			P.teleport(p)
			found = true
			break
	ok(found, "open ground to stage a test on")
	P.vel = Vector3.ZERO
	P.inp["aim"] = P.pos + Vector3(6.0, 0, 0)
	foe.teleport(P.pos + Vector3(6.0, 0, 0))

## Flat ground all round to 9 m, so a gate or a pad can go anywhere near.
func _open(m: Match, p: Vector3) -> bool:
	for a in 8:
		for k: float in [3.0, 6.0, 9.0]:
			var q := p + Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * k
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - p.y) > 0.3:
				return false
	return true

## 5. Cloud Raft: denied on solid ground; over the abyss you hang in the air for its 0.3 s cast and the
## raft forms under you [P-1.03].
func _raft_cast(m: Match, P: Hunter) -> void:
	var spot := _edge(m)
	if spot.is_empty():
		ok(false, "an island edge for the raft cast")
		return
	var from: Vector3 = spot["from"]
	var dir: Vector2 = spot["dir"]
	_live(P)
	P.teleport(from)
	P.grounded = true
	P.vel = Vector3.ZERO
	UtilityBelt.grant(P, "cloud_raft", 1)
	ok(not UtilityBelt.use_id(P, "cloud_raft") and UtilityBelt.count(P, "cloud_raft") == 1,
			"a Cloud Raft is for open air only: denied on the ground")
	var air := Vector3(from.x + dir.x * 2.0, from.y + 1.5, from.z + dir.y * 2.0)
	P.teleport(air)
	P.grounded = false
	P.inp["aim"] = air + Vector3(dir.x, 0, dir.y) * 3.0
	var spans: int = m.verbs.terrain.size()
	ok(UtilityBelt.use_id(P, "cloud_raft"), "...over the abyss it casts")
	ok(absf(P.float_t - 0.3) < 0.02, "...and holds you in the air for 0.3 s (%.2f)" % P.float_t)
	_steps(m, 0.2)
	ok(absf(P.pos.y - air.y) < 0.02 and absf(P.vel.y) < 0.01 and m.verbs.terrain.size() == spans,
			"...no fall and no raft yet at 0.2 s (dy %.3f)" % (P.pos.y - air.y))
	_steps(m, 0.2)
	ok(m.verbs.terrain.size() == spans + 1 and P.float_t <= 0.0, "...the raft forms at 0.3 s and the hold ends")
	ok(not m.world.is_void(air.x, air.z), "...from your own tile, not a step ahead of you")
	_steps(m, 1.5)
	var deck := floorf(air.y / World.LEVEL) * World.LEVEL
	ok(P.grounded and absf(P.pos.y - deck) < 0.05,
			"...you land on it, at your own height (y %.2f, raft %.2f)" % [P.pos.y, deck])

## A spot on an island 1 m in from a clear edge, and the way out over the abyss.
func _edge(m: Match) -> Dictionary:
	for isl in m.world.islands.size():
		for tries in 12:
			var p: Vector3 = m.world.random_ground(isl)
			for a in 8:
				var d := Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0))
				for k in range(1, 60):
					var q := Vector2(p.x, p.z) + d * float(k) * 0.5
					if m.world.is_void(q.x, q.y):
						var b := Vector2(p.x, p.z) + d * float(k - 2) * 0.5
						if k > 3 and not m.world.is_void(b.x, b.y) and not m.world.is_block(b.x, b.y):
							return {"from": Vector3(b.x, m.world.ground_at(b.x, b.y), b.y), "dir": d}
						break
					if m.world.is_block(q.x, q.y):
						break
	return {}
