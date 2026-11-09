class_name WardenKit
extends RefCounted
## Shared pieces of the Warden models (concept phase 2: docs/art/concepts on ext/concepts): the
## Warden's own palette nudged by the player's outfit pick (MantleLook's 20%), the materials made
## from it in the hunters' painted toon look, and the small shapes several Wardens use (icicles, fur
## rolls). Each Warden's builder (warden_<id>.gd) dresses the shared rig that Models.hunter builds.

## The Warden's palette colour c, moved the way the player's outfit pick moved the Warden's outfit
## colour (MantleLook.tint keeps that within the Warden's range), so a Bearer's coat is the Warden's
## coat a shade toward their pick and signature colours stay what they are.
static func tint(c: Dictionary, col: Color) -> Color:
	var base: Color = MantleLook.warden(String(c["arch"]))["outfit"]
	var now: Color = c["hero_col"]
	var dh := wrapf(now.h - base.h, -0.5, 0.5)
	return Color.from_hsv(fposmod(col.h + dh, 1.0), clampf(col.s + now.s - base.s, 0.0, 1.0),
			clampf(col.v + now.v - base.v, 0.0, 1.0))

## A cloth or leather material from the Warden's palette (painted like the hunters' cloth).
static func cloth(c: Dictionary, col: Color, surface := 1) -> ShaderMaterial:
	var m := Models.toon(tint(c, col))
	m.set_shader_parameter("rim_amount", 0.75)
	Models.painted(m, surface, 0.3, 0.3, 0.26)
	return m

## A metal from the palette: glossy, painted as metal (surface 3).
static func metal(c: Dictionary, col: Color, gloss := 0.6) -> ShaderMaterial:
	var m := Models.shiny(tint(c, col), gloss)
	Models.painted(m, 3, 0.14, 0.12, 0.14)
	return m

## Fur from the palette: soft, painted like hair (surface 5).
static func fur(c: Dictionary, col: Color) -> ShaderMaterial:
	var m := Models.toon(tint(c, col))
	m.set_shader_parameter("rim_amount", 0.75)
	Models.painted(m, 5, 0.3, 0.3, 0.3)
	return m

## Ice that never melts: pale and glassy with a faint cold glow of its own, never tinted.
static func rime(col := Color("c4ecff"), glow := 0.12) -> ShaderMaterial:
	var m := Models.shiny(col, 0.85)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("rim_amount", 0.9)
	return m

## Recolours one of the rig's shared materials (the coat on the torso and sleeves, the trousers,
## the boots, the gloves) to a palette colour.
static func recolour(c: Dictionary, key: String, col: Color) -> void:
	(c["m"][key] as ShaderMaterial).set_shader_parameter("albedo", tint(c, col))

## A ring of icicles hanging from a hem: n points round an ellipse rx x rz at height y, each a thin
## cone pointing down, longer and shorter by turns, skipping the arc a_skip0..a_skip1 (0..1 round, the
## front is 0.75).
static func icicles(n: Node3D, m: Material, y: float, rx: float, rz: float, count: int, length: float,
		a_skip0 := 2.0, a_skip1 := 2.0) -> void:
	for k in count:
		var a := (k + 0.5) / count
		if a > a_skip0 and a < a_skip1:
			continue
		var th := a * TAU
		var ln := length * (0.55 + 0.45 * absf(sin(k * 2.39)))
		var at := Vector3(cos(th) * rx, y, sin(th) * rz)
		Models._spike(n, m, at, Vector3(cos(th) * 0.15, -1.0, sin(th) * 0.15), 0.014 + 0.006 * absf(sin(k * 1.7)), ln)

## A puffy roll of fur round a limb or the neck (a lumpy torus, flatter underneath).
static func fur_roll(
	n: Node3D,
	m: Material,
	key: String,
	at: Vector3,
	r: float,
	tube: float,
	lumps := 7.0
) -> MeshInstance3D:
	return Models.part(n, HeroKit.mantle("wk_" + key, r, r, tube, lumps), m, at)
