class_name Wardrobe
extends RefCounted
## Dress-up for the farm (and the social spaces): hats, clothes and accessories you put on at the
## wardrobe by the house. They only ever show at home. On an expedition your archetype owns your
## silhouette (HeroGear: its headgear, coat and kit, in your outfit's colourway), so nobody can
## dress as a class they aren't; the one thing you can pick for matches here is each archetype's
## colourway (Save.d["look"]["arch_cols"]: colour only, never a shape).
##
## Save.d["wardrobe"] = {owned: [item ids], wear: {hat, top, acc: item id or ""}, col: {item id: palette index}}

const SLOTS := ["hat", "top", "acc"]
const SLOT_NAMES := {"hat": "Hats", "top": "Clothes", "acc": "Accessories"}
const PALETTE := [Color("e0607e"), Color("f2a24a"), Color("f2d06a"), Color("8fd16a"), Color("5ab0f0"), Color("9a7ae0"), Color("f3eee2"), Color("4a4458"), Color("b07a4a")]
## id -> [name, slot, price in gems (0: everyone has it), default colour, blurb]
const ITEMS := {
	"straw_hat": ["Straw hat", "hat", 0, 2, "Wide and sunny, for long days in the field."],
	"beanie": ["Knit beanie", "hat", 0, 4, "Warm, with a bobble on top."],
	"cap": ["Farm cap", "hat", 0, 3, "A cap with a stiff bill."],
	"bucket": ["Bucket hat", "hat", 40, 8, "Soft brim all the way round."],
	"beret": ["Beret", "hat", 50, 0, "Tilted just so."],
	"flower_crown": ["Flower crown", "hat", 60, 5, "Fresh from the garden."],
	"sprout": ["Sprout cap", "hat", 90, 3, "A mushroom cap with a leaf on top."],
	"overalls": ["Overalls", "top", 0, 4, "Bib and braces, ready for work."],
	"apron": ["Garden apron", "top", 0, 8, "Deep pockets for seeds."],
	"sweater": ["Cosy sweater", "top", 40, 1, "A chunky knit with a rolled collar."],
	"hoodie": ["Hoodie", "top", 60, 5, "Hood down, pocket up front."],
	"poncho": ["Poncho", "top", 70, 0, "Striped, for rainy mornings."],
	"waistcoat": ["Waistcoat", "top", 50, 7, "Smart buttons for visiting day."],
	"scarf": ["Scarf", "acc", 0, 0, "Loose ends that flutter."],
	"satchel": ["Satchel", "acc", 30, 8, "A leather bag on a long strap."],
	"glasses": ["Round glasses", "acc", 40, 7, "For reading seed packets."],
	"bowtie": ["Bow tie", "acc", 25, 0, "Very dapper."],
	"hair_flower": ["Hair flower", "acc", 20, 0, "A bloom tucked over one ear."],
	"plush": ["Boki plush", "acc", 120, 4, "A tiny stuffed Boki riding on your shoulder."],
}

static func ensure() -> Dictionary:
	if typeof(Save.d.get("wardrobe")) != TYPE_DICTIONARY:
		Save.d["wardrobe"] = {"owned": [], "wear": {"hat": "", "top": "", "acc": ""}, "col": {}}
	var w: Dictionary = Save.d["wardrobe"]
	for k in ["owned", "wear", "col"]:
		if not w.has(k): w[k] = [] if k == "owned" else {}
	for s in SLOTS:
		if not (w["wear"] as Dictionary).has(s): w["wear"][s] = ""
	return w

static func owns(id: String) -> bool:
	return ITEMS.has(id) and (int(ITEMS[id][2]) == 0 or (ensure()["owned"] as Array).has(id))

static func price(id: String) -> int:
	return int(ITEMS.get(id, ["", "", 0])[2])

