extends RefCounted
## --come-look-check: news at home (a new Boki, a Rare Egg, a new toy, you back with loot) fires once
## each and up to three nearby Boki come to look: the most curious first, a timid one last and hanging
## back, a napping one and the newcomer staying out of it. They chatter, and the first to arrive
## keeps one memory line of the day. Never touches the real save.

const STEP_S := 0.1
const RUN_S := 30.0
## [curiosity, bravery] of the Boki who live there: A curious and bold, B bold, C dull, D curious but
## timid, E asleep.
const TRAITS := [[0.9, 0.8], [0.7, 0.8], [0.2, 0.8], [0.8, 0.2], [0.95, 0.9]]

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("COMELOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> void:
	var d := Save.fresh()
	var names := ["A", "B", "C", "D", "E"]
	var species: Array = Data.KIN.keys()
	for i in names.size():
		var rec := Save.new_kin(String(species[i]), names[i])
		rec["traits"]["curiosity"] = TRAITS[i][0]
		rec["traits"]["bravery"] = TRAITS[i][1]
		d["roster"].append(rec)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)

## A spot with open ground all round it, so everyone can stand there.
func _open_spot() -> Vector3:
	var at: Vector3 = home.world.random_ground(0)
	for i in 300:
		var isle: int = home.world.island_of(at.x, at.z)
		var open := true
		for a in 8:
			var p := at + Vector3(cos(a * 0.785), 0, sin(a * 0.785)) * 6.0
			open = open and home.world.island_of(p.x, p.z) == isle and not home.world.is_void(p.x, p.z)
		if open:
			return at
		at = home.world.random_ground(0)
	return at

## Puts everyone around the spot, a few metres out and idle, and E to sleep.
func _gather(at: Vector3) -> void:
	var taken: Array = [home.ppos]
	for i in home.kins.size():
		var k: Dictionary = home.kins[i]
		var p: Vector3 = home.world.free_spot_near(at + Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 4.0, taken, 1.3)
		taken.append(p)
		k["pos"] = p
		(k["node"] as Node3D).position = p
		k["goal"] = Vector3.INF
		k["t"] = 5.0
		k["hold_t"] = 0.0
		k["say_t"] = 0.0
		for key in ["nap_t", "job", "chase", "fetch", "bath", "going_in", "called_t"]:
			k.erase(key)
	_entry("E")["nap_t"] = 60.0

func _entry(nm: String) -> Dictionary:
	for k in home.kins:
		if k["rec"]["name"] == nm:
			return k
	return {}

func _names(came: Array) -> String:
	return "".join(came.map(func(k): return String(k["rec"]["name"])))

## Runs the farm; returns who spoke, and how far from the spot each stood when it began to look.
func _watch(at: Vector3) -> Dictionary:
	var spoke := {}
	var stood := {}
	for i in int(RUN_S / STEP_S):
		home._move_kin(STEP_S)
		ComeLook.tick(home, STEP_S)
		for l in ComeLook._looks:
			var nm := String(l["k"]["rec"]["name"])
			if float(l["watch"]) >= 0.0 and not stood.has(nm):
				stood[nm] = (l["k"]["pos"] as Vector3).distance_to(at)
			if float(l["k"].get("say_t", 0.0)) > 0.0:
				spoke[nm] = true
	return {"spoke": spoke, "stood": stood}

func _mem_size(nm: String) -> int:
	return (_entry(nm)["rec"]["memory"] as Array).size()

func _last_mem(nm: String) -> String:
	var mem: Array = _entry(nm)["rec"]["memory"]
	return String(mem[-1]["text"]) if not mem.is_empty() else ""

