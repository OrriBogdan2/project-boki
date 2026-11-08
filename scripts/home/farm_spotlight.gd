class_name FarmSpotlight
extends Control
## The tutorial spotlight: the screen darkens with a rounded cut-out round the one thing to do next (a bottom-bar
## button and/or a Boki in the world), the cut-out flashes a few times with the hint beside it, then the dim eases
## to a light vignette and the ring keeps a soft pulse until the thing is clicked. FarmGuide drives it (sync, every
## poll); a step asks for it with "spot" in farm_tutorial.json ({"hub": button id, "world": true}).
## Only the opening beat swallows mouse clicks; after it nothing here takes a click, so the target is always clickable.
## A placing step ("tile" in its spot: the house, the trough) is modal instead: the screen stays dark and every click
## outside the cut-out does nothing, through three phases: the Build button, then the piece's tile on the build bar,
## then the exact ground it goes on (the ghost sits there, and a click in the cut-out puts it down). Each is ringed
## with a pulse and a short "Click here" (the spot's "click" text); it fades out once the piece is down.

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
const DIM_MODAL := 0.72          # alpha of the dark in a placing step
const SOFT_MODAL_PX := 60.0      # px the dark takes to build up outside the cut-out
const MODAL_PULSE_HZ := 1.2      # ring pulses per second in a placing step
const MODAL_RAMP_S := 0.2        # s the dark takes to come in
const MODAL_MIN_PX := 56.0       # px, the smallest cut-out (one tile of ground is small on screen)
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
var phase := ""                  # "hub", "tile" or "spot" in a placing step, else ""
var modal := false               # a placing step: dark throughout, clicks outside the cut-out do nothing
var beat := true
var age := 0.0
var closing := false
var _dim: ColorRect
var _mat: ShaderMaterial
var _rings: Array[PanelContainer] = []
var _ring_a := 1.0
var _card: PanelContainer = null
var _holes: Array[Rect2] = []
var _block: _Blocker = null
var _ring_pad := RING_PAD_PX

## Starts, keeps or ends the spotlight for the tutorial's current step. FarmGuide calls this every poll.
static func sync(home: Node, quiet: bool) -> void:
	var id := FarmTutorial.current()
	var want := {}
	if not quiet and id != "":
		want = FarmTutorial.spot(id)
		if not _free_to_show(home, want.has("tile")):
			want = {}
	var phase := _phase(home, want)
	var key := JSON.stringify(want, "", true) + phase if not want.is_empty() else ""
	if key == _key and is_instance_valid(_node):
		return
	close()
	if key == "":
		return
	if phase == "tile" and home.hb.bar != null and home.hb.bar.tile_of(String(want["tile"])) == null:
		home.guide.show_tile(String(want["tile"]))
	if _rects(home, id, want, phase).is_empty():
		return
	_key = key
	_node = FarmSpotlight.new(home, id, want, phase, not _seen.has(key))
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

static func _free_to_show(home: Node, placing: bool) -> bool:
	var building: bool = home.hb != null and home.hb.active and not placing
	return home.panel_open == "" and not home.chat_open and not home.building_now and not building \
			and not Overlay.is_open()

## Which part of a placing step the player is at: "hub" (build mode is off), "tile" (nothing, or the wrong piece,
## in hand) or "spot" (the piece is in hand). "" for every other spotlight.
static func _phase(home: Node, want: Dictionary) -> String:
	if not want.has("tile"):
		return ""
	var hb: HomeBuild = home.hb
	if hb == null or not hb.active:
		return "hub"
	var is_feeder: bool = not hb.held.is_empty() and hb.held["kind"] == "feeder"
	var held := ("feeder_" if is_feeder else "") + String(hb.held.get("id", ""))
	return "spot" if held == String(want["tile"]) else "tile"

## The screen boxes to light: the named bottom-bar button, and the step's marker in the world (a Boki); in a
## placing step the one thing for its phase (the button, the tile, the ground).
static func _rects(home: Node, id: String, want: Dictionary, phase := "") -> Array[Rect2]:
	var out: Array[Rect2] = []
	if phase == "tile":
		var tile: Control = home.hb.bar.tile_of(String(want["tile"])) if home.hb.bar != null else null
		if tile != null and tile.is_visible_in_tree():
			out.append(tile.get_global_rect())
		return out
	if phase == "spot":
		var cs: Array = home.guide.place_cells()
		if not cs.is_empty():
			out.append(_ground_box(home.cam, cs))
		return out
	if bool(want.get("world", false)):
		var box := _world_box(home, id)
		if box.size.x > 0.0:
			out.append(box)
	var b: Control = home.hub_btns.get(String(want.get("hub", "")))
	if b != null and is_instance_valid(b) and b.is_visible_in_tree():
		out.append(b.get_global_rect())
	return out

