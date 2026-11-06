class_name FarmHob
extends RefCounted
## Hob Brackenridge in the world (home.gd owns one): he turns up beside the house once it is down,
## you press interact to talk and get new blueprints (FarmBuilder), and a mark floats over him while
## some are waiting. Holding the same interact key hammers a house or building going up, beat after
## beat, when the tutorial option player_swing is on; your Boki nearby come and help, and the
## materials are spent as it goes (FarmSites).

var h
var node: Node3D = null
var mark: Label3D = null
var arm: Node3D = null
var t := 0.0
var poll_t := 0.0
var site_u := -1                 # the construction site you are hammering (deco uid)
var pos := Vector3.INF

const SITE_REACH := 2.2     # m beyond the site's half-size you can keep hammering from

func _init(home) -> void:
	h = home

func rules() -> Dictionary:
	return FarmBuilder.rules()

## Where he stands: in front of the house and off to its right, clear of the door. INF without a house.
func stand_at() -> Vector3:
	var e := house_entry()
	if e.is_empty():
		return Vector3.INF
	var face: Vector3 = HomeLayout.facing(int(e.get("r", 0)))
	var side := Vector3(-face.z, 0, face.x)
	var st: Dictionary = rules()["stand"]
	return HomeLayout.deco_center(e) + face * float(st["along"]) + side * float(st["side"])

static func house_entry() -> Dictionary:
	for e in HomeLayout.of(Save.d).get("deco", []):
		if String(e.get("id", "")) == "house":
			return e
	return {}

## Puts him beside the house (or takes him away when there is none). home.gd calls it when the layout changes.
func sync() -> void:
	if not FarmUnlocks.gated() or not h.visit.is_empty():
		return
	pos = stand_at()
	if pos.x == INF:
		if is_instance_valid(node):
			node.queue_free()
		node = null
		return
	if not is_instance_valid(node):
		node = _make_model()
		h.add_child(node)
	node.position = pos
	var e := house_entry()
	var face: Vector3 = HomeLayout.facing(int(e.get("r", 0)))
	node.rotation.y = atan2(face.x, face.z)      # looks back at the house door

func tick(dt: float) -> void:
	t += dt
	_hammer(dt)
	if not is_instance_valid(node):
		return
	if arm:
		var tapping := fmod(t, 7.0) < 2.8
		arm.rotation.x = -0.9 + (maxf(0.0, sin(t * 2.2)) * 0.9 if tapping else 0.0)
	if mark:
		mark.visible = FarmBuilder.pending().size() > 0
		mark.position.y = 2.75 + sin(t * 3.0) * 0.08
	poll_t -= dt
	if poll_t <= 0.0:
		poll_t = 1.0
		if FarmBuilder.toast_due():
			h._toast(String(rules()["toast"]))
			Sfx.play("unlock", node.position, -8.0)

# ------------------------------------------------------------------ interaction
## The thing to interact with near the player, or {}: Hob, or a site you can help build.
func find(p2: Vector2) -> Dictionary:
	if not h.visit.is_empty() or not FarmUnlocks.gated():
		return {}
	if is_instance_valid(node) and p2.distance_to(Vector2(pos.x, pos.z)) < float(rules()["talk_reach"]):
		return {"kind": "hob"}
	if not swing_on():
		return {}
	for e in FarmSites.sites():
		if FarmSites.is_site(e):
			var c := HomeLayout.deco_center(e)
			var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
			if p2.distance_to(Vector2(c.x, c.z)) < maxf(sz.x, sz.y) * 0.5 + 1.8:
				return {"kind": "site", "u": int(e["u"])}
	return {}

func swing_on() -> bool:
	return bool(FarmTutorial.option("player_swing"))

func label(it: Dictionary) -> String:
	if String(it["kind"]) == "hob":
		var n := FarmBuilder.pending().size()
		return "Talk to %s%s" % [FarmBuilder.short_name(), (" (%d new blueprints)" % n) if n > 0 else ""]
	var e := FarmSites.entry(int(it["u"]))
	if e.is_empty():
		return ""
	var need := FarmSites.need_text(e)
	if need != "":
		return need
	var nm := String(HomeLayout.CATALOG[String(e["id"])]["name"]).to_lower()
	return "Hold to hammer the %s (%d/%d)" % [nm, int(e["site"]["got"]), int(e["site"]["need"])]

func use(it: Dictionary) -> void:
	if String(it["kind"]) == "hob":
		talk()
		return
	var e := FarmSites.entry(int(it["u"]))
	if e.is_empty() or not FarmSites.has_site(e) or h.tw.active():
		return
	var need := FarmSites.need_text(e)
	if need != "":
		h._toast(need)
		return
	site_u = int(e["u"])
	h.tw.begin("hammer", HomeLayout.deco_center(e), _land_swing, HunterTool.period("hammer") * 0.4)
	FarmSites.call_helpers(h.hw, e)

## The hammer comes down on the site: one swing of labour. False when the build is done or waiting.
func _land_swing() -> bool:
	var e := FarmSites.entry(site_u)
	if e.is_empty() or not FarmSites.has_site(e):
		return false
	FarmSites.player_swing(h.hw, e)
	FarmTutorial.event("swing")
	h._refresh_top()
	e = FarmSites.entry(site_u)
	if e.is_empty() or not FarmSites.has_site(e):
		return false
	var need := FarmSites.need_text(e)
	if need != "":
		h._toast(need)
		return false
	return true

