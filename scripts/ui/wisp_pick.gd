class_name WispPick
extends RefCounted
## The Wisp picker on the Hunters screen, under the glider pick (HomeClasses): every Wisp look
## (WispLook, content/rules/wisp_looks.json) as a card with a small live preview, its name and a click that
## wears it from now on. The worn one is marked; one you haven't earned is greyed and says how to get it.
## The preview is the real Wisp body in your colour, so every look keeps the round "person" outline.

const PREVIEW := Vector2i(72, 72)     # px, one preview
const CAM_BACK := 0.9                 # m, the camera's distance from the Wisp (frames the body and head)
const BOB := 0.04                     # m, the preview's idle bob (the in-match bob is the look's own)
const BOB_SECONDS := 1.6              # s, one bob

## The picker: a title and one card per look. `on_change` runs after a new Wisp is worn (and saved).
static func make(on_change: Callable) -> Control:
	var v := UI.vbox(4)
	v.set_meta("wisp_pick", true)
	v.add_child(UI.label("Wisp", 12, UI.MUTED, UI.caps))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for id in WispLook.rules()["looks"]:
		flow.add_child(card(String(id), on_change))
	return v

## One look: preview over a choice button. The worn one is chosen, a locked one disabled and greyed.
static func card(id: String, on_change: Callable) -> Control:
	var look := WispLook.get_look(id)
	var owned := WispLook.owned(id)
	var c := UI.vbox(2)
	c.set_meta("wisp", id)
	c.add_child(preview(look))
	var b := UI.choice(String(look["name"]), id == WispLook.equipped(), func(): _wear(id, on_change), 0)
	b.disabled = not owned
	b.tooltip_text = String(look["desc"]) if owned else "Unlocks: %s" % WispLook.how(id)
	c.add_child(b)
	if not owned:
		c.modulate = Color(1, 1, 1, 0.45)
		c.add_child(UI.label(WispLook.how(id), UI.T_SMALL, UI.MUTED))
	return c

static func _wear(id: String, on_change: Callable) -> void:
	if not WispLook.equip(id):
		return
	Save.save_game()
	Sfx.play("scan_pop", null, -10.0, 0.0, 1.2)
	on_change.call()

## The Wisp body of a look in its own little world, bobbing; the rim is your colour.
static func preview(look: Dictionary) -> SubViewportContainer:
	var c := SubViewportContainer.new()
	c.stretch = true
	c.custom_minimum_size = Vector2(PREVIEW)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = PREVIEW
	c.add_child(vp)
	var wisp := WispLook.build(look, SideColor.YOU)
	vp.add_child(wisp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.13, CAM_BACK)
	vp.add_child(cam)
	wisp.tree_entered.connect(func(): _bob(wisp), CONNECT_ONE_SHOT)
	return c

static func _bob(wisp: Node3D) -> void:
	var bob := wisp.create_tween().set_loops()
	bob.tween_property(wisp, "position:y", BOB, BOB_SECONDS * 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(wisp, "position:y", -BOB, BOB_SECONDS * 0.5).set_trans(Tween.TRANS_SINE)
