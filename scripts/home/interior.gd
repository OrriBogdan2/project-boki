extends Node3D
## Inside a building: walk around, hang out with the kin who live there, and decorate. Furniture
## sits on a tile grid; press B (or the Decorate button) to place, turn, move and put things away.

const SPEED := 4.2
const TILE := 1.0

var room := "house"
var visit: Dictionary = {}      # someone else's island snapshot when visiting
var visit_id := ""
var R: Dictionary
var W := 10
var D := 8
var cam: CamRig
var fx: Fx
var player: Node3D
var ppos := Vector3.ZERO
var pvel := Vector3.ZERO
var pface := PI
var walk_ph := 0.0
var decor: Array = []           # [{id, x, z, r}], the live list in the save (or a copy when visiting)
var nodes: Array = []           # one Node3D per decor entry
var occ := {}                   # Vector2i -> index into decor, for pieces you can't walk through
var kins: Array = []            # {rec, node, pos, goal, t, hop}
var spots: Array = []           # {kind, pos, label}
var interact: Dictionary = {}
# ui
var root_ui: Control
var prompt_box: PanelContainer
var prompt_lbl: Label
var panel_host: CenterContainer
var panel_open := ""
var decorating := false         # Decorate.active, kept here for the tile checks
var dec: Decorate
var why := ""                   # why a piece can't go where it was tried
var blocker := -1               # index of the piece in the way

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	R = Data.ROOMS.get(room, Data.ROOMS["house"])
	W = int(R["w"]); D = int(R["d"])
	_build_env()
	_build_room()
	fx = Fx.new(); add_child(fx)
	cam = CamRig.new(); add_child(cam)
	cam.zoom_to = 0.62; cam.zoom = 0.62; cam.lead = 0.0
	if visit.is_empty():
		if typeof(Save.d.get("decor")) != TYPE_DICTIONARY: Save.d["decor"] = {}
		if typeof(Save.d["decor"].get(room)) != TYPE_ARRAY:
			var start: Array = []
			for s in R["start"]: start.append({"id": s[0], "x": s[1], "z": s[2], "r": s[3]})
			Save.d["decor"][room] = start
			Save.save_game()
		decor = Save.d["decor"][room]
		if typeof(Save.d.get("furniture")) != TYPE_DICTIONARY: Save.d["furniture"] = {}
	else:
		decor = (visit.get("decor", []) as Array).duplicate(true) if room == "house" else []
	dec = Decorate.new(self)
	_rebuild_decor()
	player = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], Arch.weapon_for(Arch.of_save(), Data.class_of_save(), String(Save.d.get("weapon", ""))), "", Unmasked.worn(), Arch.of_save())
	add_child(player)
	ppos = Vector3(W * 0.5, 0, D - 0.9)
	player.position = ppos
	cam.snap(Vector3(W * 0.5, 0, D * 0.5 - 0.6))
	_spawn_kin()
	_build_ui()
	Sfx.play_ambience("")
	Sfx.play("whoosh", null, -14.0)

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0c0d12")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("ffe6c8")
	e.ambient_light_energy = 0.38
	e.glow_enabled = true; e.glow_intensity = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_color = Color("fff0dc"); sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	var warm := OmniLight3D.new()
	warm.light_color = Color("ffd8a8"); warm.light_energy = 0.7; warm.omni_range = 12.0
	warm.position = Vector3(5, 3.2, 4)
	add_child(warm)

