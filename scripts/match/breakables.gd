class_name Breakables
extends RefCounted
## Pots, crates, barrels and powder kegs (content/rules/breakables.json). Any single hit breaks one:
## a shot, a melee swing, an ability, a Boki strike, a blast or a dash through it. A powder keg is lit
## by its hit instead: a short fuse with a hiss, a flashing body, a swelling glow and a ground ring
## showing its blast, then it blows and lights any keg in reach. The look is in BreakFx.

const RULES_PATH := "res://content/rules/breakables.json"
const HITSTOP := 0.04            # seconds the game freezes when the player breaks something
const BLINK_HZ := 12.0           # how fast a lit keg flashes
const SQUASH_T := 0.07           # seconds a broken prop takes to pop flat
const SAFE_MARGIN := 1.2         # metres outside a lit keg's blast a bot still keeps clear
const CHAIN_SLACK := 0.4         # metres past the blast radius that still light a neighbour
const BLAST_SPEED := 1.6         # debris power per metre of blast radius
const SCORCH_SCALE := 0.9        # scorch radius as a share of the blast radius

static var _rules: Dictionary = {}

var lit: Array = []              # breaks with a fuse running
var _m: Match
var _fx: BreakFx

func _init(match_node: Match) -> void:
	_m = match_node
	_fx = BreakFx.new(rules()["debris"])
	_m.add_child(_fx)

## The rules, read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if parsed is Dictionary else {}
	return _rules

## One kind's rules.
static func spec(kind_s: String) -> Dictionary:
	return rules()["kinds"][kind_s]

## The kind a random scatter roll (0..1) lands on, by the kinds' weights.
static func kind_for(roll: float) -> String:
	var kinds: Dictionary = rules()["kinds"]
	var acc := 0.0
	var last := ""
	for k in kinds:
		acc += float(kinds[k]["weight"])
		last = k
		if roll < acc:
			return k
	return last

## A hit of any kind: breaks it, or lights it if it is a powder keg.
func hit(b: Dictionary, by: Ent, chain := false) -> void:
	if b["dead"] or b.has("fuse_t"):
		return
	var sp := spec(String(b["kind"]))
	if not sp.has("explosive"):
		smash(b, by)
		return
	var ex: Dictionary = sp["explosive"]
	var col := Color(String(ex["color"]))
	b["fuse_t"] = 0.0
	b["fuse"] = float(ex["chain_fuse"] if chain else ex["fuse"])
	b["by"] = by
	b["glow"] = _fx.arm(b["pos"], float(ex["radius"]), col)
	lit.append(b)
	_pop(b["node"])
	_m.fx.flash(b["pos"] + Vector3(0, 0.5, 0), Color("fff0c0"), 0.5, 0.08)
	_m.sfx("fuse_hiss", b["pos"], -2.0, 1.0)
	_m.sfx("break_metal", b["pos"], -10.0, 1.6)

## Runs the fuses of lit kegs.
func tick(dt: float) -> void:
	for b in lit.duplicate():
		b["fuse_t"] = float(b["fuse_t"]) + dt
		var p := clampf(float(b["fuse_t"]) / float(b["fuse"]), 0.0, 1.0)
		var ex: Dictionary = spec(String(b["kind"]))["explosive"]
		_fx.fuse_step(b["glow"], p, Color(String(ex["color"])))
		var blink_on := int(float(b["fuse_t"]) * BLINK_HZ * 2.0) % 2 == 0
		_fx.flash_prop(b["node"], blink_on)
		if p >= 1.0:
			var by = b["by"]
			smash(b, by if is_instance_valid(by) else null)

## Breaks it for good: debris, a pop, the sound, the loot (and the blast, for a keg). from_net: another
## game broke it; this game only shows it.
func smash(b: Dictionary, by: Ent, from_net := false) -> void:
	if b["dead"]:
		return
	b["dead"] = true
	if _m.net_on and not from_net:
		_m.net_event(["brk", b["i"], by.nid if by else ""])
	if by == _m.player:
		_m.train["_smash"] = true
	_hitstop(by, HITSTOP)
	if lit.has(b):
		lit.erase(b)
		_fx.release(b["glow"])
	var at: Vector3 = b["pos"]
	var kind_s: String = b["kind"]
	var sp := spec(kind_s)
	_pop(b["node"], true)
	_show_break(at, String(sp["material"]), int(sp["chunks"]))
	if not from_net:
		KeyBonus.on_break(_m, at, kind_s)
	_drop_loot(at, sp["loot"], by, from_net)
	if sp.has("explosive"):
		_explode(at, sp["explosive"], by, from_net)

## Lights every unbroken prop a blast at `c` reaches.
func _chain(c: Vector3, radius: float, by: Ent) -> void:
	for b in _m.breaks:
		var reach := Vector2(b["pos"].x - c.x, b["pos"].z - c.z).length() < radius + CHAIN_SLACK
		if not b["dead"] and reach and absf(b["pos"].y - c.y) < 2.0:
			hit(b, by, true)

