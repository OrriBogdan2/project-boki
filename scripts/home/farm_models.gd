class_name FarmModels
extends RefCounted
## How the farm's construction looks (docs/decisions/0004-farm-building.md): the scaffolded site with
## a progress bar, and the look of a building at tier 2 and 3 (a stone plinth and a pennant; gold
## trim, glowing corner lanterns and a taller pennant). Built from simple parts like the rest of
## the farm's models. HomeBuild.make_deco calls site() / dress(); FarmSites.tick keeps the bar current.

const BAR_W := 64
const BAR_H := 9

static func _size(id: String) -> Vector2:
	var s: Array = HomeLayout.CATALOG.get(id, {}).get("size", [1, 1])
	return Vector2(float(s[0]), float(s[1]))

## The stages the scaffold's rising walls come in (a rebuild each time, so the bar moves in between).
static func stage_of(e: Dictionary) -> int:
	return clampi(int(floor(FarmSites.progress(e) * 4.0)), 0, 3)

## A signature for HomeBuild._sig: changes when the look should be rebuilt.
static func sig(e: Dictionary) -> String:
	return "t%d|%s|%d" % [FarmSites.tier(e), "u" if FarmSites.is_upgrading(e) else ("s" if FarmSites.is_site(e) else "-"), stage_of(e)]

# ------------------------------------------------------------------ the site
## A building going up: posts and rails round its footprint, planks and a crate, walls that rise by stage.
static func site(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	var sz := _size(String(e["id"]))
	var wood := Models.toon(Color("a8794a"))
	var dark := Models.toon(Color("6b4a2e"))
	var pale := Models.toon(Color("d9bd8a"))
	var st := stage_of(e)
	Models.part(n, Models.box(sz.x + 0.14, 0.07, sz.y + 0.14), Models.toon(Color("8a7458")), Vector3(0, 0.035, 0), Vector3.ONE, Vector3.ZERO, "Plinth")
	# the walls so far
	var hgt: float = [0.18, 0.5, 0.85, 1.1][st]
	Models.part(n, Models.box(maxf(0.4, sz.x - 0.35), hgt, maxf(0.4, sz.y - 0.35)), pale, Vector3(0, 0.07 + hgt * 0.5, 0), Vector3.ONE, Vector3.ZERO, "Rise")
	if st >= 3:
		Models.part(n, Models.box(sz.x - 0.1, 0.1, sz.y - 0.1), dark, Vector3(0, 1.22, 0), Vector3.ONE, Vector3.ZERO, "Roofboards")
	_frame(n, sz, wood, dark)
	# a stack of planks and a crate beside it
	for i in 3:
		Models.part(n, Models.box(0.7, 0.06, 0.16), wood, Vector3(sz.x * 0.5 + 0.3, 0.1 + i * 0.07, -sz.y * 0.5 + 0.2 + (i % 2) * 0.02), Vector3.ONE, Vector3(0, 0.06 * i, 0))
	Models.part(n, Models.box(0.3, 0.3, 0.3), dark, Vector3(sz.x * 0.5 + 0.35, 0.15, -sz.y * 0.5 + 0.6), Vector3.ONE, Vector3(0, 0.4, 0))
	_bar(n, e, 1.9)
	return n

## Just the scaffolding poles and bar over a building that is being upgraded.
static func upgrade_frame(n: Node3D, e: Dictionary) -> void:
	var sz := _size(String(e["id"]))
	_frame(n, sz, Models.toon(Color("a8794a")), Models.toon(Color("6b4a2e")))
	_bar(n, e, maxf(2.4, 1.2 + sz.x * 0.2))

static func _frame(n: Node3D, sz: Vector2, wood: Material, dark: Material) -> void:
	var hx := sz.x * 0.5 + 0.05
	var hz := sz.y * 0.5 + 0.05
	var top := 1.5
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			Models.part(n, Models.box(0.08, top, 0.08), dark, Vector3(sx * hx, top * 0.5, sy * hz))
	for sy in [-1.0, 1.0]:
		Models.part(n, Models.box(hx * 2.0, 0.06, 0.06), wood, Vector3(0, top, sy * hz))
		Models.part(n, Models.box(hx * 2.0, 0.05, 0.05), wood, Vector3(0, top * 0.55, sy * hz))
	for sx in [-1.0, 1.0]:
		Models.part(n, Models.box(0.06, 0.06, hz * 2.0), wood, Vector3(sx * hx, top, 0))
	# a diagonal brace on the front
	var ang := atan2(top * 0.45, hx * 2.0)
	Models.part(n, Models.box(sqrt(pow(hx * 2.0, 2.0) + pow(top * 0.45, 2.0)), 0.045, 0.045), wood, Vector3(0, top * 0.775, hz), Vector3.ONE, Vector3(0, 0, ang))

static func _bar(n: Node3D, e: Dictionary, y: float) -> void:
	var sp := Sprite3D.new()
	sp.name = "Bar"
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.render_priority = 2
	sp.pixel_size = 0.022
	sp.position = Vector3(0, y, 0)
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	n.add_child(sp)
	set_bar(n, e)

## Redraws the bar for the entry's progress, with `live` extra (the swing in hand, 0..1 of a swing).
static func set_bar(n: Node3D, e: Dictionary, live := 0.0) -> void:
	var sp := n.get_node_or_null("Bar") as Sprite3D
	if sp == null or not FarmSites.has_site(e):
		return
	var s: Dictionary = e["site"]
	var p := clampf((float(s["got"]) + clampf(live, 0.0, 1.99)) / maxf(1.0, float(s["need"])), 0.0, 1.0)
	var key := int(p * 200.0)
	if int(sp.get_meta("k", -1)) == key:
		return
	sp.set_meta("k", key)
	var img := Image.create(BAR_W, BAR_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.07, 0.1, 0.92))
	var col := Color("f2c84a") if bool(s.get("up", false)) else Color("8fd16a")
	var fill := int(round((BAR_W - 4) * p))
	for x in range(2, 2 + fill):
		for y in range(2, BAR_H - 2):
			img.set_pixel(x, y, col.lightened(0.15) if y == 2 else col)
	for x in BAR_W:
		img.set_pixel(x, 0, Color(1, 1, 1, 0.5)); img.set_pixel(x, BAR_H - 1, Color(1, 1, 1, 0.3))
	for y in BAR_H:
		img.set_pixel(0, y, Color(1, 1, 1, 0.4)); img.set_pixel(BAR_W - 1, y, Color(1, 1, 1, 0.4))
	sp.texture = ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ tiers
