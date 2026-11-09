class_name Evo
## Boki evolution (docs/decisions/0024-evolution-rules.md). Data: content/rules/evolve.json.
##
## Each species evolves into the next one at its own level, with a Lunar/Ember/... Ink used on it,
## or by being traded, as its entry in evolve.json says. Where a line branches by temperament, the
## Boki's leading affinity (what it eats, does in matches and its personality) picks the branch.
## A Boki never evolves into a species that has no data or no model yet: it waits at the level,
## and evolves once the art exists (catch_up on load). Levels stop at the cap (100).
## Every 4 levels from level 2 it also gains a mutation: a cosmetic body part, or a bigger one.

const AFF := {
	"fierce": {"name": "Fierce", "tint": Color("e0503a"), "stat": "dmg", "amt": 0.05,
		"why": "fights hard", "food": "emberberry", "parts": ["horns", "spikes", "fangs", "brow"]},
	"steadfast": {"name": "Steadfast", "tint": Color("c9b27a"), "stat": "hp", "amt": 0.08,
		"why": "looks after you", "food": "sunroot", "parts": ["plates", "shell", "brow", "club"]},
	"curious": {"name": "Curious", "tint": Color("9a7af0"), "stat": "cd", "amt": 0.06,
		"why": "explores and uses its skill", "food": "mindmint", "parts": ["antennae", "spots", "third_eye", "crest"]},
	"swift": {"name": "Swift", "tint": Color("5ad0e0"), "stat": "speed", "amt": 0.05,
		"why": "gets thrown around and moves fast", "food": "tidebloom", "parts": ["wings", "tail_long", "fins", "crest"]},
}

const PART_NAMES := {"horns": "horns", "spikes": "back spikes", "fangs": "fangs", "brow": "an armored brow",
	"plates": "armor plates", "shell": "a shell ring", "club": "a club tail", "antennae": "antennae",
	"spots": "glowing spots", "third_eye": "a third eye", "crest": "a crest", "wings": "little wings",
	"tail_long": "a long tail", "fins": "side fins"}

## Makes sure an older record has the fields evolution needs.
static func ensure(rec: Dictionary) -> void:
	if not rec.has("aff"):
		rec["aff"] = {"fierce": 0.0, "steadfast": 0.0, "curious": 0.0, "swift": 0.0}
	if not rec.has("forms"):
		rec["forms"] = []          # one affinity per form taken
	if not rec.has("muts"):
		rec["muts"] = []           # [{id, lv, aff}]
	if not rec.has("was"):
		rec["was"] = []            # the species it evolved from, oldest first

static func add(rec: Dictionary, aff: String, n: float) -> void:
	ensure(rec)
	rec["aff"][aff] = float(rec["aff"].get(aff, 0.0)) + n

## The affinity that wins right now: what it's been doing plus its personality.
static func leading(rec: Dictionary) -> String:
	ensure(rec)
	var tr: Dictionary = rec.get("traits", {})
	var sp: Dictionary = Data.KIN.get(rec.get("species", "cindle"), {})
	var score := {
		"fierce": float(rec["aff"]["fierce"]) + (float(tr.get("bravery", 0.5)) + float(tr.get("temper", 0.5))) * 5.0,
		"steadfast": float(rec["aff"]["steadfast"]) + float(tr.get("loyalty", 0.5)) * 10.0,
		"curious": float(rec["aff"]["curious"]) + float(tr.get("curiosity", 0.5)) * 10.0,
		"swift": float(rec["aff"]["swift"]) + float(sp.get("speed", 6.5)) / 8.0 * 6.0,
	}
	var best := "fierce"; var bv := -1e9
	for k in ["fierce", "steadfast", "curious", "swift"]:
		if score[k] > bv: bv = score[k]; best = k
	return best

## The name it goes by: its species, or the form name an older save gave it (kept until it evolves).
static func form_name(rec: Dictionary) -> String:
	ensure(rec)
	var old := String(rec.get("form_name", ""))
	return old if old != "" else String(Data.KIN[rec.get("species", "cindle")]["name"])

static func rules() -> Dictionary:
	return Content.rules("evolve")

## The highest level a Boki can reach.
static func cap() -> int:
	return int(rules()["cap"])

## One level more, never past the cap.
static func level_up(rec: Dictionary) -> void:
	rec["level"] = mini(int(rec.get("level", 1)) + 1, cap())

## Can a Boki take this species' shape? It needs data, a model and the rig's framing for it.
static func has_art(id: String) -> bool:
	return Data.KIN.has(id) and BokiRig.FRAME.has(id) and ResourceLoader.exists(BokiRig.PATH % [id, id])

