class_name MaskOffer
extends Node
## The second Relic, offered in the world (after the first finished expedition; ClassUnlock.second_pending). Once
## you are home and nothing else is on screen (no panel, no toast, no building), the portal glows and the three
## Relics on offer (Kael, Cinder, Meeko: ClassUnlock.second_picks) drift out of it and hover in a row in front of
## it while the camera takes them in. Walk up to one to see what it does (its name and two ability clips);
## interact takes it: it drifts to your face and plays the put-on beat (MaskMoment.beat), the other two drift
## back into the portal (they open through their own challenges), and the new Relic's reveal plays
## (ClassReveal). Walk away and they wait by the portal, each with its name and a ring under it.
## Home wires it in at a few points: the camera (frame), interact (find, label, use).
# "mask" in code = "Relic" in game, owner 2026-11-07 (also home.gd "masks", the "mask" item kind)

const ROW_OUT := 2.4           # m in front of the portal, toward where you stand
const ROW_GAP := 1.5           # m between the Relics
const HOVER_Y := 1.45          # m up
const OUT_S := 2.2             # s each Relic takes to drift out
const STAGGER_S := 0.35        # s between them leaving the portal
const FRAME_S := 4.0           # s the camera holds on them
const FRAME_ZOOM := 0.6
const FARM_SCALE := 2.4        # x a Relic's size by the portal: it has to read from the farm's high camera
const REACH := 2.2             # m: close enough to look at one and take it
const PREVIEW_CLIP := Vector2(210, 118)
const AWAY := "%s and %s return to the portal. Their own challenges open them."

var home: Node
var relics: Array = []         # MaskRelic, in second_picks order
var phase := "waiting"         # waiting (for a clear screen) | out | ready | taking
var near_id := ""
var preview: Control
var ui: CanvasLayer
var flash: ColorRect
var glow: OmniLight3D
var _frame_t := -1.0
var _row_mid := Vector3.ZERO

## Puts the second-Relic offer on the farm when it is due. Returns whether one is (or was already) there.
static func offer(farm: Node) -> bool:
	if not ClassUnlock.second_pending() or farm == null or not farm.is_inside_tree():
		return false
	if not farm.find_children("*", "MaskOffer", false, false).is_empty():
		return true
	var m := MaskOffer.new()
	m.home = farm
	farm.add_child(m)
	farm.masks = m
	return true

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)

## Only on a clear screen: no panel, nothing being built, the welcome done and no toast showing.
func _clear() -> bool:
	return home.panel_open == "" and not home.building_now and bool(Save.d["tutorial"].get("home", false)) \
			and not UI.toast_busy(home.root_ui)

func _portal() -> Vector3:
	return home.spots["portal"]

## The portal glows and the Relics drift out to hover in a row in front of it, facing you.
func _come_out() -> void:
	phase = "out"
	var portal := _portal()
	var toward := Vector3(home.ppos.x - portal.x, 0, home.ppos.z - portal.z)
	toward = toward.normalized() if toward.length() > 0.5 else Vector3.BACK
	var side := toward.cross(Vector3.UP).normalized()
	_row_mid = portal + toward * ROW_OUT + Vector3(0, HOVER_Y, 0)
	glow = OmniLight3D.new()
	glow.position = portal + Vector3(0, 1.6, 0)
	glow.omni_range = 7.0
	home.add_child(glow)
	var gt := create_tween()
	gt.tween_property(glow, "light_energy", 4.0, 0.6)
	gt.tween_property(glow, "light_energy", 1.2, 1.4)
	var ids := ClassUnlock.second_picks()
	for i in ids.size():
		var relic := MaskRelic.make(String(ids[i]))
		relic.position = portal + Vector3(0, 1.6, 0)
		relic.ready.connect(func(): relic.scale = Vector3.ONE * FARM_SCALE)
		relic.visible = false
		home.add_child(relic)
		relics.append(relic)
		_mark(relic)
		var at := _row_mid + side * ROW_GAP * (i - (ids.size() - 1) * 0.5)
		get_tree().create_timer(0.5 + STAGGER_S * i).timeout.connect(func():
			relic.visible = true
			relic.drift_to(at, OUT_S, 0.6))
	_frame_t = 0.0
	home.cam.zoom_to = FRAME_ZOOM
	Sfx.play("whoosh")
	get_tree().create_timer(0.5 + STAGGER_S * ids.size() + OUT_S).timeout.connect(func(): phase = "ready")