## Tier 2 and 3 show on the building: a plinth and a pennant, then gold trim and corner lanterns.
static func dress(n: Node3D, e: Dictionary) -> Node3D:
	var t := FarmSites.tier(e)
	var id := String(e["id"])
	if n == null or t < 2 or FarmSites.is_site(e):
		return n
	var sz := _size(id)
	var stone := Models.toon(Color("b9b2a6"))
	var gold := Models.toon(Color("f2c84a"))
	var hx := sz.x * 0.5 + 0.08
	var hz := sz.y * 0.5 + 0.08
	var d := Node3D.new()
	d.name = "Tier"
	Models.part(d, Models.box(hx * 2.0, 0.07, hz * 2.0), gold if t >= 3 else stone, Vector3(0, 0.03, 0), Vector3.ONE, Vector3.ZERO, "Plinth")
	Models.part(d, Models.box(hx * 2.0 - 0.14, 0.09, hz * 2.0 - 0.14), stone, Vector3(0, 0.05, 0))
	# the pennant at the back left corner (so it never hides the front)
	var ph := 1.9 if t == 2 else 2.6
	var pc := Models.toon(Color("5ab0f0") if t == 2 else Color("f2c84a"), true, 0.0 if t == 2 else 0.5)
	Models.part(d, Models.cyl(0.03, 0.04, ph, 8), Models.toon(Color("6b4a2e")), Vector3(-hx + 0.05, ph * 0.5, -hz + 0.05))
	Models.part(d, Models.box(0.5, 0.28, 0.025), pc, Vector3(-hx + 0.3, ph - 0.2, -hz + 0.05), Vector3.ONE, Vector3(0, 0, -0.08))
	if t >= 3:
		Models.part(d, Models.sphere(0.08, 8), Models.toon(Color("fff2b0"), false, 1.0), Vector3(-hx + 0.05, ph + 0.06, -hz + 0.05))
		for sx in [-1.0, 1.0]:
			var post := Vector3(sx * hx, 0, hz)
			Models.part(d, Models.box(0.07, 0.62, 0.07), Models.toon(Color("6b4a2e")), post + Vector3(0, 0.31, 0))
			Models.part(d, Models.sphere(0.12, 8), Models.toon(Color("ffd36a"), false, 1.2), post + Vector3(0, 0.7, 0))
			var lt := OmniLight3D.new()
			lt.light_color = Color("ffd9a8"); lt.light_energy = 0.35; lt.omni_range = 2.2; lt.position = post + Vector3(0, 0.7, 0)
			d.add_child(lt)
	n.add_child(d)
	return n

## "Needs 2 more wood" over a site that is waiting for materials (hidden when it is not).
static func set_need(n: Node3D, e: Dictionary) -> void:
	var bar := n.get_node_or_null("Bar") as Sprite3D
	if bar == null:
		return
	var text := FarmSites.need_text(e)
	var tag := n.get_node_or_null("Need") as Label3D
	if text == "":
		if tag:
			tag.visible = false
		return
	if tag == null:
		tag = Label3D.new()
		tag.name = "Need"
		tag.font_size = 44
		tag.pixel_size = 0.01
		tag.outline_size = 14
		tag.modulate = Color("ffd36a")
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.render_priority = 3
		tag.position = bar.position + Vector3(0, 0.38, 0)
		n.add_child(tag)
	tag.text = text
	tag.visible = true

## Every frame at home: the bars on the sites follow the swings in progress (HomeWork.tick).
static func tick_bars(hw) -> void:
	if hw.h.hb == null:
		return
	var live := {}
	var swing: Dictionary = hw.h.hob.live() if hw.h.hob else {}
	if not swing.is_empty():
		live[int(swing["u"])] = float(swing["k"])
	for k in hw.h.kins:
		if k.has("job") and String(k["job"].get("kind", "")) == "build" and String(k["job"].get("phase", "")) == "work":
			var J: Dictionary = k["job"]
			live[int(J["u"])] = float(live.get(int(J["u"]), 0.0)) + 1.0 - float(J["left"]) / maxf(0.01, float(J["dur"]))
	for e in FarmSites.sites():
		var n: Node3D = hw.h.hb.nodes.get(int(e["u"]))
		if is_instance_valid(n):
			set_bar(n, e, float(live.get(int(e["u"]), 0.0)))
			set_need(n, e)
