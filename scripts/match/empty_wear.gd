class_name EmptyWear
extends RefCounted
## The Empty's outfit, worn as layers over the bare void body: top, bottom, shoes, gloves, headwear (look["wear"]),
## a cloak (a Shrouds cut: look["shroud"], "colour", "accent", "hood", "trim") and an accessory (look["accessory"],
## "acc_col"). Every layer can be empty (NONE); each item takes two or three colours from Unmasked.COLOURS. The slot
## list, item names and colour slots are content/rules/empty_creator.json "slots"; EmptyWearKit draws the items.
## The creator reads and sets every slot through item() / colour() and set_item() / set_colour(), whatever the slot
## keeps its data in.

const NONE := -1
const LAYERS := ["top", "bottom", "shoes", "gloves", "head"]      # kept in look["wear"]: [item, colour x 3]
const DRESS_ORDER := ["bottom", "top", "shoes", "gloves", "head"]  # a top hangs over the trousers, boots under them
const COLOURS_PER_ITEM := 3
const VOID_BODY := preload("res://shaders/void_body.gdshader")
const OUTLINE_W := 0.0024           # the bare body's ink line (outline.gdshader), bolder than a Hunter's
const DROP_Z := -0.01               # m: a part in front of the knee's pivot is the knee pad (the bare body has none)
## The skin-side materials Models.hunter gives the body: on the Empty they all become the void.
const SKIN_MATS := ["body", "pants", "skin", "leather", "dark"]
const BARE_BELT := 0.06             # m up the torso: an accessory's belt with no cloak to sit on
const CHEST_Y := 0.38               # m up the torso: where a strap or necklace crosses the chest
const NECK_Y := 0.62                # m up the torso: where a scarf wraps

## The slots in creator order (content/rules/empty_creator.json).
static func slots() -> Array:
	return EmptyFrame.rules()["slots"]

static func slot(id: String) -> Dictionary:
	for s in slots():
		if String(s["id"]) == id:
			return s
	return {}

## The item names a slot offers (not counting empty).
static func items(id: String) -> Array:
	match id:
		"back":
			return Shrouds.LABELS
		"accessory":
			return Shrouds.ACCESSORIES.slice(1)
	return slot(id).get("items", [])

## Nothing worn: every layer empty, its colours at the slot's defaults.
static func bare() -> Dictionary:
	var out := {}
	for id in LAYERS:
		var dflt: Array = slot(id).get("default", [])
		var item_cols: Array = [NONE]
		for k in COLOURS_PER_ITEM:
			item_cols.append(int(dflt[k]) if k < dflt.size() else 0)
		out[id] = item_cols
	return out

## The item worn in a slot (NONE for empty).
static func item(lk: Dictionary, id: String) -> int:
	match id:
		"back":
			return int(lk.get("shroud", NONE))
		"accessory":
			return int(lk.get("accessory", 0)) - 1
	return int(lk["wear"][id][0])

static func set_item(lk: Dictionary, id: String, i: int) -> void:
	var n := items(id).size()
	var at := clampi(i, NONE, n - 1)
	match id:
		"back":
			lk["shroud"] = at
		"accessory":
			lk["accessory"] = at + 1
		_:
			lk["wear"][id][0] = at

## A slot's k-th colour (an index into Unmasked.COLOURS; NONE for the cut's own shade, on a cloak or accessory).
static func colour(lk: Dictionary, id: String, k: int) -> int:
	return int(lk.get(_colour_key(id, k), NONE)) if id in ["back", "accessory"] else int(lk["wear"][id][1 + k])

static func set_colour(lk: Dictionary, id: String, k: int, ci: int) -> void:
	var at := clampi(ci, NONE, Unmasked.COLOURS.size() - 1)
	if id in ["back", "accessory"]:
		lk[_colour_key(id, k)] = at
	else:
		lk["wear"][id][1 + k] = maxi(at, 0)

## The cloak's colours are its cloth and accent, the accessory's its strap and the same accent.
static func _colour_key(id: String, k: int) -> String:
	if k > 0:
		return "accent"
	return "colour" if id == "back" else "acc_col"

## Every outfit value in range (a missing one empty), in place on a look being cleaned.
static func clean_into(out: Dictionary) -> void:
	var src: Variant = out.get("wear")
	var wear := bare()
	for id in LAYERS:
		var got: Variant = src.get(id) if src is Dictionary else null
		if not got is Array:
			continue
		var n := items(id).size()
		for k in mini((got as Array).size(), 1 + COLOURS_PER_ITEM):
			var hi := n - 1 if k == 0 else Unmasked.COLOURS.size() - 1
			wear[id][k] = clampi(_i(got[k], wear[id][k]), NONE if k == 0 else 0, hi)
	out["wear"] = wear
	out["shroud"] = clampi(_i(out.get("shroud"), NONE), NONE, Shrouds.LABELS.size() - 1)
	out["colour"] = clampi(_i(out.get("colour"), 1), 0, Unmasked.COLOURS.size() - 1)
	out["accessory"] = clampi(_i(out.get("accessory"), 0), 0, Shrouds.ACCESSORIES.size() - 1)
	out["trim"] = clampi(_i(out.get("trim"), 0), 0, Shrouds.TRIMS.size() - 1)
	if out.has("hood"):
		out["hood"] = clampi(_i(out["hood"], 0), 0, 1)
	for k in ["accent", "acc_col"]:
		out[k] = clampi(_i(out.get(k), NONE), NONE, Unmasked.COLOURS.size() - 1)

