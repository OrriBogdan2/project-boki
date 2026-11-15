extends RefCounted
## --loot-glow-check: loot in the world shows its rarity (scripts/match/loot_glow.gd). Every rarity tier has a
## look in its own colour; Rare and below get a halo only, Epic and Legendary add a pillar that grows with the tier;
## a drop, a gear shape, a tuning and a deathbox all wear it; no drop carries a flat ground ring or a particle
## node (the VFX particle budget stays untouched); the meshes and materials are shared across drops; and on every
## preset the glow is culled by distance, a Common halo is dropped on Low, and a busy pile stays inside its
## draw budget.

const MAX_PILLAR := 4.0          # m, "short": a marker, not a skybeam
const FIRST_PILLAR := 3          # Epic: the top two tiers get the beam
const PILE := [20, 10, 6, 3, 1]  # a busy fight's drops per tier, Common to Legendary
const BUDGET_PER_DROP := {"low": 1.0, "medium": 1.5, "high": 1.5, "ultra": 1.5}   # glow meshes per drop in the pile

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LOOTGLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var picked: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "high"
	var tiers: int = Data.RARITY.size()
	ok(LootGlow.LOOKS.size() == tiers, "every rarity has a look (%d tiers, %d looks)" % [tiers, LootGlow.LOOKS.size()])
	var cols := {}
	var last_h := 0.0
	var last_a := 0.0
	for r in tiers:
		var nm: String = Data.RARITY[r]["name"]
		var n := Models.gear_drop(Color.WHITE, r)
		var halo := n.get_node_or_null("Halo") as MeshInstance3D
		var pillar := n.get_node_or_null("Pillar") as MeshInstance3D
		var col: Color = Data.RARITY[r]["color"]
		ok(halo != null and _rgb(halo) == col.to_html(false), "%s: a halo in the rarity colour" % nm)
		cols[col.to_html(false)] = true
		var has_pillar: bool = r >= FIRST_PILLAR
		ok((pillar != null) == has_pillar, "%s: pillar %s" % [nm, has_pillar])
		if pillar != null:
			var h: float = (pillar.mesh as CylinderMesh).height
			ok(h > last_h and h <= MAX_PILLAR, "%s: pillar %.1f m, taller than the last, short" % [nm, h])
			ok(pillar.position.y == h * 0.5, "%s: the pillar stands on the ground" % nm)
			last_h = h
		var a: float = (halo.material_override as ShaderMaterial).get_shader_parameter("color").a
		ok(a > last_a, "%s: the halo is brighter than the tier below" % nm)
		last_a = a
		ok(_count(n, "GPUParticles3D") + _count(n, "CPUParticles3D") == 0, "%s: no particles" % nm)
		ok(_flat_rings(n) == 0, "%s: no flat ground ring" % nm)
		var twin := Models.gear_drop(Color.WHITE, r)
		var shared: bool = (twin.get_node("Halo") as MeshInstance3D).material_override == halo.material_override
		ok(shared, "%s: the halo material is shared" % nm)
		for slot in 4:
			var piece := GearModels.drop(slot, Color.WHITE, r)
			ok(piece.get_node_or_null("Halo") != null, "%s: gear slot %d wears it" % [nm, slot])
			piece.free()
		var box := Models.deathbox(Color.WHITE, r)
		var glow := box.get_node("Glow")
		var lit: bool = glow.get_node_or_null("Halo") != null and _flat_rings(box) == 0
		ok(lit, "%s: the deathbox glows, no value ring" % nm)
		for x in [n, twin, box]:
			x.free()
	ok(cols.size() == tiers, "every tier has its own colour")
	ok(LootGlow.tier(-3) == 0 and LootGlow.tier(99) == tiers - 1, "an out-of-range rarity clamps to a look")
	ok(GearModels.tuning(Color.WHITE, true).get_node_or_null("Pillar") != null, "a Brand tuning has a pillar")
	ok(GearModels.tuning(Color.WHITE, false).get_node_or_null("Pillar") == null, "a plain tuning is halo only")
	for q in Settings.QUALITY_ORDER:
		_preset(q)
	var holder := Node3D.new()
	LootGlow.stand_in(holder)
	var stand := holder.get_node("LootGlowStandIn")
	var warm: bool = not (stand as Node3D).visible and stand.get_node_or_null("Pillar") != null
	ok(warm, "a hidden stand-in warms the pillar shader")
	holder.free()
	var mixed := {"gear": [{"rar": 1}], "pack": [{"t": "gear", "rar": 3}, {"t": "val", "id": "old_coin"}]}
	ok(Life.box_rarity(mixed) == 3, "a box shows its best item's rarity")
	ok(Life.box_rarity({}) == 0, "an empty box is the lowest tier")
	Settings.v["quality"] = picked
	print("LOOTGLOW %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## One preset: culling ranges, the Common halo rule, and the glow-mesh budget of a busy pile.
func _preset(q: String) -> void:
	Settings.v["quality"] = q
	var draw := float(Settings.q("draw"))
	var meshes := 0
	var pillars := 0
	var drops := 0
	for r in PILE.size():
		for i in int(PILE[r]):
			var n := Models.gear_drop(Color.WHITE, r)
			var halo := n.get_node_or_null("Halo") as MeshInstance3D
			var pillar := n.get_node_or_null("Pillar") as MeshInstance3D
			if i == 0:
				_look_at(q, r, halo, pillar)
			meshes += [halo, pillar].filter(func(x): return x != null).size()
			pillars += int(pillar != null)
			drops += 1
			n.free()
	var budget: float = BUDGET_PER_DROP[q] * drops
	ok(meshes <= budget, "%s: a pile of %d drops draws %d glow meshes (budget %.0f)" % [q, drops, meshes, budget])
	ok(pillars == int(PILE[3]) + int(PILE[4]), "%s: %d pillars, only on the top two tiers" % [q, pillars])

func _look_at(q: String, r: int, halo: MeshInstance3D, pillar: MeshInstance3D) -> void:
	var tag := "%s, %s" % [q, Data.RARITY[r]["name"]]
	var reach: float = LootGlow.HALO_RANGE * float(Settings.q("draw"))
	var want_halo: bool = r > 0 or float(Settings.q("fx")) >= LootGlow.COMMON_MIN_FX
	ok((halo != null) == want_halo, "%s: halo present %s" % [tag, want_halo])
	ok(halo == null or is_equal_approx(halo.visibility_range_end, reach), "%s: halo culled at %.0f m" % [tag, reach])
	ok(pillar == null or pillar.visibility_range_end > reach, "%s: a pillar outlasts the halo" % tag)

func _rgb(mi: MeshInstance3D) -> String:
	var c: Color = (mi.material_override as ShaderMaterial).get_shader_parameter("color")
	return Color(c.r, c.g, c.b).to_html(false)

func _count(n: Node, cls: String) -> int:
	return n.find_children("*", cls, true, false).size()

func _flat_rings(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).filter(func(mi): return mi.mesh is PlaneMesh).size()
