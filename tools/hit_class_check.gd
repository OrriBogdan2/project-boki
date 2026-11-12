extends RefCounted
## --hit-class-check: what a hit landed on decides its look (HitClass, the one place that decides).
##  1. The class: armour beats everything, a Boki is BOKI, any monster (even a boss) MONSTER, a
##     Hunter BODY, and a shot with no target (wall or terrain) WALL.
##  2. The colour: the armour tier's, the Boki's type's, the monster's hide_col.
##  3. Each class draws within the pools (one spray, at most one flash, no ring) and the body class
##     is a flash and nothing else; a wall hit is dust only.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HITCLASS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var hunter := Hunter.new()
	var kin := Kin.new()
	kin.sp = {"type": "venom"}
	var mob := Mob.new()
	mob.mkind = "brute"
	var boss := Boss.new()
	ok(HitClass.of(hunter, false) == HitClass.BODY, "a Hunter without armour: body")
	ok(HitClass.of(hunter, true) == HitClass.ARMOUR, "a Hunter's armour: armour")
	ok(HitClass.of(kin, false) == HitClass.BOKI, "a Boki: boki")
	var monsters := HitClass.of(mob, false) == HitClass.MONSTER and HitClass.of(boss, false) == HitClass.MONSTER
	ok(monsters, "monsters and bosses: monster")
	ok(HitClass.of(mob, true) == HitClass.ARMOUR, "armour on anything: armour")
	ok(HitClass.of(null, false) == HitClass.WALL, "no target: wall")
	var fall := Color.MAGENTA
	ok(HitClass.tint(hunter, HitClass.ARMOUR, fall) == hunter.armor_col(), "armour paints in the armour tier colour")
	ok(HitClass.tint(kin, HitClass.BOKI, fall) == DexView.type_col("venom"), "a Boki puffs in its type colour")
	var hide_col: Color = Data.MOBS["brute"]["color"]
	ok(HitClass.tint(mob, HitClass.MONSTER, fall) == hide_col, "a monster sparks in its hide colour")
	ok(HitClass.tint(hunter, HitClass.BODY, fall) == fall, "a body keeps the hit colour")
	var fx := Fx.new()
	main.add_child(fx)
	await main.get_tree().process_frame
	for cls in [HitClass.BODY, HitClass.ARMOUR, HitClass.BOKI, HitClass.MONSTER, HitClass.WALL]:
		_look(fx, cls)
	for n in [hunter, kin, mob, boss, fx]:
		n.free()
	print("HITCLASS DONE, failures: %d" % bad)
	main.get_tree().quit()

func _look(fx: Fx, cls: int) -> void:
	var s0 := fx.si
	var b0 := fx.bi
	var f0 := fx.fi
	var r0 := fx.rings.size()
	HitClass.draw(fx, cls, Vector3(0, 1, 0), Vector3.FORWARD, Color.WHITE, 3.0, true)
	var sprays := (fx.si - s0) + (fx.bi - b0)
	var flashes := fx.fi - f0
	var no_ring := fx.rings.size() == r0
	ok(sprays <= 1 and flashes <= 1 and no_ring, "class %d: %d spray, %d flash, no ring" % [cls, sprays, flashes])
	if cls == HitClass.BODY:
		ok(sprays == 0 and flashes == 1, "body: the hit flash only")
	if cls == HitClass.WALL:
		ok(fx.bi - b0 == 1 and flashes == 0, "wall: dust only")
