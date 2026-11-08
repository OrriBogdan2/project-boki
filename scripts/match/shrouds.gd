class_name Shrouds
extends RefCounted
## The Empty's shrouds: ten cuts with different silhouettes, a hood where the cut has one, a trim
## pattern, an accent colour and an accessory. All of it is procedural (HeroKit shells) and costs no texture: the
## cloth takes the shroud colour from Models.hunter and the trim takes the accent colour.
##
## The creator wires rows from this file alone. Each look key below is optional; a missing or bad value falls back
## to the style's default (Shrouds.settings), so old saves keep working:
##   look["shroud"]     index into STYLES (0 Hooded Cloak, 1 Wrap and 2 Tatters are the old Cloak, Wrap and Tatters)
##   look["hood"]       0 down, 1 up; only where has_hood(style)
##   look["trim"]       index into TRIMS
##   look["accent"]     -1 for a shade of the shroud colour, else index into Unmasked.COLOURS
##   look["accessory"]  index into ACCESSORIES
## ROWS has these in Unmasked.ROWS's format, without the shroud and accent rows' swatches decided.

## One entry per cut, in save order: append only. hood: -1 the cut has no hood, 0 it starts down, 1 it starts up.
## fit: where a worn accessory sits on this cut (chest: m in front of the spine at the ribs, waist: the belt's
## radius, belt: the belt's height on the torso).
const STYLES := [
	{"id": "hooded_cloak", "name": "Hooded Cloak", "hood": 1, "fit": {"chest": 0.31, "waist": 0.36, "belt": 0.06}},
	{"id": "wrap", "name": "Wrap", "hood": -1, "fit": {"chest": 0.2, "waist": 0.215, "belt": 0.06}},
	{"id": "tatters", "name": "Tatters", "hood": 0, "fit": {"chest": 0.25, "waist": 0.27, "belt": 0.06}},
	{"id": "long_coat", "name": "Long Coat", "hood": -1, "fit": {"chest": 0.235, "waist": 0.235, "belt": 0.04}},
	{"id": "poncho", "name": "Poncho", "hood": 0, "fit": {"chest": 0.33, "waist": 0.3, "belt": 0.02}},
	{"id": "robe_sash", "name": "Robe & Sash", "hood": 0, "fit": {"chest": 0.27, "waist": 0.35, "belt": 0.14}},
	{"id": "mantle_cape", "name": "Mask Cape", "hood": -1, "fit": {"chest": 0.23, "waist": 0.225, "belt": 0.04}},
	{"id": "shawl_scarf", "name": "Shawl & Scarf", "hood": -1, "fit": {"chest": 0.25, "waist": 0.25, "belt": 0.04}},
	{"id": "cowl_feathers", "name": "Cowl & Feathers", "hood": 0, "fit": {"chest": 0.28, "waist": 0.26, "belt": 0.04}},
	{"id": "patchwork", "name": "Patchwork", "hood": 1, "fit": {"chest": 0.27, "waist": 0.3, "belt": 0.1}},
]
## STYLES' names, for Unmasked.SHROUDS (a const list: the creator's row reads it).
const LABELS := ["Hooded Cloak", "Wrap", "Tatters", "Long Coat", "Poncho", "Robe & Sash", "Mask Cape",
	"Shawl & Scarf", "Cowl & Feathers", "Patchwork"]
const HOODS := ["Down", "Up"]
const TRIMS := ["Plain", "Stitched", "Runes", "Stripes", "Embroidered"]
const ACCESSORIES := ["None", "Belt pouches", "Satchel strap", "Charm necklace", "Lantern hook", "Bandolier"]
## Extra creator rows, as Unmasked.ROWS has them: look key, label, choices, and a tooltip. Hood applies only where
## has_hood(look["shroud"]). The accent is -1 or a colour, so a row for it adds "Match shroud" before COLOURS.
const ROWS := [
	["hood", "Hood", HOODS, "Only where the shroud has one"],
	["trim", "Trim", TRIMS],
	["accessory", "Accessory", ACCESSORIES],
]
const NO_ACCENT := -1

static func has_hood(style: int) -> bool:
	return int(_style(style)["hood"]) >= 0

static func _style(style: int) -> Dictionary:
	return STYLES[clampi(style, 0, STYLES.size() - 1)]

## The shroud part of a look with every value in range and each missing one at its default.
static func settings(lk: Dictionary) -> Dictionary:
	var style := clampi(_i(lk.get("shroud"), 0), 0, STYLES.size() - 1)
	var dflt := int(STYLES[style]["hood"])
	var hood := -1 if dflt < 0 else clampi(_i(lk.get("hood"), dflt), 0, 1)
	var accent := clampi(_i(lk.get("accent"), NO_ACCENT), NO_ACCENT, Unmasked.COLOURS.size() - 1)
	return {"style": style, "hood": hood, "trim": clampi(_i(lk.get("trim"), 0), 0, TRIMS.size() - 1), "accent": accent,
		"accessory": clampi(_i(lk.get("accessory"), 0), 0, ACCESSORIES.size() - 1)}

static func _i(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float or v is String else fallback

## Puts the shroud on a body: Unmasked.dress calls it with Models.hunter's parts. The cloth is one skinned mesh per
## tone under a ShroudSkin, the pieces that ride a single joint (wraps, hood, accessories) are parts of that joint.
static func dress(c: Dictionary, lk: Dictionary) -> void:
	var set_ := settings(lk)
	var t := ShroudTailor.new(c, set_)
	t.bulk = float(Unmasked.race(lk)["bulk"])
	ShroudCuts.cut(t, int(set_["style"]), int(set_["hood"]) == 1)
	ShroudExtras.trim(t, int(set_["trim"]))
	ShroudExtras.accessory(t, int(set_["accessory"]), STYLES[set_["style"]]["fit"])
	t.finish()

## The finished model's rest pose, for the bones: Models.hunter calls it once the body is at its final proportions.
static func bind(model: Node3D) -> void:
	var skin := model.get_node_or_null("Rig/Torso/ShroudBones") as ShroudSkin
	if skin:
		skin.bind(model.get_node("Rig"))
	EmptySlim.apply(model)