## Its name floating over it and a ring of its colour on the ground under it, so you find it again.
func _mark(relic: MaskRelic) -> void:
	var col := Arch.color(relic.id)
	var tag := Label3D.new()
	tag.text = HeroTitle.base_name(relic.id)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 48
	tag.outline_size = 12
	tag.pixel_size = 0.006
	tag.modulate = col.lightened(0.3)
	tag.position = Vector3(0, 0.42, 0)
	relic.add_child(tag)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(0.7)
	ring.material_override = Models.ring_mat(Color(col, 0.75), 0.1)
	ring.position = Vector3(0, (0.05 - HOVER_Y) / FARM_SCALE, 0)
	relic.add_child(ring)

## The camera's focus: on you, drawn over to take in the Relics while they come out.
func frame(at: Vector3) -> Vector3:
	if _frame_t < 0.0:
		return at
	var k := smoothstep(0.0, 0.8, _frame_t) * (1.0 - smoothstep(FRAME_S - 0.8, FRAME_S, _frame_t))
	return at.lerp(Vector3(_row_mid.x, at.y, _row_mid.z).lerp(at, 0.35), k)

func _process(dt: float) -> void:
	if phase == "waiting":
		if _clear():
			_come_out()
		return
	if _frame_t >= 0.0:
		_frame_t += dt
		if _frame_t > FRAME_S:
			_frame_t = -1.0
			home.cam.zoom_to = home.HOME_ZOOM
	var eye := get_viewport().get_camera_3d()
	for r in relics:
		if eye and is_instance_valid(r) and (r as MaskRelic).bobbing:
			(r as MaskRelic).face_to = eye.global_position      # (their faces turned up to you)
	if phase == "ready":
		var id := _nearest()
		if id != near_id:
			near_id = id
			_show_preview()

func _nearest() -> String:
	var best := ""
	var bd := REACH
	for r in relics:
		var rp := (r as Node3D).position
		var d := Vector2(rp.x, rp.z).distance_to(Vector2(home.ppos.x, home.ppos.z))
		if d < bd:
			bd = d
			best = (r as MaskRelic).id
	return best

## The Relic you're at: its name and title, and two of its abilities working (AbilityClip).
func _show_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null
	if near_id == "" or home.panel_open != "":
		return
	var col := Arch.color(near_id)
	var card := UI.card(Color(0.05, 0.045, 0.08, 0.94), 12, 14)
	card.set_meta("mask_preview", near_id)
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(10)
	head.add_child(ClassCard.portrait(near_id, 44.0))
	var nm := UI.title(HunterViewer.display_name(near_id), 24, col)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	v.add_child(head)
	var clips := UI.hbox(8)
	for slot in preview_slots(near_id):
		clips.add_child(AbilityClip.make(near_id, String(slot), PREVIEW_CLIP))
	v.add_child(clips)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.position.y = 70
	holder.add_child(card)
	ui.add_child(holder)
	preview = holder
	UI.pop_in(card)

## The two abilities a Relic's preview shows (its "clip" block's "preview", else attack and right click).
static func preview_slots(hunter_id: String) -> Array:
	var own: Array = (Arch.def(hunter_id).get("clip", {}) as Dictionary).get("preview", [])
	return own if own.size() == 2 else ["lmb", "rmb"]

# ------------------------------------------------------------------ interact (Home's find, label, use)
## The Relic in reach of `p2`, for Home's interact prompt.
func find(p2: Vector2) -> Dictionary:
	if phase != "ready":
		return {}
	var id := _nearest()
	return {} if id == "" else {"kind": "mask", "id": id}

func label(it: Dictionary) -> String:
	return "Put on %s" % HunterViewer.display_name(String(it["id"]))

func use(it: Dictionary) -> void:
	take(String(it["id"]))

## Takes this Relic: it drifts to your face (the put-on beat), the others go back into the portal, and its
## reveal plays.
func take(id: String) -> void:
	if phase != "ready" or not ClassUnlock.choose_second(id):
		return
	Save.save_game()
	phase = "taking"
	near_id = ""
	_show_preview()
	var others: Array = []
	for r in relics:
		var relic := r as MaskRelic
		if relic.id == id:
			MaskMoment.beat(relic, home.player, flash, func(_body): _taken(), false)
		else:
			others.append(HeroTitle.base_name(relic.id))
			relic.drift_to(_portal() + Vector3(0, 1.6, 0), 1.4, 0.3).finished.connect(relic.queue_free)
	home._toast(AWAY % others)

func _taken() -> void:
	ClassReveal.maybe_show(home)
	if glow:
		glow.queue_free()
	home.masks = null
	queue_free()
