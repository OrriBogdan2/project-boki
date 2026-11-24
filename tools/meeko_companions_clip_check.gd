extends RefCounted
## --meeko-companions-clip-check: Meeko's sun and raincloud against the POSED body (the live Meshy model, CPU-skinned
## from the clip that plays), in every state her native clips cover: idle, walk, run, dash (a 14 m/s burst: the ring snaps
## and trails), crouch, jump, attack, the ult move (mm_call plays the attack clip), a kit shot, a
## heavy hit flinch from four sides and the dead pose. Every 3rd frame, every
## companion vertex against the body's vertices (every 5th), each bucketed by the part of her its main bone belongs to
## (head, arms, hands, spine, hips, legs; Meshy's unnamed Bone_nnn chains are the wings, ears and tail), and the sun
## against the cloud. Passes when each pair stays >= the data's clear_min (warden_anim/pip.json companions.clear_min)
## and the two companions stay >= PAIR_MIN apart. Prints MEEKOCLIP lines: closest approach in mm and the part of her.

const DT := 1.0 / 30.0
const EVERY := 3        # frames between samples
const SUB_BODY := 5     # every 5th body vertex
const SUB_COMP := 3     # every 3rd companion vertex
const CELL := 0.06
const PAIR_MIN := 0.30  # m: the sun and the cloud never nearer than this
const FRAMES := 130
const SCREEN_MIN := 0.03   # m (at the player's depth, the match camera's view): no part of a companion nearer her silhouette than this on screen
const CAM_PITCH := 66.0    # the match camera's default pitch and distance (content/rules/camera.json)
const CAM_DIST := 23.0
# state name -> [state dict (STATE meta), burst seconds (0: all the time)]
const STATES := {
	"idle": [{}, 0.0],
	"walk": [{"vel": Vector3(1.4, 0, 0)}, 0.0],
	"run": [{"vel": Vector3(4.6, 0, 0)}, 0.0],
	"dash": [{"vel": Vector3(14.0, 0, 0)}, 0.5],
	"crouch": [{"crouch": 1.0}, 0.0],
	"jump": [{"grounded": false, "vel": Vector3(3.0, 0, 0)}, 0.0],
	"attack": [{"kmove": "mm_shot_r", "swing": true}, 0.0],
	"ult": [{"kmove": "mm_call", "swing": true}, 0.0],
	# a heavy hit every 0.5 s from the front, right, back and left in turn (WardenFlinch leans her away from it)
	"hit": [{"hit": 2.0}, 0.0],
	"death": [{"dead": true}, 0.0],
}
const KEYS := ["hand", "forearm", "arm", "shoulder", "head", "neck", "spine", "hips", "leg", "foot", "toe"]