## Every frame: keeps the hammering going while you hold the key and stay at the site.
func _hammer(dt: float) -> void:
	if h.tw.tool != "hammer":
		site_u = -1
		return
	var e := FarmSites.entry(site_u)
	var at := Vector2(h.ppos.x, h.ppos.z)
	var away := e.is_empty() or at.distance_to(Vector2(h.tw.target.x, h.tw.target.z)) > _reach(e)
	var walking := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).length() > 0.2
	if away or walking or h.panel_open != "":
		h.tw.stop()
		return
	h.tw.tick(dt, h.tw.held())

## How far from the middle of a site you can keep hammering (the same reach as finding it).
func _reach(e: Dictionary) -> float:
	var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
	return maxf(sz.x, sz.y) * 0.5 + SITE_REACH

## The swing in progress on a site, for its bar: {u, k} with k the share of the swing done (else {}).
func live() -> Dictionary:
	if h.tw.tool != "hammer" or site_u < 0:
		return {}
	var period := HunterTool.period("hammer")
	return {"u": site_u, "k": clampf(h.tw.swing_t / (period * HunterTool.IMPACT), 0.0, 1.0)}

func talk() -> void:
	var first := not bool(FarmBuilder.state().get("met", false))
	var ids := FarmBuilder.draw_up()
	Save.save_game()
	FarmTutorial.event("hob")
	var v: VBoxContainer = h._new_panel(FarmBuilder.full_name(), 540)
	UI.subtitle(v, "Builder")
	v.add_child(UI.para(FarmBuilder.line_for(ids, first), UI.T_BODY + 1, UI.INK))
	if not ids.is_empty():
		var names: Array = ids.map(func(i): return FarmUnlocks.name_of(String(i)))
		v.add_child(UI.para("New blueprints: " + ", ".join(names), UI.T_BODY, UI.GOLD))
	else:
		v.add_child(UI.para(String(rules()["menu_hint_empty"]), UI.T_SMALL, UI.MUTED))
	UI.footer_primary(v, "Open the build menu", func():
		h._close_panel()
		if h.hb and not h.hb.active:
			h.hb.toggle(), 200)
	if h.guide:
		h.guide.refresh()

# ------------------------------------------------------------------ the model
func _part(shape: Mesh, col: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m

func _make_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Hob"
	root.scale = Vector3.ONE * 1.25
	var body := CapsuleMesh.new()
	body.radius = 0.42
	body.height = 1.3
	_part(body, Color("b8432c"), Vector3(0, 0.85, 0), root)
	var apron := BoxMesh.new()
	apron.size = Vector3(0.55, 0.7, 0.08)
	_part(apron, Color("e9dcc0"), Vector3(0, 0.8, -0.38), root)
	var belt := CylinderMesh.new()
	belt.top_radius = 0.44
	belt.bottom_radius = 0.44
	belt.height = 0.1
	_part(belt, Color("2e2118"), Vector3(0, 0.72, 0), root)
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	_part(head, Color("e8bf98"), Vector3(0, 1.7, 0), root)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.6
	brim.bottom_radius = 0.6
	brim.height = 0.05
	_part(brim, Color("4a3220"), Vector3(0, 1.9, 0), root)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.24
	crown.bottom_radius = 0.32
	crown.height = 0.26
	_part(crown, Color("4a3220"), Vector3(0, 2.02, 0), root)
	var band := CylinderMesh.new()
	band.top_radius = 0.325
	band.bottom_radius = 0.325
	band.height = 0.06
	_part(band, Color("e7b53c"), Vector3(0, 1.94, 0), root)
	var beard := SphereMesh.new()
	beard.radius = 0.22
	beard.height = 0.36
	_part(beard, Color("d8d4cc"), Vector3(0, 1.5, -0.14), root)
	var shoulders := BoxMesh.new()
	shoulders.size = Vector3(1.1, 0.22, 0.4)
	_part(shoulders, Color("8f3220"), Vector3(0, 1.3, 0), root)
	arm = Node3D.new()
	arm.position = Vector3(0.6, 1.25, 0)
	root.add_child(arm)
	var haft := CylinderMesh.new()
	haft.top_radius = 0.04
	haft.bottom_radius = 0.04
	haft.height = 0.8
	var hm := _part(haft, Color("7a5230"), Vector3(0, 0, -0.4), arm)
	hm.rotation.x = PI * 0.5
	var head_h := BoxMesh.new()
	head_h.size = Vector3(0.14, 0.14, 0.3)
	_part(head_h, Color("8a8f98"), Vector3(0, 0, -0.8), arm)
	var nm := Label3D.new()
	nm.text = FarmBuilder.full_name()
	nm.font_size = 40
	nm.pixel_size = 0.0085
	nm.outline_size = 12
	nm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nm.no_depth_test = true
	nm.position = Vector3(0, 2.45, 0)
	root.add_child(nm)
	mark = Label3D.new()
	mark.text = "!"
	mark.font_size = 90
	mark.pixel_size = 0.01
	mark.outline_size = 16
	mark.modulate = UI.GOLD
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.position = Vector3(0, 2.75, 0)
	mark.visible = false
	root.add_child(mark)
	return root
