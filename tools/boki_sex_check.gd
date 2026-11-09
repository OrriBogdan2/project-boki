extends RefCounted
## --boki-sex-check: every Boki is male or female, 50/50 (Unique.sex, DECISIONS 2026-11-08); only species
## with "sex_forms" in content/kin/<id>.json get a female look (BokiSex), the rest show the sex icon only.
##   1. at hatch (Care.breed, Care.hatch_rare), wild and captured (a seeded Save.new_kin): a sex each, half and half
##   2. a Boki keeps its sex through save and load; an old save's Boki get one written down
##   3. the female look: only for flagged species, and only when its art exists (else the base model)
##   4. the card shows the icon; a female Boki builds on her female model when it exists, else the base one

const N := 2000
## The in-game species whose lines have "sex_forms" in the art's LIVE_MANIFEST.json: Gongibbon, Kestrike,
## Murmurling, Lunowl. The starters branch, so they keep one look (GAME_RULES_NOV8 section 6).
const SEX_FORMS := ["gibbelle", "kestrike", "murmurling", "wisplet"]

var fails := 0
var n := 0

func ok(cond: bool, label: String, info := "") -> void:
	n += 1
	print("BOKISEX %-66s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_rolls()
	_migrate()
	_looks()
	_icon_and_model()
	print("BOKISEX DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _half(sexes: Array, who: String) -> void:
	var share := float(sexes.count("f")) / sexes.size()
	ok(absf(share - 0.5) < 0.04 and not sexes.has(""), "%s are about half female (%.1f%%)" % [who, 100.0 * share])

func _rolls() -> void:
	var sps: Array = Data.common_kin()
	var made: Array = []
	var wild: Array = []
	for i in N:
		made.append(Unique.sex(Save.new_kin(sps[i % sps.size()])))
		wild.append(Unique.sex(Save.new_kin(sps[i % sps.size()], "", 90000 + i)))
	_half(made, "new Boki")
	_half(wild, "wild and captured Boki (seeded)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := Save.new_kin("cindle")
	var b := Save.new_kin("puddlet")
	var babies: Array = []
	var rare: Array = []
	for i in N:
		babies.append(Unique.sex(Care.breed(a, b, rng)))
		rare.append(Unique.sex(Care.hatch_rare({"species": "kestrike"}, rng)))
	_half(babies, "bred babies")
	_half(rare, "Rare Egg hatches")
	var fm := Save.new_kin("cindle", "F", 5)
	var sx := Unique.sex(fm)
	var again := Unique.sex(Save.new_kin("cindle", "F", 5))
	ok(sx == Unique.sex_for_seed(5) and again == sx, "the same seed gives the same sex")

func _migrate() -> void:
	var rec := Save.new_kin("kestrike", "Old", 77)
	var want: String = Unique.sex(rec)
	var back: Dictionary = JSON.parse_string(JSON.stringify(rec))
	ok(Unique.sex(back) == want, "a Boki keeps its sex through save and load (%s)" % want)
	var bare := rec.duplicate(true)
	(bare["dna"] as Dictionary).erase("sex")
	var lost := {"rec": bare.duplicate(true)}
	var grave := {"rec": bare.duplicate(true)}
	var old := {"v": 2, "roster": [bare], "lost_kin": [lost], "graves": [grave]}
	var moved := Save.migrate(old)
	var kept := [old["roster"][0], old["lost_kin"][0]["rec"], old["graves"][0]["rec"]]
	var all_set := kept.all(func(r): return String(r["dna"].get("sex", "")) == want)
	ok(moved and int(old["v"]) == Save.VERSION and all_set, "a v2 save's roster, lost and buried Boki get a sex")
	var v1 := {"v": 1, "roster": [{"uid": "old-one", "species": "cindle", "name": "Ash"}], "lost_kin": [], "graves": []}
	var v1_ok: bool = Save.migrate(v1) and v1["roster"][0]["dna"].has("sex")
	ok(v1_ok, "a v1 save's Boki are given a sex too")

func _looks() -> void:
	var wrong: Array = Data.KIN.keys().filter(func(sp): return BokiSex.has_forms(sp) != (sp in SEX_FORMS))
	ok(wrong.is_empty(), "female looks are flagged for exactly the manifest's species", str(wrong))
	var female := _of_sex("kestrike", "f")
	var male := _of_sex("kestrike", "m")
	var base := "res://art/kin/kestrike/kestrike.glb"
	ok(BokiSex.model_path("kestrike", male, base) == base, "a male Boki wears the base model")
	var want := BokiSex.female_path % ["kestrike", "kestrike"]
	var got: String = BokiSex.model_path("kestrike", female, base)
	var expect := want if ResourceLoader.exists(want) else base
	ok(got == expect, "a female Boki wears the female model only if its art exists", got)
	var starter: String = BokiSex.model_path("cindle", _of_sex("cindle", "f"), "x")
	ok(starter == "x", "a species without female looks keeps its one model")
	var bare: String = BokiSex.model_path("kestrike", {"species": "kestrike"}, base)
	ok(bare == base, "a bare look-only record wears the base model")

## Points the female art at models that exist (the base ones) so the whole route is seen to load it.
func _icon_and_model() -> void:
	var f := _of_sex("kestrike", "f")
	var ic := UI.sex_icon(f, 12.0)
	ok(ic != null and ic.tooltip_text == "Female", "the card's sex icon reads Female")
	ic.free()
	var real := BokiSex.female_path
	BokiSex.female_path = "res://art/kin/%s/%s.glb"
	var lunowl := _of_sex("wisplet", "f")
	var path := BokiSex.model_path("wisplet", lunowl, "base")
	ok(path == "res://art/kin/wisplet/wisplet.glb", "a female Boki wears her species' female art once it lands", path)
	var brother := BokiSex.model_path("wisplet", _of_sex("wisplet", "m"), "base")
	ok(brother == "base", "her brother still wears the base model")
	var mdl := Models.kin("wisplet", lunowl)
	ok(mdl.find_child("BokiRig", true, false) != null, "she builds on that female model")
	mdl.free()
	BokiSex.female_path = real
	mdl = Models.kin("kestrike", f)
	ok(mdl.find_child("BokiRig", true, false) != null, "with no female art yet she builds on the base model")
	mdl.free()

func _of_sex(species: String, want: String) -> Dictionary:
	for i in 64:
		var rec := Save.new_kin(species, "", 5000 + i)
		if Unique.sex(rec) == want:
			return rec
	return {}
