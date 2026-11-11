class_name RecastCue
extends RefCounted
## Two-step abilities, loud and the same for every hunter (DECISIONS 2026-11-08 "two-step abilities must be obvious
## and in your face"). A kit reports its open recast through ArchKit.recast_window() and the foes carrying its
## mark/stack/Daze through ArchKit.combo_marks(); this module turns them into one visual language:
##   the ability slot pulses, shows a big "<KEY> AGAIN" and a shrinking timer ring, and "EXPIRED" if it ran out;
##   a world marker with the same key sits on the thing the recast triggers (the seed, the knife, the hammer);
##   a foe carrying your mark shows it in its plate's status row (HudPlate.row: the icon, a ring for the time left),
##   and a burst goes off on it when the payoff lands;
##   sounds: a chime as the window opens, ticks before it closes, a low click when it runs out.
## Only the local player's own cues show (track runs for the local hunter); key names come from the live InputMap.

const KEYS := {"e": "signature", "x": "hunter_ult", "dash": "dash", "lmb": "fire", "sec": "secondary"}
const WARN := 0.6              # s left when the ring turns hot and the ticks start
const TICKS := [0.6, 0.4, 0.2] # s left at which a closing tick plays
const EXPIRED_T := 0.9         # s "EXPIRED" stays on the slot
const RAN_OUT := 0.12          # s: a window that vanished with less than this left ran out (more: it was used)
const POP_T := 0.45            # s the payoff burst on a foe lasts
const PILL_PAD := 7.0           # px of dark backdrop either side of the slot's big text
const HOT := Color("ff5a4a")
const DIM := Color(0.6, 0.6, 0.66)

## Every step for the local hunter's kit: reads the window and the marks, plays the cues. State lives on the kit
## (ArchKit.cue): {w (the open window), last (its last left), slot, col, tick, exp_slot, exp_t, marks, pop}.
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
	var marks: Array = cue.get("marks", [])
	marks.clear()
	k.combo_marks(marks)
	cue["marks"] = marks
	var pop: Dictionary = cue.get("pop", {})
	if not pop.is_empty():
		pop["t"] = float(pop["t"]) - dt
		if float(pop["t"]) <= 0.0: cue["pop"] = {}

## The payoff landed on `victim`: a burst goes off on it (ArchKit.payoff_fx and the payoffs that don't go through it).
static func payoff(k: ArchKit, victim: Ent) -> void:
	if victim != null and k.h.is_local():
		k.cue["pop"] = {"e": victim, "t": POP_T}

## A window as kits report it (ArchKit.recast_window).
static func window(slot_id: String, left: float, total: float, at: Vector3, armed := true, auto := false) -> Dictionary:
	return {"slot": slot_id, "left": left, "total": total, "at": at, "armed": armed, "auto": auto}

## A mark on a foe as kits report it (ArchKit.combo_marks), for its plate's status row: `icon` an Icons id, n = the
## stack count shown (0: none), ready = the payoff is ready (a gold rim).
static func mark(e: Ent, n: int, left: float, total: float, icon: String, ready: bool) -> Dictionary:
	return {"e": e, "n": n, "left": left, "total": total, "icon": icon, "ready": ready}

static func slot_col(k: ArchKit, slot: String) -> Color:
	match slot:
		"e": return k.col_of(k.e_def())
		"x": return k.col_of(k.x_def())
		"dash": return k.col_of(k.dash_def())
		"lmb": return k.col_of(k.lmb_def()) if k.lmb_def().has("col") else k.res_col()
	return k.col_of(k.rmb_def())

static func key_of(slot: String) -> String:
	return Settings.key_cap(String(KEYS.get(slot, slot)))

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
			_label(H, mid + Vector2(0, -rad - 22.0), "WAIT", 16, DIM)
			return true
		var fs := int(24.0 + 4.0 * beat)
		var tc := (HOT if hot else col).lerp(Color.WHITE, 0.35)
		_label(H, mid + Vector2(0, -rad - 18.0), "%s AGAIN" % key_of(slot_id), fs, tc)
		return true
	if String(cue.get("exp_slot", "")) == slot_id and float(cue.get("exp_t", 0.0)) > 0.0:
		var a := clampf(float(cue["exp_t"]) / 0.3, 0.0, 1.0)
		c.draw_rect(r, Color(0, 0, 0, 0.5 * a))
		_label(H, mid + Vector2(0, -r.size.y * 0.5 - 14.0), "EXPIRED", 18, Color(DIM.lerp(Color.WHITE, 0.3), a))
		return true
	return false

## Big text on a dark pill so it reads over the HP bar or the item slots (`base` is the text's baseline).
static func _label(H: Node, base: Vector2, text: String, fs: int, col: Color) -> void:
	var w := TextCache.width(H.big, text, fs)
	var box := Rect2(base + Vector2(-w * 0.5 - PILL_PAD, -fs * 0.95), Vector2(w + PILL_PAD * 2.0, fs * 1.3))
	(H.c as Control).draw_rect(box, Color(0.03, 0.03, 0.05, 0.8 * col.a))
	H._ctext(base, text, fs, col, H.big)

## In the world: the marker on what the open recast triggers, and the burst on a foe the payoff just landed on.
static func world(H: Node, cam: Camera3D, p: Hunter) -> void:
	if p == null or p.ak == null or cam == null:
		return
	var cue := p.ak.cue
	var w: Dictionary = cue.get("w", {})
	if not w.is_empty() and not cam.is_position_behind(w["at"]):
		_marker(H, cam.unproject_position(w["at"] + Vector3(0, 1.1, 0)), w, cue.get("col", Color.WHITE))
	var pop: Dictionary = cue.get("pop", {})
	if not pop.is_empty() and is_instance_valid(pop["e"]) and not cam.is_position_behind((pop["e"] as Ent).position):
		var k := 1.0 - float(pop["t"]) / POP_T
		var sp := cam.unproject_position((pop["e"] as Ent).position + Vector3(0, 1.4, 0))
		H.c.draw_circle(sp, 30.0 + 50.0 * k, Color(1, 1, 1, 0.55 * (1.0 - k)))
		H.c.draw_arc(sp, 34.0 + 90.0 * k, 0, TAU, 48, Color(p.ak.res_col().lerp(Color.WHITE, 0.4), 1.0 - k), 6.0, true)

## The key in a ring that empties with the window, over the seed / knife / hammer / landing spot.
static func _marker(H: Node, sp: Vector2, w: Dictionary, col: Color) -> void:
	var c: Control = H.c
	var hot := float(w["left"]) <= WARN
	var beat := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
	var frac := clampf(float(w["left"]) / maxf(0.05, float(w["total"])), 0.0, 1.0)
	c.draw_circle(sp, 21.0 + 3.0 * beat, Color(col, 0.25))
	c.draw_circle(sp, 17.0, Color(0.03, 0.03, 0.05, 0.92))
	H._arc(sp, 19.0, frac, HOT if hot else col, 4.0)
	var key := key_of(String(w["slot"]))
	H._ctext(sp + Vector2(0, 6.0), key, 17 if key.length() <= 2 else 11, Color.WHITE, H.big)
	var word := "AGAIN" if bool(w.get("armed", true)) else "WAIT"
	_label(H, sp + Vector2(0, 36.0), word, 12, col.lerp(Color.WHITE, 0.4))