## The species this Boki would evolve into by `how` ("level", "item" with an Ink id, or "trade"),
## art or not; "" when that isn't a way it evolves.
static func next_for(rec: Dictionary, how: String, item := "") -> String:
	var line: Dictionary = rules()["lines"].get(String(rec.get("species", "")), {})
	var fits: Array = []
	for o in line.get("into", []):
		match how:
			"level":
				var by_level: bool = not o.has("item") and not o.get("trade", false)
				if by_level and line.has("level") and int(rec.get("level", 1)) >= int(line["level"]):
					fits.append(o)
			"item":
				if String(o.get("item", "")) == item: fits.append(o)
			"trade":
				if o.get("trade", false): fits.append(o)
	if fits.is_empty():
		return ""
	var lead := leading(rec)
	for o in fits:
		if String(o.get("path", "")) == lead: return String(o["id"])
	return String(fits[0]["id"])

## Evolves it if `how` allows and the art exists. Returns the event, or {} if it didn't (or waits).
static func try_evolve(rec: Dictionary, how: String, item := "") -> Dictionary:
	ensure(rec)
	var to := next_for(rec, how, item)
	if to == "" or not has_art(to):
		return {}
	var before := form_name(rec)
	var a := leading(rec)
	rec["was"].append(String(rec["species"]))
	rec["species"] = to
	rec["forms"].append(a)       # the next node on its affinity's path (KinLib.nodes_for)
	rec.erase("form_name")
	return {"kind": "form", "aff": a, "from": before, "to": form_name(rec), "how": how, "item": item}

## Uses one Ink from the market goods on it. Returns the event, or {} (and keeps the Ink) if it can't.
static func use_ink(rec: Dictionary, ink: String) -> Dictionary:
	if Goods.have("good:" + ink) <= 0:
		return {}
	var ev := try_evolve(rec, "item", ink)
	if not ev.is_empty():
		Goods.take("good:" + ink)
	return ev

## Called each time a kin gains a level. Returns what changed, or {} if nothing did.
static func on_level(rec: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	ensure(rec)
	var lv := int(rec.get("level", 1))
	if rng == null:
		rng = RandomNumberGenerator.new(); rng.seed = hash(str(rec.get("uid", "")) + str(lv))
	var ev := try_evolve(rec, "level")
	if not ev.is_empty():
		return ev
	if lv >= 2 and lv % 4 == 2:
		var a := leading(rec)
		# mostly from the leading affinity, sometimes from another one it's been building
		if rng.randf() < 0.3:
			a = ["fierce", "steadfast", "curious", "swift"][rng.randi_range(0, 3)]
		var pool: Array = AFF[a]["parts"]
		var part: String = pool[rng.randi_range(0, pool.size() - 1)]
		for m in rec["muts"]:
			if m["id"] == part:
				m["lv"] = int(m["lv"]) + 1
				return {"kind": "grow", "aff": a, "part": part, "lv": m["lv"]}
		rec["muts"].append({"id": part, "lv": 1, "aff": a})
		return {"kind": "mutate", "aff": a, "part": part}
	return {}

## Boki that reached their level while their next form had no art evolve once it exists (on load).
## Returns the events; each is also queued on the Boki for the home island to play.
static func catch_up(roster: Array) -> Array:
	var out: Array = []
	for rec in roster:
		var ev := try_evolve(rec, "level")
		while not ev.is_empty():
			ev["text"] = describe(ev, rec)
			if not rec.has("pending_evo"): rec["pending_evo"] = []
			rec["pending_evo"].append(ev)
			out.append(ev)
			ev = try_evolve(rec, "level")
	return out

## The form names version-11 saves gave every 4 levels (e.g. "Cindfang"), so migrate can keep them.
const V11_ROOTS := {"cindle": "Cind", "puddlet": "Pud", "burrlet": "Burr", "zapple": "Zap", "pebbit": "Peb",
	"wisplet": "Wisp"}
const V11_SUFFIX := {
	"fierce": ["fang", "claw", "maw", "rend", "fury"],
	"steadfast": ["shell", "ward", "keep", "bulwark", "aegis"],
	"curious": ["wick", "seer", "mote", "glim", "oracle"],
	"swift": ["dart", "wing", "gale", "streak", "comet"],
}

## Save v11 -> v12: levels and forms stay as they are (a level over the cap comes down to it), and
## each Boki keeps the form name it had. Safe to run twice.
static func migrate(data: Dictionary) -> void:
	var recs: Array = (data.get("roster", []) as Array).duplicate()
	for L in data.get("lost_kin", []):
		if typeof(L) == TYPE_DICTIONARY and typeof(L.get("rec")) == TYPE_DICTIONARY: recs.append(L["rec"])
	for rec in recs:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		rec["level"] = mini(int(rec.get("level", 1)), cap())
		if rec.has("was"):
			continue
		rec["was"] = []
		var forms: Array = rec.get("forms", [])
		if forms.is_empty() or not V11_SUFFIX.has(String(forms[-1])):
			continue
		var sfx: Array = V11_SUFFIX[String(forms[-1])]
		var n := forms.size()
		var root := String(V11_ROOTS.get(String(rec.get("species", "")), "Kin"))
		var extra := "" if n <= sfx.size() else " " + _roman(n - sfx.size() + 1)
		rec["form_name"] = root + String(sfx[mini(n - 1, sfx.size() - 1)]) + extra

static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 10)] if n <= 10 else str(n)

