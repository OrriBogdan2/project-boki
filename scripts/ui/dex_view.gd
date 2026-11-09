class_name DexView
extends RefCounted
## The Field Book: field notes on every kind of Boki, laid out like a creature index. A grid of
## numbered tiles (#001...): a Boki you've caught shows in full colour, one you've only seen is a dark
## silhouette, one you've never met is a "?". Each tile carries a small type badge, and a soft
## sparkle when you've found its shimmer form. Clicking a tile opens its page: the Boki turning on a
## stand, its number, name and type, a field note, its size range, where it lives, its quirk and how
## its sexes work (BokiQuirks), the forms you've found and the ones you're raising.
##
## Reads Save "dex" exactly as Care keeps it ({species: {seen, caught, forms, shimmer, mutations}});
## nothing here writes to it. Field notes, not a checklist (docs/POSITIONING.md): no completion
## percentage, no rarity colours.

## Each type's badge colour and name (the glyphs are drawn by TypeIcon).
const TYPES := {
	"spore": {"name": "Spore", "col": Color("9ccf6a")},
	"titan": {"name": "Titan", "col": Color("cbb48a")},
	"venom": {"name": "Venom", "col": Color("b98cff")},
	"swarm": {"name": "Swarm", "col": Color("f2c24a")},
	"gravity": {"name": "Gravity", "col": Color("8f8cff")},
	"prism": {"name": "Prism", "col": Color("ff9fd0")},
	"lunar": {"name": "Lunar", "col": Color("cfdcff")},
	"echo": {"name": "Echo", "col": Color("6fb6ff")},
	"tempest": {"name": "Tempest", "col": Color("6fe0cf")},
}
const TILE := Vector2(106, 132)
const PORTRAIT := 70.0

static func type_of(spk: String) -> String:
	return String(Data.KIN.get(spk, {}).get("type", ""))

static func type_name(t: String) -> String:
	return String(TYPES.get(t, {}).get("name", t.capitalize()))

static func type_col(t: String) -> Color:
	return TYPES.get(t, {}).get("col", Color("a9b0bf"))

## Its number in the Field Book: the order species are listed in (Data.KIN: the starters first).
static func number(spk: String) -> int:
	return Data.KIN.keys().find(spk) + 1

static func num_text(spk: String) -> String:
	return "#%03d" % number(spk)

static func entry(spk: String) -> Dictionary:
	var dx: Dictionary = Save.d.get("dex", {})
	return dx.get(spk, {})

static func seen(spk: String) -> bool:
	return bool(entry(spk).get("seen", false))

static func caught(spk: String) -> bool:
	return bool(entry(spk).get("caught", false))

## [seen, caught] across every species (caught ones count as seen).
static func counts() -> Vector2i:
	var s := 0; var t := 0
	for spk in Data.KIN:
		if seen(spk) or caught(spk): s += 1
		if caught(spk): t += 1
	return Vector2i(s, t)