func _build_room() -> void:
	var floor_c: Color = R["floor"]; var wall_c: Color = R["wall"]
	# floor boards
	for z in D:
		var plank := Models.part(self, Models.box(W, 0.12, 0.98), Models.toon(floor_c.darkened(0.05 if z % 2 == 0 else 0.0), false), Vector3(W * 0.5, -0.06, z + 0.5))
		plank.name = "Plank%d" % z
	var wall := Models.toon(wall_c)
	var trim := Models.toon(Color("7a5236"))
	Models.part(self, Models.box(W + 0.4, 2.8, 0.2), wall, Vector3(W * 0.5, 1.4, -0.1))
	Models.part(self, Models.box(0.2, 2.8, D + 0.2), wall, Vector3(-0.1, 1.4, D * 0.5))
	Models.part(self, Models.box(0.2, 2.8, D + 0.2), wall, Vector3(W + 0.1, 1.4, D * 0.5))
	Models.part(self, Models.box(W + 0.4, 0.16, 0.24), trim, Vector3(W * 0.5, 0.08, 0.0))
	# windows on the back wall
	for wx in [W * 0.25, W * 0.75]:
		Models.part(self, Models.box(1.3, 0.9, 0.05), Models.toon(Color("9fd0ff"), false, 0.5), Vector3(wx, 1.7, 0.01))
		Models.part(self, Models.box(1.45, 0.08, 0.1), trim, Vector3(wx, 1.22, 0.04))
	# the front is open toward the camera, with a low sill and a doormat
	Models.part(self, Models.box(W * 0.5 - 0.8, 0.35, 0.2), wall, Vector3((W * 0.5 - 0.8) * 0.5, 0.17, D + 0.1))
	Models.part(self, Models.box(W * 0.5 - 0.8, 0.35, 0.2), wall, Vector3(W - (W * 0.5 - 0.8) * 0.5, 0.17, D + 0.1))
	Models.part(self, Models.box(1.4, 0.03, 0.8), Models.toon(Color("8a6a3a"), false), Vector3(W * 0.5, 0.015, D - 0.4))
	spots.append({"kind": "door", "pos": Vector3(W * 0.5, 0, D - 0.4), "label": "Go outside"})
# ------------------------------------------------------------------ furniture on the grid
static func footprint(id: String, r: int) -> Vector2i:
	var sz: Array = Data.FURN[id]["size"]
	return Vector2i(int(sz[0]), int(sz[1])) if r % 2 == 0 else Vector2i(int(sz[1]), int(sz[0]))

func _make_piece(id: String, r: int) -> Node3D:
	var pivot := Node3D.new()
	var sz: Array = Data.FURN[id]["size"]
	var m := RoomPieces.model(id) if RoomPieces.is_usable(id) else Models.furniture(id)
	m.position = Vector3(-float(sz[0]) * 0.5, 0, -float(sz[1]) * 0.5)
	pivot.add_child(m)
	pivot.rotation.y = -r * PI * 0.5
	return pivot

func _place_node(n: Node3D, id: String, x: int, z: int, r: int) -> void:
	var fp := footprint(id, r)
	n.position = Vector3(x + fp.x * 0.5, 0, z + fp.y * 0.5)

func _rebuild_decor() -> void:
	for n in nodes:
		n.queue_free()
	nodes.clear()
	occ.clear()
	var keep: Array = []
	for e in decor:
		if typeof(e) == TYPE_DICTIONARY and Data.FURN.has(e.get("id", "")):
			keep.append(e)
	decor.clear()
	if visit.is_empty():
		decor.append_array(keep)
	else:
		# someone else's room: drop anything that overlaps, sits in the doorway or is out of bounds
		for e in keep:
			if _fits(String(e["id"]), int(e["x"]), int(e["z"]), int(e.get("r", 0)) % 4):
				decor.append(e)
				_occupy(decor.size() - 1)
	spots = spots.filter(func(sp): return sp["kind"] == "door")
	for i in decor.size():
		var e: Dictionary = decor[i]
		var r := int(e.get("r", 0)) % 4
		var n := _make_piece(e["id"], r)
		add_child(n)
		_place_node(n, e["id"], int(e["x"]), int(e["z"]), r)
		nodes.append(n)
		if visit.is_empty():
			_occupy(i)
			if RoomPieces.is_usable(e["id"]):
				spots.append({"kind": e["id"], "pos": n.position, "label": RoomPieces.USES[e["id"]]})

## Marks the tiles of piece i as taken (rugs and cushions can be walked over, so they are not).
func _occupy(i: int) -> void:
	var e: Dictionary = decor[i]
	if Data.FURN[e["id"]].get("walk", false):
		return
	var fp := footprint(e["id"], int(e.get("r", 0)) % 4)
	for dz in fp.y:
		for dx in fp.x:
			occ[Vector2i(int(e["x"]) + dx, int(e["z"]) + dz)] = i

