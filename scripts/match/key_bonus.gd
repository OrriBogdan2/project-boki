class_name KeyBonus
extends RefCounted
## Bonus chest keys (docs/decisions/0007-keys-and-cover.md). The carrier quota (carriers = chests in
## each region, KeyRun) is the baseline; on top of it, at low odds (content/rules/chest_keys.json):
## a lair boss or the Warden (40%, sometimes 2), an elite (25%, sometimes 2), any other monster (3%),
## a pot (2%), a crate or a sky-train crate (4%). Rolled on the keys' own seeded stream (KeyRun.bonus_rng),
## so the match's other loot never shifts. A bonus key drops on the ground like a carrier's, with the
## key badge, and bots go for it (BotKeys). Keys are never sold in shops.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/chest_keys.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## What kind of source a monster is: "boss", "elite", "monster", or "" (no bonus: the Shrubling always
## carries one anyway, and the Blight swarm would flood the map with keys).
static func mob_source(mb: Mob) -> String:
	if mb is Shrubling or mb is Blight:
		return ""
	if mb is Boss or mb.mkind == "warden" or mb.md.get("boss", false):
		return "boss"
	if (mb.md.get("stag", false) or mb.rarity >= 3) and mb.mkind != "glimmer":
		return "elite"
	return "monster"

## Expected keys from one source of kind `k` (the check sums these to measure the surplus).
static func expected(k: String) -> float:
	var r = rules().get(k)
	if r is Dictionary:
		return float(r["odds"]) * (1.0 + float(r["two"]))
	return float(r) if r != null else 0.0

## How many keys a source of kind `k` gives on this roll (0, 1 or 2).
static func roll(m: Match, k: String) -> int:
	if m.keys == null or k == "" or (m.net_on and not m.is_host):
		return 0
	var g: RandomNumberGenerator = m.keys.bonus_rng
	var r = rules().get(k)
	if r is Dictionary:
		if g.randf() >= float(r["odds"]): return 0
		return 2 if g.randf() < float(r["two"]) else 1
	return 1 if r != null and g.randf() < float(r) else 0

## A monster died (after its carrier key, if it had one).
static func on_mob_dead(m: Match, mb: Mob) -> void:
	var n := roll(m, mob_source(mb))
	if n <= 0:
		return
	m.keys.bonus_given += n
	var at := mb.pos + Vector3(0, 0.6, 0)
	if m.world.is_void(mb.pos.x, mb.pos.z):
		var q := m.world.free_spot_near(mb.camp, [], 0.6, 0.4, 30.0)
		at = Vector3(q.x, m.world.ground_at(q.x, q.z) + 0.6, q.z)
	_drop(m, at, n)

## A pot or crate broke (kind "pot" / "crate"), or a sky-train crate was opened ("train_crate").
static func on_break(m: Match, at: Vector3, kind_s: String) -> void:
	var n := roll(m, kind_s)
	if m.keys: m.keys.bonus_given += n
	_drop(m, at + Vector3(0, 0.5, 0), n)

static func _drop(m: Match, at: Vector3, n: int) -> void:
	for i in n:
		m.drop("ckey", at, 1, "", "", Vector3(randf_range(-1.2, 1.2), randf_range(4.5, 6.0), randf_range(-1.2, 1.2)))
	if n > 0:
		m.fx.burst(at, KeyModels.BRASS, 12, 3.5, 0.5)
		m.fx.word(at + Vector3(0, 0.6, 0), "KEY" if n == 1 else "2 KEYS", KeyModels.BRASS, false)

## The expected bonus keys over everything in the world now (monsters, pots, crates, sky-train
## crates), as a share of the locked chests: the surplus the check holds to 20-30%.
static func surplus(m: Match) -> Dictionary:
	var e := 0.0
	var by := {}
	for mb in m.mobs:
		if mb.dead: continue
		var k := mob_source(mb)
		e += expected(k); by[k] = int(by.get(k, 0)) + 1
	for b in m.breaks:
		var bk := String(b["kind"])
		if b["dead"] or not bk in ["pot", "crate"]: continue
		e += expected(bk); by[bk] = int(by.get(bk, 0)) + 1
	var chests := 0
	for c in m.chests:
		if c.has("ride"): e += expected("train_crate"); by["train_crate"] = int(by.get("train_crate", 0)) + 1
		elif not c.get("free", false): chests += 1
	return {"expected": e, "chests": chests, "share": e / maxf(1.0, float(chests)), "by": by}
