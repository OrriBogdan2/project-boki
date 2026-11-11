class_name CarryWisps
extends RefCounted
## Telling a Hunter's wisps apart at match zoom (DECISIONS 2026-11-11 "carry 2 in, 1 extra out": up to four
## wisps on one Hunter; docs/decisions/0038-boki-wisp-proto.md, Carry slots). Every wisp keeps its Boki's
## critter shape and colours; only what reads from the top-down camera changes with its slot:
##   lead       full size and brightest, its rim in its type colour, on the orbit
##   second     smaller and dimmer, across the orbit from the lead and a little lower
##   stolen     riding with a thief: its rim in the thief's side colour, between the lead and the second
##   carry-out  a Boki claimed this match (Capture's box): small, trailing behind the belt on a tether
## Cheap: every body and tether is drawn with BokiWispLook's one material (only its instance uniforms differ),
## the tethers share one unit cylinder, no lights. The Kin wisps (lead, second, stolen) are placed by
## KinWisp.render through place(); the Boki in Hunter.caught (carry-out, stolen capsules) have no Kin and are
## drawn here by tick(). Only with Boki wisps on (KinWisp.mode).

## Per slot: size (scale), brightness (the shader's `bright`), orbit turn (laps ahead of the lead) and drop
## (m below the lead's height). Stolen wisps take turns 0.25 and 0.75 by their order on the carrier.
const LOOKS := {
	"lead": {"size": 1.0, "bright": 1.35, "turn": 0.0, "drop": 0.0},
	"second": {"size": 0.65, "bright": 0.7, "turn": 0.5, "drop": 0.12},
	"stolen": {"size": 0.8, "bright": 1.0, "turn": 0.25, "drop": 0.05},
	"carry_out": {"size": 0.6, "bright": 0.85, "turn": 0.0, "drop": 0.0},
}
const BELT_Y := 0.95          # m above the hunter's feet where the tether is tied
const TRAIL_GAP := 0.55       # m past the orbit the carry-out wisp hangs behind, clear of the orbiting ones
const TRAIL_UP := 0.25        # m above the belt it floats
const TRAIL_FOLLOW := 5.0     # 1/s: how fast it catches up, so it swings behind a moving hunter
const TETHER_R := 0.018       # m; the tether's radius, a thread at match zoom
const TETHER_BRIGHT := 0.8    # the tether a touch under its wisp

static var _tether_mesh: CylinderMesh

## The slot of a Kin wisp riding with its hunter: "lead", "second" (in the satchel), "stolen", or "" when it
## does not ride.
static func role(k: Kin) -> String:
	var o := k.owner_h
	if not k.wisp or o == null:
		return ""
	if KinSteal.stolen(k):
		return "stolen" if k.state == "shoulder" else ""
	if k == o.kin2 and k.state == "bench" and not o.downed:
		return "second"
	return "lead" if k.state == "shoulder" else ""

## Puts a riding Kin wisp on its slot of the orbit round hunter o (shoulder height y) and dresses it.
static func place(k: Kin, o: Hunter, y: float, orbit: Dictionary) -> void:
	var slot := role(k)
	var look: Dictionary = LOOKS[slot]
	var turn := float(look["turn"]) + (_stolen_index(k) * 0.5 if slot == "stolen" else 0.0)
	var a: float = TAU * (k.m.time * float(orbit["hz"]) + _phase(o) + turn)
	k.global_position = KinWisp.orbit_spot(orbit, a, o.position, y - float(look["drop"]))
	k.model.rotation.y = atan2(sin(a), -cos(a))
	k.model.scale = Vector3.ONE * float(look["size"])
	_dress(k.model, slot, _rim(slot, k.species, k.rec, o), float(look["bright"]))

## A Kin wisp off every slot (floating loose, say): its own size and glow again.
static func plain(k: Kin) -> void:
	k.model.scale = Vector3.ONE
	_dress(k.model, "", Shiny.col(k.species, k.rec, "glow"), 1.0)

## Every frame per hunter (Hunter.render): the carry-out and stolen capsules in Hunter.caught as wisps.
static func tick(h: Hunter, dt: float) -> void:
	if h.caught.is_empty() and not h.has_meta("carry_wisps"):
		return
	var shown: Array = h.get_meta("carry_wisps", [])
	if not _same_recs(shown, h.caught) or not KinWisp.mode(h.m) or h.out or h.extracted:
		_clear(h, shown)
		if h.caught.is_empty() or not KinWisp.mode(h.m) or h.out or h.extracted:
			return
		shown = _build(h)
	var stolen_n := 0
	for w in shown:
		var rec: Dictionary = w["rec"]
		var node: Node3D = w["node"]
		if Capture.is_stolen(h, rec):
			_orbit_capsule(h, node, rec, KinSteal.count(h) + stolen_n)
			stolen_n += 1
		else:
			_trail_capsule(h, node, w["tether"], dt)
		BokiWispLook.pose(node, h.m.time)