## Does this piece fit here? Sets why (and blocker, the piece in the way) when it does not.
func _fits(id: String, x: int, z: int, r: int, ignore := -1) -> bool:
	why = ""
	blocker = -1
	var fp := footprint(id, r)
	if x < 0 or z < 0 or x + fp.x > W or z + fp.y > D:
		why = "Outside the room"
		return false
	var walk: bool = Data.FURN[id].get("walk", false)
	for dz in fp.y:
		for dx in fp.x:
			var c := Vector2i(x + dx, z + dz)
			if c.y >= D - 1 and absf(c.x + 0.5 - W * 0.5) < 1.2:
				why = "Keep the doorway clear"
				return false
			if not walk and occ.has(c) and occ[c] != ignore:
				blocker = occ[c]
				why = "Blocked by: %s" % Data.FURN[decor[blocker]["id"]]["name"]
				return false
			if decorating and not walk and absf(c.x + 0.5 - ppos.x) < 0.85 and absf(c.y + 0.5 - ppos.z) < 0.85:
				why = "You're standing there"
				return false
	if walk:
		# rugs can't overlap other rugs
		for i in decor.size():
			if i == ignore or not Data.FURN[decor[i]["id"]].get("walk", false): continue
			var ofp := footprint(decor[i]["id"], int(decor[i].get("r", 0)))
			if Rect2i(int(decor[i]["x"]), int(decor[i]["z"]), ofp.x, ofp.y).intersects(Rect2i(x, z, fp.x, fp.y)):
				blocker = i
				why = "Blocked by: %s" % Data.FURN[decor[i]["id"]]["name"]
				return false
	return true

func _blocked(x: float, z: float) -> bool:
	if x < 0.35 or z < 0.35 or x > W - 0.35 or z > D - 0.2:
		return true
	for o in [Vector2(0, 0), Vector2(0.28, 0), Vector2(-0.28, 0), Vector2(0, 0.28), Vector2(0, -0.28)]:
		if occ.has(Vector2i(int(floor(x + o.x)), int(floor(z + o.y)))):
			return true
	return false

# ------------------------------------------------------------------ kin
func _spawn_kin() -> void:
	var roster: Array = (visit.get("roster", []) if not visit.is_empty() else KinBox.farm())    # kin in the Kin Burrow stay asleep there
	var active: String = (visit.get("active", "") if not visit.is_empty() else Save.d.get("active", ""))
	var here: Array = []
	for rec in roster:
		if room == "house" and rec["uid"] == active: here.push_front(rec)
		elif room != "house" and rec["uid"] != active: here.append(rec)
	if room == "house":
		for rec in roster:
			if here.size() >= 3: break
			if not here.has(rec): here.append(rec)
	for rec in here.slice(0, 4):
		var n := Models.kin(rec["species"], rec)
		var at := _free_spot()
		n.position = at
		add_child(n)
		kins.append({"rec": rec, "node": n, "pos": at, "goal": at, "t": randf() * 2.0, "hop": 0.0})

func _free_spot() -> Vector3:
	for _i in 40:
		var p := Vector3(randf_range(0.6, W - 0.6), 0, randf_range(0.6, D - 1.2))
		if not _blocked(p.x, p.z): return p
	return Vector3(W * 0.5, 0, D - 1.5)

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	var d := minf(delta, 0.05)
	_move_player(d)
	for k in kins:
		k["t"] -= d
		if k["t"] <= 0.0:
			k["t"] = randf_range(2.0, 4.5)
			k["goal"] = _free_spot() if randf() < 0.7 else ppos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		var pos: Vector3 = k["pos"]
		if _blocked(pos.x, pos.z):
			# something got put down on top of it: hop out to open floor
			pos = _free_spot()
			k["goal"] = pos
		var to := Vector2(k["goal"].x - pos.x, k["goal"].z - pos.z)
		var n: Node3D = k["node"]
		if to.length() > 0.3:
			var st := to.normalized() * 1.8 * d
			if not _blocked(pos.x + st.x, pos.z): pos.x += st.x
			if not _blocked(pos.x, pos.z + st.y): pos.z += st.y
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.y), minf(1.0, d * 8.0))
			k["hop"] += d * 9.0
		k["pos"] = pos
		n.position = pos
		n.get_node("Body").position.y = absf(sin(k["hop"])) * 0.1
	cam.follow(Vector3(W * 0.5, 0, D * 0.5 - 0.6).lerp(ppos, 0.2), d, false)
	if decorating:
		dec.tick(d)
	else:
		_find_interact()
		if panel_open == "" and not Overlay.is_open() and Input.is_action_just_pressed("interact") and not interact.is_empty():
			_use(interact)

