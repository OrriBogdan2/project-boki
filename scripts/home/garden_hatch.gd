class_name GardenHatch
extends Node3D
## The first beat of a new save, in the garden (reviews/DESIGN_REVIEW_1110.md change 2): the three starter
## eggs in their nests in front of you and the black mystery egg in its basket at the back (MysteryEgg,
## DECISIONS 11-08). Pick one, knock on the shell until it hatches, take a closer look (KinReveal) and name
## it; then the farm opens with your Boki (Home is rebuilt) and your first Relic waits at the portal (Hatch).
## Home places one while the roster is empty (needed()); it brings its own camera and screen.

## Names, tempers and blurbs come from each species' "egg" block in content/kin/<id>.json, so every
## egg is named for its element (Venom Egg, ...).
const STARTERS := ["cindle", "puddlet", "burrlet"]
const MYSTERY := {
	"species": "mystery",
	"name": "Mystery Egg",
	"temper": "???",
	"desc": "Black as a moonless night, tucked in an old basket at the back. Nobody knows what's inside.",
	"play":
	(
		"Almost anything from the wilds could be in there, even a rare one,"
		+ " and it's more likely than most to hatch a little strange."
	),
}
const PANEL := "Hatch"  # Home.panel_open while the eggs are up: you stand still
const AHEAD_M := 3.5  # m from where you land to the eggs (the camera looks from your side)
const YOU_AT := Vector3(2.5, 0, -1.0)  # m from the eggs: where you stand while they hatch
const MYSTERY_AT := Vector3(-2.75, 0, -2.55)  # m from the eggs: the basket, at the back
const CAM_PICK := Vector3(0, 3.6, 6.4)  # m from the eggs: the camera while you choose
const CAM_KNOCK := Vector3(0, 2.5, 5.4)
const CAM_CLOSE := Vector3(0, 1.9, 4.2)  # leaned in by the last knock
const CAM_REVEAL := Vector3(0, 2.2, 5.6)
const TAPS := 7  # knocks until it hatches
const KNOCK_TITLES := [
	"Knock on the shell",
	"Something stirs...",
	"It knocks back.",
	"Again, gently.",
	"It's pushing.",
	"It's cracking.",
	"Nearly.",
	"Here it comes."
]

var h: Node = null  # the home this runs in (null in a check: then it stands alone)
var cam: Camera3D
var fx: Fx
var eggs: Array = []  # {holder, egg, base, data}
var egg_defs: Array = []  # the four eggs, the mystery egg's species (and its mutations) decided
var chosen := -1
var hover := -1
var stage := "pick"  # pick | warm | hatching | reveal | name
var mystery_found := false  # its card shows once you've hovered or picked the black egg
var kin_node: Node3D
var auto_warm := false  # test hook: knocks by itself
var taps := 0
var warmth := 0.0
var warm_bar: Control
var ui: CanvasLayer
var root_ui: Control
var bottom: VBoxContainer
var title: Label
var top_box: VBoxContainer
var sub_lbl: Label  # the line under the title, for the pick only
var cam_to := CAM_PICK
var t := 0.0


static func needed() -> bool:
	return Save.d["roster"].is_empty()


static func starter_eggs() -> Array:
	var out: Array = []
	for sp in STARTERS:
		var e: Dictionary = Data.egg_info(sp)
		e["species"] = sp
		for k in ["temper", "desc", "play"]:
			if not e.has(k):
				e[k] = ""
		out.append(e)
	out.append(MYSTERY.duplicate())
	return out


## Puts the eggs a few steps in from where you landed (toward the house spot, clear of the portal), you beside
## them, and holds you still. The farm's screen and Hob wait until the Boki is named (the farm is rebuilt then).
static func place(home: Node, at: Vector3) -> GardenHatch:
	var g := GardenHatch.new()
	g.h = home
	g.position = at + Vector3(0, 0, -AHEAD_M)
	home.ppos = g.position + YOU_AT
	home.panel_open = PANEL
	home.ui.visible = false
	if home.hob:
		home.hob.node.visible = false
	home.add_child(g)
	return g


