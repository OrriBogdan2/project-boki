extends RefCounted
## --nest-items-check (GARDEN_MODERN.md 1.2 items 26-29): the nest items. For each item, 500 seeded eggs
## (laid with NestItems.lay, hatched with Care.breed + NestItems.hatched, as home.gd does) show exactly the
## stated inheritance: Heirloom Thread 4 inborn gifts (two Threads: 5, none: 3), Likeness Locket the wearer's
## species, Lullaby Shell the wearer's habit and strongest trait to the digit, Hatchling Down one per hatch
## and trust +3 with a memory line when fed. Items are used up when the egg is laid; the Nook preview
## names each effect. Never touches the real save.

const EGGS := 500

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("NESTITEMS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _parents(rng: RandomNumberGenerator, i: int) -> Array:
	var kin: Array = Data.common_kin()
	var out: Array = []
	for j in 2:
		var r := Save.new_kin(String(kin[(i + j) % kin.size()]), "P%d%d" % [i, j])
		r["level"] = 8
		r["ivs"] = Care.roll_ivs(rng)
		for t in r["traits"]:
			r["traits"][t] = rng.randf_range(0.1, 0.9)
		r["dna"]["quirk"] = String(Unique.QUIRK_NAMES.keys()[rng.randi() % Unique.QUIRK_NAMES.size()])
		out.append(r)
	return out

## Lay an egg with the items placed, hatch it on seed i: [egg, baby].
func _egg(a: Dictionary, b: Dictionary, i: int) -> Array:
	var egg := {}
	NestItems.lay(egg, a, b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + i
	var baby := Care.breed(a, b, rng, String(egg.get("sp", "")), NestItems.inherit_n(egg))
	NestItems.hatched(baby, egg, a, b)
	return [egg, baby]

func _has_habit(baby: Dictionary, parent: Dictionary, top: String) -> bool:
	return baby["dna"]["quirk"] == parent["dna"]["quirk"] and float(baby["traits"][top]) == float(parent["traits"][top])

func _stock(thread: int, locket: int, shell: int) -> void:
	Save.d["items"]["heirloom_thread"] = thread
	Save.d["items"]["likeness_locket"] = locket
	Save.d["items"]["lullaby_shell"] = shell
	Save.d[NestItems.SET_KEY] = {}

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_rules()
	_threads()
	_locket()
	_shell()
	_down()
	_rows()
	_old_save()
	print("NESTITEMS done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _rules() -> void:
	var ids := ["heirloom_thread", "likeness_locket", "lullaby_shell", "hatchling_down"]
	var fine := true
	for id in ids:
		fine = fine and GardenItems.has(id) and not (GardenItems.item(id)["sources"] as Array).is_empty()
	ok(fine, "the four nest items are in content/rules/garden_items.json with sources")
	var shell_try := GardenItems.preview(Save.new_kin("cindle", "T"), "lullaby_shell")
	ok(not GardenItems.fed("heirloom_thread") and not shell_try["ok"], "Thread, Locket and Shell are placed, not fed")

func _threads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for n in [0, 1, 2]:
		var exact := 0
		var copied := 0
		var spent := 0
		for i in EGGS:
			var p := _parents(rng, i)
			_stock(2, 0, 0)
			NestItems.add_threads(n)
			var line: Array = NestItems.preview_lines(p[0], p[1])
			var res := _egg(p[0], p[1], i)
			var baby: Dictionary = res[1]
			var from: Dictionary = baby["iv_from"]
			var want := "%d of 5 gifts from parents" % (3 + n)
			var said: bool = n == 0 or (line.size() == 1 and line[0].begins_with(want))
			exact += int(from.size() == 3 + n and said)
			var same := true
			for k in from:
				same = same and int(baby["ivs"][k]) == int(Care.ivs(p[int(from[k])])[k])
			copied += 1 if same else 0
			spent += 2 - int(Save.d["items"]["heirloom_thread"])
		ok(exact == EGGS, "%d Thread(s): %d of %d eggs take exactly %d of 5 gifts, previewed" % [n, exact, EGGS, 3 + n])
		ok(copied == EGGS and spent == n * EGGS, "%d Thread(s): gifts equal the parent's, %d used up per egg" % [n, n])

func _locket() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var worn := 0
	var from_a := 0
	var used := 0
	for i in EGGS:
		var p := _parents(rng, i)
		var wearer: Dictionary = p[i % 2]
		_stock(0, 1, 0)
		NestItems.wear("species", String(wearer["uid"]))
		var line: Array = NestItems.preview_lines(p[0], p[1])
		var baby: Dictionary = _egg(p[0], p[1], i)[1]
		var named: bool = line.size() == 1 and line[0].contains(Data.KIN[wearer["species"]]["name"])
		worn += int(baby["species"] == wearer["species"] and named)
		used += 1 - int(Save.d["items"]["likeness_locket"])
		_stock(0, 0, 0)
		from_a += 1 if _egg(p[0], p[1], i)[1]["species"] == p[0]["species"] else 0
	ok(worn == EGGS and used == EGGS, "Locket: %d of %d babies are the wearer's species, one used each" % [worn, EGGS])
	ok(from_a > EGGS / 4 and from_a < EGGS * 3 / 4, "without a Locket it is about 50/50 (%d of %d)" % [from_a, EGGS])

func _shell() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var exact := 0
	var plain := 0
	var used := 0
	for i in EGGS:
		var p := _parents(rng, i)
		var wearer: Dictionary = p[i % 2]
		var top := NestItems.top_trait(wearer)
		_stock(0, 0, 1)
		NestItems.wear("habit", String(wearer["uid"]))
		var line: Array = NestItems.preview_lines(p[0], p[1])
		var baby: Dictionary = _egg(p[0], p[1], i)[1]
		var habit := Unique.quirk_name(wearer).to_lower()
		var named: bool = line.size() == 1 and line[0].contains(habit) and line[0].contains(top)
		exact += int(_has_habit(baby, wearer, top) and named)
		used += 1 - int(Save.d["items"]["lullaby_shell"])
		_stock(0, 0, 0)
		plain += int(_has_habit(_egg(p[0], p[1], i)[1], wearer, top))
	ok(exact == EGGS and used == EGGS, "Shell: %d of %d babies have the wearer's habit and top trait" % [exact, EGGS])
	ok(plain < EGGS / 10, "without a Shell that exact match is rare (%d of %d)" % [plain, EGGS])

func _down() -> void:
	Save.d = Save.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	for i in EGGS:
		var baby := Save.new_kin("cindle", "Baby%d" % i)
		NestItems.drop_down(baby)
	var downs := int(Save.d["items"]["hatchling_down"])
	ok(downs == EGGS, "one Hatchling Down per hatch: %d hatches, %d in the bag" % [EGGS, downs])
	var exact := 0
	for i in EGGS:
		var rec := Save.new_kin("zapple", "Eater")
		var trust := float(rng.randi_range(0, 96))
		rec["trust"] = trust
		var text := String(GardenItems.preview(rec, "hatchling_down")["text"])
		var res := Care.feed(rec, "hatchling_down")
		var mem: String = String(rec["memory"].back()["text"])
		var baby_name := "Baby%d" % i
		var said: bool = mem == "remembers %s's hatching" % baby_name and text.contains(baby_name)
		said = said and text.contains("+3")
		exact += int(res["ok"] and float(rec["trust"]) == trust + 3.0 and said)
	ok(exact == EGGS, "fed to a Boki: trust +3 exactly and a memory line per baby in turn (%d of %d)" % [exact, EGGS])
	var full := Save.new_kin("zapple", "Full")
	full["trust"] = 100.0
	ok(not Care.feed(full, "hatchling_down")["ok"] and float(full["trust"]) == 100.0, "at full trust it is not used")

func _rows() -> void:
	var p := _parents(RandomNumberGenerator.new(), 3)
	var box := VBoxContainer.new()
	NestItemRows.add(box, p[0], p[1], func(): pass)
	ok(box.get_child_count() == 0, "the Nook shows no nest rows without nest items in the bag")
	_stock(2, 1, 1)
	NestItems.wear("species", String(p[1]["uid"]))
	NestItemRows.add(box, p[0], p[1], func(): pass)
	ok(box.get_child_count() == 1 + 3 + 1, "with items: heading, three rows, the placed Locket line")
	box.free()

func _old_save() -> void:
	Save.d = Save.fresh()
	Save.d.erase(NestItems.SET_KEY)
	Save.d.erase(NestItems.DOWN_NAMES)
	var p := _parents(RandomNumberGenerator.new(), 1)
	var egg := {}
	NestItems.lay(egg, p[0], p[1])
	var plain: bool = NestItems.plan(p[0], p[1])["inherit"] == Care.IV_INHERIT
	plain = plain and NestItems.inherit_n({}) == Care.IV_INHERIT
	ok(plain and not egg.has("habit") and not egg.has("sp"), "a save from before nest items: no placement, 3 gifts")
	ok(NestItems.take_memory() == "remembers a hatching", "a Down with no name recorded still gives a memory line")
