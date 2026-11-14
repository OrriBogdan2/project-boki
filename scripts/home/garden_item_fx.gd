class_name GardenItemFx
extends Node3D
## The moment on a Boki when it is given a shaping item (GardenItems, GARDEN_MODERN.md 1.2-1.3), so the change
## reads at a glance: Sunsap's tick rising in garden-xp gold (the stat bites already rise as StatGlint icons in
## their stat colour), a path token's pip sliding onto the path meter over the head and its charm popping on,
## a sweet filling the lean ring at the feet in the type colour, Rinse Melon draining it (the tint fades), and
## Stayleaf's leaf settling on the head under a lock that closes. All of it is cel bits (Models.toon) from one
## pool made once; a give never makes a node. The aura items (GardenAura draws them) get no moment here.

const POOL := 16           # bits on screen at once: a full lean ring plus spares; a new moment takes the oldest
const LIFE := 1.2          # s a moment lasts
const POP_S := 0.12        # s a bit takes to pop in at its start and out at the end
const RING_SEGS := 12      # segments in the lean ring: each is Evo.LEAN_FULL / RING_SEGS lean points
const RING_R := 0.6        # m: the lean ring's radius round the feet
const RING_Y := 0.08       # m: its height off the ground
const FILL_S := 0.06       # s between one ring segment changing colour and the next
const HEAD_Y := 1.3        # m above the feet: the path meter and the leaf lock
const PIP_GAP := 0.22      # m between the path meter's slots
const PIP_IN := 0.7        # m: where a new pip starts, off the meter's free end
const SLIDE_S := 0.35      # s the new pip slides
const CHARM_AT := Vector3(0.0, 0.62, 0.32)   # m: the charm, on the Boki's chest
const TICK_Y := 0.9        # m: where Sunsap's tick starts
const TICK_RISE := 0.8     # m it climbs over the moment
const LEAF_DROP := 0.6     # m the leaf falls onto the head
const LOCK_AT := 0.45      # s: the lock starts closing round the leaf ...
const LOCK_S := 0.15       # ... and is shut this much later
const LEAF_FLAT := Vector3(1.0, 0.35, 1.0)   # the leaf: a flattened bead
const DIM := Color(0.16, 0.13, 0.22)   # an empty ring segment or meter slot
const XP_GOLD := UI.GOLD               # Sunsap: garden xp

var bits: Array = []       # the pool: MeshInstance3D, each with its own toon material
var live: Array = []       # {mi, k, a, b, c0, c1, s0, s1, t0, t1, t}: a bit moving from a to b over t0..t1
var _next := 0
var _mesh := {}            # shape -> Mesh

func _ready() -> void:
	name = "GardenItemFx"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.22, 0.16, 0.06)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.17
	_mesh = {"tick": prism, "bead": Models.sphere(0.055, 8), "seg": Models.box(0.2, 0.05, 0.1),
			"leaf": Models.sphere(0.13, 10), "lock": torus}
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.material_override = Models.toon(Color.WHITE, true, 0.35)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		bits.append(mi)
	set_process(false)

## The moment for a give the feed menu just made (res: GardenItems.feed or use, with id and deltas), on the
## Boki entry k. False when the item's family has no moment here or the give didn't take.
func play(k: Dictionary, res: Dictionary) -> bool:
	if not res.get("ok", false) or not GardenItems.has(String(res.get("id", ""))):
		return false
	var id := String(res["id"])
	var d: Dictionary = res.get("deltas", {})
	match String(GardenItems.item(id)["effect"]["kind"]):
		"xp": _tick(k)
		"token": _path(k, d["path"][0], id)
		"sweet", "rinse": _lean(k, d["lean"][0], d["lean"][1])
		"stay": _leaf_lock(k)
		_: return false
	set_process(true)
	return true

func _tick(k: Dictionary) -> void:
	var at := Vector3(0, TICK_Y, 0)
	_bit(k, "tick", at, at + Vector3(0, TICK_RISE, 0), XP_GOLD, XP_GOLD, 0.0, LIFE)

## The meter: one slot per token it can wear, the ones it wore already in their path's tint; the new pip slides
## in from the free end to the first empty slot, then the charm pops on.
func _path(k: Dictionary, was: Array, id: String) -> void:
	var across := _across()
	var n := int(GardenItems.rules()["max_tokens"])
	var col: Color = Evo.AFF[GardenItems.aff_of(id)]["tint"]
	for i in n:
		var at := Vector3(0, HEAD_Y, 0) + across * PIP_GAP * (i - (n - 1) * 0.5)
		if i < was.size():
			var c: Color = Evo.AFF[GardenItems.aff_of(String(was[i]))]["tint"]
			_bit(k, "bead", at, at, c, c, 0.0, 0.0)
		elif i == was.size():
			_bit(k, "bead", at + across * PIP_IN, at, col, col, 0.0, SLIDE_S)
		else:
			_bit(k, "bead", at, at, DIM, DIM, 0.0, 0.0, Vector3.ONE * 0.6, Vector3.ONE * 0.6)
	_bit(k, "bead", CHARM_AT, CHARM_AT, col, col, SLIDE_S, SLIDE_S + POP_S, Vector3.ZERO, Vector3.ONE * 1.6)

