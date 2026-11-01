class_name HomeWardrobe
extends RefCounted
## The wardrobe by the house: a tall cupboard with a mirror. F opens it: hats, clothes and
## accessories for the farm (bought with gems, some free), each in a colour you pick, on a turning
## preview of your hunter; and an Expedition tab where you pick each archetype's colourway for
## matches, next to how you'll look there (the archetype's own gear: only the colours change).

const AT := Vector3(34.5, 0, 25.4)       # against the house's west wall, by the Boki beds
const FACE := 0.0                      # it opens toward +Z (south)
const TABS := ["hat", "top", "acc", "match"]

var h
var node: Node3D = null
var tab := "hat"
var preview_vp: SubViewport = null
var preview_mdl: Node3D = null
var match_mdl: Node3D = null
var spin := 0.0

func _init(home) -> void:
	h = home

func spot() -> Vector3:
	return AT + Vector3(0, 0, 1.1)

func near(p: Vector3) -> bool:
	return Vector2(p.x - AT.x, p.z - (AT.z + 1.0)).length() < 1.4

func reserve(world: World) -> void:
	world.set_block_rect(int(floor(AT.x)), int(floor(AT.z)), int(floor(AT.x)), int(floor(AT.z)))

func build() -> void:
	node = Node3D.new(); node.name = "Wardrobe"; node.position = AT; node.rotation.y = FACE
	h.add_child(node)
	var wood := Models.toon(Color("8a5e3e")); var dark := Models.toon(Color("5e3e2a")); var trim := Models.toon(Color("c99a5a"))
	Models.part(node, Models.box(1.3, 2.3, 0.62), wood, Vector3(0, 1.15, 0))
	Models.part(node, Models.box(1.42, 0.14, 0.72), dark, Vector3(0, 2.33, 0))
	Models.part(node, Models.box(1.36, 0.1, 0.68), dark, Vector3(0, 0.05, 0))
	# a crest on top, two doors, one of them a mirror
	Models.part(node, Models.cyl(0.18, 0.18, 0.06, 16), trim, Vector3(0, 2.52, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	Models.part(node, Models.box(0.58, 1.9, 0.04), wood.duplicate(), Vector3(-0.31, 1.15, 0.32))
	Models.part(node, Models.box(0.5, 1.7, 0.03), Models.toon(Color("bfe6f2"), false, 0.35), Vector3(0.31, 1.15, 0.33))
	Models.part(node, Models.box(0.56, 1.88, 0.02), trim, Vector3(0.31, 1.15, 0.315))
	for sx in [-1.0, 1.0]:
		Models.part(node, Models.sphere(0.035, 8), Models.toon(Color("f2c84a"), true, 0.3), Vector3(0.05 * sx, 1.15, 0.36))
	# a hat on a peg at the side, a scarf over the top
	Models.part(node, Models.cyl(0.02, 0.02, 0.18, 6), dark, Vector3(0.72, 1.7, 0.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	Models.part(node, Models.cyl(0.1, 0.13, 0.1, 14), Models.toon(Color("e8c878")), Vector3(0.82, 1.62, 0.1))
	Models.part(node, Models.cyl(0.22, 0.22, 0.015, 18), Models.toon(Color("e8c878")), Vector3(0.82, 1.57, 0.1))
	Models.part(node, Models.box(0.2, 0.5, 0.04), Models.toon(Color("e0607e")), Vector3(-0.5, 2.1, 0.34), Vector3.ONE, Vector3(0, 0, 0.1))
	var l := Label3D.new(); l.text = "Wardrobe"; l.font = UI.big; l.font_size = 34; l.pixel_size = 0.01; l.outline_size = 10
	l.modulate = UI.GOLD; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.position = Vector3(0, 2.95, 0)
	node.add_child(l)

# ------------------------------------------------------------------ the panel
func open(which := "") -> void:
	if which != "": tab = which
	Wardrobe.ensure()
	var v: VBoxContainer = h._new_panel("Wardrobe", 900, true)
	v.add_child(UI.label("Dress up for the farm. What you wear here shows at home and when friends visit; on an expedition your archetype wears its own gear.", 14, UI.MUTED))
	var tr := UI.hbox(8)
	for k in TABS:
		var kk: String = k
		var nm: String = "Expedition colours" if k == "match" else String(Wardrobe.SLOT_NAMES[k])
		tr.add_child(UI.choice(nm, tab == k, func(): tab = kk; open(), 170))
	v.add_child(tr)
	var row := UI.hbox(16)
	v.add_child(row)
	var left := UI.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := UI.vbox(4)
	row.add_child(right)
	if tab == "match":
		_match_tab(left, right)
	else:
		_slot_tab(left, right)
	var gl := UI.label("%d gems" % int(Save.d.get("gems", 0)), 15, UI.GOLD, UI.big)
	v.add_child(gl)

func _slot_tab(left: VBoxContainer, right: VBoxContainer) -> void:
	var w := Wardrobe.ensure()
	var cur := String(w["wear"].get(tab, ""))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	var none := UI.choice("Nothing", cur == "", func(): Wardrobe.wear(tab, ""); _changed(), 170)
	grid.add_child(none)
	for id in Wardrobe.ITEMS:
		var it: Array = Wardrobe.ITEMS[id]
		if String(it[1]) != tab: continue
		var iid: String = id
		var owned := Wardrobe.owns(iid)
		var txt := String(it[0]) if owned else "%s  ·  %d gems" % [it[0], int(it[2])]
		var b := UI.choice(txt, cur == iid, func(): _pick(iid), 170)
		b.tooltip_text = String(it[4])
		if not owned and int(Save.d.get("gems", 0)) < int(it[2]):
			b.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(b)
	if cur != "":
		left.add_child(UI.section("Colour of the %s" % String(Wardrobe.ITEMS[cur][0]).to_lower()))
		left.add_child(_swatches(Wardrobe.col_of(cur), func(ci): Wardrobe.set_col(cur, ci); _changed()))
		left.add_child(UI.label(String(Wardrobe.ITEMS[cur][4]), 13, UI.MUTED))
	right.add_child(UI.label("On the farm", 15, UI.INK, UI.big))
	right.add_child(_preview(true))

func _match_tab(left: VBoxContainer, right: VBoxContainer) -> void:
	var cls := Data.class_of_save()
	var arch := HeroKit.arch_for(cls, "", Save.d.get("look", {}))
	left.add_child(UI.label("On an expedition everyone can tell what you are at a glance: your archetype's hat, coat and kit always keep their shape. You pick their colours.", 14, UI.INK))
	left.add_child(UI.section("%s colourway" % String((HeroKit.ARCHES.get(arch, {}) as Dictionary).get("name", arch.capitalize()))))
	var cur := Wardrobe.arch_col(arch)
	var base := int(Models.clean_look(Save.d.get("look", {}))["outfit"])
	var gf := HFlowContainer.new(); gf.add_theme_constant_override("h_separation", 6); gf.add_theme_constant_override("v_separation", 6)
	left.add_child(gf)
	gf.add_child(UI.choice("Same as my outfit", cur < 0, func(): Wardrobe.set_arch_col(arch, -1); _changed(), 180))
	for i in Models.OUTFIT_COLS.size():
		var ii: int = i
		var b := UI.choice(Models.LOOK_OUTFITS[i], cur == i, func(): Wardrobe.set_arch_col(arch, ii); _changed(), 120)
		b.add_theme_color_override("font_color", Models.OUTFIT_COLS[i].lightened(0.2))
		if i == base and cur < 0: b.tooltip_text = "Your outfit's colours"
		gf.add_child(b)
	left.add_child(UI.label("Hats, clothes and accessories from the other tabs stay home.", 13, UI.MUTED))
	right.add_child(UI.label("On an expedition", 15, UI.INK, UI.big))
	right.add_child(_preview(false))

func _swatches(cur: int, cb: Callable) -> Control:
	var r := UI.hbox(6)
	for i in Wardrobe.PALETTE.size():
		var ii: int = i
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34)
		var sb := StyleBoxFlat.new(); sb.bg_color = Wardrobe.PALETTE[i]
		sb.set_corner_radius_all(17)
		sb.border_color = UI.GOLD if i == cur else Color(0, 0, 0, 0.4)
		sb.set_border_width_all(3 if i == cur else 1)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func(): cb.call(ii))
		r.add_child(b)
	return r

func _pick(id: String) -> void:
	if not Wardrobe.owns(id):
		if not Wardrobe.buy(id):
			h._toast("You need %d gems for the %s" % [Wardrobe.price(id), String(Wardrobe.ITEMS[id][0]).to_lower()])
			Sfx.play("click", null, -10.0, 0.0, 0.6)
			return
		Sfx.play("unlock")
		h._toast("%s bought" % Wardrobe.ITEMS[id][0])
	Wardrobe.wear(String(Wardrobe.ITEMS[id][1]), id)
	_changed()

func _changed() -> void:
	Sfx.play("click", null, -8.0)
	h._refresh_player_model()
	h._refresh_top()
	open()

## A turning full-length preview of your hunter: the farm look, or how you'll look in a match.
func _preview(farm: bool) -> Control:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(260, 360)
	box.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(260, 360)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93b8"); e.ambient_light_energy = 0.9
	env.environment = e; vp.add_child(env)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-30, 150, 0); key.light_color = Color("fff1dc"); key.light_energy = 1.15
	vp.add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-15, -30, 0); fill.light_energy = 0.5
	vp.add_child(fill)
	var cls := Data.class_of_save()
	var mdl: Node3D = Models.hunter(cls, Data.TEAM_COLORS[0], h._weapon(), "", Wardrobe.farm_appearance() if farm else Save.d.get("look", {}))
	var ring := mdl.get_node_or_null("TeamRing")
	if ring: (ring as Node3D).visible = false
	vp.add_child(mdl)
	HunterAnim.rest_pose(mdl)
	var s := mdl.scale.y
	var cam := Camera3D.new(); cam.fov = 30.0
	vp.add_child(cam)
	var mid := Vector3(0, 0.95 * s, 0)
	cam.transform = Transform3D(Basis(), mid + Vector3(-0.9, 0.35, -3.6) * s).looking_at(mid, Vector3.UP)
	cam.current = true
	mdl.rotation.y = 0.35
	if farm: preview_mdl = mdl
	else: match_mdl = mdl
	preview_vp = vp
	return box

func tick(d: float) -> void:
	spin += d
	for m in [preview_mdl, match_mdl]:
		if is_instance_valid(m):
			(m as Node3D).rotation.y = 0.35 + sin(spin * 0.6) * 0.7