func _move_player(d: float) -> void:
	var mv := Vector2.ZERO
	if panel_open == "" and not Overlay.is_open():
		mv = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
		if mv.length() > 1.0: mv = mv.normalized()
	var hv := Vector2(pvel.x, pvel.z)
	hv += (mv * SPEED - hv) * (1.0 - exp(-14.0 * d))
	var nx := ppos.x + hv.x * d
	if not _blocked(nx, ppos.z): ppos.x = nx
	var nz := ppos.z + hv.y * d
	if not _blocked(ppos.x, nz): ppos.z = nz
	pvel = Vector3(hv.x, 0, hv.y)
	player.position = ppos
	if hv.length() > 0.3:
		pface = lerp_angle(pface, atan2(-hv.x, -hv.y), minf(1.0, d * 14.0))
	player.rotation.y = pface
	if not player.has_meta("anim"): player.set_meta("anim", HunterAnim.new(player))
	(player.get_meta("anim") as HunterAnim).update(d, {"vel": pvel, "face": pface, "fired": 99.0, "holster": true})

func _find_interact() -> void:
	var best := {}; var bd := 1.3
	for s in spots:
		var dd := Vector2(s["pos"].x - ppos.x, s["pos"].z - ppos.z).length()
		if dd < bd: bd = dd; best = s
	for k in kins:
		var dd := Vector2(k["pos"].x - ppos.x, k["pos"].z - ppos.z).length()
		if dd < bd: bd = dd; best = {"kind": "kin", "k": k, "label": "Pet %s" % k["rec"]["name"]}
	interact = best
	prompt_box.visible = not best.is_empty() and panel_open == ""
	if prompt_box.visible:
		prompt_lbl.text = Settings.key_cap("interact") + "  " + String(best["label"])
		prompt_box.reset_size()
		var vp := get_viewport().get_visible_rect().size
		prompt_box.position = Vector2((vp.x - prompt_box.size.x) * 0.5, vp.y - 120.0)

func _use(it: Dictionary) -> void:
	Sfx.play("click")
	match String(it["kind"]):
		"door": _leave()
		"kin": _pet_kin(it["k"])
		"journal": _open_journal()
		"gramophone": _open_music()

## Petting indoors counts just like outside: joy, likes, the memory and the first-day list.
func _pet_kin(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	Sfx.play("kin_happy", null, -4.0)
	fx.burst(k["pos"] + Vector3(0, 0.9, 0), Color("ff8fb0"), 10, 1.6)
	k["t"] = 1.2; k["goal"] = k["pos"]
	if not visit.is_empty():
		return
	var loves_pet: bool = rec.get("likes", {}).get("play", "") == "pet"
	var now_s := Time.get_ticks_msec() / 1000.0
	if now_s >= float(k.get("pet_ok", 0.0)):
		k["pet_ok"] = now_s + 20.0
		Care.change(rec, "joy", 12.0 if loves_pet else 5.0)
	if loves_pet and Care.discover(rec, "play"): _toast("%s loves scratches" % rec["name"])
	if int(rec.get("pet_m", -1)) != int(Save.d["matches"]):
		rec["pet_m"] = int(Save.d["matches"])
		Save.remember(rec, "petted", "got a long scratch behind the ears", 1.5)
	Save.save_game()

func _leave() -> void:
	if decorating: dec.toggle()
	Save.save_game()
	if not visit.is_empty():
		Game.goto("home", {"visit": visit, "visit_id": visit_id, "spawn": room})
	else:
		Game.goto("home", {"spawn": room})

func _unhandled_input(event: InputEvent) -> void:
	if decorating and panel_open == "" and not Overlay.is_open() and dec.input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") and not Overlay.is_open():
		if panel_open != "":
			_close_panel()
		else:
			Overlay.open_pause("home")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build") and visit.is_empty() and panel_open == "" and not Overlay.is_open():
		dec.toggle()

# ------------------------------------------------------------------ ui
var deco_btn: Button

func _build_ui() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root_ui)
	var top := UI.glass(8, 14)
	top.position = Vector2(16, 14)
	var th := UI.hbox(14); top.add_child(th)
	th.add_child(UI.title(String(R["name"]) if visit.is_empty() else "%s's house" % String(visit.get("name", "Their")), 24, UI.ACCENT))
	var sub := UI.label("%d gems" % int(Save.d["gems"]), 15)
	sub.name = "Gems"
	th.add_child(sub)
	root_ui.add_child(top)
	prompt_box = UI.glass(10, 16)
	prompt_lbl = UI.label("", 18, UI.GOLD, UI.big)
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_box.add_child(prompt_lbl)
	root_ui.add_child(prompt_box)
	if visit.is_empty():
		deco_btn = UI.primary("Decorate  (%s)" % Settings.key_cap("build"), func(): dec.toggle(), 200)
		deco_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		deco_btn.position = Vector2(16, -64)
		root_ui.add_child(deco_btn)
		deco_btn.reset_size()
		deco_btn.offset_top = -64; deco_btn.offset_bottom = -16; deco_btn.offset_left = 16; deco_btn.offset_right = 216
	panel_dim = UI.backdrop()
	panel_dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and panel_open != "":
			_close_panel())
	root_ui.add_child(panel_dim)
	panel_host = CenterContainer.new()
	panel_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(panel_host)

