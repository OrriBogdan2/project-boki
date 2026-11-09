extends RefCounted
## --boki-sex-check: every Boki is male or female, 50/50 (Unique.sex, DECISIONS 2026-11-08); only species
## with "sex_forms" in content/kin/<id>.json get a female look (BokiSex), the rest show the sex icon only.
##   1. at hatch (Care.breed, Care.hatch_rare), wild and captured (a seeded Save.new_kin): a sex each, half and half
##   2. a Boki keeps its sex through save and load; an old save's Boki get one written down
##   3. the female look: only for flagged species, and only when its art exists (else the base model)
##   4. the card shows the icon, and a female Boki builds on the base model while no female art exists

const N := 2000
const SEX_FORMS := ["cindle", "puddlet", "burrlet", "zapple", "pebbit", "wisplet", "kestrike", "murmurling"]
const NO_FORMS := ["gibbelle", "hoarheron", "cindowary"]

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
	var all_flagged := true
	for sp in SEX_FORMS:
		all_flagged = all_flagged and BokiSex.has_forms(sp)
	var none_extra := true
	for sp in NO_FORMS:
		none_extra = none_extra and not BokiSex.has_forms(sp)
	ok(all_flagged and none_extra, "female looks are flagged for the chosen species only")
	var female := _of_sex("kestrike", "f")
	var male := _of_sex("kestrike", "m")
	var base := "res://art/kin/kestrike/kestrike.glb"
	ok(BokiSex.model_path("kestrike", male, base) == base, "a male Boki wears the base model")
	var want := "res://art/kin/kestrike/kestrike_f.glb"
	var got: String = BokiSex.model_path("kestrike", female, base)
	var expect := want if ResourceLoader.exists(want) else base
	ok(got == expect, "a female Boki wears the female model only if its art exists", got)
	var plain: String = BokiSex.model_path("gibbelle", _of_sex("gibbelle", "f"), "x")
	ok(plain == "x", "a species without female looks keeps its one model")
	var bare: String = BokiSex.model_path("kestrike", {"species": "kestrike"}, base)
	ok(bare == base, "a bare look-only record wears the base model")

func _icon_and_model() -> void:
	var f := _of_sex("kestrike", "f")
	var ic := UI.sex_icon(f, 12.0)
	ok(ic != null and ic.tooltip_text == "Female", "the card's sex icon reads Female")
	ic.free()
	var mdl := Models.kin("kestrike", f)
	ok(mdl.find_child("BokiRig", true, false) != null, "a female Boki of a flagged species builds")
	mdl.free()

func _of_sex(species: String, want: String) -> Dictionary:
	for i in 64:
		var rec := Save.new_kin(species, "", 5000 + i)
		if Unique.sex(rec) == want:
			return rec
	return {}