func _ready() -> void:
	fx = Fx.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = CAM_PICK + Vector3(0, 2.6, 4.0)
	cam.make_current()
	egg_defs = starter_eggs()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for d in egg_defs:
		if d["species"] == "mystery":
			d["species"] = MysteryEgg.roll_species(rng)
			d["rec"] = {"mutations": MysteryEgg.roll_mutations(rng)}
			d["mystery"] = true
	for i in egg_defs.size():
		var d: Dictionary = egg_defs[i]
		var holder := Node3D.new()
		holder.position = MYSTERY_AT if d.get("mystery", false) else Vector3(-1.7 + i * 1.7, 0, 0.2)
		add_child(holder)
		var egg := EggHatch.new(d["species"], fx, 0.32, 0.42, 1.1, d.get("rec", {}))
		if d.get("mystery", false):
			holder.add_child(MysteryEgg.new())
			MysteryEgg.hideout(self, MYSTERY_AT)
			egg.shell_col = MysteryEgg.SHELL
			egg.spot_col = MysteryEgg.SPOTS
		else:
			holder.add_child(_nest())
		egg.hop_out = 0.35
		egg.position = Vector3(0, 0.12, 0)
		holder.add_child(egg)
		eggs.append({"holder": holder, "egg": egg, "base": holder.position, "data": d})
	_build_ui()


## A starter egg's nest, without the eggs it comes with.
func _nest() -> Node3D:
	var nest := Models.nest()
	nest.scale = Vector3.ONE * 0.8
	for ch in nest.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is SphereMesh:
			ch.visible = false
	return nest


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 12
	add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.theme = UI.theme()
	ui.add_child(root_ui)
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 36
	top_box = top
	title = UI.title("Choose your first Boki", 40, UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09, 0.85))
	top.add_child(title)
	var sub := UI.label("Every Boki is different. It will remember how you treat it.", 16, Color(1, 0.95, 0.88, 0.95))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl = sub
	top.add_child(sub)
	root_ui.add_child(top)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -330
	holder.offset_bottom = -14
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN  # a tall card grows up, never off the bottom
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(holder)
	bottom = UI.vbox(10)
	holder.add_child(bottom)
	_show_pick()


func _clear_bottom() -> void:
	for ch in bottom.get_children():
		ch.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if stage == "warm" and (click or event.is_action_pressed("jump")):
		_tap_egg()
	elif stage == "pick" and click and hover >= 0:
		_pick(hover)


