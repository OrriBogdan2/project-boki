class_name SoulEcho
extends RefCounted
## Soul echoes (DECISIONS 2026-11-09 soul-linked wisps, decision 0097): a stolen Boki wisp you extract carrying
## leaves an echo of it with you (KinSteal.extracted puts it in the match result). Home, settle writes it:
## the species' Field Book entry counts it (seen, Care "echo"), and its shimmer and rare mutations wait for your
## next hatch. A nest egg leans toward the parent whose species you hold echoes of (egg_species), and the next
## hatch has a small chance at one stolen trait (hatched). Tuning: content/rules/soul_echo.json.
##
## On the save:
##   Save.d["dex"][species]["echo"]   echoes of that species
##   Save.d["soul_echo"]              {traits: [{sp, shimmer: true} or {sp, mutation: id}]}, newest last

static func rules() -> Dictionary:
	return Content.rules("soul_echo")

## An echo for the match result: the stolen Boki's species and what made it special.
static func of_rec(rec: Dictionary) -> Dictionary:
	return {"sp": String(rec.get("species", "")), "shimmer": bool(rec.get("shimmer", false)),
		"mutations": Mutations.of(rec)}

## Back home from a match: every echo in it goes into the Field Book and its traits wait for the next hatch.
static func settle(r: Dictionary) -> void:
	for echo in r.get("soul_echoes", []):
		var sp := String(echo.get("sp", ""))
		if not Data.KIN.has(sp):
			continue
		Care.dex_mark(sp, "echo")
		if echo.get("shimmer", false):
			_keep({"sp": sp, "shimmer": true})
		for id in echo.get("mutations", []):
			_keep({"sp": sp, "mutation": String(id)})

static func _keep(t: Dictionary) -> void:
	var pool := traits()
	pool.append(t)
	while pool.size() > int(rules()["traits_kept"]):
		pool.pop_front()

## The stolen traits waiting for the next hatch.
static func traits() -> Array:
	if not Save.d.has("soul_echo"):
		Save.d["soul_echo"] = {"traits": []}
	return Save.d["soul_echo"]["traits"]

static func count(species: String) -> int:
	return int(Care.dex_entry(species).get("echo", 0))

## A species' weight when an egg picks a parent to take after: 1, plus hatch_per_echo for each echo up to the cap.
static func weight(species: String) -> float:
	var r := rules()
	return 1.0 + float(r["hatch_per_echo"]) * mini(count(species), int(r["hatch_echo_cap"]))

## Which parent's species a nest egg takes after. roll: a uniform 0..1 draw.
static func egg_species(a: Dictionary, b: Dictionary, roll: float) -> String:
	var wa := weight(String(a["species"]))
	var wb := weight(String(b["species"]))
	return a["species"] if roll * (wa + wb) < wa else b["species"]

## A kin just out of an egg: with trait_chance it gets one stolen trait. Either way the traits are spent.
## The trait that came through ({} if none). rng: a check's seeded one, else a fresh random one.
static func hatched(baby: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var pool := traits()
	if pool.is_empty():
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var got: Dictionary = {}
	if rng.randf() < float(rules()["trait_chance"]):
		got = pool[rng.randi_range(0, pool.size() - 1)]
		if got.get("shimmer", false):
			baby["shimmer"] = true
		elif not _group_taken(baby, String(got["mutation"])):
			baby["mutations"] = Mutations.of(baby) + [String(got["mutation"])]
	pool.clear()
	return got

## Does the kin already have this mutation, or another from its group (one size, one palette)?
static func _group_taken(rec: Dictionary, id: String) -> bool:
	var g := String(Mutations.info(id).get("group", ""))
	for have in Mutations.of(rec):
		if have == id or (g != "" and String(Mutations.info(have).get("group", "")) == g):
			return true
	return false

## Save v13 -> v14: the stolen-trait list, and every Field Book entry counts its echoes (0 before).
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("soul_echo", null)) != TYPE_DICTIONARY:
		data["soul_echo"] = {"traits": []}
	for sp in data.get("dex", {}):
		var e = data["dex"][sp]
		if e is Dictionary and not e.has("echo"):
			e["echo"] = 0