## Gives a generated kin (wild or a bot's) the forms and parts it would have grown by its level.
static func simulate(rec: Dictionary, rng: RandomNumberGenerator) -> void:
	ensure(rec)
	var target := mini(int(rec.get("level", 1)), cap())
	var bias: String = ["fierce", "steadfast", "curious", "swift"][rng.randi_range(0, 3)]
	for lv in range(2, target + 1):
		add(rec, bias, rng.randf_range(2.0, 6.0))
		add(rec, ["fierce", "steadfast", "curious", "swift"][rng.randi_range(0, 3)], rng.randf_range(0.0, 3.0))
		rec["level"] = lv
		on_level(rec, rng)
	rec["level"] = target

## (Forms no longer grow stats by a percentage: a form takes the next node on its affinity's
## evolution path, budget-neutral, see KinLib.nodes_for and docs/KIN_GRAMMAR.md.)

## What a match taught it: called from Game.apply_result with the kin's match stats.
static func learn(rec: Dictionary, st: Dictionary) -> void:
	add(rec, "fierce", float(st.get("hits", 0)) * 0.4 + float(st.get("kos", 0)) * 3.0)
	add(rec, "steadfast", float(st.get("revives", 0)) * 6.0 + float(st.get("won", 0)) * 2.0)
	add(rec, "curious", float(st.get("skills", 0)) * 0.6 + float(st.get("caught", 0)) * 4.0)
	add(rec, "swift", float(st.get("throws", 0)) * 0.8)

static func describe(ev: Dictionary, rec: Dictionary) -> String:
	var kname: String = rec.get("name", "Your Boki")
	var a: Dictionary = AFF[ev["aff"]]
	match String(ev["kind"]):
		"form":
			match String(ev.get("how", "level")):
				"item": return "%s became a %s! The %s did it." % [kname, ev["to"], Goods.name_of("good:" + String(ev["item"]))]
				"trade": return "%s became a %s on its way to a new keeper!" % [kname, ev["to"]]
			return "%s became a %s! It grew %s because it %s." % [kname, ev["to"], String(a["name"]).to_lower(), a["why"]]
		"mutate":
			return "%s grew %s. (%s)" % [kname, PART_NAMES.get(ev["part"], ev["part"]), _perk(ev["aff"])]
		"grow":
			return "%s's %s grew bigger. (%s)" % [kname, PART_NAMES.get(ev["part"], ev["part"]), _perk(ev["aff"])]
	return ""

## Body-part mutations are cosmetic (docs/KIN_GRAMMAR.md); forms take budget-neutral evolution nodes.
static func _perk(_aff: String) -> String:
	return "just for looks"