## Buys an item with gems. False if you can't afford it (or it's not for sale).
static func buy(id: String) -> bool:
	if not ITEMS.has(id) or owns(id):
		return false
	var p := price(id)
	if int(Save.d.get("gems", 0)) < p:
		return false
	Save.d["gems"] = int(Save.d["gems"]) - p
	(ensure()["owned"] as Array).append(id)
	Save.save_game()
	return true

## Puts on an item (or takes off the slot's item, with id ""). Only items you own.
static func wear(slot: String, id: String) -> bool:
	if id != "" and (not owns(id) or String(ITEMS[id][1]) != slot):
		return false
	ensure()["wear"][slot] = id
	Save.save_game()
	return true

static func set_col(id: String, ci: int) -> void:
	ensure()["col"][id] = clampi(ci, 0, PALETTE.size() - 1)
	Save.save_game()

static func col_of(id: String) -> int:
	return int(ensure()["col"].get(id, ITEMS.get(id, [0, 0, 0, 0])[3]))

## What you're wearing at home: {slot: [item id, colour]} (only items you own).
static func farm_look() -> Dictionary:
	var w := ensure()
	var out := {}
	for s in SLOTS:
		var id := String(w["wear"].get(s, ""))
		if id != "" and owns(id):
			out[s] = [id, PALETTE[col_of(id)]]
	return out

## The appearance for your hunter on the farm and in social spaces: your look plus what you're
## wearing (Models.hunter dresses that instead of the archetype's gear). Never used in a match.
static func farm_appearance() -> Dictionary:
	var lk: Dictionary = (Save.d.get("look", {}) as Dictionary).duplicate()
	lk["farm"] = farm_look()
	lk["farm_on"] = true
	return lk

## Each archetype's colourway in matches (an outfit index, Models.OUTFIT_COLS), or -1 for your look's.
static func arch_col(arch: String) -> int:
	var ac = (Save.d.get("look", {}) as Dictionary).get("arch_cols", {})
	return int(ac.get(arch, -1)) if typeof(ac) == TYPE_DICTIONARY else -1

static func set_arch_col(arch: String, oi: int) -> void:
	if typeof(Save.d.get("look")) != TYPE_DICTIONARY: Save.d["look"] = {}
	var lk: Dictionary = Save.d["look"]
	if typeof(lk.get("arch_cols")) != TYPE_DICTIONARY: lk["arch_cols"] = {}
	if oi < 0: lk["arch_cols"].erase(arch)
	else: lk["arch_cols"][arch] = clampi(oi, 0, Models.OUTFIT_COLS.size() - 1)
	Save.save_game()

## How much hair a farm hat covers (HeroHair): "hat" when one's on.
static func cover(fl: Dictionary) -> String:
	if fl.has("hat") and String(fl["hat"][0]) != "flower_crown":
		return "hat"
	return ""

# ------------------------------------------------------------------------------------------ the models
const HC := Vector3(0, 0.86, 0)

static func _m(col: Color, surface := 1) -> ShaderMaterial:
	var m := Models.toon(col)
	m.set_shader_parameter("rim_amount", 0.75)
	return Models.painted(m, surface, 0.3, 0.3, 0.26)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Models.part(n, mesh, mat, pos, scl, rot)
	return mi

static func _tp(c: Dictionary, key: String, u0: float, u1: float, v0: float, v1: float, off: float, mat: Material, thick := 0.014, bevel := 0.0) -> MeshInstance3D:
	return _p(c["torso"], HeroKit.torso_patch("ward_" + key, c["fem"], u0, u1, v0, v1, off, thick, bevel), mat, Vector3(0, 0.33, 0), Vector3(c["cw"], 1.0, c["bw"] * 0.9))