## The screen box round a set of ground tiles (empty when they are behind the camera).
static func _ground_box(cam: Camera3D, cells: Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c in [cells[0], cells[-1]]:
		for corner in [Vector2(c.x, c.y), Vector2(c.x + 1, c.y + 1)]:
			var at := Vector3(corner.x, 0.0, corner.y)
			if cam.is_position_behind(at):
				return Rect2()
			var px := cam.unproject_position(at)
			lo = lo.min(px)
			hi = hi.max(px)
	var box := Rect2(lo, hi - lo)
	var grow := maxf(0.0, MODAL_MIN_PX - minf(box.size.x, box.size.y)) * 0.5
	return box.grow(grow)

static func _world_box(home: Node, id: String) -> Rect2:
	var at: Vector3 = home.guide.target(id)
	var cam: Camera3D = home.cam
	if at.x == INF or cam.is_position_behind(at):
		return Rect2()
	var head := cam.unproject_position(at + Vector3.UP * BOKI_HEIGHT_M)
	var feet := cam.unproject_position(at)
	var tall := maxf(BOKI_MIN_PX, absf(feet.y - head.y))
	return Rect2((head + feet) * 0.5 - Vector2(tall, tall) * 0.5, Vector2(tall, tall))

func _init(home: Node, id: String, want: Dictionary, at_phase: String, with_beat: bool) -> void:
	h = home
	step_id = id
	spec = want
	phase = at_phase
	modal = phase != ""
	beat = with_beat and not modal
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
	for i in 2:
		var ring := UI.card(Color(0, 0, 0, 0), 0, CORNER_PX)
		UI.set_card_border(ring, UI.GOLD, RING_WIDTH_PX)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
	if modal:
		_block = _Blocker.new()
		add_child(_block)
		_card = _hint_card(String(spec.get("click", "Click here")), 0.0, 18)
		add_child(_card)
	elif beat:
		_card = _hint_card(FarmTutorial.hint_text(step_id), CARD_WIDTH_PX)
		add_child(_card)
		Sfx.play("whoosh", null, -10.0)

func _process(dt: float) -> void:
	age += dt
	if closing:
		return
	if h.panel_open != "" or FarmTutorial.current() != step_id:
		close()
		return
	if _phase(h, spec) != phase:
		close()                  # the next part of a placing step: its spotlight starts now, not at the next poll
		sync(h, h.guide.quiet)
		return
	_holes = _rects(h, step_id, spec, phase)
	if _holes.is_empty():
		close()
		return
	for i in _holes.size():
		_holes[i].position -= global_position
	if modal:
		_follow(_holes)
	_mat.set_shader_parameter("area", size)
	_mat.set_shader_parameter("hole_a", _hole(0))
	_mat.set_shader_parameter("hole_b", _hole(1))
	_look(_settle())
	for i in _rings.size():
		_rings[i].visible = i < _holes.size()
		if i < _holes.size():
			var r := _holes[i].grow(_ring_pad)
			_rings[i].position = r.position
			_rings[i].size = r.size
			_rings[i].modulate.a = _ring_a

## A placing step: stay on top of the build bar (it opens after us), let clicks through the cut-out only, and
## in the "spot" phase keep the ghost on the exact ground.
func _follow(holes: Array[Rect2]) -> void:
	if get_parent().get_child(-1) != self:
		get_parent().move_child(self, -1)
	_block.holes = holes.map(func(r: Rect2) -> Rect2: return r.grow(RING_PAD_PX + FLASH_GROW_PX))
	if phase == "spot":
		h.hb.debug_m = h.guide.place_mouse()

func fade_out() -> void:
	if closing:
		return
	closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if modal:
		_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if phase == "spot" and h.hb != null:
			h.hb.debug_m = Vector2.INF
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
	if modal:
		var pulse := 0.5 + 0.5 * sin(TAU * MODAL_PULSE_HZ * age)
		_mat.set_shader_parameter("dim", DIM_MODAL * clampf(age / MODAL_RAMP_S, 0.0, 1.0))
		_mat.set_shader_parameter("soft", SOFT_MODAL_PX)
		_ring_a = lerpf(0.55, 1.0, pulse)
		_ring_pad = RING_PAD_PX + FLASH_GROW_PX * pulse
		_place_card()
		return
	if beat and age >= BEAT_S and mouse_filter == Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ramp := clampf(age / 0.2, 0.0, 1.0)
	var dim := lerpf(DIM_BEAT * ramp, DIM_VIGNETTE, settle) if beat else 0.0
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("soft", lerpf(SOFT_BEAT_PX, SOFT_VIGNETTE_PX, settle))
	var pulse := 0.5 + 0.5 * cos(TAU * FLASHES * age / BEAT_S)
	var soft_pulse := 0.65 + 0.35 * sin(TAU * SOFT_PULSE_HZ * age)
	var flash := pulse if settle <= 0.0 and beat else soft_pulse
	_ring_a = flash
	_ring_pad = RING_PAD_PX + (FLASH_GROW_PX * flash if settle <= 0.0 and beat else 0.0)
	if _card != null:
		_card.modulate.a = 1.0 - settle
		_place_card()

func _hole(i: int) -> Vector4:
	if i >= _holes.size():
		return Vector4(-9000.0, -9000.0, 1.0, 1.0)
	var r := _holes[i]
	return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)

func _hint_card(text: String, width: float, font_px := 16) -> PanelContainer:
	var card := UI.card(Color(0.06, 0.07, 0.11, 0.94), 10, 14)
	UI.set_card_border(card, Color(UI.GOLD, 0.7), 2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := UI.label(text, font_px, UI.INK, UI.semi)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = width
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

## Takes every click except the ones inside the cut-out, which fall through to what is lit.
class _Blocker extends Control:
	var holes: Array = []
	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _has_point(at: Vector2) -> bool:
		return not holes.any(func(r: Rect2) -> bool: return r.has_point(at))
