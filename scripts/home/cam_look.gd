class_name CamLook
extends CanvasLayer
## The shared "look here" camera beat (the farm tutorial's pans: Hob's first call over, and the stall, house and
## tree he points at; a garden home can reuse it). The camera pans to a point, HOLDS there until you press, and
## only then returns:
##   - the pan out and the pan back are eased and slow; input is locked only during them (`locked()`)
##   - while it holds, a click (or A) returns; a hold of SKIP_HOLD_S skips this pan and every later one
##   - `look(point, alone)` starts or retargets a pan; `release()` sends it back; `frame(base)` is the focus
##     to hand the camera each frame, with `base` where it sits when no pan is on
## `alone` (nothing else, like a talk box, advances the sequence): the small "Click to continue" prompt shows at
## the bottom while it holds, and the press is taken here. Otherwise the caller calls `release()` itself and
## shows its own prompt (one prompt at a time). `watching` lets a held press count toward the skip while a
## sequence of pans is under way, even between two of them.

enum Phase {IDLE, IN, HOLD, OUT}

const PAN_IN_S := 0.9          # s the camera takes to reach the point
const PAN_OUT_S := 0.7         # s it takes to come back
const SKIP_HOLD_S := 1.0       # s a press is held to skip the rest of the pans
const HINT_RISE := 0.22        # share of the screen height under the hint: clear of the action bar and key hints
const HINT_FADE := 6.0         # 1/s the hint fades in and out at

var phase := Phase.IDLE
var skip_rest := false
var watching := false
var _at := Vector3.INF
var _from := Vector3.INF       # where the pan started (INF: from `base`, which may move)
var _last := Vector3.INF       # the focus handed out last
var _t := 0.0
var _held := 0.0
var _alone := false
var _card: PanelContainer
var _text: Label

func _ready() -> void:
	layer = 44
	_card = UI.card(Color(UI.NIGHT, 0.82), 8, UI.R_PILL)
	_text = UI.label("", 16, UI.INK)
	_card.add_child(_text)
	_card.modulate.a = 0.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

## Pans to `point` and holds. False (nothing starts) when the player skipped the pans or there is no point.
func look(point: Vector3, alone := false) -> bool:
	if skip_rest or point.x == INF:
		return false
	_from = _last if phase != Phase.IDLE else Vector3.INF
	_at = point
	_alone = alone
	_go(Phase.IN)
	return true

## Sends the camera back to `base`, from wherever it is.
func release() -> void:
	if phase == Phase.IDLE or phase == Phase.OUT:
		return
	_from = _last
	_go(Phase.OUT)

func active() -> bool:
	return phase != Phase.IDLE

## Input is locked only while the camera is moving.
func locked() -> bool:
	return phase == Phase.IN or phase == Phase.OUT

## The focus for this frame: `base` with no pan, else the pan's own.
func frame(base: Vector3) -> Vector3:
	if phase == Phase.IDLE:
		_last = base
		return base
	var target := Vector3(_at.x, base.y, _at.z)
	var start := base if _from.x == INF else _from
	match phase:
		Phase.IN:
			_last = start.lerp(target, smoothstep(0.0, 1.0, _t / PAN_IN_S))
		Phase.HOLD:
			_last = target
		Phase.OUT:
			_last = start.lerp(base, smoothstep(0.0, 1.0, _t / PAN_OUT_S))
	return _last

func _go(next: Phase) -> void:
	phase = next
	_t = 0.0

func _process(dt: float) -> void:
	_t += dt
	if phase == Phase.IN and _t >= PAN_IN_S:
		_go(Phase.HOLD)
	elif phase == Phase.OUT and _t >= PAN_OUT_S:
		_go(Phase.IDLE)
	_tick_skip(dt)
	_tick_hint(dt)

## A press held for SKIP_HOLD_S ends this pan and turns off the later ones.
func _tick_skip(dt: float) -> void:
	if not (watching or active()) or not _pressed():
		_held = 0.0
		return
	_held += dt
	if _held >= SKIP_HOLD_S and not skip_rest:
		skip_rest = true
		release()

func _pressed() -> bool:
	return Input.is_action_pressed("interact") or Input.is_action_pressed("ui_accept") \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)

func _tick_hint(dt: float) -> void:
	var want := 1.0 if phase == Phase.HOLD and _alone else 0.0
	_card.modulate.a = move_toward(_card.modulate.a, want, HINT_FADE * dt)
	if want > 0.0:
		_text.text = "A to continue" if Input.get_connected_joypads().size() > 0 else "Click to continue"
		var view := get_viewport().get_visible_rect().size
		_card.position = Vector2((view.x - _card.size.x) * 0.5, view.y * (1.0 - HINT_RISE) - _card.size.y)

## The press that returns the camera: a click or A (taken here), or the interact key (left for its own use).
func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.HOLD or not _alone:
		return
	var mb := event as InputEventMouseButton
	var pad := event as InputEventJoypadButton
	var taken := (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) \
			or (pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A)
	if taken or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if taken:
			get_viewport().set_input_as_handled()
		release()
