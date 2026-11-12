class_name EmptyFrame
extends RefCounted
## The Empty's body frame: five sliders (height, build, shoulders, hips, head size), each 0..1 and mapped onto the
## range its sex allows (content/rules/empty_creator.json "frame"). A woman's frame is shorter, narrower in the
## shoulders and wider in the hips than any man's, so the two read apart at a glance whatever the sliders say,
## and no slider leaves the range the outfits are built for. Applied to the hunter rig by shape().

const RULES_PATH := "res://content/rules/empty_creator.json"
const KEYS := ["height", "build", "shoulders", "hips", "head"]
const NEUTRAL := 0.5
const STEP := 0.001                 # sliders are saved to this step, so a save reads back the same body
const BULK_PER_WIDTH := 0.85        # a wider build also thickens the limbs and torso, this much as fast
const CHEST_PER_SHOULDER := 0.6     # the chest follows the shoulders' spread this much (the rest is the arms)
const ARM_THIN_F := Vector3(0.8, 1.0, 0.8)      # a woman's arms and legs, thinner than a man's at the same build
const LEG_THIN_F := Vector3(0.9, 1.0, 0.9)
const HIPS_Y := 0.02                # m up the torso: where Models.hunter puts the hips

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {"frame": {}, "slots": [], "presets": {}}
	return _rules

## Every slider in 0..1 at the saved step, a missing or bad one neutral.
static func clean(frame: Variant) -> Dictionary:
	var src: Dictionary = frame if frame is Dictionary else {}
	var out := {}
	for k in KEYS:
		var v: Variant = src.get(k, NEUTRAL)
		var f := float(v) if v is float or v is int else NEUTRAL
		out[k] = snappedf(clampf(f, 0.0, 1.0), STEP)
	return out

## An old Empty's Short / Average / Tall height and Slight / Average / Sturdy build as slider values.
static func from_steps(height: int, build: int) -> Dictionary:
	var at := [0.15, NEUTRAL, 0.85]
	var out := clean({})
	out["height"] = at[clampi(height, 0, 2)]
	out["build"] = at[clampi(build, 0, 2)]
	return out

## The factor a slider gives this body: its value mapped onto the sex's [lo, hi].
static func factor(lk: Dictionary, key: String) -> float:
	var span: Array = rules()["frame"][key]["f" if int(lk.get("gender", 1)) == 0 else "m"]
	var v := float(clean(lk.get("frame"))[key])
	return lerpf(float(span[0]), float(span[1]), v)

## The body's width (Models.hunter's build).
static func width(lk: Dictionary) -> float:
	return factor(lk, "build")

## How much thicker the limbs and torso are (the race bulk Models.hunter reads).
static func bulk(lk: Dictionary) -> float:
	return 1.0 + (width(lk) - 1.0) * BULK_PER_WIDTH

## Female and male frames on the built rig (before the outfits go on): the shoulders' spread, the hips' width and
## the stance (content/rules/warden_stance.json "empty_f", "empty_m", read by HunterAnim through the "stance" meta).
## Height, build and head size are set by Models.hunter from width(), bulk() and Unmasked.race().
static func shape(c: Dictionary, lk: Dictionary) -> void:
	var fem: bool = c["fem"]
	var torso: Node3D = c["torso"]
	torso.get_parent().get_parent().set_meta("stance", "empty_f" if fem else "empty_m")
	var shoulders := factor(lk, "shoulders")
	var chest := lerpf(1.0, shoulders, CHEST_PER_SHOULDER)
	var hips := factor(lk, "hips")
	for ch in torso.get_children():
		var mi := ch as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh == HeroKit.torso(fem):
			mi.mesh = Unmasked.figure(fem)
			mi.scale.x *= chest
		elif mi.material_override == c["m"]["pants"] and is_equal_approx(mi.position.y, HIPS_Y):
			mi.scale.x *= hips
	c["cw"] = float(c["cw"]) * chest
	for sd in ["L", "R"]:
		var piv := (c["arms"][sd] as Array)[0] as Node3D
		piv.position.x *= shoulders
		piv.scale = ARM_THIN_F if fem else Vector3.ONE
		(c["p" + sd.to_lower()] as Node3D).position.x *= shoulders
	var legs := torso.get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		var leg := legs.get_node(nm) as Node3D
		leg.position.x *= hips
		leg.scale = LEG_THIN_F if fem else Vector3.ONE
