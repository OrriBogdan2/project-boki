extends RefCounted
## --soul-echo-check: soul echoes from stolen Boki wisps (SoulEcho, decision 0097), with Boki wisps on. Steal: the
## player grabs a downed rival's shimmering, mutated wisp and holds no echo yet; a rival thief extracting with one
## gets the gems and no echo for the player. Extract: the player gets extract_gems per stolen wisp, the wisp goes home,
## and the result carries the echo. Home (Game.apply_result): the Field Book entry is unlocked with an echo, its
## traits wait for the next hatch, and its page says so. Weighted hatch: a nest egg takes after the echoed parent
## at weight 1 + hatch_per_echo per echo (capped), and the next hatch rolls trait_chance for a stolen trait, then
## spends them. Save: a v13 save migrates with the trait list and an echo count on every entry. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const MUT := "glowing"      # a mutation with no group, so the hatchling never has a clashing one
const HATCHES := 2000       # seeded hatches for the trait rate

var bad := 0
var m: Match

func run(main: Node) -> void:
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)
	var sp := _steal_and_extract()
	m.queue_free()
	_home(sp)
	_weighted_hatch(sp)
	_migration()
	print("SOULECHO %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("SECHO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## The player steals one rival's wisp, a rival thief extracts with another, then the player extracts. The species.
func _steal_and_extract() -> String:
	var p: Hunter = m.player
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)
	var f: Hunter = foes[0]
	var thief: Hunter = foes[1]
	var fk: Kin = f.kin
	fk.rec["shimmer"] = true
	fk.rec["mutations"] = [MUT]
	m.knock(f, p, {})
	_frames(0.1)
	ok(KinSteal.grab(fk, p) and KinSteal.stolen(fk) and fk.owner_h == p, "steal: the player grabs %s's wisp" % f.pname)
	ok(SoulEcho.count(fk.species) == 0 and not m.result.has("soul_echoes"), "...and holds no echo yet")
	var pk: Kin = p.kin
	m.knock(p, thief, {})
	_frames(0.1)
	ok(KinSteal.stolen(fk) == false and KinSteal.loose(fk), "...a downed thief scatters it")
	ok(KinSteal.grab(pk, thief), "a rival grabs the player's own wisp")
	m.revive_hunter(p, null)
	_frames(0.1)
	ok(KinSteal.grab(fk, p), "...and the player takes the stolen one again")
	var tg := thief.gems
	m._extract(thief, "uplink", "test")
	var bonus := int(SoulEcho.rules()["extract_gems"])
	ok(thief.gems == tg + bonus and pk.owner_h == p and not KinSteal.taken(pk),
		"a rival thief extracting: +%d gems, the player's Boki comes home" % bonus)
	ok(not m.result.has("soul_echoes"), "...and the player gets no echo from it")
	var g0 := p.gems
	m._extract(p, "uplink", "test")
	ok(p.gems == g0 + bonus, "extract: +%d gems for the stolen wisp (%d -> %d)" % [bonus, g0, p.gems])
	ok(not KinSteal.taken(fk) and fk.owner_h == f and fk.team == f.team, "...and it goes home to its owner")
	var echoes: Array = m.result.get("soul_echoes", [])
	ok(echoes.size() == 1 and String(echoes[0]["sp"]) == fk.species and echoes[0]["shimmer"]
		and Array(echoes[0]["mutations"]) == [MUT], "...the result carries its soul echo (%s)" % [echoes])
	return fk.species