## Which egg the mouse is over, by distance on screen.
func _egg_under_mouse() -> int:
	var mp := get_viewport().get_mouse_position()
	var best := -1
	var bd := 70.0
	for i in eggs.size():
		var p: Vector3 = (eggs[i]["holder"] as Node3D).global_position + Vector3(0, 0.45, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(mp)
		if d < bd:
			bd = d
			best = i
	return best


func _show_pick() -> void:
	_clear_bottom()
	var row := UI.hbox(14)
	for i in egg_defs.size():
		var d: Dictionary = egg_defs[i]
		var mystery: bool = d.get("mystery", false)
		if mystery and not mystery_found:
			continue
		row.add_child(_egg_card(i, d, mystery))
	bottom.add_child(row)


## One egg's card: every card the same size, with its button on the same line at the bottom.
func _egg_card(i: int, d: Dictionary, mystery: bool) -> Control:
	var card := UI.card(UI.CARD, 12, 14)
	card.custom_minimum_size = Vector2(228, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_FILL
	if i == chosen:
		UI.set_card_border(card, UI.ACCENT)
	var v := UI.vbox(6)
	card.add_child(v)
	var hr := UI.hbox(8)
	var ecol: Color = Color("c4bcd6") if mystery else Data.KIN[d["species"]]["color"]
	while ecol.get_luminance() < 0.55:
		ecol = ecol.lerp(Color.WHITE, 0.2)  # dark shells still need a readable name
	var tt := UI.title(d["name"], 22, ecol)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tt)
	hr.add_child(UI.section(d["temper"], ecol))
	v.add_child(hr)
	var dl := UI.label(d["desc"], 14, UI.MUTED)
	dl.custom_minimum_size.x = 200
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	if i == chosen:
		var pl := UI.label(d["play"], 13, UI.INK)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(push)
	var make: Callable = UI.primary if i == chosen else UI.button
	var pb: Button = make.call("Hatch it" if i == chosen else "This one", func(): _pick(i))
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(pb)
	return card


func _pick(i: int) -> void:
	if stage != "pick":
		return
	if chosen == i:
		_start_hatch()
		return
	chosen = i
	mystery_found = mystery_found or egg_defs[i].get("mystery", false)
	Sfx.play("click")
	_show_pick()


## Hatching by knocks: each tap is a gentle knock on the shell, and something knocks back. The egg rocks a
## little more each time, a new crack opens, the camera leans in, and the knocks from inside get stronger.
## No flashes or bursts: it's a small, close moment (docs/POSITIONING.md).
func _tap_egg() -> void:
	if taps >= TAPS or chosen < 0:
		return
	taps += 1
	var k := float(taps) / TAPS
	var wegg: EggHatch = eggs[chosen]["egg"]
	var holder: Node3D = eggs[chosen]["holder"]
	var hop := create_tween()
	var up := hop.tween_property(wegg, "position:y", 0.28 + 0.12 * k, 0.1 + 0.04 * k)
	up.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(wegg, "position:y", 0.12, 0.14 + 0.05 * k).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	wegg.rotation.z = (0.08 + 0.22 * k) * (1.0 if taps % 2 == 0 else -1.0)
	var sq := create_tween()
	wegg.scale = Vector3(1.04 + 0.06 * k, 0.96 - 0.05 * k, 1.04 + 0.06 * k)
	sq.tween_property(wegg, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var base := 8 + taps * 3
	wegg._crack(base, base + 2 + int(k * 2.0))
	fx.burst(holder.global_position + Vector3(0, 0.5, 0), wegg.col.lightened(0.2), int(2 + 4 * k), 1.2, 0.35, 6.0, 0.5)
	# your knock, then its knock back from inside
	Sfx.play("thump", null, -16.0 + 4.0 * k, 0.04, 1.3)
	get_tree().create_timer(0.22).timeout.connect(func(): Sfx.play("thump", null, -20.0 + 8.0 * k, 0.05, 1.6 - 0.2 * k))
	cam_to = CAM_KNOCK.lerp(CAM_CLOSE, k)
	title.text = KNOCK_TITLES[mini(taps, KNOCK_TITLES.size() - 1)]


func _start_hatch() -> void:
	stage = "warm"
	_clear_bottom()
	sub_lbl.visible = false
	title.text = KNOCK_TITLES[0]
	taps = 0
	var card := UI.card(UI.CARD, 14, 16)
	card.custom_minimum_size = Vector2(460, 0)
	var v := UI.vbox(10)
	card.add_child(v)
	var l := UI.label(
		"Knock on the egg: click (or press Space). Every knock wakes it a little more," + " and it knocks back.", 15
	)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	warm_bar = Control.new()
	warm_bar.custom_minimum_size = Vector2(420, 16)
	warm_bar.draw.connect(
		func():
			var warm := Color("ff9a5a").lerp(Color("ffd36a"), snappedf(warmth, 0.05))
			UI.draw_bar(warm_bar, Rect2(Vector2.ZERO, warm_bar.size), warmth, warm, Color(0, 0, 0, 0.45), 8)
	)
	v.add_child(warm_bar)
	bottom.add_child(card)
	Sfx.play("whoosh")
	for i in eggs.size():
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		if i == chosen:
			tw.tween_property(eggs[i]["holder"], "position", Vector3(0, 0, 0.6), 0.7)
		else:
			tw.tween_property(eggs[i]["holder"], "scale", Vector3.ONE * 0.01, 0.5)
	cam_to = CAM_KNOCK


func _process(delta: float) -> void:
	t += delta
	cam.position = cam.position.lerp(cam_to, minf(1.0, delta * 2.0))
	cam.position += Vector3(sin(t * 0.37) * 0.004, sin(t * 0.51) * 0.003, 0)  # never quite still
	var look_y := 0.25
	if stage == "pick":
		look_y = 0.55
	elif stage == "name":
		look_y = -0.55
	cam.look_at(to_global(Vector3(0, look_y, 0.5)))
	if stage == "pick":
		_hover_eggs(delta)
	elif stage == "warm":
		_warm(delta)


func _hover_eggs(delta: float) -> void:
	var hv := _egg_under_mouse()
	if hv != hover:
		hover = hv
		if hover >= 0:
			Sfx.play("hover", null, -12.0)
		if hover >= 0 and egg_defs[hover].get("mystery", false) and not mystery_found:
			mystery_found = true
			_show_pick()
	for i in eggs.size():
		var hn: Node3D = eggs[i]["holder"]
		hn.scale = hn.scale.lerp(Vector3.ONE * (1.12 if i == hover else 1.0), minf(1.0, delta * 10.0))
		var egg: Node3D = eggs[i]["egg"]
		var lift := (0.12 + sin(t * 3.0) * 0.03) if i == chosen else 0.0
		egg.position.y = lerpf(egg.position.y, 0.12 + lift, minf(1.0, delta * 8.0))
		# a little wobble now and then, like something inside is awake
		egg.rotation.z = sin(t * 2.0 + i * 2.1) * 0.06 * (1.0 + float(sin(t * 0.7 + i) > 0.7) * 3.0)


func _warm(delta: float) -> void:
	if auto_warm and int(t * 3.0) != int((t - delta) * 3.0):
		_tap_egg()
	warmth = lerpf(warmth, float(taps) / TAPS, minf(1.0, delta * 10.0))
	if warm_bar:
		warm_bar.queue_redraw()
	var wegg: EggHatch = eggs[chosen]["egg"]
	wegg.set_warmth(warmth)
	# between knocks it trembles, more and more the closer it is
	wegg.rotation.z = lerpf(wegg.rotation.z, sin(t * (6.0 + warmth * 30.0)) * warmth * 0.05, minf(1.0, delta * 12.0))
	if taps < TAPS or warmth < 0.98:
		return
	stage = "hatching"
	title.text = "Something's moving..."
	_clear_bottom()
	wegg.rotation.z = 0.0
	wegg.position.y = 0.12
	wegg.popped.connect(
		func(k: Node3D):
			kin_node = k
			title.text = "It's looking at you."
	)
	wegg.done.connect(_reveal)
	wegg.start()


## A closer look (its card, and turning it round), then naming.
func _reveal() -> void:
	stage = "reveal"
	cam_to = CAM_REVEAL
	var rv := KinReveal.new(egg_defs[chosen]["species"], egg_defs[chosen].get("rec", {}))
	add_child(rv)
	top_box.visible = false  # (the reveal has its own title)
	rv.proceed.connect(
		func():
			top_box.visible = true
			stage = "name"
			_show_name()
	)


func _show_name() -> void:
	_clear_bottom()
	var sp_id: String = egg_defs[chosen]["species"]
	var sp: Dictionary = Data.KIN[sp_id]
	var card := UI.card(UI.CARD, 16, 18)
	card.custom_minimum_size = Vector2(520, 0)
	var v := UI.vbox(10)
	card.add_child(v)
	var scol: Color = sp["color"]
	while scol.get_luminance() < 0.55:
		scol = scol.lerp(Color.WHITE, 0.2)  # (a dark species colour vanishes on the dark card)
	v.add_child(UI.section("A new Boki", scol))
	v.add_child(UI.title("Name your %s" % sp["name"], 34))
	v.add_child(UI.label('"%s"' % KinSpeak.babble(sp_id, "happy"), 22, scol))
	var voice := String(sp["voice"]).split(",")[0]
	v.add_child(
		UI.label(
			"It's %s, and it can only babble for now. Whatever you call it, it'll answer to." % voice, 16, UI.MUTED
		)
	)
	var ne := LineEdit.new()
	ne.text = Data.default_kin_name(sp_id)
	ne.max_length = 14
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_row("Its name", ne))
	v.add_child(_ideas(ne))
	var btns := UI.hbox(10)
	btns.add_child(UI.primary("Welcome home", func(): finish(sp_id, ne.text), 240))
	v.add_child(btns)
	bottom.add_child(card)
	UI.pop_in(card)
	ne.text_submitted.connect(func(_t): finish(sp_id, ne.text))
	ne.grab_focus()
	ne.select_all()


func _row(what: String, field: Control) -> Control:
	var row := UI.hbox(8)
	var l := UI.label(what, 15, UI.MUTED)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	row.add_child(field)
	return row


## An idea button: its name goes into the field.
func _put_name(ne: LineEdit, nm: String) -> void:
	ne.text = nm
	ne.caret_column = nm.length()


## A few name ideas, and a button for a fresh handful.
func _ideas(ne: LineEdit) -> Control:
	var picks := UI.hbox(6)
	var fill := func(again: Callable) -> void:
		for ch in picks.get_children():
			ch.queue_free()
		var il := UI.label("Ideas", 13, UI.MUTED)
		il.custom_minimum_size.x = 120
		il.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picks.add_child(il)
		var pool: Array = Data.KIN_NAMES.duplicate()
		pool.shuffle()
		for nm in pool.slice(0, 4):
			var n2: String = nm
			picks.add_child(UI.button(n2, _put_name.bind(ne, n2)))
		var more := UI.button("More", func(): again.call(again))
		more.flat = true
		picks.add_child(more)
	fill.call(fill)
	return picks


## Your first Boki joins the save, then the farm opens with it (the Relic waits at the portal).
func finish(sp_id: String, kname: String) -> void:
	var rec := Save.new_kin(sp_id, kname.strip_edges() if kname.strip_edges() != "" else Data.default_kin_name(sp_id))
	rec["trust"] = 55.0
	var muts: Array = egg_defs[chosen].get("rec", {}).get("mutations", []) if chosen >= 0 else []
	if not muts.is_empty():
		rec["mutations"] = muts
	Save.remember(rec, "hatched", "hatched from an egg you chose")
	rec["starter"] = true  # your first kin: it always stays on the farm with you
	rec["got_t"] = Time.get_unix_time_from_system()
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	Save.register(rec, "starter")  # serial #1 of its kind, you as its trainer
	Save.d["tutorial"]["hatched"] = true
	Save.save_game()
	Sfx.play("click")
	if h:
		Game.goto("home")