## The grid, under a "Seen N · Caught N" line. on_open(species) opens a tile's page.
static func grid(v: VBoxContainer, tree: SceneTree, on_open: Callable) -> void:
	Care.dex_sync()
	demo()
	var c := counts()
	var head := UI.hbox(14)
	head.add_child(UI.chip("eye", "Seen %d" % c.x, UI.INK))
	head.add_child(UI.chip("paw", "Caught %d" % c.y, UI.INK))
	var hint := UI.label("Field notes on every Boki you've met. Click one to read its page.", UI.T_SMALL, UI.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	v.add_child(head)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for spk in Data.KIN:
		g.add_child(tile(spk, tree, on_open))

## One numbered tile.
static func tile(spk: String, tree: SceneTree, on_open: Callable) -> Control:
	var is_caught := caught(spk)
	var is_seen := is_caught or seen(spk)
	var t: PanelContainer
	if is_seen:
		var sk := spk
		t = UI.tile_card(false, func(): on_open.call(sk), 8)
		t.tooltip_text = String(Data.KIN[spk]["name"])
	else:
		t = UI.card(Color(1, 1, 1, 0.025), 8)
		t.tooltip_text = "Not met yet"
	t.custom_minimum_size = TILE
	var col := UI.vbox(2)
	t.add_child(col)
	var top := UI.hbox(4)
	var nl := UI.label(num_text(spk), 11, UI.MUTED if is_seen else UI.FAINT, UI.semi)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	if is_seen:
		top.add_child(TypeIcon.new(type_of(spk), 16.0))
	col.add_child(top)
	var pic := CenterContainer.new()
	pic.custom_minimum_size = Vector2(0, PORTRAIT + 4)
	col.add_child(pic)
	if is_seen:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pv := KinPortrait.view({"species": spk, "level": 5}, tree, PORTRAIT)
		pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not is_caught:
			pv.modulate = Color(0.05, 0.06, 0.1, 0.92)      # seen, not caught: a dark silhouette
		holder.add_child(pv)
		if is_caught and bool(entry(spk).get("shimmer", false)):
			var sp := Sparkle.new()
			sp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sp.tooltip_text = "Shimmer form found"
			holder.add_child(sp)
		pic.add_child(holder)
	else:
		var q := UI.title("?", 40, Color(1, 1, 1, 0.16))
		pic.add_child(q)
	var name_l := UI.label(String(Data.KIN[spk]["name"]) if is_seen else "???", UI.T_SMALL, UI.INK if is_caught else UI.MUTED, UI.semi)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	col.add_child(name_l)
	return t

## Screenshots only (--dex-demo, never saved): one species seen but not caught, and a shimmer found.
static func demo() -> void:
	if not "--dex-demo" in OS.get_cmdline_user_args():
		return
	Save.no_write = true
	var dx: Dictionary = Save.d.get("dex", {})
	Save.d["dex"] = dx
	var ids: Array = Data.KIN.keys()
	for spk in ids:
		if not caught(spk) and not dx.has(spk):
			dx[spk] = {"seen": true, "caught": false, "forms": [], "shimmer": false, "mutations": []}
			break
	if not ids.is_empty() and dx.has(ids[1]):
		dx[ids[1]]["shimmer"] = true
		if not (dx[ids[1]]["forms"] as Array).has("Pudward"): dx[ids[1]]["forms"].append("Pudward")

# ------------------------------------------------------------------ a Boki's page
## The page for one species: picture on the left, field notes on the right.
static func detail(v: VBoxContainer, spk: String, tree: SceneTree) -> void:
	var sp: Dictionary = Data.KIN[spk]
	var e := entry(spk)
	var is_caught := caught(spk)
	var row := UI.hbox(UI.GAP_BIG + 6)
	v.add_child(row)
	# the Boki turning on its stand (a silhouette if you've only seen it)
	var stage := UI.card(Color(0, 0, 0, 0.22), 0, 16)
	stage.custom_minimum_size = Vector2(250, 290)
	stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(stage)
	if KinPortrait.available():
		var spin := Spinner.make({"species": spk, "level": 5, "shimmer": false}, not is_caught)
		stage.add_child(spin)
	else:
		var dc := CenterContainer.new(); stage.add_child(dc)
		var d := KinPortrait.view({"species": spk}, tree, 160)
		if not is_caught: d.modulate = Color(0.05, 0.06, 0.1, 0.92)
		dc.add_child(d)
	var info := UI.vbox(7)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var nrow := UI.hbox(10)
	nrow.add_child(UI.label(num_text(spk), UI.T_HEAD, UI.MUTED, UI.big))
	nrow.add_child(UI.title(String(sp["name"]), 26, UI.INK))
	info.add_child(nrow)
	var trow := UI.hbox(8)
	var t := type_of(spk)
	var tchip := PanelContainer.new()
	var chip_box := UI.frame(Color(type_col(t), 0.14), UI.R_PILL, Color(0, 0, 0, 0), 0, 8, 3, 0.0)
	tchip.add_theme_stylebox_override("panel", chip_box)
	var th := UI.hbox(6); tchip.add_child(th)
	th.add_child(TypeIcon.new(t, 18.0))
	th.add_child(UI.label("%s type" % type_name(t), UI.T_SMALL, UI.INK, UI.semi))
	trow.add_child(tchip)
	trow.add_child(UI.tag("Caught" if is_caught else "Seen", UI.GOOD if is_caught else UI.MUTED))
	info.add_child(trow)
	var note := UI.para(_field_note(spk), UI.T_SMALL + 1, UI.INK)
	note.custom_minimum_size.x = 360
	info.add_child(note)
	_fact(info, "ruler", "Size", _size_range(spk))
	_fact(info, "pin", "Lives", _habitat(spk))
	if BokiQuirks.quirk(spk) != "":
		_fact(info, "dance", "Quirk", BokiQuirks.quirk(spk))
	if BokiQuirks.sex_note(spk) != "":
		_fact(info, "egg", "Sexes", BokiQuirks.sex_note(spk))
	# the forms you've found, as small portraits
	var forms: Array = e.get("forms", [])
	var fl := UI.vbox(4)
	fl.add_child(UI.section("Forms found", UI.FAINT.lightened(0.2)))
	var fr := UI.hbox(8)
	var shown: Array = [String(sp["name"])] + forms.slice(0, 5)
	for fname in shown:
		var fc := UI.vbox(2)
		fc.custom_minimum_size.x = 64
		var fp := KinPortrait.view(_form_rec(spk, String(fname)), tree, 46.0)
		if not is_caught: fp.modulate = Color(0.05, 0.06, 0.1, 0.92)
		var fcc := CenterContainer.new(); fcc.add_child(fp)
		fc.add_child(fcc)
		var fn := UI.label(String(fname), 11, UI.MUTED)
		fn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fn.clip_text = true
		fc.add_child(fn)
		fr.add_child(fc)
	if bool(e.get("shimmer", false)):
		var sc := UI.vbox(2); sc.custom_minimum_size.x = 64
		var sh := Control.new(); sh.custom_minimum_size = Vector2(46, 46)
		var spv := KinPortrait.view({"species": spk, "level": 5, "shimmer": true, "uid": "dex|shimmer|" + spk}, tree, 46.0)
		spv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sh.add_child(spv)
		var spk2 := Sparkle.new(); spk2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sh.add_child(spk2)
		var scc := CenterContainer.new(); scc.add_child(sh)
		sc.add_child(scc)
		var sn := UI.label("Shimmer", 11, UI.MUTED); sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_child(sn)
		fr.add_child(sc)
	fl.add_child(fr)
	info.add_child(fl)
	# the ones you're raising, each with their sex
	var mine: Array = (Save.d.get("roster", []) as Array).filter(func(r): return String(r.get("species", "")) == spk)
	if not mine.is_empty():
		var ml := UI.vbox(4)
		ml.add_child(UI.section("Yours", UI.FAINT.lightened(0.2)))
		var mr := HFlowContainer.new()
		mr.add_theme_constant_override("h_separation", 8); mr.add_theme_constant_override("v_separation", 6)
		for r in mine.slice(0, 8):
			var pc := PanelContainer.new()
			var pill := UI.frame(Color(1, 1, 1, 0.05), UI.R_PILL, Color(0, 0, 0, 0), 0, 10, 3, 0.0)
			pc.add_theme_stylebox_override("panel", pill)
			var ph := UI.name_with_sex(r, "%s  Lv %d" % [String(r["name"]), int(r.get("level", 1))], UI.T_SMALL, UI.INK, UI.semi, 12.0)
			pc.add_child(ph)
			mr.add_child(pc)
		if mine.size() > 8:
			mr.add_child(UI.label("+%d more" % (mine.size() - 8), UI.T_SMALL, UI.MUTED))
		ml.add_child(mr)
		info.add_child(ml)

## A labelled fact line: an icon, a short label, the value.
static func _fact(parent: Control, icon: String, k: String, val: String) -> void:
	var r := UI.hbox(8)
	r.add_child(UI.IconDot.new(icon, UI.MUTED, 15.0))
	var kl := UI.label(k, UI.T_SMALL, UI.MUTED, UI.semi)
	kl.custom_minimum_size.x = 48
	r.add_child(kl)
	var vl := UI.label(val, UI.T_SMALL, UI.INK)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.custom_minimum_size.x = 200
	r.add_child(vl)
	parent.add_child(r)

## One or two lines about the species (its flavour text, cut at the second sentence).
static func _field_note(spk: String) -> String:
	var f := String(Data.KIN[spk].get("flavor", Data.KIN[spk].get("desc", "")))
	if f == "":
		return "No field notes yet."
	var parts: Array = Array(f.strip_edges().trim_suffix(".").split(". "))
	return ". ".join(parts.slice(0, 2)) + "."

## From its smallest (XS) to its biggest (XL), in cm and kg.
static func _size_range(spk: String) -> String:
	var b := Unique.base_size(spk)
	var lo := 1.0 + Unique.XS_Z * Unique.SIZE_SD
	var hi := 1.0 + Unique.XL_Z * Unique.SIZE_SD
	var cm := float(b["cm"]); var kg := float(b["kg"])
	return "%d to %d cm, %s to %s kg" % [int(round(cm * lo)), int(round(cm * hi)), _kg(kg * lo * lo * lo), _kg(kg * hi * hi * hi)]

static func _kg(x: float) -> String:
	return ("%.1f" % x) if x < 10.0 else str(int(round(x)))

## Where it lives: wild across the islands, or only from a lair boss's Rare Egg; and where you've
## caught yours.
static func _habitat(spk: String) -> String:
	var out := ""
	if Data.is_rare(spk):
		var boss := String(Data.KIN[spk].get("boss", ""))
		var bn := String(Data.MOBS.get(boss, {}).get("name", "a lair boss"))
		out = "Never in the wild. It only hatches from a Rare Egg won from %s." % bn
	else:
		out = "Wild, on any island of the Skylands."
	var places: Array = []
	for r in Save.d.get("roster", []):
		if String(r.get("species", "")) != spk: continue
		var o = r.get("origin", null)
		if typeof(o) != TYPE_DICTIONARY or String(o.get("how", "")) != "wild": continue
		var w = o.get("where", {})
		if typeof(w) != TYPE_DICTIONARY: continue
		var pl := String(w.get("island", w.get("map", "")))
		if pl != "" and not places.has(pl): places.append(pl)
	if not places.is_empty():
		out += " You caught yours at %s." % ", ".join(places.slice(0, 2))
	var sighted: Array = FieldBook.places(spk)
	if not sighted.is_empty():
		out += " Last seen at %s." % ", ".join(sighted.slice(-2))      # (logged on sight, newest last)
	return out

## A look-only record wearing a found form (from its name: the root plus an affinity's suffix).
static func _form_rec(spk: String, fname: String) -> Dictionary:
	var rec := {"species": spk, "level": 5, "uid": "dex|%s|%s" % [spk, fname]}
	var root := String(Evo.ROOTS.get(spk, "Kin"))
	for aff in Evo.SUFFIX:
		var sfx: Array = Evo.SUFFIX[aff]
		for i in sfx.size():
			if fname == root + String(sfx[i]) or fname.begins_with(root + String(sfx[i]) + " "):
				var fs: Array = []
				for k in i + 1: fs.append(aff)
				rec["forms"] = fs
				return rec
	return rec

## A type badge drawn on any canvas (the Field Book's TypeIcon, the HUD's Boki box and overhead row):
## a disc in the type's colour with its glyph, centred at `c`, radius `r`.
static func draw_type(ci: CanvasItem, t: String, c: Vector2, r: float, alpha := 1.0) -> void:
	var col := DexView.type_col(t)
	col.a = alpha
	ci.draw_circle(c, r, Color(col.darkened(0.45), alpha))
	ci.draw_circle(c, r - 1.2, Color(col.darkened(0.15), alpha))
	var s := r * 0.62
	var ink := Color(1, 1, 1, 0.95 * alpha)
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * s
	var w := maxf(1.2, r * 0.16)
	match t:
		"spore":       # a toadstool
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.9, 0.0), P.call(-0.6, -0.6), P.call(0.0, -0.85), P.call(0.6, -0.6), P.call(0.9, 0.0)]), ink)
			ci.draw_rect(Rect2(P.call(-0.22, 0.0), Vector2(0.44, 0.8) * s), ink)
		"titan":       # a peak
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.95, 0.75), P.call(-0.15, -0.8), P.call(0.25, -0.1), P.call(0.45, -0.4), P.call(0.95, 0.75)]), ink)
		"venom":       # a drop
			var pts := PackedVector2Array()
			for i in 16:
				var a := PI * i / 15.0
				pts.append(P.call(cos(a) * 0.6, 0.25 + sin(a) * 0.6))
			pts.append(P.call(0.0, -0.9))
			ci.draw_colored_polygon(pts, ink)
		"swarm":       # a honeycomb cell
			var hx := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				hx.append(P.call(cos(a) * 0.82, sin(a) * 0.82))
			ci.draw_colored_polygon(hx, ink)
		"gravity":     # a weight pressing down
			ci.draw_line(P.call(0.0, -0.9), P.call(0.0, 0.2), ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.45, 0.0), P.call(0.45, 0.0), P.call(0.0, 0.55)]), ink)
			ci.draw_line(P.call(-0.8, 0.8), P.call(0.8, 0.8), ink, w, true)
		"prism":       # a cut gem
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.0, -0.95), P.call(0.75, 0.0), P.call(0.0, 0.95), P.call(-0.75, 0.0)]), ink)
		"lunar":       # a crescent
			ci.draw_circle(P.call(0.0, 0.0), s * 0.82, ink)
			ci.draw_circle(P.call(0.35, -0.25), s * 0.68, Color(col.darkened(0.15), alpha))
		"echo":        # rings of sound
			for k in 3:
				ci.draw_arc(P.call(-0.55, 0.0), s * (0.35 + k * 0.42), -0.9, 0.9, 10, ink, w, true)
		"tempest":     # a bolt
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.25, -0.95), P.call(-0.55, 0.15), P.call(-0.05, 0.15), P.call(-0.3, 0.95), P.call(0.55, -0.2), P.call(0.05, -0.2)]), ink)
		_:
			ci.draw_circle(c, s * 0.45, ink)