## The ring at the feet in the colours of the lean before, turning segment by segment into the lean after:
## a sweet fills it in the type's colour, a rinse empties it.
func _lean(k: Dictionary, was: Dictionary, now: Dictionary) -> void:
	var c0 := _ring_cols(was)
	var c1 := _ring_cols(now)
	var step := 0
	for i in RING_SEGS:
		var ang := TAU * i / RING_SEGS
		var at := Vector3(sin(ang) * RING_R, RING_Y, cos(ang) * RING_R)
		var t0 := POP_S + FILL_S * step
		if c0[i] != c1[i]:
			step += 1
		var b := _bit(k, "seg", at, at, c0[i], c1[i], t0, t0 + FILL_S)
		(b["mi"] as Node3D).rotation.y = ang

## RING_SEGS colours: each lean type its share of the ring (biggest first), the rest DIM.
func _ring_cols(lean: Dictionary) -> Array:
	var out: Array = []
	var types := lean.keys()
	types.sort_custom(func(x, y): return float(lean[x]) > float(lean[y]))
	for t in types:
		var col: Color = Lean.face(String(t))["tint"]
		for j in roundi(float(lean[t]) / Evo.LEAN_FULL * RING_SEGS):
			out.append(col)
	out.resize(mini(out.size(), RING_SEGS))
	while out.size() < RING_SEGS:
		out.append(DIM)
	return out

func _leaf_lock(k: Dictionary) -> void:
	var at := Vector3(0, HEAD_Y, 0)
	_bit(k, "leaf", at + Vector3(0, LEAF_DROP, 0), at, UI.GOOD, UI.GOOD, 0.0, LOCK_AT, LEAF_FLAT, LEAF_FLAT)
	_bit(k, "lock", at, at, XP_GOLD, XP_GOLD, LOCK_AT, LOCK_AT + LOCK_S, Vector3.ONE * 2.2)

## The screen's left-right in the world (the meter lies across the view), flat on the ground.
func _across() -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return Vector3.RIGHT
	var x := cam.global_basis.x
	x.y = 0.0
	return x.normalized() if x.length() > 0.01 else Vector3.RIGHT

## Takes the oldest bit in the pool for k: offsets a..b from its feet, colour c0..c1, size s0..s1 times its mesh,
## all over t0..t1 (s into the moment).
func _bit(k: Dictionary, shape: String, a: Vector3, b: Vector3, c0: Color, c1: Color, t0: float, t1: float,
		s0 := Vector3.ONE, s1 := Vector3.ONE) -> Dictionary:
	var mi: MeshInstance3D = bits[_next]
	_next = (_next + 1) % POOL
	live = live.filter(func(x): return x["mi"] != mi)
	mi.mesh = _mesh[shape]
	mi.rotation = Vector3.ZERO
	var bit := {"mi": mi, "k": k, "a": a, "b": b, "c0": c0, "c1": c1, "t0": t0, "t1": t1, "t": 0.0,
			"s0": s0, "s1": s1}
	live.append(bit)
	_pose(bit)
	return bit

func _process(dt: float) -> void:
	for i in range(live.size() - 1, -1, -1):
		var bit: Dictionary = live[i]
		bit["t"] = float(bit["t"]) + dt
		if float(bit["t"]) < LIFE and is_instance_valid(bit["k"]["node"]):
			_pose(bit)
		else:
			(bit["mi"] as Node3D).visible = false
			live.remove_at(i)
	set_process(not live.is_empty())

func _pose(bit: Dictionary) -> void:
	var mi: MeshInstance3D = bit["mi"]
	var node: Node3D = bit["k"]["node"]
	var t := float(bit["t"])
	var span := maxf(float(bit["t1"]) - float(bit["t0"]), 0.001)
	var u := ease(clampf((t - float(bit["t0"])) / span, 0.0, 1.0), 0.4)
	var pop := clampf(minf(t, LIFE - t) / POP_S, 0.0, 1.0)
	mi.global_position = node.global_position + (bit["a"] as Vector3).lerp(bit["b"], u)
	mi.scale = (bit["s0"] as Vector3).lerp(bit["s1"], u) * pop + Vector3.ONE * 0.001
	(mi.material_override as ShaderMaterial).set_shader_parameter("albedo", (bit["c0"] as Color).lerp(bit["c1"], u))
	mi.visible = true