## Game.apply_result writes the echo home.
func _home(sp: String) -> void:
	var r := {"extracted": true, "haul": [], "tier": 0, "gems": 0, "kin_runs": [], "caught": [], "seeds": {},
		"soul_echoes": [{"sp": sp, "shimmer": true, "mutations": [MUT]}]}
	Save.d["dex"] = {}      # (sightings during the match do not count here)
	ok(not FieldBook.entry_seen(sp), "home: %s not in the Field Book before" % sp)
	Game.apply_result(r)
	ok(FieldBook.entry_seen(sp) and SoulEcho.count(sp) == 1, "...unlocked, with one soul echo")
	ok(SoulEcho.traits().size() == 2, "...its shimmer and mutation wait for the next hatch (%s)" % [SoulEcho.traits()])
	ok(DexView._habitat(sp).contains("1 soul echo"), "...and its page says so")
	Game.apply_result({"extracted": false, "why": "knocked out", "tier": 0, "kin_runs": [], "caught": []})
	ok(SoulEcho.count(sp) == 1, "a lost match adds nothing")

func _weighted_hatch(sp: String) -> void:
	var others: Array = ["zapple", "kindlewren", "cindle"].filter(func(s: String): return s != sp)
	var other := String(others[0])
	var a := {"species": sp}
	var b := {"species": other}
	var r := SoulEcho.rules()
	var want := (1.0 + float(r["hatch_per_echo"])) / (2.0 + float(r["hatch_per_echo"]))
	ok(absf(_share(a, b) - want) < 0.002 and absf(_share(b, a) - (1.0 - want)) < 0.002,
		"hatch: an echoed parent's species %.3f of eggs (want %.3f, 0.5 without)" % [_share(a, b), want])
	ok(absf(_share(b, {"species": others[1]}) - 0.5) < 0.002, "...no echoes: half and half")
	Care.dex_entry(sp)["echo"] = 50
	var cap := 1.0 + float(r["hatch_per_echo"]) * int(r["hatch_echo_cap"])
	ok(absf(SoulEcho.weight(sp) - cap) < 0.001, "...capped at weight %.2f" % cap)
	Care.dex_entry(sp)["echo"] = 1
	var kept: Array = SoulEcho.traits().duplicate(true)
	var rng := RandomNumberGenerator.new()
	var hits := 0
	var right := true
	for i in HATCHES:
		SoulEcho.traits().assign(kept.duplicate(true))
		rng.seed = i
		var baby := Save.new_kin(other)
		baby["shimmer"] = false
		baby.erase("mutations")
		var got := SoulEcho.hatched(baby, rng)
		right = right and SoulEcho.traits().is_empty()
		if got.is_empty():
			right = right and not baby["shimmer"] and Mutations.of(baby).is_empty()
			continue
		hits += 1
		right = right and (baby["shimmer"] if got.get("shimmer", false) else Mutations.of(baby) == [MUT])
	var rate := float(hits) / HATCHES
	ok(absf(rate - float(r["trait_chance"])) < 0.015, "next hatch: a stolen trait %.3f of the time (want %.2f)"
		% [rate, float(r["trait_chance"])])
	ok(right, "...it is the stolen shimmer or mutation, and the traits are spent either way")
	var plain := Save.new_kin(other)
	ok(SoulEcho.hatched(plain, rng).is_empty(), "...with none waiting, a hatch is untouched")

## The share of eggs taking after a, over evenly spread rolls.
func _share(a: Dictionary, b: Dictionary) -> float:
	var n := 0
	for i in 1000:
		if SoulEcho.egg_species(a, b, (i + 0.5) / 1000.0) == a["species"]:
			n += 1
	return n / 1000.0

func _migration() -> void:
	var old := Save.fresh()
	old["v"] = 13
	old.erase("soul_echo")
	old["dex"] = {"cindle": {"seen": true, "caught": true, "forms": [], "shimmer": false},
		"zapple": {"seen": true, "caught": false, "forms": [], "shimmer": false, "echo": 3}}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION, "save: a v13 save upgrades to v%d" % Save.VERSION)
	ok(old["soul_echo"] == {"traits": []} and int(old["dex"]["cindle"]["echo"]) == 0
		and int(old["dex"]["zapple"]["echo"]) == 3, "...with the trait list and an echo count on every entry")
	ok(Save.fresh()["soul_echo"] == {"traits": []}, "...the same as a new save")
