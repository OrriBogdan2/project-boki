extends RefCounted
## --glider-canopy-check: the glider canopy shows its heat in the world (GliderHeat): the shader's heat follows the
## heat value, overheat shows (smoke), burning over the abyss flickers, opening and closing add no burst and no
## nodes, and what other players see over the wire matches. Prints "CANOPY ok|FAIL ..." and "CANOPY DONE, failures: N".

const DT := 1.0 / 60.0
var bad := 0
var m: Match
var h: Hunter

func ok(cond: bool, what: String) -> void:
	print("CANOPY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Renders the open glider for `secs` at the given fuel and lip state; returns the canopy's [heat, burn].
func _look(fuel: float, lip: bool, secs := 0.5) -> Array:
	h.gliding = true
	h.glide_fuel = fuel
	h.below_lip = lip
	for i in int(secs / DT):
		m.time += DT
		h.render(DT, 1.0)
	var mat := _canopy().material_override as ShaderMaterial
	return [float(mat.get_shader_parameter("canopy_heat")), float(mat.get_shader_parameter("canopy_burn"))]

## Runs the heat cue for `secs` at the given fuel on an open glider; returns the smoke puffs it spawned.
func _ticks(gl: Node3D, fuel: float, secs: float) -> int:
	h.gliding = true
	h.glide_fuel = fuel
	var b0: int = m.fx.bi
	for i in int(secs / DT):
		m.time += DT
		GliderHeat.tick(h, gl, DT)
	var pool: int = m.fx.bursts.size()      # a ring: one slot per puff
	return (int(m.fx.bi) - b0 + pool) % pool

## Shared fx spawned over 0.5 s that starts with the glider open or not (`was`) and then is open or not (`now`).
func _spawned(was: bool, now: bool) -> int:
	h.gliding = was
	for i in 30:
		m.time += DT
		h.render(DT, 1.0)
	var b0: int = m.fx.bi
	h.gliding = now
	for i in 30:
		m.time += DT
		h.render(DT, 1.0)
	var pool: int = m.fx.bursts.size()
	return (int(m.fx.bi) - b0 + pool) % pool

func _canopy() -> MeshInstance3D:
	return h.model.get_node("Rig/Torso/Glider/Canopy") as MeshInstance3D

func _nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _nodes(k)
	return c

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	h = m.hunters[0]
	h.ctrl = "local"
	h.grounded = false
	var shader := (_canopy().material_override as ShaderMaterial).shader
	var names: Array = shader.get_shader_uniform_list().map(func(u): return u["name"])
	var reads: bool = "canopy_heat" in names and "canopy_burn" in names
	ok(reads, "the canopy's own shader (%s) reads both parameters" % shader.resource_path)
	var nodes0 := _nodes(h.model)
	var cool := _look(1.0, false)
	var warm := _look(0.5, false)
	var hot := _look(0.1, false)
	var follows: bool = cool[0] < 0.01 and absf(warm[0] - 0.5) < 0.05 and hot[0] > 0.85
	ok(follows, "heat follows the glider's heat (%.2f, %.2f, %.2f)" % [cool[0], warm[0], hot[0]])
	ok(cool[1] == 0.0 and warm[1] == 0.0 and hot[1] == 0.0, "no flicker below overheat")
	var gl: Node3D = h.model.get_node("Rig/Torso/Glider")
	var over := _look(0.0, false)
	ok(over[0] == 1.0 and over[1] == 0.0, "overheated: full heat, no flicker on level air")
	var radial: int = m.fx.radial
	var puffs := _ticks(gl, 0.0, 1.0)
	ok(puffs >= 6, "overheated: a smoke trail (%d puffs in a second)" % puffs)
	ok(m.fx.radial == radial, "the heat cues are smoke only: no burst of the shared kind")
	ok(_ticks(gl, 0.5, 1.0) == 0, "heated but not overheated: no smoke")
	# opening and closing add nothing: an open spawns no more than the same time of steady glide (its wind
	# streak), and a fold spawns nothing (a cool glider)
	h.glide_fuel = 1.0
	var steady := _spawned(true, true)
	var opened := _spawned(false, true)
	var folded := _spawned(true, false)
	var quiet: bool = opened <= steady and folded == 0
	ok(quiet, "opening (%d vs %d gliding) and closing (%d) add no puff or burst" % [opened, steady, folded])
	var burn := _look(0.0, true)
	ok(burn[0] == 1.0 and burn[1] == 1.0, "overheated over the abyss, lifting at half strength: it flickers")
	h.gliding = false
	h.below_lip = true
	ok(not GliderHeat.overheated(h) and not GliderHeat.burning(h), "a closed glider never burns")
	ok(_nodes(h.model) == nodes0, "no nodes added: the canopy keeps its one material")
	# what other players see: heat steps and the overheat state ride the hunter flags
	var other: Hunter = m.hunters[1]
	for want in [1.0, 0.5, 0.0]:
		h.gliding = true
		h.glide_fuel = want
		h.below_lip = want == 0.0
		m._net_apply(other, m._ser(h))
		var step := 1.0 / GliderHeat.NET_LEVELS
		var seen: float = 1.0 - other.glide_fuel
		var near: bool = absf(seen - (1.0 - want)) <= step * 0.5 + 0.001
		ok(near, "the wire carries heat %.2f (got %.2f)" % [1.0 - want, seen])
		var hotter: bool = want == 0.0
		var state: bool = GliderHeat.overheated(other) == hotter and other.below_lip == hotter
		ok(state, "...and the overheat state (%s)" % ("on" if hotter else "off"))
	m.queue_free()
	print("CANOPY DONE, failures: ", bad)
	main.get_tree().quit()
