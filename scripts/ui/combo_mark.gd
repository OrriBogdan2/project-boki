class_name ComboMark
extends RefCounted
## What your own combo has put on a foe, drawn over it on the HUD canvas, only for the Hunter who applied it:
## a dark disc with the state's icon (Ignite, Chill, Kindle...) in the ability's colour, a ring that drains with
## the time left, and a pip per stack. It reads the kit's existing status timers (ArchKit.combo_marks), it
## keeps none. When the payoff lands, flash() puts a bright 2-frame burst on the foe (payoff_fx calls it).

const MARK_UP := 4.2          # m over the foe's feet: above its name plate and health bar
const MARK_R := 13.0          # px: the time ring's radius
const PIP_R := 2.6            # px: one stack pip
const FLASH_T := 0.034        # s: two frames at 60 fps
const FLASH_R := 70.0         # px: the payoff burst's radius

static var flash_at := Vector3.ZERO     # the world spot of the last payoff
static var flash_t := -9.0              # Match time it landed

## One mark per foe carrying the player's combo state (kit.combo_marks()): {"at", "icon", "n", "max", "frac", "col"}.
static func draw(c: Control, m: Match) -> void:
	var p: Hunter = m.player
	if p == null or p.out or p.downed:
		return
	for mk in p.ak.combo_marks():
		var wp: Vector3 = mk["at"] + Vector3(0, MARK_UP, 0)
		if not m.cam.is_position_behind(wp):
			_mark(c, m.cam.unproject_position(wp), mk)
	if m.time - flash_t < FLASH_T and not m.cam.is_position_behind(flash_at):
		var at := m.cam.unproject_position(flash_at + Vector3(0, 1.1, 0))
		c.draw_circle(at, FLASH_R, Color(1, 1, 1, 0.55))
		c.draw_circle(at, FLASH_R * 0.5, Color(1, 1, 1, 0.9))

## The payoff landed on the foe at `at`: the next HUD draw shows the 2-frame burst.
static func flash(m: Match, at: Vector3) -> void:
	flash_at = at
	flash_t = m.time

static func _mark(c: Control, at: Vector2, mk: Dictionary) -> void:
	var col: Color = mk["col"]
	c.draw_circle(at, MARK_R + 3.0, Color(0.03, 0.04, 0.07, 0.8))
	c.draw_arc(at, MARK_R, 0.0, TAU, 32, Color(col, 0.25), 3.0, true)
	var f := clampf(float(mk["frac"]), 0.0, 1.0)
	if f > 0.0:
		c.draw_arc(at, MARK_R, -PI * 0.5, -PI * 0.5 + TAU * f, 32, col, 3.0, true)
	Icons.draw(c, String(mk["icon"]), at, 8.0, col.lerp(Color.WHITE, 0.3))
	var cnt := int(mk["max"])
	if cnt < 2:
		return
	for i in cnt:
		var pip := at + Vector2((i - (cnt - 1) * 0.5) * PIP_R * 2.6, MARK_R + 8.0)
		c.draw_circle(pip, PIP_R, col if i < int(mk["n"]) else Color(1, 1, 1, 0.2))