func _explode(at: Vector3, ex: Dictionary, by: Ent, from_net: bool) -> void:
	var radius := float(ex["radius"])
	var c := at + Vector3(0, 0.4, 0)
	var col := Color(String(ex["color"]))
	_m.fx.ring(c, radius, col, 0.35)
	_m.fx.ring(c, radius * 0.6, Color("fff0c0"), 0.2)
	_m.fx.burst(c, Color("ffb070"), int(radius * 13.0), 7.0, 0.6, 6.0, 1.5)
	_m.fx.flash(c, Color("ffd9a0"), radius * 0.6, 0.12)
	_fx.shatter(c, "metal", int(spec("keg")["chunks"]), radius * BLAST_SPEED / 2.6)
	_fx.scorch(at, radius * SCORCH_SCALE)
	_m.sfx("boom", c, 2.0, 0.85)
	_hitstop(by, HITSTOP * 1.5)
	if from_net:
		return
	_hurt_around(c, ex, by)
	_chain(c, radius, by)

func _hurt_around(c: Vector3, ex: Dictionary, by: Ent) -> void:
	var radius := float(ex["radius"])
	var bodies: Array = []
	for h in _m.hunters:
		if h.hittable():
			bodies.append(h)
	for mb in _m.mobs:
		if not mb.dead:
			bodies.append(mb)
	for k in _m.kins:
		if k.hittable():
			bodies.append(k)
	for e in bodies:
		var d := Vector2(e.pos.x - c.x, e.pos.z - c.z).length()
		if e.remote or d >= radius + e.r or absf(e.pos.y + 0.5 - c.y) >= float(ex["height"]):
			continue
		var f := 1.0 - float(ex["edge_falloff"]) * minf(1.0, d / radius)
		var dir := Vector2(e.pos.x - c.x, e.pos.z - c.z).normalized()
		var credit: Ent = by if by and by.team != e.team else null
		var info := {"src": "boom", "kb": dir * float(ex["knockback"]) * f, "lift": float(ex["lift"]) * f}
		e.hurt(float(ex["damage"]) * f, credit, info)

func _show_break(at: Vector3, mat_name: String, chunks: int) -> void:
	var drules: Dictionary = rules()["debris"][mat_name]
	var mid := at + Vector3(0, 0.35, 0)
	_fx.shatter(mid, mat_name, chunks)
	_m.fx.dust(at, 8)
	_m.fx.flash(mid, Color("fff0d0"), 0.45, 0.07)
	_m.sfx(String(drules["sound"]), at, -2.0, float(drules["pitch"]))

func _drop_loot(at: Vector3, loot: Dictionary, by: Ent, from_net: bool) -> void:
	if loot.is_empty():
		return
	var up := at + Vector3(0, 0.5, 0)
	var scale_by := float(_m.T["loot"])
	var gems: Array = loot["gems"]
	var each := maxi(1, int(round(float(loot["gem_base"]) * scale_by)))
	DropMerge.gems(_m, up, randi_range(int(gems[0]), int(gems[1])), each)
	if loot.has("seed") and randf() < float(loot["seed"]):
		_m.drop("seed", up, 1, Data.pick_seed())
	if loot.has("tonic") and randf() < float(loot["tonic"]):
		_m.drop("tonic", up, 1)
	if loot.has("armor") and randf() < float(loot["armor"]):
		_m.drop("armor", up, int(loot["armor_amount"]))
	_m.fx.spark(up, Vector3.UP, Color("ffe08a"), 10, 6.0, 40.0, 0.35, 12.0, 1.0)
	if loot.has("table") and not from_net:
		GearDrops.run_table(_m, String(loot["table"]), at, _m.rng, {"h": by if by is Hunter else null})

## The brief freeze for a person who broke something (a bot playing the player's seat gets none).
func _hitstop(by: Ent, secs: float) -> void:
	if by == _m.player and by is Hunter and (by as Hunter).ctrl == "local":
		_m.freeze_frame(secs)

## A quick squash; broken, it pops flat and goes.
func _pop(node: Node3D, gone := false) -> void:
	var tw := node.create_tween()
	if gone:
		tw.tween_property(node, "scale", Vector3(1.25, 0.5, 1.25), SQUASH_T)
		tw.tween_callback(node.queue_free)
		return
	node.scale = Vector3(1.12, 0.9, 1.12)
	tw.tween_property(node, "scale", Vector3.ONE, 0.12)

## Steers a bot clear of any lit keg's blast: away from it when inside, a nudge when close.
static func bot_steer(m: Match, h: Hunter, move: Vector2) -> Vector2:
	if m.brk == null:
		return move
	for b in m.brk.lit:
		var radius := float(spec(String(b["kind"]))["explosive"]["radius"])
		var away := Vector2(h.pos.x - b["pos"].x, h.pos.z - b["pos"].z)
		var d := away.length()
		if d >= radius + SAFE_MARGIN:
			continue
		away = away.normalized() if d > 0.01 else Vector2(1, 0)
		return away if d < radius else (move + away).normalized()
	return move
