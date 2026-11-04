class_name FarmBuildUi
extends RefCounted
## Build mode's extras for the farm building pass: the footprint outline and snapping grid round the
## ghost, the reason a spot is refused floating over it, the pop when something lands, and the
## entries for the Upgrades tab. HomeBuild calls these from a few places.

const GRID_R := 3                         # tiles of snapping grid shown round the ghost

## How many of the ghost's extras of one kind ("outline", "grid", "note") are live (tooling).
static func count(root: Node3D, kind: String) -> int:
	var n := 0
	for c in root.get_children():
		if c.get_meta("fbui", "") == kind and not c.is_queued_for_deletion(): n += 1
	return n

## Thin box edges round the footprint (green when it fits, red when not) and a faint grid round it.
static func outline(root: Node3D, cells: Array, ok: bool) -> void:
	if cells.is_empty() or not is_instance_valid(root):
		return
	var x0 := 9999; var z0 := 9999; var x1 := -9999; var z1 := -9999
	for t in cells:
		x0 = mini(x0, t.x); z0 = mini(z0, t.y); x1 = maxi(x1, t.x); z1 = maxi(z1, t.y)
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = Color(0.7, 1.0, 0.75, 0.95) if ok else Color(1.0, 0.5, 0.42, 0.95)
	line.no_depth_test = true
	var w := 0.1
	var xa := float(x0); var xb := float(x1 + 1); var za := float(z0); var zb := float(z1 + 1)
	for seg in [[xa, za, xb, za], [xa, zb, xb, zb], [xa, za, xa, zb], [xb, za, xb, zb]]:
		var horiz: bool = seg[1] == seg[3]
		var ln: float = (seg[2] - seg[0]) if horiz else (seg[3] - seg[1])
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(ln + w, 0.03, w) if horiz else Vector3(w, 0.03, ln + w)
		mi.mesh = bm; mi.material_override = line
		mi.position = Vector3((seg[0] + seg[2]) * 0.5, 0.09, (seg[1] + seg[3]) * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("fbui", "outline")
		root.add_child(mi)
	# the snapping grid: tile edges a few tiles out from the footprint, fading with distance
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.16)
	for gx in range(x0 - GRID_R, x1 + GRID_R + 2):
		var m1 := MeshInstance3D.new()
		var b1 := BoxMesh.new(); b1.size = Vector3(0.02, 0.01, float(z1 - z0 + 1 + GRID_R * 2))
		m1.mesh = b1; m1.material_override = gm
		m1.position = Vector3(gx, 0.055, (z0 - GRID_R + z1 + 1 + GRID_R) * 0.5)
		m1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m1.set_meta("fbui", "grid")
		root.add_child(m1)
	for gz in range(z0 - GRID_R, z1 + GRID_R + 2):
		var m2 := MeshInstance3D.new()
		var b2 := BoxMesh.new(); b2.size = Vector3(float(x1 - x0 + 1 + GRID_R * 2), 0.01, 0.02)
		m2.mesh = b2; m2.material_override = gm
		m2.position = Vector3((x0 - GRID_R + x1 + 1 + GRID_R) * 0.5, 0.055, gz)
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m2.set_meta("fbui", "grid")
		root.add_child(m2)

## The reason a spot is refused, floating above the footprint. "" removes it.
static func note(root: Node3D, cells: Array, text: String, col := Color("ffb0a0")) -> void:
	if not is_instance_valid(root):
		return
	for old in root.get_children():
		if old.get_meta("fbui", "") == "note": old.queue_free()
	if text == "" or cells.is_empty():
		return
	var l := Label3D.new()
	l.set_meta("fbui", "note")
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.012
	l.outline_size = 16
	l.modulate = col
	l.outline_modulate = Color(0.1, 0.05, 0.05, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 3
	var c: Vector2i = cells[0]
	l.position = Vector3(c.x + 0.5, 1.7, c.y + 0.5)
	root.add_child(l)

## A little squash and settle on a node that was just placed.
static func pop(n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	var s := n.scale
	n.scale = s * Vector3(1.0, 0.55, 1.0)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", s * Vector3(1.0, 1.12, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", s, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ bar entries
## The Upgrades tab: one entry per standing building that has a next tier.
static func upgrade_entries(hb: HomeBuild) -> Array:
	var out: Array = []
	for e in HomeLayout.of(Save.d)["deco"]:
		var id := String(e["id"])
		if FarmSites.is_site(e) or not (FarmSites.rules()["upgradable"] as Array).has(id):
			continue
		var uid := int(e["u"])
		var t := FarmSites.tier(e)
		var nm := String(HomeLayout.CATALOG[id]["name"])
		if FarmSites.is_upgrading(e):
			out.append({"name": nm, "note": "Upgrading %d%%" % int(FarmSites.progress(e) * 100.0), "glyph": "hammer",
				"cb": func(): pass, "off": true, "tip": "Boki are building the next tier"})
			continue
		var cost := FarmSites.upgrade_cost(id, t + 1)
		if cost.is_empty():
			out.append({"name": nm, "note": "Tier %d (best)" % t, "glyph": "hammer", "cb": func(): pass, "off": true,
				"tip": "Fully upgraded"})
			continue
		var lock := FarmUnlocks.gated() and FarmUnlocks.level() < int(cost.get("level", 1))
		var note := "Tier %d to %d" % [t, t + 1]
		if lock:
			note = "Needs farm level %d" % int(cost.get("level", 1))
		out.append({"name": nm, "note": note, "glyph": "hammer", "cb": func(): hb.upgrade(uid), "off": lock,
			"cost": {} if lock else cost,
			"tip": "Upgrade the %s to tier %d: %s. Boki do the building; it keeps working meanwhile." % [
				nm.to_lower(), t + 1, FarmSites.cost_text(cost)]})
	return out
