extends RefCounted
## --warden-model-check (concept phase 2: the in-engine Warden models, scripts/heroes/warden_*.gd). For
## each Warden built from its concept sheet: the rig keeps every node the animation and the kits look
## up (and the hero's own weapon anchors); HunterAnim binds every part and each of the hero's keyed
## moves still moves the body; the hit radius and the ring that shows it are the class's, frozen here;
## the true height (sole to the top of the head) and the width sit on the hero sheet's scale against a
## medium hunter; at both ends of every MantleLook slider the height moves no more than the clamps
## allow, the anchors stay and the hit ring doesn't change; the portrait frames the head.

const MANTLE_CHECK := preload("res://tools/mantle_look_check.gd")
const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const EPS := 0.0005
## Per Warden: the hit radius it must keep (m), its height against a medium hunter (hero sheets, "Body,
## scale and movement feel"), its width against a medium (from, to), and the prefix of its keyed moves.
## The heights follow the owner's final height chart (Nov 8, ext/hero-heights) where it moved a Warden off its sheet.
## height_3d: the 3D model's top where something stands over the head the procedural one doesn't have.
const WARDENS := {
	"bulwark": {"hit_r": 0.46, "height": 1.5, "height_3d": 1.9, "width": [1.3, 5.2], "moves": "bul_"},
	"archer": {"hit_r": 0.392, "height": 1.07, "width": [0.5, 1.15], "moves": "arc_"},     # (slim, per her r3 art)
	# gunslinger: Vex is slim and her minigun hugs her hip
	"gunslinger": {"hit_r": 0.416, "height": 1.09, "width": [0.5, 1.15], "moves": "gunslinger_"},   # (slim)
	# (slim and long-legged; height_3d: her v2 rods stand a hand over the head)
	"mage": {"hit_r": 0.4, "height": 1.08, "height_3d": 1.13, "width": [0.6, 1.3], "moves": "mage_"},
	# (Sable v2's moth antennae stand over her head, as on the turnaround)
	"thief": {"hit_r": 0.384, "height": 0.98, "height_3d": 1.1, "width": [0.6, 1.3], "moves": "thf_"},
	# (lean; height_3d: the v2 locs hang down, no piled crown over the head)
	"dolm": {"hit_r": 0.388, "height": 1.09, "height_3d": 1.08, "width": [0.7, 1.5], "moves": "breah_"},
	# (Motley: body size 0.9, owner Nov 4: bigger and more menacing; its sheet's 1.09x was at 0.74)
	# (Motley on his box: the hover came down to a hand's width, Nov 5, so his top is 0.14 m lower; the cards widen him)
	"ostra": {"hit_r": 0.412, "height": 1.18, "height_3d": 1.2, "width": [0.5, 1.6], "moves": "ostra_"},
	# (Claire, the v2 design: the ears stand over her head; at the chart's 0.96x she is slim, as Vex)
	"rimewright": {"hit_r": 0.38, "height": 0.96, "height_3d": 1.06, "width": [0.5, 1.25], "moves": "tm_"},
	# (Cinder v2: her built lizard horns stand over her head; the chart's taller Cinder is wider by as much)
	"ashwick": {"hit_r": 0.376, "height": 1.16, "height_3d": 1.22, "width": [0.7, 1.75], "moves": "as_"},
	# (Kael v2 on his long-legged rig, the owner's height; height_3d: his wild mane over his head)
	"juggernaut": {"hit_r": 0.428, "height": 1.31, "height_3d": 1.32, "width": [1.0, 2.0], "moves": "jug"},
	# (Grimble: the head at his old height, the hoard towers over it)
	"dredge": {"hit_r": 0.452, "height": 1.48, "height_3d": 1.7, "width": [1.3, 2.4], "moves": "dr_"},
	# (Pip's tall fox ears stand over her head; her fairy wings and tail span wider than her body)
	# (Pip: body size 0.68, item 108; v2 model: 0.76 with the ears, the locked design's taller ears)
	"tender": {"hit_r": 0.34, "height": 0.6, "height_3d": 0.76, "width": [0.5, 1.5], "moves": "mm_"},
}
const REF_WEAPON := "gunslinger"   # the reference medium hunter carries the class's default weapon
const ANIM_SEED := 1          # one rest pose for every model measured
const HEIGHT_TOL := 0.04       # the true height within 4% of the sheet's
const ANCHORS := ["Rig/Legs/LegL/Knee", "Rig/Legs/LegR/Knee", "Rig/Torso/HeadPivot/Head", "Rig/Torso/Aim/Gun/Muzzle",
	"Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Torso/ArmRPivot/Elbow/Hand", "Rig/Torso/PauldronL", "Rig/Torso/PauldronR",
	"Rig/Torso/Skirt", "Rig/Torso/Shoulder", "Rig/Torso/Glider", "TeamRing"]