var bad := 0
var n := 0
var labels := {}     # skeleton bone index -> part-of-her label

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MEEKOCLIP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var m := Models.hunter(Arch.weight("tender"), Data.TEAM_COLORS[0], Arch.signature("tender"), "",
		PlayerLook.neutral(), "tender")
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Native")
	ok(sync != null and sync.get("companions") != null, "Meeko's native model has floating companions")
	if sync == null or sync.get("companions") == null:
		_done(main)
		return
	sync.set_process(false)
	var wc: WardenCompanions = sync.companions
	var clear_min := float(wc.d.get("clear_min", 0.05))
	ok(wc.avoid.size() >= 5, "the head and hand avoid spheres are found (%d)" % wc.avoid.size())
	var body := _body(wc.skel)
	ok(int(body["n"]) > 1000, "the skinned body has %d sampled vertices" % int(body["n"]))
	var cam := Camera3D.new()      # the match camera: the companions face it and keep out of her silhouette across its line of sight
	main.add_child(cam)
	cam.fov = 32.0
	cam.make_current()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).substr(7)
	for st in STATES:
		if only != "" and st != only:
			continue
		var spec: Array = STATES[st]
		m.global_position = Vector3.ZERO
		m.set_meta(WardenClips.STATE, {})
		for i in 30:
			sync.call("_process", DT)
		var swing := 0
		var worst := {}      # companion id -> [m, part of her, frame]
		var screen := {}     # companion id -> [on-screen gap m, frame]
		var pair := 9.0
		for f in FRAMES:
			var s: Dictionary = (spec[0] as Dictionary).duplicate()
			var vel: Vector3 = s.get("vel", Vector3.ZERO)
			if float(spec[1]) > 0.0 and f * DT > float(spec[1]):
				vel = Vector3.ZERO
				s.erase("vel")
			if s.has("swing"):
				if f % 40 == 0:
					swing += 1
				s["swing_n"] = swing
				s.erase("swing")
			if s.has("hit"):
				var beat := int(f * DT / 0.5)
				s["hit_t"] = fmod(f * DT, 0.5)
				s["hit_k"] = s["hit"]
				s["hit_dir"] = Vector2.from_angle(beat * PI * 0.5)
				s.erase("hit")
			m.set_meta(WardenClips.STATE, s)
			m.global_position += vel * DT
			var look_at := m.global_position + Vector3(0, 1.0, 0)
			cam.global_position = look_at + Vector3(0, sin(deg_to_rad(CAM_PITCH)), cos(deg_to_rad(CAM_PITCH))) * CAM_DIST
			cam.look_at(look_at, Vector3.UP)
			sync.call("_process", DT)
			if f % EVERY != 0 or f < 6:
				continue
			var g := _posed(wc.skel, body)
			for p in wc.parts:
				var part := p as WardenCompanions.Part
				var r := _closest(part, g, body)
				if not worst.has(part.id) or float(r[0]) < float(worst[part.id][0]):
					worst[part.id] = [r[0], r[1], f, r[2]]
			pair = minf(pair, _pair(wc.parts[0], wc.parts[1]))
			var flat := _flat(wc.skel, g, cam)
			for p in wc.parts:
				var sg := _screen_gap(wc.skel, p as WardenCompanions.Part, flat, cam)
				var pid := (p as WardenCompanions.Part).id
				if not screen.has(pid) or sg < float(screen[pid][0]):
					screen[pid] = [sg, f]
		for id in worst:
			var w: Array = worst[id]
			ok(float(w[0]) >= clear_min, "%s: %s clear of her %s by %.0f mm (needs %.0f; frame %d) %s"
					% [st, id, w[1], float(w[0]) * 1000.0, clear_min * 1000.0, w[2], w[3]])
		for id in screen:
			ok(float(screen[id][0]) >= SCREEN_MIN, "%s: %s keeps %.0f mm off her silhouette on screen (needs %.0f; frame %d)"
					% [st, id, float(screen[id][0]) * 1000.0, SCREEN_MIN * 1000.0, screen[id][1]])
		ok(pair >= PAIR_MIN, "%s: the sun and the cloud stay %.0f mm apart (needs %.0f)" % [st, pair * 1000.0, PAIR_MIN * 1000.0])
	m.free()
	_done(main)

