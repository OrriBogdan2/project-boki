class_name WildTypeCue
extends RefCounted
## A wild Boki's type, readable from across the map: a soft tint disc in the type's colour under it.
## It is the Boki's own ground ring (Kin.ring, no extra node, light or particle) with the ring shader's `fill`
## on, so it reads as a lit patch of ground, not as a Hunter side ring (those are hollow: SideRings).
## One colour parameter per Boki, set once at spawn. The disc fades out over the capture scan.

const FILL := 0.6             # share of the disc's alpha that is the filled tint (the rim stays brighter)
const RIM := 0.22             # rim thickness as a share of the radius
const ALPHA := 0.8            # the disc's alpha at full strength
const FADE_S := 0.35          # s for the cue to fade in or out when the Boki is wild, dazed, scanned or gone

## The 18 standard types (DECISIONS 2026-11-08). Hues are kept off the three side colours (SideColor).
const COLORS := {
	"normal": Color("cfc6b0"), "fire": Color("e8431f"), "water": Color("2f7cff"), "grass": Color("2fae4a"),
	"spore": Color("d9b97f"), "electric": Color("f5ec3a"), "ice": Color("b8f0ff"), "rock": Color("8a6a4a"),
	"psychic": Color("ff3d9a"), "flying": Color("c7d3ff"), "dragon": Color("4b35d6"), "dark": Color("7a5fa8"),
	"poison": Color("9b3fd6"), "bug": Color("a6d12e"), "steel": Color("9fb0c0"), "fairy": Color("ffb3e6"),
	"crystal": Color("22d6b0"), "sound": Color("f29a2e"),
}

## Species themes still carrying their old names map to the standard type (the rename is ext/types-standard-names).
const OLD_TYPE := {
	"venom": "poison", "gravity": "psychic", "prism": "crystal", "lunar": "fairy", "echo": "sound", "ember": "fire",
	"frost": "ice", "storm": "electric", "stone": "rock", "bloom": "grass", "shadow": "dark", "titan": "steel",
	"swarm": "bug", "tempest": "flying",
}

## The standard type id of a species, "normal" for a species with no type.
static func type_of(sp: Dictionary) -> String:
	var t := String(sp.get("type", ""))
	t = String(OLD_TYPE.get(t, t))
	return t if COLORS.has(t) else "normal"

## Dresses the ring of a wild Boki as its type cue (a Boki with a Hunter keeps the side ring).
static func paint(k: Kin) -> void:
	var col: Color = COLORS[type_of(k.sp)]
	var mat := Models.ring_mat(Color(col, 0.0), RIM)
	mat.set_shader_parameter("fill", FILL)
	k.ring.material_override = mat
	k.ring.set_meta("cue_type", type_of(k.sp))
	k.ring.set_meta("cue_a", 0.0)

## Is `ring` a type cue, and how strong is it now (0..1)? For checks.
static func strength(ring: MeshInstance3D) -> float:
	return float(ring.get_meta("cue_a", 0.0)) if ring and ring.has_meta("cue_type") else 0.0

## Every frame while rendering: fades the cue in while the Boki is wild or dazed, out as the scan fills.
## Returns whether the ring should be drawn at all.
static func tick(k: Kin, dt: float) -> bool:
	var ring := k.ring
	var want := 0.0
	if k.state in ["wild", "dazed"]:
		want = 1.0 - (Capture.scan_frac(k.scan_by) if is_instance_valid(k.scan_by) else 0.0)
	var a := float(ring.get_meta("cue_a", 0.0))
	if is_equal_approx(a, want):
		return a > 0.0
	a = move_toward(a, want, dt / FADE_S)
	ring.set_meta("cue_a", a)
	var mat := ring.material_override as ShaderMaterial
	var col: Color = COLORS[String(ring.get_meta("cue_type"))]
	mat.set_shader_parameter("color", Color(col, ALPHA * a))
	return a > 0.0
