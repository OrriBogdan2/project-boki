class_name FirstEvolveBeat
extends RefCounted
## The first time any Boki can evolve (its path meter is due and has picked a final, or a held Ink makes a form),
## a short guided beat: a marker over that Boki, three lines in the message lane one
## after another, then its card opens on the Growth tab, where the Evolve prompt is (EvoPathView).
## It runs once per save (Save.d["tutorial"]["first_evolve"], set as it starts, so it never repeats) and the
## player skips it by opening anything (a panel, or Esc's menu): the marker goes and the card stays shut.

const LINES := ["%s is ready to change.", "Pick what it grows into.", "It keeps its name and memories."]
const LINE_S := 2.4        # s between two lines, and from the last line to the card
const SCAN_S := 1.0        # s between two looks over the garden's Boki while no beat runs
const MARK_UP := 2.2       # m above the Boki's feet the marker floats
const TIP_COL := Color("f3e6c8")

var h                      # the Home screen
var marker: Label3D = null
var rec: Dictionary = {}   # the Boki the beat is about ({} while none runs)
var step := 0              # lines shown so far
var _t := 0.0              # s until the next line (or the next scan)

func _init(home) -> void:
	h = home

## Is this Boki ready to change, by its meter or a held Ink? A final without art counts: the card the beat
## opens says it waits for it (no branching final has art yet, so gating on art would never teach it).
static func can_evolve(r: Dictionary) -> bool:
	var picked := EvoPath.due(r) and not EvoPath.blocked(r) in ["stay", "undecided"]
	return picked or not EvoPath.ink_previews(r).is_empty()

static func seen() -> bool:
	return bool(Save.d["tutorial"].get("first_evolve", false))

## Per frame: starts the beat when the first Boki can evolve, then paces its lines and the card.
func tick(dt: float) -> void:
	if rec.is_empty() and seen():
		return
	_t -= dt
	if not rec.is_empty():
		_run()
	elif _t <= 0.0:
		_t = SCAN_S
		_scan()

func _scan() -> void:
	if h.panel_open != "" or Overlay.is_open() or not Settings.get_v("tips") or FarmTutorial.active():
		return
	for k in h.kins:
		if can_evolve(k["rec"]) and is_instance_valid(k["node"]):
			_start(k)
			return

func _start(k: Dictionary) -> void:
	Save.d["tutorial"]["first_evolve"] = true
	rec = k["rec"]
	step = 0
	_t = 0.0
	marker = Label3D.new()
	marker.text = "▼"
	marker.font_size = 56
	marker.pixel_size = 0.0095
	marker.outline_size = 16
	marker.modulate = UI.GOLD
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.position = Vector3(0, MARK_UP, 0)
	k["node"].add_child(marker)

func _run() -> void:
	if h.panel_open != "" or Overlay.is_open():
		skip()
		return
	if _t > 0.0:
		return
	_t = LINE_S
	if step < LINES.size():
		var line := String(LINES[step])
		MsgLane.of(h.root_ui).push(line % rec["name"] if step == 0 else line, TIP_COL, MsgLane.NORMAL, LINE_S * 3.0)
		step += 1
		return
	var r := rec
	_end()
	h.kin_tab = "Growth"
	h._open_kin(r)

## Ends the beat early: no more lines, no card.
func skip() -> void:
	_end()

func _end() -> void:
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null
	rec = {}
