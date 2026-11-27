extends RefCounted
## --wardrobe-check: the Empty's earned clothes (scripts/match/wardrobe.gd, content/rules/wardrobe.json) and the
## frame's added sliders. Every slot has pieces, every old cloak and accessory has one, no piece carries a stat; a
## new Empty is bare; the first-day list puts the first piece on; play (expeditions, stats, clan, garden, mastery)
## earns the rest, a new piece goes on only in an empty slot; an old save keeps its outfit as a starter set (and
## nothing else goes on); worn pieces draw as cloth on the body, a hood, a scarf; the Wardrobe tab wears an earned
## piece and refuses a locked one; each added slider changes the built body.

const ALLOWED := [
	"id", "slot", "name", "earn", "how", "sleeves", "length", "boots", "col", "up", "peak", "flop", "cut", "kind"
]

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("WARDROBE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	_data()
	_new_empty()
	_earning()
	_old_save()
	_drawing()
	_sliders()
	await _locker()
	print("WARDROBE_CHECK %s" % ("FAILED %d" % bad if bad > 0 else "PASSED"))
	main.get_tree().quit(1 if bad > 0 else 0)


func _data() -> void:
	var all: Array = Wardrobe.rules()["pieces"]
	var ids := {}
	for p in all:
		ids[p["id"]] = true
	ok(ids.size() == all.size(), "piece ids are unique (%d pieces)" % all.size())
	for slot in Wardrobe.SLOTS:
		ok(Wardrobe.pieces(slot).size() >= 2, "slot %s has earnable pieces" % slot)
	var extra: Array = all.filter(func(p: Dictionary) -> bool: return p.keys().any(func(k): return not k in ALLOWED))
	ok(extra.is_empty(), "cosmetic only: no piece has any other field (%s)" % str(extra))
	var cuts: Array = Wardrobe.pieces("back").map(func(p: Dictionary) -> int: return int(p["cut"]))
	var kinds: Array = Wardrobe.pieces("accessory").map(func(p: Dictionary) -> int: return int(p["kind"]))
	ok(
		(
			range(Shrouds.STYLES.size()).all(func(i: int) -> bool: return cuts.has(i))
			and range(1, Shrouds.ACCESSORIES.size()).all(func(i: int) -> bool: return kinds.has(i))
		),
		"every cloak cut and accessory an old save can wear is a piece"
	)


func _model(lk: Dictionary) -> Node3D:
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", lk)
	main.add_child(m)
	return m


## The materials on a rig node's own meshes that are not the void.
func _cloth_on(m: Node3D, path: String) -> int:
	var n := 0
	for ch in m.get_node(path).get_children():
		var mi := ch as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			if (mi.material_override as ShaderMaterial).shader != EmptyVoid.VOID_BODY:
				n += 1
	return n


func _new_empty() -> void:
	Save.d = Save.fresh()
	var u := Unmasked.clean(Save.d.get("look", {}))
	var m := _model(u)
	ok(
		u["shroud"] == Shrouds.NONE and m.get_node_or_null("Rig/Torso/ShroudBones") == null,
		"a new Empty is bare: no cloak"
	)
	ok(_cloth_on(m, "Rig/Legs/LegL") == 0 and Save.d["wardrobe"]["owned"].is_empty(), "and no clothes, none owned")
	m.free()
	Save.d["look"] = u
	Save.d["roster"] = [{"level": 1}]
	GardenFirstDay.mark("feed")
	var lk: Dictionary = Save.d["look"]
	ok(
		Wardrobe.owned("plain_tunic") and lk["wear"].get("top") == "plain_tunic",
		"feeding your Boki on day one: a tunic, worn"
	)
	ok(Save.d["wardrobe"].get("news", []) == ["Plain Tunic"], "and it is waiting to be announced")


func _earning() -> void:
	var c := ClassUnlock.state()
	c["stats"]["extracts"] = 5
	c["stats"]["chests"] = 10
	Save.d["guild_perks"] = ["hall"]
	Save.d["zones"] = {"a": {"open": true}, "b": {"open": true}}
	c["hunters"]["gunslinger"] = {"far_hits": 30, "revives": 2}
	Wardrobe.refresh()
	var want := [
		"hooded_cloak", "wrapped_soles", "field_boots", "wrap", "belt_pouches", "long_coat", "field_hood", "long_scarf"
	]
	ok(
		want.all(func(id: String) -> bool: return Wardrobe.owned(id)),
		(
			"expeditions, chests, a clan hall, garden zones and Vex mastery earn their pieces (%s)"
			% str(Save.d["wardrobe"]["owned"])
		)
	)
	ok(not Wardrobe.owned("patchwork") and not Wardrobe.owned("neck_scarf"), "and nothing that is not done yet")
	var wear: Dictionary = Save.d["look"]["wear"]
	ok(wear["top"] == "plain_tunic" and wear["back"] == "hooded_cloak", "a new piece goes on only in an empty slot")
	var u := Unmasked.clean(Save.d["look"])
	ok(u["shroud"] == 0 and u["accessory"] == 1, "a worn cloak and accessory are the look's shroud and accessory")


func _old_save() -> void:
	var data := Save.fresh()
	data.erase("wardrobe")
	data["look"] = {"unmasked": true, "gender": 0, "shroud": 3, "accessory": 2, "colour": 6, "hood": 0}
	Save.d = data
	ClassUnlock.state()["stats"]["extracts"] = 20
	Unmasked.migrate(data)
	var once := data.duplicate(true)
	Unmasked.migrate(data)
	var lk: Dictionary = data["look"]
	ok(
		(
			lk["wear"] == {"back": "long_coat", "accessory": "satchel_strap"}
			and lk["shroud"] == 3
			and lk["accessory"] == 2
		),
		"an old save keeps the cloak and accessory it wore (%s)" % str(lk["wear"])
	)
	ok(
		Wardrobe.owned("long_coat") and Wardrobe.owned("field_boots") and not lk["wear"].has("feet"),
		"owns them, and what it had already earned, without anything else put on"
	)
	ok(data == once, "migrating twice changes nothing")


func _drawing() -> void:
	var lk := Unmasked.default_look()
	lk["wear"] = {"top": "long_shirt", "bottom": "plain_trousers", "feet": "field_boots", "head": "field_hood"}
	var m := _model(lk)
	ok(_cloth_on(m, "Rig/Torso") >= 2, "a top and a bottom are cloth on the torso and hips")
	ok(_cloth_on(m, "Rig/Legs/LegL/Knee") >= 2, "long trousers and boots cover the knee and the shin (with a sole)")
	var bones := m.get_node_or_null("Rig/Torso/ShroudBones")
	ok(bones != null, "a hood alone goes on the bare body")
	m.free()
	lk["wear"] = {"top": "plain_tunic"}
	m = _model(lk)
	var sleeve := m.find_child("Elbow", true, false)
	ok(
		_cloth_on(m, "Rig/Torso") >= 1 and _cloth_on(m, String(m.get_path_to(sleeve))) == 0,
		"a tunic leaves the arms bare"
	)
	m.free()
	lk["wear"] = {"accessory": "neck_scarf"}
	m = _model(lk)
	ok(m.get_node_or_null("Rig/Torso/ShroudBones") != null, "a scarf goes on the bare body")
	m.free()


## A measure of the built body: the legs' hip height, an upper arm's and a thigh's width (their merged meshes).
func _measure(lk: Dictionary) -> Array:
	var m := _model(lk)
	var out := [m.get_meta("hip_y"), _width(m.get_node("Rig/Torso/ArmLPivot")), _width(m.get_node("Rig/Legs/LegL"))]
	m.free()
	return out


func _width(joint: Node) -> float:
	var w := 0.0
	for ch in joint.get_children():
		if ch is MeshInstance3D:
			w = maxf(w, (ch as MeshInstance3D).get_aabb().size.x)
	return w


func _sliders() -> void:
	for sex in 2:
		var lo := _measure({"unmasked": true, "gender": sex, "frame": {"arms": 0.0, "legs": 0.0, "tone": 0.0}})
		var hi := _measure({"unmasked": true, "gender": sex, "frame": {"arms": 1.0, "legs": 1.0, "tone": 1.0}})
		var tag: String = Unmasked.SEXES[sex]
		ok(hi[0] > lo[0] * 1.05, "%s: leg length lifts the hips (%.3f to %.3f m)" % [tag, lo[0], hi[0]])
		ok(hi[1] > lo[1] * 1.1, "%s: arms and tone thicken the upper arms (%.3f to %.3f m)" % [tag, lo[1], hi[1]])
		ok(hi[2] > lo[2] * 1.05, "%s: tone thickens the thighs (%.3f to %.3f m)" % [tag, lo[2], hi[2]])
		var slim := Unmasked.figure(sex == 0, EmptyFrame.factor({"gender": sex, "frame": {"waist": 0.0}}, "waist"))
		var wide := Unmasked.figure(sex == 0, EmptyFrame.factor({"gender": sex, "frame": {"waist": 1.0}}, "waist"))
		var flat := Unmasked.figure(sex == 0, 1.0, EmptyFrame.factor({"gender": sex, "frame": {"chest": 0.0}}, "chest"))
		var full := Unmasked.figure(sex == 0, 1.0, EmptyFrame.factor({"gender": sex, "frame": {"chest": 1.0}}, "chest"))
		ok(slim != wide and flat != full, "%s: waist and chest reshape the torso" % tag)
		ok(full.get_aabb().size.z > flat.get_aabb().size.z, "%s: a fuller chest is deeper" % tag)
	var neutral := {"gender": 0, "frame": {}}
	ok(
		["waist", "chest", "arms", "legs", "tone"].all(
			func(k: String) -> bool: return is_equal_approx(EmptyFrame.factor(neutral, k), 1.0)
		),
		"the added sliders are 1.0 at neutral, so an older body keeps its shape"
	)


func _locker() -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"]["intro"] = true
	Save.d["wardrobe"]["owned"] = ["plain_tunic"]
	Save.d["look"] = Unmasked.default_look()
	LookLocker.open_on = "Wardrobe"
	var hx: Node = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	for i in 3:
		await main.get_tree().process_frame
	var locker: LookLocker = hx.locker
	ok(locker.tab == "Wardrobe" and LookLocker.open_on == "", "the farm menu's Wardrobe opens the locker on its tab")
	var tiles: Array = hx.root_ui.find_children("*", "Control", true, false).filter(
		func(c: Node) -> bool: return String(c.get_meta("look_opt", "")).begins_with(LookLocker.WEAR)
	)
	ok(tiles.size() == Wardrobe.rules()["pieces"].size() + Wardrobe.SLOTS.size(), "a tile per piece, and None per slot")
	locker.pick(LookLocker.WEAR + "back", "hooded_cloak")
	ok(not locker.look["wear"].has("back"), "a locked piece does not go on")
	locker.pick(LookLocker.WEAR + "top", "plain_tunic")
	ok(locker.look["wear"].get("top") == "plain_tunic", "an earned one does")
	locker.pick(LookLocker.WEAR + "top", "")
	ok(not locker.look["wear"].has("top"), "and None takes it off")
	hx.free()