func _deco_button_text() -> void:
	if deco_btn:
		deco_btn.visible = not decorating
	_refresh_gems()

func _refresh_gems() -> void:
	var gems := root_ui.find_child("Gems", true, false)
	if gems: (gems as Label).text = "%d gems" % int(Save.d["gems"])

func _toast(txt: String) -> void:
	UI.toast(root_ui, txt)

func _new_panel(title_txt: String, width := 560.0) -> VBoxContainer:
	_close_panel()
	var pb := UI.scroll_panel(title_txt, width, _close_panel)
	panel_host.add_child(pb[0])
	panel_open = title_txt
	UI.show_backdrop(panel_dim, true)
	UI.pop_in(pb[0])
	return pb[1]

var panel_dim: ColorRect = null

func _close_panel() -> void:
	for ch in panel_host.get_children():
		ch.queue_free()
	if panel_open != "" and panel_dim: UI.show_backdrop(panel_dim, false)
	panel_open = ""

## Every kin you have, and who comes along on expeditions.
func _open_journal() -> void:
	var v := _new_panel("Boki journal", 640)
	v.add_child(UI.label("Your Boki out on the farm. The one you bring on expeditions is your partner.", 14, UI.MUTED))
	if not KinBox.boxed().is_empty():
		v.add_child(UI.label("%d more asleep in the Boki Burrow (open it on the farm to swap them out)." % KinBox.boxed().size(), 13, Color("cdb8ff")))
	for rec in KinBox.farm():
		var row := UI.card(UI.CARD, 10, 10)
		var h := UI.hbox(12); row.add_child(h)
		var sp: Dictionary = Data.KIN[rec["species"]]
		var dot := ColorRect.new(); dot.color = sp["color"]; dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var info := UI.label("%s the %s  ·  level %d  ·  trust %d" % [rec["name"], Evo.form_name(rec), int(rec["level"]), int(rec["trust"])], 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var r: Dictionary = rec
		if rec["uid"] == Save.d.get("active", ""):
			h.add_child(UI.label("Partner", 14, UI.GOLD))
		else:
			h.add_child(UI.button("Make partner", func():
				Save.d["active"] = r["uid"]
				Save.save_game()
				_open_journal()))
		v.add_child(row)

func _open_music() -> void:
	var v := _new_panel("Gramophone", 560)
	var heard: Array = Save.d.get("music", [])
	v.add_child(UI.label("Every tune you've heard on your travels. Pick one to play at home.", 14, UI.MUTED))
	for tid in Data.MUSIC:
		var md: Dictionary = Data.MUSIC[tid]
		var row := UI.hbox(10)
		var known := heard.has(tid)
		var l := UI.label(String(md["name"]) if known else "???  ·  " + String(md.get("hint", "")), 15, UI.INK if known else UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if known:
			var t: String = tid
			row.add_child(UI.choice("Playing" if Sfx.music_lock == tid else "Play", Sfx.music_lock == tid, func():
				Sfx.music_lock = t
				Sfx.play_music(t, 1.0)
				_open_music(), 110))
		v.add_child(row)
	if Sfx.music_lock != "":
		v.add_child(UI.button("Back to the island's own music", func():
			Sfx.music_lock = ""
			_open_music(), 300))

## The menu's "I'm stuck": back to the doormat.
func unstick() -> void:
	ppos = Vector3(W * 0.5, 0, D - 1.0)
	if player: player.position = ppos
