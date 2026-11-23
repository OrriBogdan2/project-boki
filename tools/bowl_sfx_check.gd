extends RefCounted
## --bowl-sfx-check: the Mixing Bowl's sounds (scripts/home/bowl_sfx.gd, tools/gen_sfx_bowl.py, docs/AUDIO.md).
##   1. every sound exists; an ingredient's plop follows its kind (snack, treat, bun); every recipe has a tier 1-3
##      and the tiers climb with the grandness of the recipe (Twinbun 1, a zone sweet 2, Fourfold Bun 3)
##   2. each recipe's mix plays one plop per ingredient (four at most), the stir once and then stops, and one chime
##      of the recipe's own tier
##   3. a Boki tastes a bowl item once (sweet, Fourfold Bun, personality item, Twinbun) and nothing else (a stat
##      bite, a refused item); a small Boki tastes higher than a large one
##   4. a Twinbun between a clashing pair fizzles once after the taste, between a calm pair it does not
## Never touches the real save.

const WAIT_PAD_S := 0.3          # real s to wait past the longest timer of a mix

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOWLSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_names()
	for r in GardenRecipes.all():
		await _mix(r)
	await _taste()
	await _fizzle()
	print("BOWLSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _heard(sname: String) -> int:
	return int(GardenSfx.heard.get(sname, 0))

func _wait(secs: float) -> void:
	await main.get_tree().create_timer(secs).timeout

func _names() -> void:
	var silent := []
	for sname in ["bowl_plop_snack", "bowl_plop_treat", "bowl_plop_bun", "bowl_stir", "bowl_done_1", "bowl_done_2",
			"bowl_done_3", "bowl_fizzle", "bowl_taste"]:
		if not Sfx.ensure(sname):
			silent.append(sname)
	ok(silent.is_empty(), "the bowl's 9 sounds exist (silent: %s)" % [silent])
	var by_kind := [BowlSfx.kind("hushpearl"), BowlSfx.kind("sweetbun"), BowlSfx.kind(Data.CROPS.keys()[0])]
	ok(by_kind == ["treat", "bun", "snack"], "ingredients sound by kind: pearl a treat, bun a bun, a crop a snack")
	var tiers := {}
	for r in GardenRecipes.all():
		tiers[r["id"]] = int(r["tier"])
	var climbs: bool = tiers["twinbun"] == 1 and tiers["bramble_honey"] == 2 and tiers["fourfold_bun"] == 3
	var in_range: bool = tiers.values().all(func(t): return t >= 1 and t <= 3)
	ok(climbs and in_range, "tiers: Twinbun 1, a zone sweet 2, Fourfold Bun 3")

## Stock the bag for a recipe, mix it and count what played.
func _mix(r: Dictionary) -> void:
	Save.d = Save.fresh()
	var need: Dictionary = r["need"]
	match String(need["kind"]):
		"different":
			for id in need["of"]:
				Save.d["items"][id] = 1
		"snack_type":
			var snack: String = Data.CROPS.keys().filter(func(f): return Lean.key_of(f) in need["types"])[0]
			Save.d["crops"][snack] = int(need["n"])
		_:
			Save.d["items"][need["item"]] = int(need["n"])
	var plan := GardenRecipes.plan(r)
	var before := GardenSfx.heard.duplicate()
	GardenRecipes.mix(r)
	BowlSfx.mixed(r, plan["take"])
	var ings := 0
	for id in plan["take"]:
		ings += int(plan["take"][id])
	await _wait(BowlSfx.PLOP_GAP * mini(ings, BowlSfx.MAX_PLOPS) + BowlSfx.STIR_S + WAIT_PAD_S)
	var plops := 0
	for kind in ["snack", "treat", "bun"]:
		plops += _heard("bowl_plop_" + kind) - int(before.get("bowl_plop_" + kind, 0))
	var done := "bowl_done_%d" % int(r["tier"])
	var chimes := _heard(done) - int(before.get(done, 0))
	var stirs := _heard("bowl_stir") - int(before.get("bowl_stir", 0))
	var right: bool = plops == mini(ings, BowlSfx.MAX_PLOPS) and chimes == 1 and stirs == 1
	right = right and not Sfx.loop_on("bowl_stir")
	ok(right, "%s: %d plops, 1 stir (stopped), 1 tier-%d chime (got %d, %d, %d)" % [
			r["id"], ings, int(r["tier"]), plops, stirs, chimes])

func _boki(sp: String) -> Dictionary:
	var rec := Save.new_kin(sp, sp)
	rec["level"] = 10
	Care.ensure(rec)
	return rec

func _taste() -> void:
	Save.d = Save.fresh()
	Save.d["items"] = {"fourfold_bun": 1, "windfloss": 1, "dare_pepper": 1, "thumpnut": 1}
	var rec := _boki("cindle")
	var tasted := func(res: Dictionary) -> int:
		var was := _heard("bowl_taste")
		BowlSfx.taste(rec, null, res)
		return _heard("bowl_taste") - was
	ok(tasted.call(GardenItems.use(rec, "fourfold_bun")) == 1, "a Fourfold Bun is tasted once")
	ok(tasted.call(GardenItems.use(rec, "windfloss", "fairy")) == 1, "a sweet is tasted once")
	ok(tasted.call(GardenItems.feed(rec, "dare_pepper")) == 1, "a personality item is tasted once")
	ok(tasted.call(GardenItems.use(rec, "thumpnut")) == 0, "a stat bite is not a bowl item: no tasting")
	var again: int = tasted.call(GardenItems.use(rec, "fourfold_bun"))
	again += tasted.call(GardenItems.use(rec, "windfloss", "fairy"))
	ok(again == 0, "nothing left, nothing tasted")
	var pitch: Dictionary = BowlSfx.SIZE_PITCH
	var sized: bool = GardenSfx.SIZE.values().all(func(s): return pitch.has(s))
	var falling: bool = pitch["small"] > pitch["medium"] and pitch["medium"] > pitch["large"]
	ok(sized and falling, "a small Boki tastes higher than a large one")

func _fizzle() -> void:
	var themes := {}
	for sp in Data.KIN:
		themes[String(Data.KIN[sp].get("theme", ""))] = sp
	var clashes: Array = Content.rules("unstable_mix")["clashes"]
	var clash: Array = clashes.filter(func(c): return themes.has(c[0]) and themes.has(c[1]))[0]
	var clashing := [_boki(themes[clash[0]]), _boki(themes[clash[1]])]
	for case in [["calm", _boki("cindle"), _boki("cindle")], ["clashing", clashing[0], clashing[1]]]:
		Save.d["items"] = {"twinbun": 1}
		var was := _heard("bowl_fizzle")
		var taste := _heard("bowl_taste")
		BowlSfx.taste(case[1], null, GardenItems.share(case[1], case[2], "twinbun"))
		await _wait(BowlSfx.FIZZLE_DELAY + WAIT_PAD_S)
		var fizz := _heard("bowl_fizzle") - was
		ok(_heard("bowl_taste") - taste == 1 and fizz == (1 if case[0] == "clashing" else 0),
				"a Twinbun between a %s pair: tasted once, %d fizzle" % [case[0], fizz])
