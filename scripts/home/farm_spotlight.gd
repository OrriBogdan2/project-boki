class_name FarmSpotlight
extends Control
## The tutorial spotlight: the screen darkens with a rounded cut-out round the one thing to do next (a bottom-bar
## button and/or a Boki in the world), the cut-out flashes a few times with the hint beside it, then the dim eases
## to a light vignette and the ring keeps a soft pulse until the thing is clicked. FarmGuide drives it (sync, every
## poll); a step asks for it with "spot" in farm_tutorial.json ({"hub": button id, "world": true}).
## Only the opening beat swallows mouse clicks; after it nothing here takes a click, so the target is always clickable.

const BEAT_S := 0.9              # s, the opening beat: clicks held, the target flashes
const FLASHES := 3               # ring flashes in the beat
const DIM_BEAT := 0.72           # alpha of the dark round the target in the beat
const DIM_VIGNETTE := 0.3        # alpha the dark settles to, far from the target
const SOFT_BEAT_PX := 40.0       # px the dark takes to build up outside the cut-out in the beat
const SOFT_VIGNETTE_PX := 380.0  # the same once settled: a wide, light vignette
const EASE_S := 0.45             # s the beat takes to settle
const RING_PAD_PX := 6.0         # px between the target and its ring
const FLASH_GROW_PX := 8.0       # px the ring swells at the top of a flash
const RING_WIDTH_PX := 3
const CORNER_PX := 14
const SOFT_PULSE_HZ := 0.8       # pulses per second once settled
const BOKI_HEIGHT_M := 1.7       # m, how tall the cut-out round a Boki is
const BOKI_MIN_PX := 64.0        # px, the smallest cut-out round a Boki (one far off)
const CARD_GAP_PX := 24.0        # px between the cut-out and the hint card
const CARD_WIDTH_PX := 340.0
const SCREEN_EDGE_PX := 8.0

const SHADER := """
shader_type canvas_item;
uniform vec2 area = vec2(1280.0, 720.0);
uniform vec4 hole_a = vec4(-9000.0, -9000.0, 1.0, 1.0);
uniform vec4 hole_b = vec4(-9000.0, -9000.0, 1.0, 1.0);
uniform float corner = 14.0;
uniform float dim = 0.7;
uniform float soft = 40.0;
float edge(vec2 p, vec4 r) {
	vec2 q = abs(p - (r.xy + r.zw * 0.5)) - r.zw * 0.5 + vec2(corner);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}
void fragment() {
	vec2 p = UV * area;
	float d = min(edge(p, hole_a), edge(p, hole_b));
	COLOR = vec4(0.02, 0.03, 0.07, dim * smoothstep(0.0, soft, d));
}
"""

static var _shader: Shader = null
static var _node: FarmSpotlight = null
static var _key := ""
static var _seen := {}           # target keys that have had their beat (once each per run of the game)

var h: Node
var step_id := ""
var spec := {}
var beat := true
var age := 0.0
var closing := false
var _dim: ColorRect
var _mat: ShaderMaterial
var _ring: StyleBoxFlat
var _card: PanelContainer = null
var _holes: Array[Rect2] = []
var _ring_pad := RING_PAD_PX

## Starts, keeps or ends the spotlight for the tutorial's current step. FarmGuide calls this every poll.
static func sync(home: Node, quiet: bool) -> void:
	var id := FarmTutorial.current()
	var want := {}
	if not quiet and id != "" and _free_to_show(home):
		want = FarmTutorial.spot(id)
	var key := JSON.stringify(want, "", true) if not want.is_empty() else ""
	if key == _key and is_instance_valid(_node):
		return
	close()
	if key == "" or _rects(home, id, want).is_empty():
		return
	_key = key
	_node = FarmSpotlight.new(home, id, want, not _seen.has(key))
	_seen[key] = true
	home.root_ui.add_child(_node)

## Fades the spotlight out (a menu opened, the step moved on, a talk began).
static func close() -> void:
	if is_instance_valid(_node):
		_node.fade_out()
	_node = null
	_key = ""

## Forgets which beats were shown (the next target gets its full beat again).
static func reset() -> void:
	close()
	_seen.clear()

## Is the spotlight showing now?
static func showing() -> bool:
	return is_instance_valid(_node) and not _node.closing

## Is it in its opening beat (clicks held)?
static func in_beat() -> bool:
	return showing() and _node.beat and _node.age < BEAT_S

static func _free_to_show(home: Node) -> bool:
	var building: bool = home.hb != null and home.hb.active
	return home.panel_open == "" and not home.chat_open and not home.building_now and not building \
			and not Overlay.is_open()