## A new Boki hatched or arrived: the farm notices it on its own (FarmChatter) and Boki come.
func _newcomer(rare: bool) -> void:
	var baby_name := "Rarity" if rare else "Newt"
	var baby := Save.new_kin(String(Data.KIN.keys()[6 if rare else 5]), baby_name)
	baby["traits"]["curiosity"] = 0.1
	baby["traits"]["bravery"] = 0.8
	if rare:
		Save.remember(baby, "born", "hatched from a Rare Egg you carried home")
	Save.d["roster"].append(baby)
	home._spawn_kin()
	var at := _open_spot()
	_gather(at)
	var who := _entry(String(baby["name"]))
	who["pos"] = at
	var before := _mem_size("A")
	var others := {}
	for nm in ["B", "C", "D", "E"]:
		others[nm] = _mem_size(nm)
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)
	var kind := "rare" if rare else "boki"
	var came: Array = ComeLook._looks.map(func(l): return l["k"])
	var tag := "a %s Boki" % ("Rare Egg" if rare else "new")
	ok(_names(came) == "ABD", "%s: A, B, D come (curious first, timid last): %s" % [tag, _names(came)])
	ok(ComeLook._looks.size() == ComeLook.MAX_LOOKERS, "%s: no more than three come" % tag)
	ok(ComeLook._looks[0]["kind"] == kind and ComeLook._looks[2]["timid"], "%s: a %s event; D is timid" % [tag, kind])
	var res := _watch(at)
	ok(ComeLook._looks.is_empty(), "%s: everyone who came has looked and gone back to what they do" % tag)
	var far: float = res["stood"].get("D", -1.0)
	var close: float = res["stood"].get("A", 99.0)
	ok(far > close + 1.0, "%s: D hung back (%.1f m), A stood close (%.1f m)" % [tag, far, close])
	ok(res["spoke"].has("A"), "%s: they chatter (%s)" % [tag, ",".join(res["spoke"].keys())])
	ok(_mem_size("A") == before + 1 and _last_mem("A").contains(String(who["rec"]["name"])),
		"%s: A keeps one memory line: '%s'" % [tag, _last_mem("A")])
	ok(rare == _last_mem("A").contains("Rare Egg"), "%s: the line says it was a Rare Egg only when it was" % tag)
	var same := others.keys().all(func(nm): return _mem_size(nm) == others[nm])
	ok(same, "%s: nobody else wrote a line" % tag)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_new_save()
	home = await main._hb_home()
	ok(home.kins.size() == 5, "five Boki live on the farm (%d)" % home.kins.size())
	home.panel_open = ""      # the welcome card would keep the farm quiet
	FarmChatter._known.clear()
	ComeLook._extracts = -1
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)
	ok(ComeLook._looks.is_empty(), "the first look only learns who lives here: nobody comes")
	await _newcomer(false)
	await _newcomer(true)
	# ------------------------------------------------ a new toy: the most curious bold Boki tries it first
	var at := _open_spot()
	_gather(at)
	var before := _mem_size("A")
	Save.d["gems"] = 500
	var tile := Vector2i(int(at.x), int(at.z))
	home.hb.held = {"id": "rug", "kind": "d", "r": 0, "c": ""}
	home.hb.cells = [tile]
	home.hb.ghost_ok = true
	ok(home.hb.place_held(), "a new toy: you put a picnic rug down")
	var came: Array = ComeLook._looks.map(func(l): return l["k"])
	ok(_names(came) == "ABD", "a new toy: A, B, D come: %s" % _names(came))
	at = Vector3(tile.x + 0.5, 0, tile.y + 0.5)
	var res := _watch(at)
	var near := float(res["stood"].get("A", 9.0))
	ok(near < ComeLook.LOOK_DIST, "a new toy: A (most curious) reaches the toy first (%.1f m)" % near)
	var line := _last_mem("A")
	ok(_mem_size("A") == before + 1 and line.contains("picnic rug"), "a new toy: A keeps '%s'" % line)
	# ------------------------------------------------ you arrive with loot
	_gather(home.ppos)
	Save.d["extracts"] = int(Save.d.get("extracts", 0)) + 1
	before = _mem_size("A")
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)
	ok(ComeLook._looks.size() == 3 and ComeLook._looks[0]["kind"] == "loot", "you home with loot: three come to you")
	res = _watch(home.ppos)
	ok(res["spoke"].size() >= 1 and _mem_size("A") == before + 1 and _last_mem("A").contains("loot"),
		"you home with loot: they chatter and A keeps '%s'" % _last_mem("A"))
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)
	ok(ComeLook._looks.is_empty(), "the same trip is not news twice")
	print("COMELOOK done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
