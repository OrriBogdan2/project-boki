class_name ParityBench
extends Node
## The parity bench: a toggle panel in the practice areas that have dummies (the Training Area and the
## Arena; never a real match). For the selected dummy (the last one hit) it reads, from CombatBus
## hit and status events only: rolling damage per second and the last hit, the crowd control it is under
## and how long is left, and how far and how long the last knock moved it. Reset clears the readouts and
## sends everyone back to their marks (Arena.reset).

const KNOCK_MIN_SPEED := 2.5     # m/s, a hit that leaves the dummy at least this fast (and in a knock slide) is a knock
const KNOCK_END_SPEED := 0.5     # m/s, slower than this the knock is over
const KNOCK_MAX_T := 1.0         # s, give up following a knock (the dummy walks back to its mark after a quiet moment)
const PANEL_POS := Vector2(16, 120)   # px, from the top left, under the portrait

var m: Match
var target: Hunter = null       # the selected dummy
var cc_kind := ""               # the last crowd control put on it ("stun" | "root" | "slow" | "burn")
var cc_until := 0.0             # match time it ends
var knock_dist := 0.0           # m, the last finished knock
var knock_time := 0.0           # s
var knocking := false           # a knock is being followed
var _knock_from := Vector3.ZERO
var _knock_t0 := 0.0
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _text: Label = null
var _hit_cb: Callable
var _status_cb: Callable

static func of(match_node: Match) -> ParityBench:
	return match_node.get_node_or_null("ParityBench") as ParityBench

## Adds the (closed) bench to a match that has practice dummies; null otherwise.
static func attach(match_node: Match) -> ParityBench:
	if match_node.arena == null:
		return null
	var b := ParityBench.new()
	b.name = "ParityBench"
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.m = match_node
	match_node.add_child(b)
	b.set_process(false)
	return b

func is_open() -> bool:
	return _layer != null

func toggle() -> void:
	if is_open(): _close()
	else: _open()

func _open() -> void:
	_hit_cb = func(_by, t, _d, _tags): _on_hit(t)
	_status_cb = func(t, st, _by, dur): _on_status(t, st, dur)
	CombatBus.hit_landed.connect(_hit_cb)
	CombatBus.status_applied.connect(_status_cb)
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_panel = UI.glass(10, 14)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = PANEL_POS
	_layer.add_child(_panel)
	var v := UI.vbox(6)
	_panel.add_child(v)
	v.add_child(UI.label("Parity bench", 14, UI.INK, UI.semi))
	_text = UI.label("", 13, UI.MUTED)
	v.add_child(_text)
	var rb := UI.button("Reset", reset)
	rb.focus_mode = Control.FOCUS_NONE
	v.add_child(rb)
	if m.hud:
		m.hud.ui_extra.append(_panel)
	set_process(true)
	_refresh()

func _exit_tree() -> void:
	if is_open():
		_close()

func _close() -> void:
	CombatBus.hit_landed.disconnect(_hit_cb)
	CombatBus.status_applied.disconnect(_status_cb)
	if m.hud:
		m.hud.ui_extra.erase(_panel)
	_layer.queue_free()
	_layer = null
	_panel = null
	_text = null
	set_process(false)

func _dummy_row(h: Node) -> Dictionary:
	for dm in m.arena.dummies:
		if dm["h"] == h:
			return dm
	return {}

## Selects `t` if it is a practice dummy (the status event comes before the hit event). False if it is not.
func _select(t: Node) -> bool:
	if _dummy_row(t).is_empty():
		return false
	if t != target:
		target = t as Hunter
		cc_kind = ""
		_clear_knock()
	return true

func _on_hit(t: Node) -> void:
	if not _select(t):
		return
	var hv := Vector2(target.vel.x, target.vel.z)
	if not knocking and target.knock_t > 0.0 and hv.length() >= KNOCK_MIN_SPEED:
		knocking = true
		_knock_from = target.pos
		_knock_t0 = m.time

func _on_status(t: Node, st: String, dur: float) -> void:
	if not _select(t):
		return
	var until := m.time + dur
	cc_until = maxf(cc_until, until) if st == cc_kind else until
	cc_kind = st

func _process(_dt: float) -> void:
	if knocking and is_instance_valid(target):
		var hv := Vector2(target.vel.x, target.vel.z)
		if hv.length() < KNOCK_END_SPEED or m.time - _knock_t0 > KNOCK_MAX_T:
			knocking = false
			knock_dist = Vector2(target.pos.x - _knock_from.x, target.pos.z - _knock_from.z).length()
			knock_time = m.time - _knock_t0
	_refresh()

func _clear_knock() -> void:
	knock_dist = 0.0
	knock_time = 0.0
	knocking = false

## Clears the readouts and sends the player, dummies and bot back to their marks.
func reset() -> void:
	target = null
	cc_kind = ""
	_clear_knock()
	m.arena.reset()

## The readout as lines, one per quantity (also what the check asserts on).
func lines() -> Array:
	if target == null or not is_instance_valid(target):
		return ["Hit a dummy to select it."]
	var dm := _dummy_row(target)
	var cc := "none"
	if cc_kind != "" and cc_until > m.time:
		cc = "%s  %.1f s left" % [cc_kind, cc_until - m.time]
	return [
		"DPS  %d" % int(round(Arena.dps_of(dm["hits"], m.time))),
		"Last hit  %d" % int(round(float(dm["last"]))),
		"CC  %s" % cc,
		"Knock  %.2f m in %.2f s" % [knock_dist, knock_time] + ("  (moving)" if knocking else ""),
	]

func _refresh() -> void:
	if _text:
		_text.text = "\n".join(lines())
