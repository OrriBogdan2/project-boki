class_name WardenFx
extends RefCounted
## A model's smoke and bloom off its held weapon (warden_look.json), split out of WardenGlb.

## A model's wisps of smoke off its held weapon (warden_look.json "smoke": colour [r, g, b, a], amount, life (s),
## size (m), rise (m/s); Kael's demon blade): dark soft puffs from along the weapon's length that drift up and
## fade, in world space so they trail behind a swing.
static func smoke(root: Node3D, own: Dictionary) -> void:
	var sm: Dictionary = own.get("smoke", {})
	var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	var weapon := gun.get_node_or_null(WardenGlb.WEAPON) as Node3D if gun else null
	# (a skinned weapon: "at" names an anchor on it, "box" the half size round that anchor)
	var at_anchor := WardenGlb.anchor(root, String(sm.get("at", ""))) if sm.has("at") else null
	if sm.is_empty() or (weapon == null and at_anchor == null):
		return
	var box := AABB()
	var meshes: Array = []
	if weapon is MeshInstance3D:
		meshes.append(weapon)
	if weapon:
		meshes.append_array(weapon.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		var a := (mi as MeshInstance3D).get_aabb()
		box = a if box.size == Vector3.ZERO else box.merge(a)
	if at_anchor:
		var half := float(sm.get("box", 0.2))
		box = AABB(Vector3.ONE * -half, Vector3.ONE * half * 2.0)
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = int(sm.get("amount", 16))
	p.lifetime = float(sm.get("life", 1.4))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# (along the blade only: the weapon's box past its grip end, `from` of its length)
	var k := float(sm.get("from", 0.3))
	var ax := 0
	for i in 3:
		if box.size[i] > box.size[ax]:
			ax = i
	var c := box.get_center()
	var ext := box.size * 0.5
	c[ax] += ext[ax] * k
	ext[ax] *= 1.0 - k
	p.position = c
	p.emission_box_extents = ext * 0.8
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, float(sm.get("rise", 0.5)), 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = curve
	var col := WardenGlb._param(sm.get("color", [0.05, 0.04, 0.05, 0.45])) as Color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.set_color(1, Color(col, 0.0))
	ramp.add_point(0.25, col)
	ramp.add_point(0.6, Color(col, col.a * 0.6))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	var sz := float(sm.get("size", 0.12))
	q.size = Vector2(sz, sz)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(at_anchor if at_anchor else weapon).add_child(p)

## A model's soft glow around what burns (warden_look.json "bloom": a list of {at: "weapon" or an anchor name,
## color [r, g, b, a], size (m), count (along the weapon's length, or from the anchor to the anchor `to`
## on the same bone: a skinned blade; from `from` of it), depth_test}): additive
## camera-facing puffs, so a white-hot blade core or a magma arm glows past its own edges like the art's bloom
## instead of reading as flat white paint. World-sized, so it shrinks with the model at the match camera.
static func bloom(root: Node3D, glb: Node3D, own: Dictionary) -> void:
	for b in own.get("bloom", []):
		var at := String(b.get("at", "weapon"))
		var col := WardenGlb._param(b.get("color", [1.0, 0.9, 0.7, 0.35])) as Color
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = not bool(b.get("depth_test", false))
		m.albedo_color = col
		m.albedo_texture = _puff()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var sz := float(b.get("size", 0.2))
		if at == "weapon":
			var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
			var weapon := gun.get_node_or_null(WardenGlb.WEAPON) as Node3D if gun else null
			if weapon == null or not weapon is MeshInstance3D:
				continue
			var box := (weapon as MeshInstance3D).get_aabb()
			var ax := 0
			for i in 3:
				if box.size[i] > box.size[ax]:
					ax = i
			var n := int(b.get("count", 5))
			var k0 := float(b.get("from", 0.35))
			for j in n:
				var p := box.get_center()
				p[ax] = box.position[ax] + box.size[ax] * lerpf(k0, 0.95, (j + 0.5) / n)
				weapon.add_child(_bloom_quad(m, sz, p))
		else:
			var a := glb.find_child(at, true, false) as Node3D
			if a == null:
				continue
			var to := glb.find_child(String(b.get("to", "")), true, false) as Node3D if b.has("to") else null
			var n := int(b.get("count", 1)) if to else 1
			for j in n:
				# (on the root, following the anchor like the halos: the model's own surfaces stay toon-only)
				var q := _bloom_quad(m, sz, Vector3.ZERO)
				root.add_child(q)
				var follow := RemoteTransform3D.new()
				follow.name = "BloomFollow"
				follow.update_scale = false
				follow.update_rotation = false
				if to:      # (both ride one bone: the step between them is fixed in the anchor's frame)
					var step := (a.transform.affine_inverse() * to.transform).origin
					follow.position = step * lerpf(float(b.get("from", 0.0)), 1.0, (j + 0.5) / n)
				a.add_child(follow)
				follow.remote_path = follow.get_path_to(q)

static func _bloom_quad(m: Material, sz: float, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Bloom"
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.set_meta("glb_hidden", true)      # (kept out of the model's own bounds, like the hidden procedural parts)
	return mi

static var _puff_tex: Texture2D
## A soft round puff (a radial fall-off), made once.
static func _puff() -> Texture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff_tex = t
	return _puff_tex
