class_name LowHpCue
extends RefCounted
## "One hit from down" for the local player (numbers: content/rules/low_hp.json). While your health share
## (health + armour over their maximums) is under the line, a soft heartbeat plays and the screen edge glows
## red on each beat; the lower the share, the faster. It stops the moment you heal over the line, are downed
## or are out. The sound ducks under a fight (many voices already playing) and has a toggle in Settings >
## Audio; the glow follows Fewer flashes. Hud owns one (hud.lowhp): tick() every frame, draw_edge() in its draw.

const RULES := "low_hp"
const SOUND := "heartbeat"
const GLOW_FALL := 2.5         # per second: how fast the edge glow fades back after a beat
const GLOW_REST := 0.6         # the glow's share of full between beats
const EDGE_RINGS := 5
const EDGE_STEP := 16.0        # px between the edge rings (and each ring's width)

var active := false
var _rules := Content.rules(RULES)
var _wait := 0.0               # s until the next beat
var _glow := 0.0               # 0..1, jumps to 1 on a beat

## Health and armour as a share of their maximums (1 = full of both).
static func share(h: Hunter) -> float:
	return (h.hp + h.armor) / maxf(1.0, h.max_hp + h.max_armor)

## Beats a minute at this share: `bpm_start` at the line, `bpm_empty` at 0.
func bpm(s: float) -> float:
	var line := float(_rules["start_share"])
	return lerpf(float(_rules["bpm_empty"]), float(_rules["bpm_start"]), clampf(s / line, 0.0, 1.0))

## One frame for your hunter.
func tick(h: Hunter, dt: float) -> void:
	var alive := h != null and not h.downed and not h.out
	if step(share(h) if alive else 1.0, dt) and Settings.get_v("low_hp_pulse"):
		var duck: bool = Sfx.busy_voices() >= int(_rules["duck_voices"])
		Sfx.play(SOUND, null, float(_rules["volume_db"]) + (float(_rules["duck_db"]) if duck else 0.0), 0.03)

## Advances the cue by dt at health share `s`; true on the frame a beat lands (the first one right away).
func step(s: float, dt: float) -> bool:
	_glow = maxf(0.0, _glow - dt * GLOW_FALL)
	if s >= float(_rules["start_share"]):
		active = false
		return false
	if not active:
		active = true
		_wait = 0.0
	_wait -= dt
	if _wait > 0.0:
		return false
	_wait = 60.0 / bpm(s)
	_glow = 1.0
	return true

## The red glow in from the screen edge, brightest on the beat.
func draw_edge(c: Control, sz: Vector2) -> void:
	if not active:
		return
	var calm: float = float(_rules["edge_calm"]) if Settings.get_v("reduce_flashes") else 1.0
	var a: float = float(_rules["edge_alpha"]) * (GLOW_REST + (1.0 - GLOW_REST) * _glow) * calm
	for i in EDGE_RINGS:
		var inset := i * EDGE_STEP
		var ring := Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0)
		c.draw_rect(ring, Color(0.75, 0.05, 0.05, a * (1.0 - i * 0.18)), false, EDGE_STEP)