## Adds evolved parts, size and colour to a kin model built by Models.kin.
static func dress(root: Node3D, rec: Dictionary) -> void:
	if rec.is_empty():
		return
	ensure(rec)
	var forms: Array = rec["forms"]
	var muts: Array = rec["muts"]
	if forms.is_empty() and muts.is_empty():
		return
	var body: Node3D = root.get_node("Body/Flex") if root.has_node("Body/Flex") else root.get_node("Body")
	var sp: Dictionary = Data.KIN[rec.get("species", "cindle")]
	var base: Color = Shiny.body(rec)
	if forms.size() > 0:
		var last: String = forms[forms.size() - 1]
		base = base.lerp(AFF[last]["tint"], minf(0.1 * forms.size(), 0.35))
		# recolour the body to the form's tint
		var mats: Array = root.get_meta("mats", [])
		if mats.size() > 0:
			(mats[0] as ShaderMaterial).set_shader_parameter("albedo", base)
		root.set_meta("evo_scale", 1.0 + minf(forms.size() * 0.1, 0.6))
	if body.has_node("BokiRig"):
		return         # its grown parts are on the rig (BokiDna)
	var mats2: Array = root.get_meta("mats", [])
	for m in muts:
		var col: Color = base.lerp(AFF[m["aff"]]["tint"], 0.6)
		var mat := Models.toon(col.darkened(0.1))
		var glow := Models.toon(AFF[m["aff"]]["tint"].lightened(0.3), false, 0.9)
		mats2.append(mat)
		var k := 1.0 + (int(m["lv"]) - 1) * 0.3
		match String(m["id"]):
			"horns":
				for sx in [-1.0, 1.0]:
					Models.part(body, Models.cyl(0.0, 0.06 * k, 0.28 * k), mat, Vector3(0.15 * sx, 0.68 + 0.05 * k, -0.08), Vector3.ONE, Vector3(-0.35, 0, -0.45 * sx))
			"spikes":
				for i in 3:
					Models.part(body, Models.cyl(0.0, 0.07 * k, 0.2 * k), mat, Vector3(0, 0.62 - i * 0.12, 0.12 + i * 0.12), Vector3.ONE, Vector3(0.6 + i * 0.3, 0, 0))
			"fangs":
				for sx in [-1.0, 1.0]:
					Models.part(body, Models.cyl(0.0, 0.025 * k, 0.09 * k), Models.toon(Color.WHITE), Vector3(0.06 * sx, 0.31, -0.33), Vector3.ONE, Vector3(PI, 0, 0))
			"brow":
				Models.part(body, Models.box(0.36 * k, 0.07, 0.14), mat, Vector3(0, 0.55, -0.25), Vector3.ONE, Vector3(0.4, 0, 0))
			"plates":
				for i in 2:
					Models.part(body, Models.box(0.34 * k, 0.06, 0.2), mat, Vector3(0, 0.6 - i * 0.14, 0.14 + i * 0.12), Vector3.ONE, Vector3(-0.5 - i * 0.3, 0, 0))
			"shell":
				var t := TorusMesh.new(); t.inner_radius = 0.33; t.outer_radius = 0.33 + 0.07 * k
				Models.part(body, t, mat, Vector3(0, 0.3, 0))
			"club":
				Models.part(body, Models.sphere(0.12 * k, 10), mat, Vector3(0, 0.22, 0.48))
			"antennae":
				for sx in [-1.0, 1.0]:
					Models.part(body, Models.cyl(0.012, 0.012, 0.3 * k, 6), mat, Vector3(0.09 * sx, 0.78, -0.12), Vector3.ONE, Vector3(-0.3, 0, -0.25 * sx))
					Models.part(body, Models.sphere(0.045 * k, 8), glow, Vector3(0.13 * sx, 0.78 + 0.15 * k, -0.18))
			"spots":
				for i in 4:
					var a := TAU * i / 4.0 + 0.4
					Models.part(body, Models.sphere(0.04 * k, 6), glow, Vector3(cos(a) * 0.33, 0.36 + sin(a * 2.0) * 0.06, sin(a) * 0.3 + 0.03))
			"third_eye":
				Models.part(body, Models.sphere(0.045 * k, 8), glow, Vector3(0, 0.56, -0.29))
			"crest":
				for i in 3:
					Models.part(body, Models.box(0.03, 0.16 * k - i * 0.03, 0.1), mat, Vector3(0, 0.72 - i * 0.02, -0.04 + i * 0.09), Vector3.ONE, Vector3(0.3, 0, 0))
			"wings":
				for sx in [-1.0, 1.0]:
					var w := Models.part(body, Models.sphere(0.16 * k, 10), mat, Vector3(0.26 * sx, 0.5, 0.18), Vector3(0.25, 1.0, 1.4), Vector3(0.3, 0.4 * sx, 0.5 * sx))
					w.name = "Wing%d" % int(sx)
			"tail_long":
				for i in 3:
					Models.part(body, Models.sphere(0.08 * k - i * 0.015, 8), mat, Vector3(0, 0.28 + i * 0.05, 0.36 + i * 0.13))
			"fins":
				for sx in [-1.0, 1.0]:
					Models.part(body, Models.sphere(0.12 * k, 8), mat, Vector3(0.34 * sx, 0.28, 0.0), Vector3(0.2, 0.7, 1.2), Vector3(0, 0, 0.3 * sx))
	root.set_meta("mats", mats2)
	if root.has_meta("evo_scale"):
		root.scale = Vector3.ONE * float(root.get_meta("evo_scale"))
