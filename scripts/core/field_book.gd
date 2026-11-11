class_name FieldBook
extends RefCounted
## The Field Book (docs/decisions/0002): a record of every kind of Boki you have laid eyes on, kept in the save
## under "dex" next to what Care already tracks there ({species: {seen, caught, forms, shimmer, mutations,
## places}}). A wild Boki that comes into view (inside the sight range and in line of sight) is logged by
## species with where you saw it, automatically, the first time and each new place. The page that shows it
## is DexView (the Boki tab of the inventory). Numbers: content/rules/capture.json.
## The two finals of a branching line are alternate forms of ONE entry (content/rules/branch_forms.json):
## the save keeps one record per species as always, and the entry is derived from its forms' records.

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

## The forms (species ids in the game) that share this species' entry: itself unless it is in a branch pair.
static func forms_of(species: String) -> Array:
	for pair in Content.rules("branch_forms")["pairs"]:
		if pair.has(species):
			var here: Array = pair.filter(func(f): return Data.KIN.has(f))
			return here if not here.is_empty() else [species]
	return [species]

## The id an entry goes by (and is numbered by): its first form.
static func entry_key(species: String) -> String:
	return forms_of(species)[0]

## Every Field Book entry, in species order: a branch pair is one.
static func entries() -> Array:
	return Data.KIN.keys().filter(func(s): return entry_key(s) == s)

## One species on its own (caught ones count as seen).
static func form_seen(species: String) -> bool:
	return bool(Care.dex_entry(species).get("seen", false)) or form_caught(species)

static func form_caught(species: String) -> bool:
	return bool(Care.dex_entry(species).get("caught", false))

static func entry_seen(species: String) -> bool:
	return forms_of(species).any(form_seen)

static func entry_caught(species: String) -> bool:
	return forms_of(species).any(form_caught)

## Both forms of a branch pair are yours (the small "both forms" star).
static func both_forms(species: String) -> bool:
	var forms := forms_of(species)
	return forms.size() > 1 and forms.all(form_caught)

## The form an entry's tile shows: one you own, else one you have seen, else the first.
static func face(species: String) -> String:
	var forms := forms_of(species)
	for f in forms:
		if form_caught(f):
			return f
	for f in forms:
		if form_seen(f):
			return f
	return forms[0]

## Entries you have seen (caught ones count).
static func seen_count() -> int:
	return entries().filter(entry_seen).size()

## Entries you have caught (either form).
static func caught_count() -> int:
	return entries().filter(entry_caught).size()

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
