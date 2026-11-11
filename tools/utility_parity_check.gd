extends RefCounted
## --utility-parity-check: the belt items that changed to match the source (docs/SOURCE_UTILITIES.md
## section 4). Tonic, armor kit and slot rules are --equal-check; this one covers the field items:
##  1. Bounty Banner: knocked under it you go straight out (no wisp), and the knocker pockets the gems.
##  2. Skyfall Charge: the blast kills a full-health hunter, then the ground burns for 3 s.
##  3. Blight Flask: the patch lasts 40 s and blights whoever stands in it (healing barely takes).
##  4. Twin Gate swaps on a second press once armed, not by itself.   5. Gust Fan can be shot down.
##  6. Pilfer Pouch: a 1.5 s channel that also empties locked chests.  7. Skyfall hurts allies, razes beacons.
##  8. Lookout Lantern can be taken down by whoever steps on it.     9. Toss Satchel bounces a body in the air.
## 10. Thorn Wall roots you 2 s and rises after.  11. Hearth Lamp revives carry sickness (damage and healing).
## 12. Tonic cleanses anti-heal.  13. Each knock shortens a Bounty Banner.  14. Cloud Raft refills gliders.
## 15. Using an item and moving (MOVES): cast length, speed, starting in the air or mid-dash, a hit.
## 16. Cloud Raft: open air only, and you hang in the air for its 0.3 s cast.
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
	_stage(m, P, foe)
	_gate(m, P, foe)
	_fan(m, P, foe)
	_pilfer(m, P, foe)
	_skyfall_friendly(m, P, foe)
	_lantern(m, P, foe)
	_satchel(m, P, foe)
	_thorn(m, P)
	_lamp_sickness(m, P, foe)
	_tonic(m, P)
	_bounty_cut(m, P, foe)
	_raft(m, P, foe)
	_moves(m, P, foe)
	_raft_cast(m, P)
	print("UTIL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

## Fields the belt put down: the biome's own lava vents come and go on their own clock.
func _patches(m: Match) -> int:
	return m.fields.list.filter(func(f): return (f["ctx"] as Dictionary).get("slot", "") != "lava").size()

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
	_live(P)        # the Skyfall blast above reaches its own thrower now
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

# ------------------------------------------------------------------ the Nov 10 follow-ups
func _live(x: Hunter) -> void:
	x.out = false
	x.downed = false
	x.dead = false
	x.gone = false
	x.hp = x.max_hp
	x.armor = x.max_armor
	x.inv_t = 0.0
	x.sick_t = 0.0
	x.blight_t = 0.0
	x.root_t = 0.0
	x.roll_t = 0.0
	x.shield = 0.0
	x.belt = UtilityBelt.empty()

## Item patches (gates, wards, packs, banners) standing now; the damage patches are not counted.
func _kx_zones(m: Match) -> int:
	return m.fields.list.filter(func(z): return z.has("kx")).size()

## Both hunters alive and empty-handed, the caster on open ground, the rival 6 m off.
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
	for h in [P, foe]:
		if h.kin:
			h.kin.stow()                     # on the shoulder: out, your Boki would run off and bite the rival

## Flat ground all round to 9 m, so a gate or a pad can go anywhere near.
func _open(m: Match, p: Vector3) -> bool:
	for a in 8:
		for k: float in [3.0, 6.0, 9.0]:
			var q := p + Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * k
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - p.y) > 0.3:
				return false
	return true

func _gate(m: Match, P: Hunter, foe: Hunter) -> void:
	var home := P.pos
	var far := home + Vector3(9.0, 0, 0)
	P.inp["aim"] = far
	UtilityBelt.grant(P, "twin_gate", 2)
	ok(UtilityBelt.use_id(P, "twin_gate"), "a Twin Gate opens")
	foe.teleport(far)
	_steps(m, 4.0)
	ok(not UtilityBelt.use_id(P, "twin_gate"), "...pressing it again before 8 s does nothing")
	_steps(m, 5.0)
	ok(P.flat_dist(home) < 1.0 and foe.flat_dist(far) < 1.0, "...and nothing swaps by itself")
	ok(UtilityBelt.use_id(P, "twin_gate"), "the second press, once armed, swaps")
	_steps(m, 0.2)
	ok(P.flat_dist(far) < 2.0 and foe.flat_dist(home) < 2.0, "...you and the rival trade places")
	ok(UtilityBelt.count(P, "twin_gate") == 1, "...at no extra charge")
	_steps(m, 1.0)
	ok(_kx_zones(m) == 0, "...and both gates close")

