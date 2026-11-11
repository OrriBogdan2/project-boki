class_name StompPick
extends RefCounted
## The stomp picker on the Hunters screen, under the Wisp pick (HomeClasses): the picked Hunter's own stomp
## and every stomp style sold for gems (StompLook, content/rules/stomps.json), each a card with a short live
## preview of this Hunter stomping that way. The worn one is marked; one you don't own shows its price and
## a Buy button that spends the gems (StompLook.buy) and wears it. Every style keeps Stomp's timing.

const PREVIEW := Vector2i(96, 120)    # px, one preview
const PAUSE := 0.8                    # s, standing still between two run-throughs of the stomp
const CAM_FROM := Vector3(-1.7, 1.1, -3.9)   # m (times the model's scale), a front three-quarter view
const CAM_AT := 0.8                   # m (times the model's scale), the height the camera looks at

## The picker: a title and one card per stomp. `on_change` runs after a stomp is bought or worn (and saved).
static func make(hunter_id: String, on_change: Callable) -> Control:
	var v := UI.vbox(4)
	v.set_meta("stomp_pick", true)
	var title := UI.label("Stomp", 12, UI.MUTED, UI.caps)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.tooltip_text = "How you finish a downed enemy: hold %s on its Wisp." % Settings.key_cap("interact")
	v.add_child(title)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	flow.add_child(card(hunter_id, "", on_change))
	for id in StompLook.rules()["styles"]:
		if StompLook.style(String(id)).has("cost"):
			flow.add_child(card(hunter_id, String(id), on_change))
	return v

## One stomp ("" = the Hunter's own): preview over a choice button, or over its name and a Buy button.
static func card(hunter_id: String, id: String, on_change: Callable) -> Control:
	var shown := id if id != "" else StompLook.default_for(hunter_id)
	var st := StompLook.style(shown)
	var c := UI.vbox(2)
	c.set_meta("stomp", id)
	c.add_child(preview(hunter_id, shown))
	if id == "" or StompLook.owned(id):
		var b := UI.choice(String(st["name"]), id == StompLook.equipped(), func(): _wear(id, on_change), 0)
		b.tooltip_text = String(st.get("desc", "This Hunter's own stomp."))
		c.add_child(b)
		return c
	var cost := int(st["cost"])
	c.add_child(UI.label(String(st["name"]), UI.T_SMALL, UI.MUTED))
	var buy := UI.button("Buy  ·  %d gems" % cost, func(): _buy(id, on_change), 0, "gem")
	buy.disabled = int(Save.d.get("gems", 0)) < cost
	buy.tooltip_text = String(st.get("desc", ""))
	if buy.disabled:
		buy.tooltip_text += "\nYou have %d gems." % int(Save.d.get("gems", 0))
	c.add_child(buy)
	return c

static func _wear(id: String, on_change: Callable) -> void:
	if not StompLook.equip(id):
		return
	Save.save_game()
	Sfx.play("scan_pop", null, -10.0, 0.0, 1.2)
	on_change.call()

static func _buy(id: String, on_change: Callable) -> void:
	if not StompLook.buy(id) or not StompLook.equip(id):
		return
	Save.save_game()
	Sfx.play("unlock", null, -4.0)
	on_change.call()

## The Hunter in its own little lit world, stomping in a style over and over.
static func preview(hunter_id: String, style_id: String) -> SubViewportContainer:
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
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8a93b8")
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 160, 0)
	key.light_color = Color("fff1dc")
	vp.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	vp.add_child(Stage.new(hunter_id, style_id, cam))
	return c

## Builds the Hunter when PreviewBuild gives it a turn, then plays the stomp: Stomp.TIME of beats, a pause.
class Stage extends Node3D:
	var hunter_id: String
	var style_id: String
	var cam: Camera3D
	var anim: HunterAnim
	var t := 0.0

	func _init(hunter: String, style: String, camera: Camera3D) -> void:
		hunter_id = hunter
		style_id = style
		cam = camera
		name = "StompStage"

	func _process(dt: float) -> void:
		if anim == null:
			if not PreviewBuild.turn(hunter_id):
				return
			var model := PreviewBuild.model(hunter_id)
			add_child(model)
			anim = HunterAnim.new(model)
			var s := model.scale.y
			cam.transform = Transform3D(Basis(), CAM_FROM * s).looking_at(Vector3(0, CAM_AT * s, 0), Vector3.UP)
		t = fmod(t + minf(dt, 0.1), Stomp.TIME + PAUSE)
		var beat := t / (Stomp.TIME / Stomp.BEATS) if t < Stomp.TIME else -1.0
		anim.update(minf(dt, 0.1), {"fired": 99.0, "face": 0.0, "grounded": true, "wid": Arch.signature(hunter_id),
				"stomp": beat, "stomp_style": style_id})