## The screen boxes to light: the named bottom-bar button, and the step's marker in the world (a Boki).
static func _rects(home: Node, id: String, want: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if bool(want.get("world", false)):
		var box := _world_box(home, id)
		if box.size.x > 0.0:
			out.append(box)
	var b: Control = home.hub_btns.get(String(want.get("hub", "")))
	if b != null and is_instance_valid(b) and b.is_visible_in_tree():
		out.append(b.get_global_rect())
	return out

static func _world_box(home: Node, id: String) -> Rect2:
	var at: Vector3 = home.guide.target(id)
	var cam: Camera3D = home.cam
	if at.x == INF or cam.is_position_behind(at):
		return Rect2()
	var head := cam.unproject_position(at + Vector3.UP * BOKI_HEIGHT_M)
	var feet := cam.unproject_position(at)
	var tall := maxf(BOKI_MIN_PX, absf(feet.y - head.y))
	return Rect2((head + feet) * 0.5 - Vector2(tall, tall) * 0.5, Vector2(tall, tall))

func _init(home: Node, id: String, want: Dictionary, with_beat: bool) -> void:
	h = home
	step_id = id
	spec = want
	beat = with_beat
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP if beat else Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("corner", float(CORNER_PX))
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.material = _mat
	add_child(_dim)
	_ring = StyleBoxFlat.new()
	_ring.draw_center = false
	_ring.set_border_width_all(RING_WIDTH_PX)
	_ring.set_corner_radius_all(CORNER_PX)
	if beat:
		_card = _hint_card(FarmTutorial.hint_text(step_id))
		add_child(_card)
		Sfx.play("whoosh", null, -10.0)

func _process(dt: float) -> void:
	age += dt
	if closing:
		return
	if h.panel_open != "" or FarmTutorial.current() != step_id:
		close()
		return
	_holes = _rects(h, step_id, spec)
	if _holes.is_empty():
		close()
		return
	for i in _holes.size():
		_holes[i].position -= global_position
	_mat.set_shader_parameter("area", size)
	_mat.set_shader_parameter("hole_a", _hole(0))
	_mat.set_shader_parameter("hole_b", _hole(1))
	_look(_settle())
	queue_redraw()

func _draw() -> void:
	for r in _holes:
		draw_style_box(_ring, r.grow(_ring_pad))

func fade_out() -> void:
	if closing:
		return
	closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

## 0 in the opening beat, easing to 1 as it settles (always 1 for a target that already had its beat).
func _settle() -> float:
	if not beat:
		return 1.0
	return clampf((age - BEAT_S) / EASE_S, 0.0, 1.0)

## Sets the dim, the ring and the card for the moment: flashing in the beat, a soft pulse after.
func _look(settle: float) -> void:
	if beat and age >= BEAT_S and mouse_filter == Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ramp := clampf(age / 0.2, 0.0, 1.0)
	var dim := lerpf(DIM_BEAT * ramp, DIM_VIGNETTE, settle) if beat else 0.0
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("soft", lerpf(SOFT_BEAT_PX, SOFT_VIGNETTE_PX, settle))
	var pulse := 0.5 + 0.5 * cos(TAU * FLASHES * age / BEAT_S)
	var soft_pulse := 0.65 + 0.35 * sin(TAU * SOFT_PULSE_HZ * age)
	var flash := pulse if settle <= 0.0 and beat else soft_pulse
	_ring.border_color = Color(UI.GOLD, flash)
	_ring_pad = RING_PAD_PX + (FLASH_GROW_PX * flash if settle <= 0.0 and beat else 0.0)
	if _card != null:
		_card.modulate.a = 1.0 - settle
		_place_card()

func _hole(i: int) -> Vector4:
	if i >= _holes.size():
		return Vector4(-9000.0, -9000.0, 1.0, 1.0)
	var r := _holes[i]
	return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)

func _hint_card(text: String) -> PanelContainer:
	var card := UI.card(Color(0.06, 0.07, 0.11, 0.94), 10, 14)
	UI.set_card_border(card, Color(UI.GOLD, 0.7), 2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := UI.label(text, 16, UI.INK, UI.semi)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = CARD_WIDTH_PX
	card.add_child(lbl)
	return card

## The hint card beside the first cut-out: above it when that is low on the screen, below it otherwise.
func _place_card() -> void:
	if _holes.is_empty():
		return
	var r := _holes[0]
	var room_above := r.get_center().y > size.y * 0.5
	var y := r.position.y - _card.size.y - CARD_GAP_PX if room_above else r.end.y + CARD_GAP_PX
	var x := r.get_center().x - _card.size.x * 0.5
	_card.position = Vector2(_on_screen(x, size.x, _card.size.x), _on_screen(y, size.y, _card.size.y))

## `at` kept so a box `extent` long fits inside `limit`, with a margin.
func _on_screen(at: float, limit: float, extent: float) -> float:
	return clampf(at, SCREEN_EDGE_PX, maxf(SCREEN_EDGE_PX, limit - extent - SCREEN_EDGE_PX))