# ------------------------------------------------------------------ widgets
## A type badge: a disc in the type's colour with its glyph.
class TypeIcon extends Control:
	var t := ""
	func _init(type_id: String, px := 16.0) -> void:
		t = type_id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tooltip_text = "%s type" % DexView.type_name(type_id)
	func _draw() -> void:
		DexView.draw_type(self, t, size * 0.5, minf(size.x, size.y) * 0.5)

## A soft twinkle over a portrait: the shimmer form has been found.
class Sparkle extends Control:
	var t := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var spots := [Vector2(0.18, 0.2), Vector2(0.84, 0.32), Vector2(0.7, 0.86), Vector2(0.26, 0.78)]
		for i in spots.size():
			var a := 0.5 + 0.5 * sin(t * 2.2 + i * 1.7)
			var r := (2.0 + 3.2 * a) * minf(size.x, size.y) / 70.0
			var p: Vector2 = size * (spots[i] as Vector2)
			var col := Color(1.0, 0.95, 0.75, 0.25 + 0.6 * a)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.6), p + Vector2(r * 0.35, 0), p + Vector2(0, r * 1.6), p + Vector2(-r * 0.35, 0)]), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.6, 0), p + Vector2(0, r * 0.35), p + Vector2(r * 1.6, 0), p + Vector2(0, -r * 0.35)]), col)

