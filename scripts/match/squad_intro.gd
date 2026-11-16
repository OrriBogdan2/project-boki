class_name SquadIntro
extends RefCounted
## The squad intro before the skyship ride (0.24.4): your squad on the deck, side by side with their
## Boki wisps, each striking their pose in turn under a "Vex the Hired Gun" plate, while the camera
## arcs low across them from the bow; then it cuts to the ride camera and the drop
## map opens. About five seconds; any key skips it after SKIP_AFTER.
##
## It plays in the drop planning (the ship waits at the map's edge and the match clock waits with
## it), so nothing in the match moves on under it. Offline, the plan gets the intro's length on top
## and a skip gives back what's left; a lineup you just saw is not shown again this session. Online
## every client plays it from the start with the same padding (plan_t is kept per client, so it must
## match) and a skip only cuts the picture: no message is sent.

const INTRO_T := 5.0           # s, the whole intro
const SKIP_AFTER := 1.5        # s before a key skips it (a key still held from the menu must not)
const CUT_T := 4.3             # s of the low arc across the squad, then a cut to the ride camera
const BEAT_AT := 0.7           # s: the first hunter's pose...
const BEAT_GAP := 0.6          # s: ...and the next one's after it
const PLATE_LEAD := 0.15       # s: a plate fades in just before its hunter's beat
const PLATE_FADE := 0.3        # s
const CAM_BACK := Vector2(9.6, 8.2)    # m ahead of the squad: at the start, at the end of the arc
const CAM_UP := Vector2(2.3, 2.9)      # m over the deck, likewise (over the bow post)
const CAM_ARC := Vector2(-0.62, -0.16)  # rad off the bow line, start to end: never on it (the bow post)
const LOOK_UP := 1.15          # m over the deck: the camera aims at the squad's chests
const FOV := 50.0              # degrees: a closer lens than the narrow match camera
const BAR_H := 0.09            # of the screen's height, each letterbox bar
const PLATE_UP := 2.35         # m over a hunter's feet: where its plate sits (pushed up over a plate it would overlap)
const PLATE_GAP := 4.0         # px between plates stacked that way

static var _last_lineup := ""

var m: Match
var t := 0.0
var squad: Array = []
var _beats: Array = []         # the emote entries this intro put in truce.shown
var _layer: CanvasLayer
var _plates: Array = []
var _bars: Array = []
var _hint: Label
var _fov := 0.0
var _online := false

## Starts the intro if this match wants one (main's real match start sets opts.squad_intro); null if not.
static func start(match_node: Match) -> SquadIntro:
	var mt := match_node
	if not mt.opts.get("squad_intro", false) or mt.player == null or mt.skydrop == null or not mt.skydrop.planning:
		return null
	var mates: Array = []
	for h in mt.hunters:
		if h.team == mt.player.team and h.riding:
			mates.append(h)
	if mates.is_empty():
		return null
	var lineup := ",".join(mates.map(func(h: Hunter) -> String: return h.arch + "/" + h.pname))
	var again := lineup == _last_lineup
	_last_lineup = lineup
	if again and not mt.net_on:
		return null
	mt.skydrop.plan_len += INTRO_T
	mt.skydrop.plan_t += INTRO_T
	var it := SquadIntro.new()
	it.m = mt
	it.squad = mates
	it._online = mt.net_on
	it._build()
	return it

## True while the intro holds the screen.
func running() -> bool:
	return _layer != null

## One planning tick (match.step): the beats, the end.
func tick(dt: float) -> void:
	if not running():
		return
	t += dt
	for i in squad.size():
		if _beats.size() == i and t >= BEAT_AT + i * BEAT_GAP:
			var e := {"h": squad[i], "id": emote_for((squad[i] as Hunter).arch), "t": 0.0}
			_beats.append(e)
			if m.truce: m.truce.shown.append(e)
	for e in _beats:
		e["t"] = float(e["t"]) + dt       # (truce.tick doesn't run in the planning)
	if t >= INTRO_T or not m.skydrop.planning:
		finish(false)

## A key, button or click: skips the intro once SKIP_AFTER has gone. True if it was taken.
func skip(event: InputEvent) -> bool:
	if not running() or not event.is_pressed() or event.is_echo():
		return false
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return false
	if t >= SKIP_AFTER:
		finish(true)
	m.get_viewport().set_input_as_handled()
	return true

## Ends the intro: the HUD and the drop map come back. `skipped`: offline, the plan gives back the rest.
func finish(skipped: bool) -> void:
	if not running():
		return
	if skipped and not _online:
		var left := maxf(0.0, INTRO_T - t)
		m.skydrop.plan_len -= left
		m.skydrop.plan_t = maxf(0.1, m.skydrop.plan_t - left)
	for e in _beats:
		if m.truce: m.truce.shown.erase(e)
	_layer.queue_free()
	_layer = null
	m.cam.fov = _fov
	if m.hud:
		m.hud.visible = true
		if m.skydrop.planning and not m.hud.map_open():
			m.hud.open_map(true)

