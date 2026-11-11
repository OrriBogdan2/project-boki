class_name EggStages
extends RefCounted
## How a Rare Egg in an Incubator cradle shows how far it has warmed, on the egg itself (no panel):
## its shell glows brighter, hairline cracks appear in three stages (the last let gold light
## through), and it wobbles harder and faster. Progress is Incubator.progress(e), 0..1. A ready egg
## is HomeIncubator's job (the sharp rattle). Models.rare_egg_small is the egg this dresses.

const STAGES := [0.3, 0.6, 0.85]      # progress where the next crack set shows
const GLOW_MIN := 0.35                # the shell's glow on a cold egg (as Models.rare_egg_small)
const GLOW_GAIN := 1.8                # extra glow at progress 1
const WOBBLE_MIN := 0.03              # radians of sway on a cold egg
const WOBBLE_GAIN := 0.14             # extra sway at progress 1
const SHELL_R := 0.26                 # the shell's sphere radius, centre height and squash, as in Models
const SHELL_Y := 0.3
const SHELL_SQUASH := Vector3(0.9, 1.22, 0.9)
const CRACK_W := 0.045                # a crack's width and length in egg units, wide enough to read
const CRACK_LEN := 0.13
const CRACKS := [                     # per stage: [turn round the egg (rad), angle down from the top (rad)]
	[[0.3, 0.75], [3.4, 0.75]],       # on the upper cap, spread round the egg so some always face the camera
	[[1.4, 0.6], [4.5, 0.65], [5.6, 0.9]],
	[[0.9, 0.35], [2.5, 0.5], [4.0, 0.4], [5.2, 0.45]]]

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

## The shell's surface at (turn, down), egg scale s, and the basis a crack sits in there: x across the
## crack, y along it (down the egg), z out of the shell.
static func _on_shell(turn: float, down: float, s: float) -> Transform3D:
	var r := SHELL_SQUASH * SHELL_R * s
	var dir := Vector3(sin(down) * cos(turn), cos(down), sin(down) * sin(turn))
	var out := Vector3(dir.x / r.x, dir.y / r.y, dir.z / r.z).normalized()
	var along := Vector3(cos(down) * cos(turn), -sin(down), cos(down) * sin(turn))
	along = (along - out * along.dot(out)).normalized()
	var at := Vector3(0, SHELL_Y * s, 0) + dir * r + out * 0.003 * s
	return Transform3D(Basis(along.cross(out), along, out), at)

## Adds the (hidden) cracks to an egg node from Models.rare_egg_small, scale s. Each crack is two
## short strokes at a kink, the last stage's lit gold.
static func dress(egg: Node3D, s: float) -> void:
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	var dark := _unshaded(Color("4a2c12"))
	var lit := _unshaded(Color("ff9a1f"))
	var box := BoxMesh.new()
	box.size = Vector3(CRACK_W, CRACK_LEN, 0.01) * s
	for st in CRACKS.size():
		var group := Node3D.new()
		group.visible = false
		for c in CRACKS[st]:
			var t := _on_shell(float(c[0]), float(c[1]), s)
			for k in 2:
				var m := MeshInstance3D.new()
				m.mesh = box
				m.material_override = lit if st == CRACKS.size() - 1 else dark
				var kink := (0.5 if k == 0 else -0.4) * signf(0.5 - st % 2)
				m.transform = t * Transform3D(Basis(Vector3.BACK, kink), Vector3(0, (k - 0.5) * CRACK_LEN * 0.8 * s, 0))
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