func _fan(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	UtilityBelt.grant(P, "gust_fan", 1)
	UtilityBelt.use_id(P, "gust_fan")
	var fan: Dictionary = m.gpads[-1]
	var hp0 := float(fan["hp"])
	var at: Vector3 = fan["pos"] + Vector3(0, 1.0, 0)
	ok(hp0 > 0.0 and hp0 < 150.0, "a Gust Fan has health (%.0f)" % hp0)
	ok(m.verbs.shot_check({"team": P.team, "dmg": 40.0}, at) == "", "...your own bullets pass through it")
	ok(m.verbs.shot_check({"team": foe.team, "dmg": 40.0}, at) == "end" and float(fan["hp"]) == hp0 - 40.0,
			"...a rival's bullet is stopped and hurts it")
	for i in 3:
		m.verbs.shot_check({"team": foe.team, "dmg": 40.0}, at)
	_steps(m, 0.1)
	ok(not m.gpads.has(fan), "...and enough of them shoot it down")

func _pilfer(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	var chest := m.add_chest(P.pos + Vector3(6.0, 0, 0))
	foe.gems = 100
	UtilityBelt.grant(P, "pilfer_pouch", 2)
	ok(UtilityBelt.use_id(P, "pilfer_pouch"), "a Pilfer Pouch is thrown")
	ok(P.root_t > 1.0, "...and you stand still to channel")
	_steps(m, 1.0)
	ok(foe.gems == 100 and not chest["open"], "...nothing is taken for 1.5 s")
	_steps(m, 0.8)
	ok(foe.gems == 50, "then half the rival's gems go (%d left)" % foe.gems)
	ok(chest["open"], "...and the locked chest there is emptied")
	_steps(m, 3.0)
	UtilityBelt.grant(P, "pilfer_pouch", 1)
	ok(UtilityBelt.use_id(P, "pilfer_pouch"), "a second pouch")
	P.downed = true
	_steps(m, 2.0)
	P.downed = false
	ok(foe.gems == 50, "...knocked while channelling, the raid never happens")

func _skyfall_friendly(m: Match, P: Hunter, ally: Hunter) -> void:
	_stage(m, P, ally)
	var team := ally.team
	ally.team = P.team
	ally.teleport(P.pos + Vector3(4.0, 0, 0))
	P.inp["aim"] = ally.pos
	Beacons.lamp(m, ally.pos + Vector3(1.0, 0, 0))
	var lamp: Dictionary = m.beacons[-1]
	UtilityBelt.grant(P, "skyfall_charge", 1)
	UtilityBelt.use_id(P, "skyfall_charge")
	_steps(m, 5.5)
	ok(ally.downed or ally.out or ally.dead, "a Skyfall blast takes down a squadmate in it")
	ok(P.downed or P.out or P.dead, "...and you, standing close")
	ok(lamp["used"], "...and wrecks a revive beacon")
	ally.team = team
	_steps(m, 3.5)

func _lantern(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	UtilityBelt.grant(P, "lookout_lantern", 1)
	UtilityBelt.use_id(P, "lookout_lantern")
	var ward := P.pos + Vector3(1.6, 0, 0)
	var zones := _kx_zones(m)
	foe.teleport(ward)
	_steps(m, 1.0)
	ok(UtilityBelt.count(foe, "lookout_lantern") == 0 and _kx_zones(m) == zones,
			"a lantern hung a moment ago cannot be taken yet")
	_steps(m, 2.0)
	ok(UtilityBelt.count(foe, "lookout_lantern") == 1, "...later a rival steps on it and takes it")
	ok(_kx_zones(m) == zones - 1, "...and it stops lighting the place")

func _satchel(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	UtilityBelt.grant(P, "toss_satchel", 1)
	UtilityBelt.use_id(P, "toss_satchel")
	var at := P.pos + Vector3(6.0, 0, 0)
	foe.teleport(at + Vector3(0, 2.5, 0))
	foe.grounded = false
	foe.vel = Vector3.ZERO
	var zones := _kx_zones(m)
	_steps(m, 0.3)
	ok(foe.pos.y > at.y + 2.0 or foe.vel.y > 4.0, "a body falling past a Toss Satchel is thrown up")
	ok(_kx_zones(m) == zones - 1 and foe.hp == foe.max_hp, "...the pack is used up, nothing healed")

func _thorn(m: Match, P: Hunter) -> void:
	_live(P)
	var walls := m.verbs.walls.size()
	UtilityBelt.grant(P, "thorn_wall", 1)
	UtilityBelt.use_id(P, "thorn_wall")
	ok(P.root_t > 1.5, "a Thorn Wall roots you (%.1f s)" % P.root_t)
	_steps(m, 1.0)
	ok(m.verbs.walls.size() == walls, "...the wall is not up yet")
	_steps(m, 1.3)
	ok(m.verbs.walls.size() == walls + 1 and P.root_t <= 0.0, "...it rises after 2 s and you are free")

func _lamp_sickness(m: Match, P: Hunter, ally: Hunter) -> void:
	_stage(m, P, ally)
	var team := ally.team
	ally.team = P.team
	ally.out = true
	UtilityBelt.grant(P, "hearth_lamp", 1)
	UtilityBelt.use_id(P, "hearth_lamp")
	_steps(m, 5.0)
	ok(not ally.out and ally.sick_t > 10.0 and ally.sick_t <= 12.0,
			"a Hearth Lamp revive carries 12 s of sickness (%.1f)" % ally.sick_t)
	ally.hp = 10.0
	ally.heal(40.0)
	ok(absf(ally.hp - 40.0) < 0.5, "...which cuts healing by a quarter (10 + 40 gives %.0f)" % ally.hp)
	ok(HudPlate.statuses(ally).any(func(x): return x[0] == "heart" and float(x[3]) > 0.0),
			"...shown on the plate and the squad row as a status with its seconds left")
	var row: Array = ["lv", 3, "sk", snappedf(ally.sick_t, 0.1)]
	ally.sick_t = 0.0
	HunterNet.apply(ally, row)
	ok(absf(ally.sick_t - float(row[3])) < 0.01 and ally.lvl == 3, "...and rides the hunter snapshot")
	_steps(m, 12.0)
	ok(ally.sick_t <= 0.0 and HudPlate.statuses(ally).is_empty(), "...gone after the 12 s")
	ally.team = team

func _tonic(m: Match, P: Hunter) -> void:
	_live(P)
	P.inv_t = 99.0        # a patch left by an earlier item must not spill the drink
	P.hp = 10.0
	P.blight_t = 8.0
	UtilityBelt.grant(P, "tonic", 1)
	UtilityBelt.use_id(P, "tonic")
	_steps(m, 1.3)
	ok(P.blight_t <= 0.0, "a tonic cleanses anti-heal")
	ok(P.hp >= 10.0 + 41.0, "...and its heal is whole, not cut (hp %.0f)" % P.hp)

func _bounty_cut(m: Match, P: Hunter, foe: Hunter) -> void:
	_stage(m, P, foe)
	var banner := UtilityBelt.def("bounty_banner")
	var time0: float = banner["time"]
	banner["time"] = 30.0
	var gems0 := P.gems
	UtilityBelt.grant(P, "bounty_banner", 1)
	UtilityBelt.use_id(P, "bounty_banner")
	_steps(m, 2.0)
	foe.hurt(foe.hp + foe.armor + 50.0, P, {"src": "shot"})
	_steps(m, 10.0)
	ok(_kx_zones(m) >= 1 and P.gems == gems0, "a 30 s banner with a knock behind it still runs at 12 s")
	_steps(m, 4.0)
	ok(P.gems - gems0 >= int(banner["reward"]), "...and has paid out by 16 s: the knock took 15 s off")
	banner["time"] = time0

func _raft(m: Match, P: Hunter, foe: Hunter) -> void:
	var spot := _edge(m)
	ok(not spot.is_empty(), "an island edge to build a raft off")
	if spot.is_empty():
		return
	_live(P)
	_live(foe)
	var e: Dictionary = (UtilityBelt.def("cloud_raft")["effects"] as Array)[0]
	var from: Vector3 = spot["from"]
	var dir: Vector2 = spot["dir"]
	ok(m.verbs.add_bridge(P, from, dir, e) > 0, "a Cloud Raft is laid over the gap")
	var deck := Vector3(from.x + dir.x * 2.5, from.y, from.z + dir.y * 2.5)
	P.teleport(deck)
	foe.teleport(deck)
	P.glide_fuel = 0.0
	foe.glide_fuel = 0.0
	_steps(m, 0.35)
	ok(P.glide_fuel > 0.8, "a squadmate's glider is cooled on it (%.2f)" % P.glide_fuel)
	ok(foe.glide_fuel < 0.5, "...a rival's is not (%.2f)" % foe.glide_fuel)

## 15. The table in docs/SOURCE_UTILITIES.md "Using an item and moving", one row per belt item (keys aside:
## they need a lock). [cast s, speed while it runs, starts mid-air, starts mid-dash, a hit spills it].
## Drinks and the kit channel; Thorn Wall and Pilfer Pouch root you; everything else lands at once.
const MOVES := {
	"tonic": [1.0, 1.0, true, false, true], "deep_draught": [5.0, 0.4, true, false, true],
	"lostway_scroll": [4.0, 1.0, true, false, true], "omen_draught": [1.0, 1.0, true, false, true],
	"armor_kit": [1.6, 0.45, true, false, true],
	"thorn_wall": [2.0, 0.0, true, true, false], "pilfer_pouch": [1.5, 0.0, true, true, false],
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
	foe.team = P.team           # a fallen squadmate for the ember and the lamp
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
		var held := P.drink_t + P.kit_t + P.root_t
		ok(absf(held - cast) < 0.05, "...%s cast %.1f s (expected %.1f)" % [id, held, cast])
		var spd := UtilityUse.channel_move(P)
		ok(is_equal_approx(spd, float(row[1])) if P.root_t <= 0.0 else P.root_t > 0.0,
				"...%s speed %.2f while it runs (expected %.2f; a root stands still)" % [id, spd, row[1]])
		if cast > 0.0 and P.root_t > 0.0:
			P.do_dash()
			ok(P.roll_t <= 0.0 and P.root_t > 0.0, "...%s: a dash can't cut the root" % id)
		var spent_later := held > 0.0 and P.root_t <= 0.0    # a drink or a repair spends its charge at the end
		ok(UtilityBelt.count(P, id) == (1 if spent_later else 0), "...%s spends its charge when it lands" % id)
		# a hit
		P.inv_t = 0.0
		P.hurt(5.0, null, {"src": "shot"})
		P.inv_t = 99.0
		if bool(row[4]):
			ok(P.drink_t <= 0.0 and P.kit_t <= 0.0 and UtilityBelt.count(P, id) == 1,
					"...%s: a hit spills it, nothing spent (%d left)" % [id, UtilityBelt.count(P, id)])
		else:
			ok(UtilityBelt.count(P, id) == 0 and (cast <= 0.0 or P.root_t > cast - 0.1),
					"...%s: a hit does not stop it" % id)
		# in the air (not gliding)
		_ready_for(m, P, foe, id, ground)
		P.teleport(ground + Vector3(0, 4.0, 0))
		P.grounded = false
		var started := UtilityBelt.use_id(P, id)
		var going := P.drink_t + P.kit_t + P.root_t > 0.0 or UtilityBelt.count(P, id) == 0
		ok(started == bool(row[2]) and going == bool(row[2]),
				"...%s mid-air: %s" % [id, "starts" if row[2] else "waits"])
		# mid-dash
		_ready_for(m, P, foe, id, ground)
		P.roll_t = 0.15
		P.roll_dir = Vector2.RIGHT
		P.move_kind = "dash"
		started = UtilityBelt.use_id(P, id)
		going = P.drink_t + P.kit_t + P.root_t > 0.0 or UtilityBelt.count(P, id) == 0
		ok(started == bool(row[3]) and going == bool(row[3]),
				"...%s mid-dash: %s" % [id, "starts" if row[3] else "denied, nothing spent"])
		P.roll_t = 0.0
	foe.team = team
	P.inv_t = 0.0
	_ready_for(m, P, foe, "", ground)

## One fresh charge of `id` on an otherwise empty belt, the caster hurt and bare so a drink or a repair has
## work to do, the squadmate down for the ember, and nothing of the last item left: no channel, no root,
## no pending fuse or raid, no open gate or banner.
func _ready_for(m: Match, P: Hunter, ally: Hunter, id: String, ground: Vector3) -> void:
	for z in m.fields.list:
		z["t"] = 0.0
	m._later.clear()
	m.step(Match.DT)
	m.remove_meta("gate_%d" % P.get_instance_id())
	m.remove_meta("banner_%d" % P.team)
	_live(P)
	P.teleport(ground)
	P.grounded = true
	P.vel = Vector3.ZERO
	P.roll_t = 0.0
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

## 16. Cloud Raft: denied on solid ground; over the abyss you hang in the air for its 0.3 s cast and the
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
	var spans := m.verbs.terrain.size()
	ok(UtilityBelt.use_id(P, "cloud_raft"), "...over the abyss it casts")
	ok(absf(P.float_t - 0.3) < 0.02, "...and holds you in the air for 0.3 s (%.2f)" % P.float_t)
	_steps(m, 0.2)
	ok(absf(P.pos.y - air.y) < 0.02 and absf(P.vel.y) < 0.01 and m.verbs.terrain.size() == spans,
			"...no fall and no raft yet at 0.2 s (dy %.3f)" % (P.pos.y - air.y))
	_steps(m, 0.2)
	ok(m.verbs.terrain.size() == spans + 1 and P.float_t <= 0.0, "...the raft forms at 0.3 s and the hold ends")
	_steps(m, 1.5)
	var deck := floorf(air.y / World.LEVEL) * World.LEVEL
	ok(P.grounded and absf(P.pos.y - deck) < 0.05,
			"...you land on it, at your own height (y %.2f, raft %.2f)" % [P.pos.y, deck])

## A ground point and a heading that points off the island's edge into open air.
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
