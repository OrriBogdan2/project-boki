class_name FieldBook
extends RefCounted
## The Field Book (docs/decisions/0002): a record of every kind of Boki you have laid eyes on, kept in the save
## under "dex" next to what Care already tracks there ({species: {seen, caught, forms, shimmer, mutations,
## places}}). A wild Boki that comes into view (inside the sight range and in line of sight) is logged by
## species with where you saw it, automatically, the first time and each new place. The page that shows it
## is DexView (the Boki tab of the inventory). Numbers: content/rules/capture.json.

static func rules() -> Dictionary:
	return Content.rules("capture")

## Logs a sighting. Returns true if it was new (a species never seen before).
static func log_sight(species: String, place: String) -> bool:
	if not Data.KIN.has(species):
		return false
	var was := bool(Care.dex_entry(species).get("seen", false))
	Care.dex_mark(species, "seen")
	Care.dex_mark(species, "place", place)
	return not was

## Species you have seen (caught ones count).
static func seen_count() -> int:
	var n := 0
	for spk in Data.KIN:
		if bool(Care.dex_entry(spk).get("seen", false)):
			n += 1
	return n

## The places a species was seen, newest last.
static func places(species: String) -> Array:
	return Care.dex_entry(species).get("places", [])

## Each step (about once a second): log what the local player can see. `m` is the Match.
static func scan_sights(m, new_species: Callable = Callable()) -> void:
	var p = m.player
	var rng := float(rules()["sight_range"])
	for k in m.kins:
		if not k.is_wild() or k.dead or p.flat_dist(k) > rng or not m.sees(p.team, k.pos):
			continue
		var w: Dictionary = m.where_at(k.pos)
		if log_sight(k.species, String(w.get("island", w.get("biome", w.get("map", ""))))) and new_species.is_valid():
			new_species.call(k)

## v3 -> v4 (Save): every species you own counts as seen, and the new fields exist.
static func migrate(data: Dictionary) -> void:
	var dx: Dictionary = data.get("dex", {})
	data["dex"] = dx
	for spk in dx.keys():
		var e: Dictionary = dx[spk]
		if not e.has("places"): e["places"] = []
	var recs: Array = []
	for rec in data.get("roster", []):
		recs.append(rec)
	for key in ["lost_kin", "graves"]:           # a Boki you lost or buried was yours too
		for e in data.get(key, []):
			if typeof(e) == TYPE_DICTIONARY and typeof(e.get("rec", null)) == TYPE_DICTIONARY:
				recs.append(e["rec"])
	for rec in recs:
		if typeof(rec) != TYPE_DICTIONARY or not rec.has("species"):
			continue
		var spk := String(rec["species"])
		if not dx.has(spk):
			dx[spk] = {"seen": true, "caught": true, "forms": [], "shimmer": false, "mutations": [], "places": []}
		else:
			dx[spk]["seen"] = true