static func _i(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback

## Each slot worn or not at random (about half of them), in random colours.
static func randomise(out: Dictionary) -> void:
	for s in slots():
		var id := String(s["id"])
		var worn := randf() < 0.55
		set_item(out, id, randi() % items(id).size() if worn else NONE)
		for k in (s["cols"] as Array).size():
			set_colour(out, id, k, randi() % Unmasked.COLOURS.size())

# ------------------------------------------------------------------------------------------ on the body
## The bare body made of void (the frame already applied), then each worn layer, then the hair (under any headwear).
static func dress(c: Dictionary, u: Dictionary) -> void:
	var body := void_body(u)
	c["void"] = body
	_bare(c, body)
	var kit := EmptyWearKit.new(c, body)
	for id in DRESS_ORDER:
		var it := item(u, id)
		if it != NONE:
			kit.wear(id, it, _cloth_set(c, u, id))
	_hair(c, u, kit.cover)
	if int(u["acc_col"]) != NONE:
		c["m"]["leather"] = cloth(Unmasked.COLOURS[u["acc_col"]])

## Where an accessory sits (Shrouds' fit): on the cloak's cut, but never inside the clothes or body under it.
static func accessory_fit(c: Dictionary, u: Dictionary) -> Dictionary:
	var fit := EmptyFit.of(EmptyWearKit.torso_parts(c["torso"], null))
	var cut := int(u["shroud"])
	var own: Dictionary = {"chest": 0.0, "waist": 0.0, "belt": BARE_BELT}
	if cut != NONE:
		own = (Shrouds.STYLES[cut]["fit"] as Dictionary).duplicate()
	own["chest"] = maxf(float(own["chest"]), fit.widest(CHEST_Y) + 0.01)
	own["waist"] = maxf(float(own["waist"]), fit.widest(float(own["belt"])) + 0.008)
	own["neck"] = fit.widest(NECK_Y) + 0.012
	return own

## The bare body's material: the void fill in the look's tint, its lit edge and ink line in the outline colour.
static func void_body(u: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOID_BODY
	var line: Color = Unmasked.LINES[u["line"]]
	mat.set_shader_parameter("deep", Unmasked.VOID_TINTS[u["void"]])
	mat.set_shader_parameter("edge", line)
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("color", line)
	ink.set_shader_parameter("width", OUTLINE_W)
	mat.next_pass = ink
	return mat

## A cloth material in this colour, lit like the Hunters' cloth (EmptySlim keeps more of what wears it).
static func cloth(col: Color) -> ShaderMaterial:
	var mat := Models.toon(col)
	mat.set_shader_parameter("rim_amount", 0.75)
	Models.painted(mat, 1, 0.3, 0.3, 0.26)
	mat.set_meta("wear", true)
	return mat

## A layer's three materials, one per colour; a colour another layer already wears shares its material.
static func _cloth_set(c: Dictionary, u: Dictionary, id: String) -> Array:
	var made: Dictionary = c.get("cloth", {})
	c["cloth"] = made
	var out: Array = []
	for k in COLOURS_PER_ITEM:
		var ci := colour(u, id, k)
		if not made.has(ci):
			made[ci] = cloth(Unmasked.COLOURS[ci])
		out.append(made[ci])
	return out

## Every skin-side part of the rig in the void, and the hunter's boot soles, cuffs and knee pads gone.
static func _bare(c: Dictionary, body: Material) -> void:
	var m: Dictionary = c["m"]
	var skin: Array = SKIN_MATS.map(func(k: String) -> Material: return m[k])
	for node in EmptyWearKit.body_nodes(c):
		var drop: Array = []
		for ch in (node as Node3D).get_children():
			var mi := ch as MeshInstance3D
			if mi == null:
				continue
			if _is_gear(node, mi, m):
				drop.append(mi)
			elif mi.material_override in skin:
				mi.material_override = body
		for mi in drop:
			mi.free()

## A hunter's gear on the rig's joints, which the bare body does not have: the boot's sole and cuff and the knee pad
## (on the knee), the glove's cuff (on the hand).
static func _is_gear(node: Node, mi: MeshInstance3D, m: Dictionary) -> bool:
	var mat := mi.material_override
	if node.name == "Knee":
		return mat in [m["dark"], m["trim"], m["steel"]] or (mat == m["leather"] and mi.position.z < DROP_Z)
	return node.name == "Hand" and mat == m["leather"]

## The hair style and colour, cut to fit under the headwear (HeroHair).
static func _hair(c: Dictionary, u: Dictionary, cover: String) -> void:
	var style := int(u["hair"])
	if style == 0:
		return
	var mat := Models.toon(Models.LOOK_HAIR[u["hair_col"]])
	mat.set_shader_parameter("rim_amount", 0.75)
	mat.set_shader_parameter("gloss", 0.35)
	Models.painted(mat, 5, 0.3, 0.24, 0.24)
	var hair := (c["torso"] as Node3D).get_node("Hair") as Node3D
	HeroHair.human(hair, style - 1, bool(c["fem"]), mat, String(c["hk"]), cover)