## Nodes a hero's own kit or weapon code finds by name (BjornFx: the hammer pivot under Gun; the prow).
const HERO_ANCHORS := {"bulwark": ["Rig/Torso/ArmLPivot/Elbow/Hand/Shield"]}
const SKIP := ["hammer", "Glider", "Gun", "Shield", "TeamRing"]     # not part of the body's silhouette
## a .glb's floating pieces (warden_parts.crescent, Motley's void orb held up by his head): not headwear
const FLOATING := ["hammer", "Halo", "Orb"]

var bad := 0
var n := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDEN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var ref := _model("", MantleLook.at_home(PlayerLook.neutral()))
	var ref_h := _head_top(ref)
	var ref_w := _body_box(ref).size.x
	print("WARDEN medium reference: head top %.3f m, body %.3f m wide" % [ref_h, ref_w])
	for id in WARDENS:
		_anchors(id)
		_anim(id)
		_hitbox(id)
		_scale(id, ref_h, ref_w)
		_sliders(id)
		_portrait(id)
	print("WARDEN %d checks, %d failed" % [n, bad])
	print("WARDEN_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

## A Warden's model; id "" with an at-home look is the plain medium hunter (no Warden's shape or class
## size) every height is measured against.
func _model(id: String, look: Dictionary) -> Node3D:
	var cls := Arch.weight(id) if id != "" else "medium"
	var m := Models.hunter(cls, Data.TEAM_COLORS[0], Arch.signature(id if id != "" else REF_WEAPON), "", look, id)
	# the rest pose's stance (which leg takes the weight) is seeded per node: fix the seed so every model
	# is measured in the same pose and the size comparisons don't drift from build to build
	m.set_meta("anim_seed", ANIM_SEED)
	HunterAnim.rest_pose(m)
	holder.add_child(m)
	return m

func _anchors(id: String) -> void:
	var m := _model(id, PlayerLook.neutral())
	var want: Array = ANCHORS + HERO_ANCHORS.get(id, [])
	var missing := want.filter(func(p): return not m.has_node(p))
	ok(missing.is_empty(), "%s keeps every node the animation and kits look up (missing %s)" % [id, str(missing)])
	if id == "bulwark":
		var pv: Node3D = null
		for ch in m.get_node("Rig/Torso/Aim/Gun").get_children():
			if ch.has_meta("hammer_pivot"): pv = ch
		ok(
			pv != null and _box(pv).has_point(Vector3(0, 0, -0.62)),
			"%s: the oar's ice head is where BjornFx looks for the hammer head" % id
		)
	m.free()

func _anim(id: String) -> void:
	var m := _model(id, PlayerLook.neutral())
	var an := HunterAnim.new(m)
	var parts := {"head": an.head, "aim": an.aim, "gun": an.gun, "hand_l": an.hand_l, "hand_r": an.hand_r,
		"pad_l": an.pad_l, "pad_r": an.pad_r, "skirt": an.skirt}
	var unbound := parts.keys().filter(func(k): return parts[k] == null)
	ok(unbound.is_empty(), "%s: HunterAnim binds every part (unbound %s)" % [id, str(unbound)])
	var rest := _pose(an, m, "", 0.0)
	var still: Array = []
	var moves: Array = []
	for t in [HunterAnim.KMOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES, KMovesVV.MOVES, KMovesStone.MOVES,
			KMovesCare.MOVES, KMovesPair.MOVES]:
		for mv in t:
			if String(mv).begins_with(WARDENS[id]["moves"]): moves.append(mv)
	for mv in moves:
		var keys: Array = HunterAnim.km_def(mv)["keys"]
		var most := 0.0
		for k in keys:
			var p := _pose(an, m, mv, float(k[0]))
			for i in p.size():
				most = maxf(most, (p[i] as Vector3).distance_to(rest[i]))
		if most < 0.02:
			still.append(mv)
	ok(
		not moves.is_empty() and still.is_empty(),
		"%s: each of its %d keyed moves moves the hands or the body (still: %s)"
			% [id, moves.size(), str(still)])
	m.free()

## The hands, the head and the torso after driving the move to time tt.
func _pose(an: HunterAnim, m: Node3D, mv: String, tt: float) -> Array:
	for k in 30:
		an.update(1.0 / 60.0, {"fired": 99.0, "face": 0.0, "grounded": true, "kmove": mv, "kmove_t": tt})
	var torso := m.get_node("Rig/Torso") as Node3D
	return [an.hand_l.global_position, an.hand_r.global_position, an.head.global_position,
		torso.global_transform.basis * Vector3.FORWARD]

func _hitbox(id: String) -> void:
	var cdat: Dictionary = Data.CLASSES[Arch.weight(id)]
	var hr := Arch.hit_r(id, cdat)
	ok(
		absf(hr - float(WARDENS[id]["hit_r"])) < EPS,
		"%s: hit radius %.2f m, the class's (%.2f)" % [id, hr, WARDENS[id]["hit_r"]]
	)
	var m := _model(id, PlayerLook.neutral())
	var ring := m.get_node("TeamRing") as MeshInstance3D
	var drawn := (ring.mesh as PlaneMesh).size.x * 0.5 * ring.global_transform.basis.x.length()
	ok(absf(drawn - hr) < 0.005, "%s: the ring under its feet shows that radius (%.3f)" % [id, drawn])
	m.free()

func _scale(id: String, ref_h: float, ref_w: float) -> void:
	var m := _model(id, PlayerLook.neutral())
	var h := _head_top(m) / ref_h
	var w := _body_box(m).size.x / ref_w
	var want := float(WARDENS[id]["height"])
	ok(absf(h - want) <= HEIGHT_TOL, "%s stands %.3fx a medium hunter (sheet %.2fx)" % [id, h, want])
	if m.has_node("Warden"):
		var hg := _glb_top(m) / ref_h
		var want3 := float(WARDENS[id].get("height_3d", want))
		ok(absf(hg - want3) <= HEIGHT_TOL, "%s's 3D model stands %.3fx a medium hunter, headwear and all (sheet %.2fx)"
				% [id, hg, want3])
	var span: Array = WARDENS[id]["width"]
	ok(
		w >= float(span[0]) and w <= float(span[1]),
		"%s is %.2fx a medium hunter's width (%.2f to %.2f)" % [id, w, span[0], span[1]]
	)
	m.free()

func _sliders(id: String) -> void:
	var w := MantleLook.warden(id)
	var m0 := _model(id, PlayerLook.neutral())
	var h0 := _head_top(m0)
	var ring0 := (m0.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
	# the height slider scales the whole model; leg length scales the legs' share of it, head size and
	# jaw the head's (and a bigger head sits a little higher on its pivot: the small margin)
	var leg_share := ((m0.get_node("Rig/Torso") as Node3D).global_position.y - m0.global_position.y) / h0
	var head := m0.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
	var head_share := (head.global_transform * head.mesh.get_aabb()).size.y / h0
	var c: Dictionary = w["clamp"]
	var grow := 1.0 + float(c["limbs"]) * leg_share + (float(c["head"]) + float(c["jaw"])) * head_share
	var reach := (1.0 + float(c["height"])) * grow - 1.0 + 0.012
	var g0 := _glb_top(m0) if m0.has_node("Warden") else 0.0
	m0.free()
	for v in [0.0, 1.0]:
		var m := _model(id, MANTLE_CHECK.flat(v))
		if m.has_node("Warden"):
			var hg := _glb_top(m) / g0
			# the sliders reshape the 3D model too (its bones follow the rig's move from the neutral look)
			ok(absf(hg - 1.0) <= reach and absf(hg - 1.0) > 0.02,
					"%s's 3D model: sliders at %d change its height within the clamps (%.3fx, at most ±%.3f)"
					% [id, int(v), hg, reach])
		var h := _head_top(m) / h0
		var ring := (m.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
		var missing := ANCHORS.filter(func(p): return not m.has_node(p))
		ok(absf(h - 1.0) <= reach and absf(ring - ring0) < EPS and missing.is_empty(),
				"%s: sliders at %d keep the height in the clamps (%.3fx, at most ±%.3f), the hit ring, the anchors"
				% [id, int(v), h, reach])
		m.free()

## Portraits frame the head (Portraits.head_at); the point must sit inside the head itself.
func _portrait(id: String) -> void:
	var m := _model(id, PlayerLook.neutral())
	var at := Portraits.head_at(m)
	var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
	var hb := head.global_transform * head.mesh.get_aabb()
	ok(hb.grow(0.02).has_point(m.global_position + at), "%s: the portrait frames its head" % id)
	m.free()

func _head_top(m: Node3D) -> float:
	var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
	return (head.global_transform * head.mesh.get_aabb()).end.y - m.global_position.y

## The top of a .glb Warden as skinned in its current pose (every vertex through its bones), above its feet.
func _glb_top(m: Node3D) -> float:
	(m.get_node("Warden/Sync") as WardenGlb.Sync).apply()
	var top := -INF
	for nd in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		if String(nd.get_parent().name).begins_with(WardenGlb.Orbits.PREFIX) or String(nd.name) in FLOATING:
			continue        # (floating props, Tarek's stones and Motley's halo: not the height)
		for p in WARDEN_SKIN.points(nd as MeshInstance3D):
			top = maxf(top, p.y)
	return top - m.global_position.y

## The body's bounds in world space, leaving out the weapon, the shield, the glider and the ring.
func _body_box(m: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [m]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if String(nd.name) in SKIP:
			continue
		if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null and (nd as Node3D).is_visible_in_tree():
			var mi := nd as MeshInstance3D
			var b := mi.global_transform * mi.mesh.get_aabb()
			if mi.skin:           # a 3D Warden: its posed vertices (the mesh box is the rest pose's)
				var pts := WARDEN_SKIN.points(mi)
				b = AABB(pts[0], Vector3.ZERO)
				for p in pts:
					b = b.expand(p)
			out = b if first else out.merge(b)
			first = false
		stack.append_array(nd.get_children())
	return out

## A node's meshes' bounds in its own space.
func _box(nd: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for ch in nd.get_children():
		if ch is MeshInstance3D:
			var b := (ch as MeshInstance3D).transform * (ch as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
	return out
