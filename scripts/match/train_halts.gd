class_name TrainHalts
extends Node3D
## Where to wait for the sky train: a slim light post on each halt's pier (readable from the drop and
## from 40 m on the ground), and a soft glow on the pier's edge while the train stands at it. No rings
## and no bursts. All posts are merged into four meshes with shared materials (post, brass cage, lamp,
## beam and halo), the glow is two pooled blobs moved to the halt the train is at. The Low preset keeps the
## posts and drops the glow.

const POST_H := 6.5           # m, the post's height above the pier
const BEAM_H := 36.0          # m, the thin light column over the lamp (finds the halt from the drop)
const POST_OUT := 2.6         # tiles from the track's centre line to the post
const POST_SIDE := 1.0       # tiles sideways, at the pier's long edge
const EDGE_OUT := 1.9         # tiles from the centre line to the glow, the pier's end at the track
const FADE_RATE := 1.5        # glow per second, in and out
const GLOW_ALPHA := 0.55
const STOPPED_V := 0.3        # m/s: slower than this is "stopped" (as SkyTrain's own moving test)

var train: SkyTrain = null
var beacons: Array = []       # [{halt, pos}] one per pier side that has ground
var piers: Array = []         # per halt: [{at, out}] the pier ends the glow sits on
var glow_nodes: Array = []
var glow_mat: ShaderMaterial = null
var halt := -1                # the halt the train is at, or was last at while the glow fades
var glow := 0.0               # 0..1, follows the stop state
var _placed := -2

func setup(sky_train: SkyTrain, lite: bool) -> void:
	train = sky_train
	name = "TrainHalts"
	_find_piers(train.world)
	_build_posts()
	if not lite:
		_build_glow()

## The piers run out from the track at each halt, square to it, on both sides where there's ground.
func _find_piers(W: World) -> void:
	for arc in W.train_route["stations"]:
		var at := W.train_at(float(arc))
		var along := W.train_at(float(arc) + 0.5) - W.train_at(float(arc) - 0.5)
		var tang := Vector2(along.x, along.z).normalized()
		var out := Vector2(-tang.y, tang.x)
		var base := Vector2(at.x, at.z)
		piers.append([])
		for side: float in [-1.0, 1.0]:
			var q := base + out * side * POST_OUT
			if W.is_void(q.x, q.y):
				continue
			var sd := tang if not W.is_void(q.x + tang.x * POST_SIDE, q.y + tang.y * POST_SIDE) else -tang
			q += sd * POST_SIDE
			beacons.append({"halt": piers.size() - 1, "pos": Vector3(q.x, W.ground_at(q.x, q.y), q.y)})
			var e := base + out * side * EDGE_OUT
			piers[-1].append({"at": Vector3(e.x, W.ground_at(e.x, e.y) + 0.06, e.y), "out": out})

func _build_posts() -> void:
	var post := []
	var cage := []
	var lamp := []
	var beam := []
	for b in beacons:
		var p: Vector3 = b["pos"]
		post.append([Models.cyl(0.09, 0.13, POST_H), Transform3D(Basis.IDENTITY, p + Vector3(0, POST_H * 0.5, 0))])
		cage.append([Models.cyl(0.2, 0.2, 0.16), Transform3D(Basis.IDENTITY, p + Vector3(0, POST_H * 0.8, 0))])
		cage.append([Models.cyl(0.3, 0.3, 0.1), Transform3D(Basis.IDENTITY, p + Vector3(0, POST_H, 0))])
		lamp.append([Models.sphere(0.42, 12), Transform3D(Basis.IDENTITY, p + Vector3(0, POST_H + 0.4, 0))])
		var column := p + Vector3(0, POST_H + 0.8 + BEAM_H * 0.5, 0)
		beam.append([Models.cyl(0.05, 0.22, BEAM_H, 8), Transform3D(Basis.IDENTITY, column)])
		# a flat halo, so the post reads from straight above too
		var crown := Basis.IDENTITY.scaled(Vector3(1.1, 0.3, 1.1))
		beam.append([Models.sphere(1.0, 12), Transform3D(crown, p + Vector3(0, POST_H + 0.5, 0))])
	_merged(post, Models.toon(Color("3f6fa8"), false), "Posts")
	_merged(cage, Models.toon(Color("d6a85a"), false, 0.1), "Cages")
	_merged(lamp, Models.glow_mat(Color("fff2b8")), "Lamps")
	_merged(beam, Models.glow_mat(Color(1.0, 0.9, 0.66, 0.3)), "Beams")

## One mesh from many [mesh, transform] parts, with one shared material.
func _merged(parts: Array, mat: Material, node_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		st.append_from(part[0], 0, part[1])
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_glow() -> void:
	glow_mat = Models.glow_mat(Color(1.0, 0.82, 0.5, 0.0))
	var blob := Models.sphere(1.0, 12)
	for _i in 2:
		var g := MeshInstance3D.new()
		g.mesh = blob
		g.material_override = glow_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		add_child(g)
		glow_nodes.append(g)

## The halt whose pier the stopped train's middle is at.
func _halt_of_train() -> int:
	var R: Dictionary = train.world.train_route
	var mid := train.head_s - (train.cars_n - 1) * SkyTrain.CAR_GAP * 0.5
	var best := -1
	var best_d := INF
	for i in (R["stations"] as Array).size():
		var off := fposmod(mid - float(R["stations"][i]) + train.loop_len * 0.5, train.loop_len) - train.loop_len * 0.5
		if absf(off) < best_d:
			best_d = absf(off)
			best = i
	return best

func tick(dt: float) -> void:
	if glow_nodes.is_empty():
		return
	var stopped := train.head_v < STOPPED_V
	if stopped:
		halt = _halt_of_train()
	glow = move_toward(glow, 1.0 if stopped else 0.0, FADE_RATE * dt)
	if halt != _placed:
		_place_glow()
	var a := glow * GLOW_ALPHA
	if stopped and train.depart_warned:
		a *= 0.75 + 0.25 * sin(float(train.m.time) * 9.0)     # pulses with the rails when it's about to leave
	glow_mat.set_shader_parameter("color", Color(1.0, 0.82, 0.5, a))
	for g: MeshInstance3D in glow_nodes:
		g.visible = glow > 0.01 and bool(g.get_meta("has", false))

func _place_glow() -> void:
	_placed = halt
	for k in glow_nodes.size():
		var g: MeshInstance3D = glow_nodes[k]
		var ends: Array = piers[halt] if halt >= 0 else []
		g.set_meta("has", k < ends.size())
		if k < ends.size():
			var d: Vector2 = ends[k]["out"]
			var blob := Basis(Vector3(-d.y, 0, d.x) * 1.7, Vector3(0, 0.12, 0), Vector3(d.x, 0, d.y) * 0.6)
			g.transform = Transform3D(blob, ends[k]["at"])
