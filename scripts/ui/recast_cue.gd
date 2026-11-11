class_name RecastCue
extends RefCounted
## Two-step abilities, the same for every hunter (DECISIONS 2026-11-08 "two-step abilities must be obvious").
## A kit reports its open recast through ArchKit.recast_window(); this module turns it into one visual language:
##   the ability slot pulses with a shrinking timer ring, dims while a press is still eaten, and darkens if it ran out;
##   the thing the recast triggers (the seed, the knife, the hammer) flashes in its last WARN seconds;
##   a foe the payoff lands on gets a white burst;
##   sounds: a chime as the window opens, ticks before it closes, a low click when it runs out.
## No words or key letters anywhere (the owner 2026-11-11, docs/UI_DECLUTTER.md): the slot's own key shows the key.
## Only the local player's own cues show (track runs for the local hunter). The marks a kit puts on foes read
## through ComboMark (ArchKit.combo_read).

const WARN := 0.6              # s left when the ring turns hot and the ticks start
const TICKS := [0.6, 0.4, 0.2] # s left at which a closing tick plays
const EXPIRED_T := 0.9         # s the slot stays dark after a window ran out
const RAN_OUT := 0.12          # s: a window that vanished with less than this left ran out (more: it was used)
const POP_T := 0.45            # s the payoff flash on a foe's badge lasts
const HOT := Color("ff5a4a")
const BLINK_HZ := 8.0          # flashes a second on the object in the last WARN seconds

## Every step for the local hunter's kit: reads the window and the marks, plays the cues. State lives on the kit
## (ArchKit.cue): {w (the open window), last (its last left), slot, col, tick, exp_slot, exp_t, pop}.
static func track(k: ArchKit, dt: float) -> void:
	var cue := k.cue
	var w := k.recast_window()
	var was := String(cue.get("slot", ""))
	if not w.is_empty() and String(w["slot"]) != was:
		cue["col"] = slot_col(k, String(w["slot"]))
		cue["tick"] = 0
		Sfx.play("ab_ready", null, -3.0, 0.0, 1.35)
	elif w.is_empty() and was != "":
		if float(cue.get("last", 1.0)) < RAN_OUT and not bool((cue.get("w", {}) as Dictionary).get("auto", false)):
			cue["exp_slot"] = was
			cue["exp_t"] = EXPIRED_T
			Sfx.play("click", null, -5.0, 0.0, 0.6)
	if not w.is_empty():
		var left := float(w["left"])
		var n := int(cue.get("tick", 0))
		if n < TICKS.size() and left <= float(TICKS[n]):
			cue["tick"] = n + 1
			Sfx.play("click", null, -4.0, 0.0, 1.5 + 0.2 * n)
		cue["last"] = left
	cue["slot"] = String(w.get("slot", ""))
	cue["w"] = w
	cue["exp_t"] = maxf(0.0, float(cue.get("exp_t", 0.0)) - dt)
	var pop: Dictionary = cue.get("pop", {})
	if not pop.is_empty():
		pop["t"] = float(pop["t"]) - dt
		if float(pop["t"]) <= 0.0: cue["pop"] = {}

## The payoff landed on `victim`: a white burst on it (ArchKit.payoff_fx and the payoffs that don't go through it).
static func payoff(k: ArchKit, victim: Ent) -> void:
	if victim != null and k.h.is_local():
		k.cue["pop"] = {"e": victim, "t": POP_T}

## A window as kits report it (ArchKit.recast_window).
static func window(slot_id: String, left: float, total: float, at: Vector3, armed := true, auto := false) -> Dictionary:
	return {"slot": slot_id, "left": left, "total": total, "at": at, "armed": armed, "auto": auto}

static func slot_col(k: ArchKit, slot: String) -> Color:
	match slot:
		"e": return k.col_of(k.e_def())
		"x": return k.col_of(k.x_def())
		"dash": return k.col_of(k.dash_def())
		"lmb": return k.col_of(k.lmb_def()) if k.lmb_def().has("col") else k.res_col()
	return k.col_of(k.rmb_def())

## On the slot's rect in the ability row. True when it drew (the slot's own "up" ring stays off then).
static func slot(H: Node, p: Hunter, slot_id: String, r: Rect2) -> bool:
	if p == null or p.ak == null:
		return false
	var cue := p.ak.cue
	var w: Dictionary = cue.get("w", {})
	var c: Control = H.c
	var mid := r.get_center()
	if not w.is_empty() and String(w["slot"]) == slot_id:
		var frac := clampf(float(w["left"]) / maxf(0.05, float(w["total"])), 0.0, 1.0)
		var hot := float(w["left"]) <= WARN
		var col: Color = cue.get("col", Color.WHITE)
		var beat := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * (0.024 if hot else 0.012))
		var rad := r.size.x * 0.5
		c.draw_circle(mid, rad + 10.0 + 4.0 * beat, Color(col, 0.18 + 0.2 * beat))
		c.draw_rect(r.grow(2.0 + 2.0 * beat), Color(col.lerp(Color.WHITE, beat * 0.5), 0.95), false, 3.0)
		c.draw_arc(mid, rad + 7.0, 0, TAU, 40, Color(0, 0, 0, 0.55), 6.0, true)
		H._arc(mid, rad + 7.0, frac, HOT if hot else col.lerp(Color.WHITE, 0.25), 6.0)
		if not bool(w.get("armed", true)):
			c.draw_rect(r, Color(0, 0, 0, 0.45))       # a press now is still eaten
		return true
	if String(cue.get("exp_slot", "")) == slot_id and float(cue.get("exp_t", 0.0)) > 0.0:
		var a := clampf(float(cue["exp_t"]) / 0.3, 0.0, 1.0)
		c.draw_rect(r, Color(0, 0, 0, 0.5 * a))
		return true
	return false

## In the world: the thing the open recast triggers flashes as the window closes, and the payoff burst on a foe.
static func world(H: Node, cam: Camera3D, p: Hunter) -> void:
	if p == null or p.ak == null or cam == null:
		return
	var cue := p.ak.cue
	var w: Dictionary = cue.get("w", {})
	if not w.is_empty() and float(w["left"]) <= WARN and not cam.is_position_behind(w["at"]):
		_closing(H, cam.unproject_position(w["at"] + Vector3(0, 0.6, 0)), cue.get("col", Color.WHITE))
	var pop: Dictionary = cue.get("pop", {})
	if not pop.is_empty() and is_instance_valid(pop["e"]) and not cam.is_position_behind((pop["e"] as Ent).position):
		var k := 1.0 - float(pop["t"]) / POP_T
		var sp := cam.unproject_position((pop["e"] as Ent).position + Vector3(0, 1.4, 0))
		H.c.draw_circle(sp, 30.0 + 50.0 * k, Color(1, 1, 1, 0.55 * (1.0 - k)))
		H.c.draw_arc(sp, 34.0 + 90.0 * k, 0, TAU, 48, Color(p.ak.res_col().lerp(Color.WHITE, 0.4), 1.0 - k), 6.0, true)

## The closing flash over the knife / seed / hammer: a glow that blinks between hot and white, no text.
static func _closing(H: Node, sp: Vector2, col: Color) -> void:
	var on := fmod(float(Time.get_ticks_msec()) * 0.001 * BLINK_HZ, 1.0) < 0.5
	var glow := Color(Color.WHITE, 0.5) if on else Color(HOT, 0.3)
	var c: Control = H.c
	c.draw_circle(sp, 24.0, glow)
	c.draw_arc(sp, 26.0, 0, TAU, 32, Color(HOT if on else col, 0.9), 3.0, true)
