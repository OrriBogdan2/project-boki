extends RefCounted
## --fav-food-check: a Boki's favourite food (FavFood). Rolled from type and personality, hidden until
## the first feeding, extra trust and joy up to a daily cap, old records get one, babies inherit a
## parent's. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FAVFOOD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _hungry(rec: Dictionary) -> void:
	rec["needs"]["food"] = 20.0
	rec["needs"]["joy"] = 40.0

func _old_rec(uid: String, sp: String, known: Array) -> Dictionary:
	return {"uid": uid, "species": sp, "name": "Old", "level": 7, "xp": 0, "traits": {"bravery": 0.5},
		"trust": 60.0, "memory": [], "likes": {"food": "kibble", "hates": "puffcorn", "play": "fetch"},
		"known": known}

## A species whose type food differs from what its personality alone would give (so both show up).
func _mixed_species(sps: Array, by_type: Dictionary) -> String:
	for sp in sps:
		var theme := String(Data.KIN[sp].get("theme", ""))
		var base := {"uid": "probe", "species": "", "traits": Data.KIN[sp]["traits"]}
		if by_type.has(theme) and FavFood.roll(base) != by_type[theme]:
			return sp
	return ""

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var sps: Array = Data.common_kin()
	var all_valid := true
	for sp in sps:
		var rec := Save.new_kin(sp)
		var f := String(rec["likes"]["food"])
		var real := Data.CROPS.has(f) or Care.FOODS.has(f)
		if not real or f == rec["likes"]["hates"] or FavFood.roll(rec) != f: all_valid = false
	ok(all_valid, "every species rolls a real favourite, never its hated food, and the roll is stable")
	var by_type: Dictionary = Content.rules("fav_food")["by_type"]
	var sp_t := _mixed_species(sps, by_type)
	var type_food := String(by_type[Data.KIN[sp_t]["theme"]])
	var hits := 0
	for i in 200:
		if Save.new_kin(sp_t)["likes"]["food"] == type_food: hits += 1
	ok(hits >= 110 and hits <= 190, "a type's Boki mostly likes %s, not always (%d of 200)" % [type_food, hits])
	var bold := {"uid": "t1", "species": "", "traits": {"bravery": 0.9, "curiosity": 0.4}}
	var shy := {"uid": "t1", "species": "", "traits": {"bravery": 0.1, "curiosity": 0.9}}
	var by_trait := FavFood.roll(bold) == "emberberry" and FavFood.roll(shy) == "glowcap"
	ok(by_trait, "no type: personality picks it (brave emberberry, curious glowcap)")
	# ---------------------------------------------------------------- hidden, then revealed and rewarded
	var rec := Save.new_kin(sps[0], "Pip")
	var fav := String(rec["likes"]["food"])
	var plain := "sweetbun" if fav != "sweetbun" and rec["likes"]["hates"] != "sweetbun" else "kibble"
	ok(not (rec["known"] as Array).has("food"), "a new Boki's favourite is hidden")
	_hungry(rec)
	var t0 := float(rec["trust"])
	var j0 := Care.need(rec, "joy")
	Care.feed(rec, plain)
	var plain_trust := float(rec["trust"]) - t0
	var plain_joy := Care.need(rec, "joy") - j0
	var other := Save.new_kin(sps[0], "Pop")
	FavFood.set_food(other, fav)
	_hungry(other)
	var t1 := float(other["trust"])
	var j1 := Care.need(other, "joy")
	var res := Care.feed(other, fav)
	var trust_up := float(other["trust"]) - t1
	var joy_up := Care.need(other, "joy") - j1
	var shown: bool = res["love"] and res["new"] and (other["known"] as Array).has("food")
	ok(shown, "feeding the favourite the first time reveals it")
	var more := "trust +%.1f vs +%.1f, joy +%.0f vs +%.0f" % [trust_up, plain_trust, joy_up, plain_joy]
	ok(trust_up > plain_trust and joy_up > plain_joy, "the favourite gives more trust and joy (%s)" % more)
	# ---------------------------------------------------------------- the daily cap
	var cap := int(Content.rules("fav_food")["daily_cap"])
	var gains := 0
	for i in cap + 3:
		_hungry(other)
		var before := float(other["trust"])
		Care.feed(other, fav)
		if float(other["trust"]) > before: gains += 1
	ok(gains == cap - 1, "only %d favourite feedings a day give trust (%d more after the first)" % [cap, gains])
	other["fav_fed"]["day"] = -1
	var back := float(other["trust"])
	_hungry(other)
	Care.feed(other, fav)
	ok(float(other["trust"]) > back, "a new day opens the bonus again")
	# ---------------------------------------------------------------- old saves
	var old := _old_rec("k123456789", sps[1], [])
	Care.ensure(old)
	var rolled: bool = old["likes"]["food"] == FavFood.roll(old) and old.has("fav_v")
	ok(rolled, "an old Boki that never found its favourite gets a rolled one")
	var found := _old_rec("k2", sps[1], ["food"])
	Care.ensure(found)
	ok(found["likes"]["food"] == "kibble", "one whose favourite you already found keeps it")
	# ---------------------------------------------------------------- breeding
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var pa := Save.new_kin(sps[0], "A")
	var pb := Save.new_kin(sps[0], "B")
	FavFood.set_food(pa, "emberberry")
	FavFood.set_food(pb, "tidebloom")
	var took := 0
	var valid := true
	for i in 200:
		var baby := Care.breed(pa, pb, rng, sps[0])
		var f := String(baby["likes"]["food"])
		if f == "emberberry" or f == "tidebloom": took += 1
		if f == baby["likes"]["hates"]: valid = false
	ok(took >= 130 and took <= 190, "babies mostly take a parent's (%d of 200)" % took)
	ok(valid, "no baby's favourite is its hated food")
	print("FAV FOOD CHECK DONE, failures: ", bad)
	m.get_tree().quit()