## A Boki turning slowly on a little stand, live (for the Field Book page).
class Spinner extends SubViewportContainer:
	var turn: Node3D
	static func make(rec: Dictionary, silhouette := false) -> Spinner:
		var c := Spinner.new()
		c.stretch = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.size = Vector2i(270, 300)
		c.add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color("8a93b8")
		e.ambient_light_energy = 0.95
		env.environment = e
		vp.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-35, 200, 0)
		key.light_color = Color("fff1dc"); key.light_energy = 1.15
		vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-10, 20, 0)
		rim.light_color = Color("a8c8ff"); rim.light_energy = 0.5
		vp.add_child(rim)
		c.turn = Node3D.new()
		vp.add_child(c.turn)
		var mdl := Models.kin(String(rec["species"]), rec)
		mdl.scale = Vector3.ONE
		for ch in mdl.get_children():
			if ch is CPUParticles3D or ch is GPUParticles3D: (ch as Node3D).visible = false
		c.turn.add_child(mdl)
		# the stand: a low disc
		var st := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.6; cm.height = 0.06
		st.mesh = cm
		st.material_override = Models.toon(Color("2a2f45"), false)
		st.position = Vector3(0, -0.03, 0)
		vp.add_child(st)
		# frame the whole Boki whatever its size: the camera backs off to fit its bounds
		var bb := _bounds(mdl)
		# turning, its widest reach is the diagonal of its footprint
		var reach := 0.0          # how far it sweeps from the axis it turns on (its origin)
		for k in 8:
			var cr := bb.get_endpoint(k)
			reach = maxf(reach, Vector2(cr.x, cr.z).length())
		var rad := maxf(0.25, maxf(reach, bb.size.y * 0.55))
		var at := Vector3(0, bb.get_center().y, 0)
		st.position = Vector3(0, bb.position.y - 0.03, 0)
		cm.top_radius = rad * 0.8; cm.bottom_radius = rad * 0.84
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		var dist := rad / tan(deg_to_rad(cam.fov * 0.5)) * 1.18
		cam.transform = Transform3D(Basis(), at + Vector3(0, 0.38, -1.0).normalized() * dist).looking_at(at, Vector3.UP)
		cam.current = true
		if silhouette:
			c.modulate = Color(0.05, 0.06, 0.1, 0.94)
		return c
	func _process(d: float) -> void:
		if turn: turn.rotation.y += d * 0.7
	## The model's bounds in its own space (all its meshes).
	static func _bounds(n: Node3D) -> AABB:
		var out := AABB()
		var first := true
		var stack: Array = [[n, Transform3D.IDENTITY]]
		while not stack.is_empty():
			var it: Array = stack.pop_back()
			var nd: Node = it[0]
			var xf: Transform3D = it[1]
			if nd is MeshInstance3D and (nd as MeshInstance3D).mesh:
				var b := xf * (nd as MeshInstance3D).mesh.get_aabb()
				out = b if first else out.merge(b)
				first = false
			for ch in nd.get_children():
				if ch is Node3D: stack.append([ch, xf * (ch as Node3D).transform])
		return out if not first else AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 0.8, 0.8))
