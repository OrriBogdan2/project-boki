class_name WardenOrbits
extends RefCounted
## Props on an orbit (RIG_CONTRACT "Orbits"): a .glb node named orbit_<name> riding a bone carries unskinned
## props (Tarek's three seeing-stones round his head, each built facing out from the orbit's centre). Each frame
## the node turns round its own up axis (its rest is upright) at ORBIT_HZ, so every prop circles the bone
## and keeps facing outward, and each prop bobs on its own phase. The orbit is data here; nothing is baked.

const PREFIX := "orbit_"
const ORBIT_HZ := 0.12      # turns a second
const BOB := 0.025          # m, each prop up and down
const BOB_HZ := 0.5
const LOOKERS := "orbit_stones"   # the orbit whose props are eyes (Tarek's seeing-stones)
const LOOK_RATE := 7.0      # 1/s: how fast they turn to what they watch
var look := Vector3.INF     # world point they watch (WardenGlb.ORBIT_LOOK), INF for none
var pivots: Array = []      # [node, its rest transform, [prop, its rest position]...]
var t := 0.0

func setup(glb: Node) -> void:
	for n in glb.find_children(PREFIX + "*", "Node3D", true, false):
		var nd := n as Node3D
		if nd is MeshInstance3D or nd.get_child_count() == 0:
			continue
		var props: Array = []
		for ch in nd.get_children():
			if ch is Node3D:
				props.append([ch, (ch as Node3D).position, (ch as Node3D).quaternion])
		pivots.append([nd, nd.transform, props])

func step(dt: float) -> void:
	t += dt
	for pv in pivots:
		var nd: Node3D = pv[0]
		var rest: Transform3D = pv[1]
		nd.transform = rest * Transform3D(Basis(Vector3.UP, TAU * ORBIT_HZ * t), Vector3.ZERO)
		var props: Array = pv[2]
		for i in props.size():
			var pr: Node3D = props[i][0]
			pr.position = (props[i][1] as Vector3) + Vector3.UP * BOB * sin(TAU * BOB_HZ * t + i * 2.1)
			if nd.name == LOOKERS and pr.is_inside_tree():
				_face(pr, props[i][2], dt)

## A seeing-stone's eye (-Z on the prop) turns toward what the kit is watching, then back to looking outward.
func _face(pr: Node3D, rest: Quaternion, dt: float) -> void:
	var want := rest
	if look.is_finite() and pr.global_position.distance_squared_to(look) > 0.01:
		var to := Basis.looking_at(look - pr.global_position, Vector3.UP).get_rotation_quaternion()
		want = (pr.get_parent() as Node3D).global_basis.get_rotation_quaternion().inverse() * to
	pr.quaternion = pr.quaternion.slerp(want, 1.0 - exp(-LOOK_RATE * dt))
