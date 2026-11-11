class_name EggStages
extends RefCounted
## How a Rare Egg in an Incubator cradle shows how far it has warmed, on the egg itself (no panel):
## its shell glows brighter, hairline cracks appear in three stages (the last let gold light
## through), and it wobbles harder and faster. Progress is Incubator.progress(e), 0..1. A ready egg
## is HomeIncubator's job (the sharp rattle). Models.rare_egg_small is the egg this dresses.

const STAGES := [0.3, 0.6, 0.85]      # progress where the next crack set shows
const GLOW_MIN := 0.35                # the shell's glow on a cold egg (as Models.rare_egg_small)
const GLOW_GAIN := 1.4                # extra glow at progress 1
const WOBBLE_MIN := 0.03              # radians of sway on a cold egg
const WOBBLE_GAIN := 0.1              # extra sway at progress 1
const SHELL_R := 0.26                 # the shell's sphere radius, and its squash (x/z, y), as in Models
const SHELL_SQUASH := Vector3(0.9, 1.22, 0.9)
const CRACKS := [                     # per stage: [x, y, length] on the shell's front, in egg units
	[[0.05, 0.5, 0.16], [0.12, 0.38, 0.1]],
	[[-0.1, 0.42, 0.16], [-0.04, 0.26, 0.12], [0.1, 0.22, 0.1]],
	[[0.0, 0.34, 0.2], [-0.14, 0.2, 0.1], [0.14, 0.5, 0.1]]]

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

## A point on the shell's front for a crack at (x, y), egg units scaled by s.
static func _on_shell(x: float, y: float, s: float) -> Vector3:
	var rx := SHELL_SQUASH.x * SHELL_R * s
	var ry := SHELL_SQUASH.y * SHELL_R * s
	var u := 1.0 - pow(x / rx, 2) - pow((y - 0.3 * s) / ry, 2)
	return Vector3(x, y, rx * sqrt(maxf(0.0, u)) + 0.004)

## Adds the (hidden) cracks to an egg node from Models.rare_egg_small, scale s.
static func dress(egg: Node3D, s: float) -> void:
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	var dark := _unshaded(Color("5a3a1c"))
	var lit := _unshaded(Color("fff0a0"))
	for st in CRACKS.size():
		var group := Node3D.new()
		group.visible = false
		for c in CRACKS[st]:
			var m := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.02, float(c[2]) * 1.6, 0.01) * s
			m.mesh = box
			m.material_override = lit if st == CRACKS.size() - 1 else dark
			m.position = _on_shell(float(c[0]) * s, float(c[1]) * s, s)
			var lean := 0.5 if c[0] > 0.0 else -0.4
			m.rotation.z = -lean if st == 1 else lean
			group.add_child(m)
		cracks.add_child(group)
	(egg.get_node("Shell") as Node3D).add_child(cracks)

## Which crack sets show at this progress (0..3).
static func stage(p: float) -> int:
	return STAGES.filter(func(t): return p >= t).size()

## Per frame: glow, cracks and wobble for an egg still warming. tt is seconds, ph its own phase.
static func apply(egg: Node3D, p: float, tt: float, ph: float) -> void:
	var shell: Node3D = egg.get_node("Shell")
	shell.rotation.z = sin(tt * (1.3 + 3.2 * p) + ph) * (WOBBLE_MIN + WOBBLE_GAIN * p)
	var mat := (shell.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("glow", GLOW_MIN + GLOW_GAIN * p * (0.85 + 0.15 * sin(tt * 2.4 + ph)))
	var shown := stage(p)
	var cracks := shell.get_node("Cracks")
	for i in cracks.get_child_count():
		(cracks.get_child(i) as Node3D).visible = i < shown