func _done(main: Node) -> void:
	print("MEEKOCLIP %d checks, %d failed" % [n, bad])
	print("MEEKOCLIP_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

## The part of her a bone drives: its own or its nearest ancestor's name when that names a body part (L/R kept),
## else the unnamed Bone_nnn chain it hangs on.
func _label(sk: Skeleton3D, bi: int) -> String:
	if labels.has(bi):
		return labels[bi]
	var b := bi
	var lab := ""
	while b >= 0 and lab == "":
		var nm := String(sk.get_bone_name(b))
		for key in KEYS:
			if nm.to_lower().contains(key):
				lab = nm.replace("mixamorig:", "")
				break
		b = sk.get_bone_parent(b)
	if lab == "":
		lab = "%s chain (wing/ear/tail)" % sk.get_bone_name(bi)
	elif String(sk.get_bone_name(bi)).begins_with("Bone_"):
		lab = "%s (via %s)" % [lab, sk.get_bone_name(bi)]
	labels[bi] = lab
	return lab

## The skinned body's every SUB_BODY-th vertex: rest position, its bind indices and weights, its main part.
func _body(sk: Skeleton3D) -> Dictionary:
	var pos := PackedVector3Array()
	var bn: Array = []
	var wt: Array = []
	var binds: Array = []
	var dom := PackedStringArray()
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		var inst := mi as MeshInstance3D
		if inst.skin == null:
			continue
		var base := binds.size()
		for i in inst.skin.get_bind_count():
			var bi := sk.find_bone(inst.skin.get_bind_name(i))
			if bi < 0:
				bi = inst.skin.get_bind_bone(i)
			binds.append([bi, inst.skin.get_bind_pose(i)])
		for si in inst.mesh.get_surface_count():
			var a := inst.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			if v.is_empty() or b.is_empty():
				continue
			var k := b.size() / v.size()   # (4 or 8 influences a vertex)
			for i in range(0, v.size(), SUB_BODY):
				pos.append(v[i])
				var bb := []
				var ww := []
				var top := -1.0
				var tb := base
				for j in k:
					var wj := w[i * k + j]
					if wj > 0.0:
						bb.append(base + b[i * k + j])
						ww.append(wj)
						if wj > top:
							top = wj
							tb = base + b[i * k + j]
				bn.append(bb)
				wt.append(ww)
				dom.append("%s [%s]" % [_label(sk, int(binds[tb][0])), sk.get_bone_name(int(binds[tb][0]))])
	return {"pos": pos, "bn": bn, "wt": wt, "binds": binds, "dom": dom, "n": pos.size()}

## The body's sampled vertices in skeleton space this frame, in a hash grid of [point, index].
func _posed(sk: Skeleton3D, body: Dictionary) -> Dictionary:
	var tf: Array = []
	for b in (body["binds"] as Array):
		tf.append(sk.get_bone_global_pose(int(b[0])) * (b[1] as Transform3D) if int(b[0]) >= 0 else Transform3D.IDENTITY)
	var pos: PackedVector3Array = body["pos"]
	var bn: Array = body["bn"]
	var wt: Array = body["wt"]
	var grid := {}
	for i in pos.size():
		var p := Vector3.ZERO
		var bb: Array = bn[i]
		var ww: Array = wt[i]
		for j in bb.size():
			p += (tf[bb[j]] as Transform3D) * pos[i] * float(ww[j])
		var k := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
		if not grid.has(k):
			grid[k] = []
		grid[k].append([p, i])
	return grid

func _closest(part: WardenCompanions.Part, grid: Dictionary, body: Dictionary) -> Array:
	var best := 0.25 * 0.25
	var who := "(nothing within 0.25 m)"
	var at := ""
	for si in part.node.mesh.get_surface_count():
		var v: PackedVector3Array = part.node.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), SUB_COMP):
			var q := part.node.transform * v[i]
			var k := Vector3i(floori(q.x / CELL), floori(q.y / CELL), floori(q.z / CELL))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var l = grid.get(k + Vector3i(dx, dy, dz))
						if l:
							for e in l:
								var d2 := q.distance_squared_to(e[0])
								if d2 < best:
									best = d2
									who = (body["dom"] as PackedStringArray)[e[1]]
									at = "companion (%.2f %.2f %.2f) body (%.2f %.2f %.2f)" % [q.x, q.y, q.z, e[0].x, e[0].y, e[0].z]
	return [sqrt(best), who, at]

## The nearest the sun's vertices come to the cloud's (every 6th vertex each).
func _pair(a: WardenCompanions.Part, b: WardenCompanions.Part) -> float:
	var vb: Array = []
	for si in b.node.mesh.get_surface_count():
		var v: PackedVector3Array = b.node.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), SUB_COMP * 2):
			vb.append(b.node.transform * v[i])
	var best := 99.0
	for si in a.node.mesh.get_surface_count():
		var v: PackedVector3Array = a.node.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), SUB_COMP * 2):
			var q := a.node.transform * v[i]
			for w: Vector3 in vb:
				best = minf(best, q.distance_to(w))
	return best

## A world point on the match camera's screen plane, in metres at the player's depth (a perspective divide, no pixels).
func _screen(cam: Camera3D, w: Vector3) -> Vector2:
	var r := cam.global_transform.affine_inverse() * w
	var k := CAM_DIST / maxf(-r.z, 0.1)
	return Vector2(r.x, r.y) * k

## The posed body's sampled vertices on screen, in a hash grid of cells SCREEN_MIN wide.
func _flat(sk: Skeleton3D, grid: Dictionary, cam: Camera3D) -> Dictionary:
	var out := {}
	for k in grid:
		for e in grid[k]:
			var q := _screen(cam, sk.global_transform * (e[0] as Vector3))
			var c := Vector2i(floori(q.x / SCREEN_MIN), floori(q.y / SCREEN_MIN))
			if not out.has(c):
				out[c] = []
			out[c].append(q)
	return out

## The nearest any vertex of the part comes to the body on screen (a vertex of the part right on the body counts as 0).
func _screen_gap(sk: Skeleton3D, part: WardenCompanions.Part, flat: Dictionary, cam: Camera3D) -> float:
	var best := 9.0
	for si in part.node.mesh.get_surface_count():
		var v: PackedVector3Array = part.node.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), SUB_COMP):
			var q := _screen(cam, sk.global_transform * (part.node.transform * v[i]))
			var c := Vector2i(floori(q.x / SCREEN_MIN), floori(q.y / SCREEN_MIN))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var l = flat.get(c + Vector2i(dx, dy))
					if l:
						for e: Vector2 in l:
							best = minf(best, q.distance_to(e))
	return best if best < 9.0 else 1.0