## The camera and plates this frame (match's ride camera, after it has placed the ride view).
func frame(_delta: float) -> void:
	if not running():
		return
	var ride: Transform3D = m.cam.global_transform
	var n: Node3D = m.ship_of(m.player).get("node")
	if n == null or not is_instance_valid(n):
		return
	var mid := Vector3.ZERO
	for h in squad:
		mid += SkyDeck.world_at(m, h)
	mid /= float(squad.size())
	var a := clampf(t / CUT_T, 0.0, 1.0)
	var bow := -n.global_basis.z
	var side := lerpf(CAM_ARC.x, CAM_ARC.y, a)
	var back := bow.rotated(Vector3.UP, side) * lerpf(CAM_BACK.x, CAM_BACK.y, a)
	var eye := mid + back + Vector3.UP * lerpf(CAM_UP.x, CAM_UP.y, a)
	var shot := Transform3D(Basis.IDENTITY, eye).looking_at(mid + Vector3.UP * LOOK_UP, Vector3.UP)
	var cut := t >= CUT_T      # (a blend would fly through the envelope: the ride camera is high behind it)
	var k := smoothstep(CUT_T, INTRO_T, t)
	m.cam.global_transform = ride if cut else shot
	m.cam.fov = _fov if cut else FOV
	if m.hud: m.hud.visible = false
	_place_plates(k)
	var vh := m.get_viewport().get_visible_rect().size.y
	(_bars[0] as Control).position.y = -vh * BAR_H * k
	(_bars[1] as Control).position.y = vh * (1.0 - BAR_H) + vh * BAR_H * k
	_hint.visible = t >= SKIP_AFTER and not cut

## The pose each Hunter strikes (the warden clips play their own emote clip; the rest wave, laugh...).
static func emote_for(arch: String) -> String:
	var picks := ["wave", "laugh", "thanks", "gg"]
	return String(picks[absi(arch.hash()) % picks.size()])

## The plate on one hunter: "<Name> the <Title>", their player tag under it.
static func plate_text(h: Hunter) -> PackedStringArray:
	var who: String = HeroTitle.label(HeroTitle.base_name(h.arch), h.arch)
	return PackedStringArray([who, h.pname if h.pname != HeroTitle.base_name(h.arch) else ""])

func _place_plates(k: float) -> void:
	var taken: Array[Rect2] = []
	for i in squad.size():
		var h: Hunter = squad[i]
		var pl: Control = _plates[i]
		var head: Vector3 = SkyDeck.world_at(m, h) + Vector3.UP * PLATE_UP
		var in_t := BEAT_AT + i * BEAT_GAP - PLATE_LEAD
		var alpha := clampf((t - in_t) / PLATE_FADE, 0.0, 1.0) * (0.0 if k > 0.0 else 1.0)
		pl.visible = alpha > 0.0 and not m.cam.is_position_behind(head)
		if pl.visible:
			pl.modulate.a = alpha
			var at: Vector2 = m.cam.unproject_position(head) - Vector2(pl.size.x / 2.0, pl.size.y)
			at = _clear_of(Rect2(at, pl.size), taken)
			taken.append(Rect2(at, pl.size))
			pl.position = at + Vector2(0, (1.0 - alpha) * 10.0)      # (rising into place as it fades in)

## Where a plate goes so it covers none placed before it: straight up over each one in its way.
static func _clear_of(r: Rect2, taken: Array[Rect2]) -> Vector2:
	var moved := true
	while moved:
		moved = false
		for o in taken:
			if r.intersects(o):
				r.position.y = o.position.y - r.size.y - PLATE_GAP
				moved = true
	return r.position

func _build() -> void:
	_fov = m.cam.fov
	_layer = CanvasLayer.new()
	_layer.layer = 5
	m.add_child(_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		var vs := m.get_viewport().get_visible_rect().size
		bar.size = Vector2(vs.x, vs.y * BAR_H)
		bar.position = Vector2(0, 0.0 if top else vs.y * (1.0 - BAR_H))
		_layer.add_child(bar)
		_bars.append(bar)
	for h in squad:
		var lines: PackedStringArray = plate_text(h)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_END
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_label(lines[0], 26, Color("fff4dc")))
		if lines[1] != "":
			box.add_child(_label(lines[1], 17, Color("cfe3ff") if h == m.player else Color("e6dccb")))
		box.visible = false
		_layer.add_child(box)
		box.reset_size()
		_plates.append(box)
	_hint = _label("Any key to skip", 16, Color(1, 1, 1, 0.7))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_hint.visible = false
	_layer.add_child(_hint)
	if m.hud: m.hud.visible = false

static func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, int(px / 4.0)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