## The carry-out wisp hangs behind the belt, swinging after the hunter, on its tether.
static func _trail_capsule(h: Hunter, node: Node3D, tether: MeshInstance3D, dt: float) -> void:
	var belt := h.position + Vector3(0, BELT_Y, 0)
	var reach := float(BokiWispCosmetics.worn(h)["orbit"]["radius"]) + TRAIL_GAP
	var back := Vector3(sin(h.face), 0, cos(h.face)) * reach
	var want := belt + back + Vector3(0, TRAIL_UP, 0)
	node.global_position = node.global_position.lerp(want, minf(1.0, dt * TRAIL_FOLLOW))
	var to := node.global_position - belt
	var mid := belt + to * 0.5
	var up := to.normalized() if to.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	tether.global_transform = Transform3D(Basis(side, up * to.length(), side.cross(up)), mid)
	node.rotation.y = h.face

## A stolen capsule on a stolen slot of the orbit, like a stolen Kin wisp.
static func _orbit_capsule(h: Hunter, node: Node3D, rec: Dictionary, index: int) -> void:
	var orbit: Dictionary = BokiWispCosmetics.worn(h)["orbit"]
	var look: Dictionary = LOOKS["stolen"]
	var a: float = TAU * (h.m.time * float(orbit["hz"]) + _phase(h) + float(look["turn"]) + index * 0.5)
	var y := h.position.y + KinWisp.SHOULDER_Y - float(look["drop"])
	node.global_position = KinWisp.orbit_spot(orbit, a, h.position, y)
	node.rotation.y = atan2(sin(a), -cos(a))
	_dress(node, "stolen", _rim("stolen", String(rec["species"]), rec, h), float(look["bright"]))

static func _build(h: Hunter) -> Array:
	var out := []
	for rec in h.caught:
		var node := BokiWispLook.build(String(rec["species"]), rec, BokiWispCosmetics.worn(h))
		node.top_level = true
		h.add_child(node)
		var w := {"rec": rec, "node": node, "tether": null}
		if not Capture.is_stolen(h, rec):
			node.scale = Vector3.ONE * float(LOOKS["carry_out"]["size"])
			node.global_position = h.position + Vector3(0, BELT_Y + TRAIL_UP, 0)
			var rim := _rim("carry_out", String(rec["species"]), rec, h)
			_dress(node, "carry_out", rim, float(LOOKS["carry_out"]["bright"]))
			w["tether"] = _tether(h, rim)
		else:
			node.scale = Vector3.ONE * float(LOOKS["stolen"]["size"])
		out.append(w)
	h.set_meta("carry_wisps", out)
	return out

## A thread from the belt to the carry-out wisp: the shared unit cylinder, stretched each frame.
static func _tether(h: Hunter, col: Color) -> MeshInstance3D:
	if _tether_mesh == null:
		_tether_mesh = CylinderMesh.new()
		_tether_mesh.top_radius = TETHER_R
		_tether_mesh.bottom_radius = TETHER_R
		_tether_mesh.height = 1.0
		_tether_mesh.radial_segments = 4
		_tether_mesh.rings = 1
	var t := MeshInstance3D.new()
	t.name = "CarryTether"
	t.mesh = _tether_mesh
	t.material_override = BokiWispLook.material()
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.set_instance_shader_parameter("rim_col", col)
	t.set_instance_shader_parameter("bright", TETHER_BRIGHT)
	t.top_level = true
	h.add_child(t)
	return t

static func _clear(h: Hunter, shown: Array) -> void:
	for w in shown:
		(w["node"] as Node).queue_free()
		if w["tether"]:
			(w["tether"] as Node).queue_free()
	h.remove_meta("carry_wisps")

## The same records, in the same order, as last frame (Hunter.caught can be swapped for a new array).
static func _same_recs(shown: Array, caught: Array) -> bool:
	if shown.size() != caught.size():
		return false
	for i in shown.size():
		if not is_same(shown[i]["rec"], caught[i]):
			return false
	return true

## The rim of a slot: the lead's type colour, a stolen wisp's thief's side colour, else the Boki's glow.
static func _rim(slot: String, species: String, rec: Dictionary, carrier: Hunter) -> Color:
	match slot:
		"lead":
			return DexView.type_col(String(Data.KIN[species].get("type", "")))
		"stolen":
			return SideColor.of(carrier.m, carrier)
	return Shiny.col(species, rec, "glow")

## Sets the body's instance uniforms when its slot or rim changes, not every frame.
static func _dress(wisp: Node3D, slot: String, rim: Color, bright: float) -> void:
	if wisp.get_meta("slot", "-") == slot and wisp.get_meta("rim", Color.BLACK) == rim:
		return
	wisp.set_meta("slot", slot)
	wisp.set_meta("rim", rim)
	var body := wisp.get_node("Body") as GeometryInstance3D
	body.set_instance_shader_parameter("rim_col", rim)
	body.set_instance_shader_parameter("bright", bright)

## Which of its carrier's stolen Kin wisps this is (0 or 1): a scan only stolen wisps pay for.
static func _stolen_index(k: Kin) -> int:
	var n := 0
	for o in k.m.kins:
		if o == k:
			return n
		if o.owner_h == k.owner_h and KinSteal.stolen(o) and not o.dead:
			n += 1
	return n

## Each hunter's orbit starts at its own angle, so neighbours' wisps do not circle in step.
static func _phase(h: Hunter) -> float:
	return float(absi(hash(h.pname)) % 1000) / 1000.0