## Dresses a hunter for the farm (called by Models.hunter in place of the archetype's gear): a belt,
## then each worn item. c is the same context HeroGear.dress gets.
static func dress(c: Dictionary, fl: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	# a simple belt
	var rx := 0.222 * maxf(cw, bw) + 0.01; var rz := 0.214 * bw + 0.008
	_p(t, HeroKit.band("ward_belt|%.3f|%.3f" % [rx, rz], rx, rz, 0.06, 0.014), m["leather"], Vector3(0, 0.1, 0))
	_p(t, Models.box(0.08, 0.065, 0.024), m["gold"], Vector3(0, 0.1, -rz - 0.012))
	for s in SLOTS:
		if not fl.has(s):
			continue
		var id := String(fl[s][0]); var col: Color = fl[s][1]
		var g := Node3D.new(); g.name = "Ward_" + id
		var host: Node3D = c["gear"] if s == "hat" or id in ["glasses", "hair_flower"] else t
		host.add_child(g)
		g.set_meta("stay", true)
		_item(id, col, c, g)

static func _item(id: String, col: Color, c: Dictionary, g: Node3D) -> void:
	var m: Dictionary = c["m"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var mc := _m(col)
	var dark := _m(col.darkened(0.35))
	var light := _m(col.lerp(Color("f3eee2"), 0.55))
	match id:
		"straw_hat":
			var straw := _m(Color("e8c878"), 2)
			_p(g, HeroGear.brim("ward_straw", 0.18, 0.5, 0.05, 0.03, 0.02, 1.05), straw, HC + Vector3(0, 0.15, 0.0), Vector3.ONE, Vector3(-0.08, 0, 0))
			_p(g, Models.lathe(Models.smooth_curve(PackedVector2Array([Vector2(0.0, 0.17), Vector2(0.12, 0.165), Vector2(0.19, 0.12), Vector2(0.21, 0.0), Vector2(0.0, 0.0)]), 2), 22, "ward_strawcrown"), straw, HC + Vector3(0, 0.15, 0.0), Vector3.ONE, Vector3(-0.08, 0, 0))
			_p(g, HeroKit.band("ward_strawband", 0.212, 0.222, 0.05, 0.01), mc, HC + Vector3(0, 0.19, 0.0), Vector3.ONE, Vector3(-0.08, 0, 0))
		"beanie":
			_p(g, Models.sphere(0.25, 20), mc, HC + Vector3(0, 0.08, 0.01), Vector3(1.0, 0.86, 1.05))
			_p(g, HeroKit.band("ward_beaniecuff", 0.245, 0.255, 0.08, 0.03), light, HC + Vector3(0, 0.07, 0.01), Vector3.ONE, Vector3(-0.12, 0, 0))
			_p(g, Models.sphere(0.075, 12), light, HC + Vector3(0, 0.32, 0.03))
		"cap":
			_p(g, Models.sphere(0.24, 20), mc, HC + Vector3(0, 0.1, 0.01), Vector3(1.0, 0.72, 1.05))
			_p(g, HeroKit.dome_plate("ward_capbill", 0.17, 0.35, 0.25, 0.0, 0.02), dark, HC + Vector3(0, 0.1, -0.21), Vector3(1.0, 1.0, 1.25), Vector3(-0.15, 0, 0))
			_p(g, Models.sphere(0.025, 8), dark, HC + Vector3(0, 0.275, 0.0))
		"bucket":
			_p(g, HeroGear.brim("ward_bucket", 0.2, 0.36, -0.06, 0.0, 0.0, 1.05), mc, HC + Vector3(0, 0.14, 0.01), Vector3.ONE, Vector3(-0.06, 0, 0))
			_p(g, Models.cyl(0.19, 0.225, 0.16, 20), mc, HC + Vector3(0, 0.22, 0.01), Vector3(1.0, 1.0, 1.05), Vector3(-0.06, 0, 0))
			_p(g, HeroKit.band("ward_bucketband", 0.215, 0.228, 0.035, 0.008), dark, HC + Vector3(0, 0.17, 0.01), Vector3.ONE, Vector3(-0.06, 0, 0))
		"beret":
			_p(g, Models.sphere(0.27, 20), mc, HC + Vector3(0.04, 0.17, 0.02), Vector3(1.05, 0.38, 1.0), Vector3(0, 0, -0.22))
			_p(g, Models.cyl(0.012, 0.02, 0.05, 6), dark, HC + Vector3(0.06, 0.27, 0.02), Vector3.ONE, Vector3(0, 0, -0.22))
		"flower_crown":
			var leaf := _m(Color("5a9a4f"))
			_p(g, HeroKit.band("ward_crown", 0.235, 0.245, 0.025, 0.02), leaf, HC + Vector3(0, 0.12, 0.01), Vector3.ONE, Vector3(-0.15, 0, 0))
			for k in 9:
				var a := TAU * k / 9.0
				var b := Basis.from_euler(Vector3(-0.15, 0, 0))
				var at := HC + Vector3(0, 0.12, 0.01) + b * Vector3(cos(a) * 0.245, 0.0, sin(a) * 0.255)
				var fc: Color = col if k % 3 != 1 else Color("f3eee2")
				_p(g, Models.sphere(0.04, 8), _m(fc), at + Vector3(0, 0.02, 0), Vector3(1.0, 0.7, 1.0))
				_p(g, Models.sphere(0.015, 6), _m(Color("f2d06a")), at + Vector3(0, 0.045, 0))
		"sprout":
			_p(g, Models.sphere(0.28, 20), mc, HC + Vector3(0, 0.13, 0.01), Vector3(1.0, 0.62, 1.0))
			for k in 6:
				var a := TAU * k / 6.0 + 0.3
				_p(g, Models.sphere(0.045, 8), light, HC + Vector3(cos(a) * 0.17, 0.27, sin(a) * 0.17), Vector3(1.0, 0.45, 1.0))
			var stem := _m(Color("6aa84f"))
			_p(g, Models.cyl(0.012, 0.016, 0.12, 6), stem, HC + Vector3(0, 0.35, 0.0))
			_p(g, HeroKit.lock_mesh("ward_leaf", [Vector3(0, 0, 0), Vector3(0.06, 0.03, 0), Vector3(0.14, 0.02, 0)], 0.07, 0.15, Vector3.UP, 0.9, 0.4), stem, HC + Vector3(0, 0.41, 0.0))
		"overalls":
			_tp(c, "overalls_bib", 0.66, 0.84, 0.32, 0.86, 0.012, mc, 0.014, 0.004)
			_tp(c, "overalls_back", 0.16, 0.34, 0.5, 0.86, 0.012, mc, 0.014, 0.004)
			for sx in [-1.0, 1.0]:
				_p(c["torso"], HeroKit.loft("ward_brace%d" % int(sx), [Vector3(0.09 * sx, 0.4, -0.235), Vector3(0.12 * sx, 0.6, -0.15), Vector3(0.12 * sx, 0.64, 0.0), Vector3(0.1 * sx, 0.58, 0.17), Vector3(0.07 * sx, 0.36, 0.235)], [Vector2(0.024, 0.008), Vector2(0.024, 0.008), Vector2(0.024, 0.008), Vector2(0.024, 0.008), Vector2(0.024, 0.008)], 6, Vector3.UP, 0.9), dark, Vector3.ZERO, Vector3(cw, 1.0, bw))
				_p(c["torso"], Models.sphere(0.018, 8), m["gold"], Vector3(0.09 * sx * cw, 0.4, -0.245 * bw))
			_p(c["torso"], Models.box(0.1, 0.07, 0.012), dark, Vector3(0, 0.3, -0.25 * bw))
			for sx in [-1.0, 1.0]:
				var leg: Node3D = (c["knees"]["L" if sx < 0.0 else "R"] as Node3D).get_parent()
				_p(leg, Models.limb(0.112 * bw, 0.074 * bw, 0.34, 0.16), mc, Vector3(0, -0.12, 0))
		"apron":
			_tp(c, "apron", 0.64, 0.86, 0.45, 1.0, 0.012, mc, 0.014, 0.004)
			_p(c["skirt"], HeroKit.drape("ward_apron|%.3f" % bw, 0.235 * bw, 0.27 * bw, 0.3, 0.64, 0.86, 4.0, 0.02, 0.0, 0.0), mc, Vector3(0, -0.02, 0.0))
			_p(c["skirt"], Models.box(0.16, 0.08, 0.012), dark, Vector3(0, -0.12, -0.27 * bw))
			var rx := 0.222 * maxf(cw, bw) + 0.02; var rz := 0.214 * bw + 0.016
			_p(c["torso"], HeroKit.band("ward_apronstring|%.3f" % rx, rx, rz, 0.03, 0.008), light, Vector3(0, 0.15, 0))
			_p(c["torso"], HeroKit.loft("ward_neckstrap", [Vector3(-0.07, 0.52, -0.22), Vector3(0, 0.66, -0.06), Vector3(0.07, 0.52, -0.22)], [Vector2(0.016, 0.006), Vector2(0.016, 0.006), Vector2(0.016, 0.006)], 6, Vector3.FORWARD, 0.9), light, Vector3.ZERO, Vector3(cw, 1.0, bw))
		"sweater":
			_tp(c, "sweater", 0.0, 1.0, 0.04, 1.0, 0.014, mc, 0.02, 0.0)
			_p(c["torso"], HeroKit.mantle("ward_rollneck", 0.13, 0.13, 0.045, 14.0), light, Vector3(0, 0.64, 0.0))
			for k in 4:
				_p(c["torso"], HeroKit.band("ward_stripe%d|%.3f" % [k, cw], 0.236 * cw, 0.236 * bw * 0.9, 0.018, 0.006), light, Vector3(0, 0.08 + k * 0.035, 0))
		"hoodie":
			_tp(c, "hoodie", 0.0, 1.0, 0.04, 1.0, 0.014, mc, 0.02, 0.0)
			_p(c["torso"], HeroKit.mantle("ward_hooddown", 0.2, 0.19, 0.07, 5.0, 0.4), mc, Vector3(0, 0.6, 0.04))
			_tp(c, "hoodie_pocket", 0.69, 0.81, 0.62, 0.86, 0.03, dark, 0.012, 0.004)
			for sx in [-1.0, 1.0]:
				_p(c["torso"], Models.cyl(0.008, 0.008, 0.14, 4), light, Vector3(0.04 * sx, 0.5, -0.245 * bw))
		"poncho":
			_p(c["torso"], HeroKit.drape("ward_poncho|%.3f" % cw, 0.15 * cw, 0.42 * cw, 0.36, 0.0, 1.0, 6.0, 0.03, 0.0, 0.0, 0.016), mc, Vector3(0, 0.66, 0.0))
			for k in 3:
				var hh := 0.12 + k * 0.1
				var rr := lerpf(0.15, 0.42, hh / 0.36) * cw
				_p(c["torso"], HeroKit.band("ward_ponchostripe%d|%.3f" % [k, cw], rr + 0.012, rr + 0.012, 0.03, 0.006), light if k % 2 == 0 else dark, Vector3(0, 0.66 - hh, 0.0))
		"waistcoat":
			for sx in [-1.0, 1.0]:
				_tp(c, "waistcoat%d" % int(sx), 0.75 + 0.025 * sx if sx > 0 else 0.6, 0.9 if sx > 0 else 0.75 - 0.025, 0.18, 0.86, 0.012, mc, 0.014, 0.004)
			for k in 3:
				_p(c["torso"], Models.sphere(0.014, 8), m["gold"], Vector3(0.0, 0.44 - k * 0.09, -0.245 * bw))
		"scarf":
			_p(c["torso"], HeroKit.mantle("ward_scarf", 0.13, 0.13, 0.05, 8.0), mc, Vector3(0, 0.63, 0.0))
			var sc := Models._pivot(c["torso"], "Scarf", Vector3(0, 0.6, 0.12 * bw))
			_p(sc, HeroKit.lock_mesh("ward_scarftail", [Vector3(0.06, 0.0, 0.0), Vector3(0.09, -0.1, 0.12), Vector3(0.1, -0.28, 0.18)], 0.09, 0.2, Vector3.BACK, 0.8, 0.5), mc)
			_p(sc, HeroKit.lock_mesh("ward_scarftail2", [Vector3(-0.04, 0.0, 0.0), Vector3(-0.05, -0.08, 0.1), Vector3(-0.04, -0.2, 0.15)], 0.08, 0.2, Vector3.BACK, 0.8, 0.5), dark)
		"satchel":
			var strap := [Vector3(0.2, 0.6, -0.12), Vector3(0.02, 0.4, -0.25), Vector3(-0.18, 0.12, -0.21), Vector3(-0.24, 0.04, -0.05)]
			_p(c["torso"], HeroKit.loft("ward_satchelstrap", strap, [Vector2(0.022, 0.008), Vector2(0.024, 0.008), Vector2(0.024, 0.008), Vector2(0.022, 0.008)], 6, Vector3.FORWARD, 0.9), dark, Vector3.ZERO, Vector3(cw, 1.0, bw))
			_p(c["torso"], Models.box(0.08, 0.16, 0.2), mc, Vector3(-0.27 * cw, 0.0, 0.0), Vector3.ONE, Vector3(0, 0, 0.12))
			_p(c["torso"], Models.box(0.085, 0.07, 0.205), dark, Vector3(-0.272 * cw, 0.06, 0.0), Vector3.ONE, Vector3(0, 0, 0.12))
			_p(c["torso"], Models.sphere(0.016, 8), m["gold"], Vector3(-0.32 * cw, 0.04, 0.0))
		"glasses":
			var fr := _m(col.darkened(0.2))
			for sx in [-1.0, 1.0]:
				var ring := TorusMesh.new(); ring.inner_radius = 0.042; ring.outer_radius = 0.052; ring.rings = 20; ring.ring_segments = 6
				_p(g, ring, fr, HC + Vector3(0.075 * sx, 0.015, -0.23), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
				_p(g, Models.cyl(0.006, 0.006, 0.17, 4), fr, HC + Vector3(0.13 * sx, 0.02, -0.15), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
			_p(g, Models.cyl(0.006, 0.006, 0.05, 4), fr, HC + Vector3(0, 0.025, -0.235), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		"bowtie":
			for sx in [-1.0, 1.0]:
				_p(c["torso"], Models.cyl(0.0, 0.045, 0.07, 4), mc, Vector3(0.035 * sx, 0.62, -0.17 * bw), Vector3(1.0, 1.0, 0.45), Vector3(0, 0, -PI * 0.5 * sx))
			_p(c["torso"], Models.sphere(0.022, 8), dark, Vector3(0, 0.62, -0.18 * bw))
		"hair_flower":
			for k in 5:
				var a := TAU * k / 5.0
				_p(g, Models.sphere(0.035, 8), mc, HC + Vector3(0.22, 0.1, -0.02) + Vector3(0, sin(a), cos(a)) * 0.035, Vector3(0.5, 1.0, 1.0))
			_p(g, Models.sphere(0.022, 8), _m(Color("f2d06a")), HC + Vector3(0.235, 0.1, -0.02))
		"plush":
			var pl := Node3D.new(); pl.name = "Plush"; pl.position = Vector3(-0.27 * cw, 0.62, 0.02)
			c["torso"].add_child(pl)
			pl.set_meta("stay", true)
			_p(pl, Models.sphere(0.09, 12), mc, Vector3(0, 0.06, 0), Vector3(1.0, 0.9, 1.0))
			_p(pl, Models.sphere(0.07, 12), mc, Vector3(0, 0.17, -0.02))
			for sx in [-1.0, 1.0]:
				_p(pl, Models.cyl(0.0, 0.03, 0.08, 6), dark, Vector3(0.04 * sx, 0.25, -0.02), Vector3.ONE, Vector3(0, 0, -0.3 * sx))
				_p(pl, Models.sphere(0.012, 6), Models.toon(Color("2b2a33")), Vector3(0.025 * sx, 0.18, -0.085))
