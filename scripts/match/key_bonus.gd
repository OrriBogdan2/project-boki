class_name KeyBonus
extends RefCounted
## Bonus chest keys (docs/decisions/0009-keys-and-cover.md). The carrier quota (carriers = chests in
## each region, KeyRun) is the baseline; on top of it, at low odds (content/rules/chest_keys.json):
## a lair boss or the Warden, an elite, any other monster, a breakable or a sky-train crate.
## Rolled on the keys' own seeded stream (KeyRun.bonus_rng), so the match's other loot never shifts.
## A bonus key drops on the ground like a carrier's (KeyCarry.drop_keys) and bots go for it (BotKeys).
## Keys are never sold in shops.

const RULES_PATH := "res://content/rules/chest_keys.json"

static var _rules: Dictionary = {}

## The bonus odds per source kind, read once from content/rules/chest_keys.json.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if parsed is Dictionary else {}
	return _rules

## What kind of source a monster is: "boss", "elite", "monster", or "" for none. The Shrubling always
## carries a key anyway, and the Blight swarm would flood the map with keys.
static func mob_source(mb: Mob) -> String:
	if mb is Shrubling or mb is Blight:
		return ""
	if mb is Boss or mb.mkind == "warden" or mb.md.get("boss", false):
		return "boss"
	var is_elite: bool = mb.md.get("stag", false) or mb.rarity >= 3
	if is_elite and mb.mkind != "glimmer":
		return "elite"
	return "monster"

## Expected keys from one source of kind `source` (the check sums these to measure the surplus).
static func expected(source: String) -> float:
	var odds = rules().get(source)
	if odds is Dictionary:
		return float(odds["odds"]) * (1.0 + float(odds["two"]))
	if odds == null:
		return 0.0
	return float(odds)

## How many keys a source of kind `source` gives on this roll (0, 1 or 2). Only the host rolls.
static func roll(m: Match, source: String) -> int:
	if m.keys == null or source == "" or (m.net_on and not m.is_host):
		return 0
	var dice: RandomNumberGenerator = m.keys.bonus_rng
	var odds = rules().get(source)
	if odds == null:
		return 0
	if odds is Dictionary:
		if dice.randf() >= float(odds["odds"]):
			return 0
		return 2 if dice.randf() < float(odds["two"]) else 1
	return 1 if dice.randf() < float(odds) else 0

## A monster died: maybe a bonus key, on top of its carrier key if it had one.
static func on_mob_dead(m: Match, mb: Mob) -> void:
	var n := roll(m, mob_source(mb))
	if n <= 0:
		return
	m.keys.bonus_given += n
	KeyCarry.drop_keys(m, KeyCarry.drop_spot(m, mb), n)

## A breakable broke (kind "pot", "crate", "barrel" or "keg"), or a sky-train crate was opened ("train_crate").
static func on_break(m: Match, at: Vector3, source: String) -> void:
	var n := roll(m, source)
	if n <= 0:
		return
	m.keys.bonus_given += n
	KeyCarry.drop_keys(m, at + Vector3(0, 0.5, 0), n)

## The expected bonus keys over everything in the world now (monsters, pots, crates, sky-train
## crates), as a share of the locked chests: the surplus --keys-check holds to 20-30%.
static func surplus(m: Match) -> Dictionary:
	var total := 0.0
	var by_source := {}
	var sources: Array = []
	for mb in m.mobs:
		if not mb.dead:
			sources.append(mob_source(mb))
	for b in m.breaks:
		if not b["dead"] and String(b["kind"]) in ["pot", "crate", "barrel", "keg"]:
			sources.append(String(b["kind"]))
	var locked := 0
	for c in m.chests:
		if c.has("ride"):
			sources.append("train_crate")
		elif not c.get("free", false):
			locked += 1
	for source in sources:
		total += expected(source)
		by_source[source] = int(by_source.get(source, 0)) + 1
	return {"expected": total, "chests": locked, "share": total / maxf(1.0, float(locked)), "by": by_source}
