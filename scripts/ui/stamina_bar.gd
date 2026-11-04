class_name StaminaBar
extends RefCounted
## The dash bar: one segment per dash charge (the count comes from the hunter's kit and class), then a
## shorter pale one for the long air dash when the kit has it. A spent segment stays on screen dimmed;
## the one recharging sweeps full over the recharge time; when it completes it flashes bright (and, on
## your own bar, ticks softly). While the long dash is on cooldown the whole bar takes a cool blue tint.
## Pressing dash with nothing to spend shakes the bar and flashes it red. Hud's plates own one of these
## (hud.plates.stam); the overhead plates, the bottom-left block and the squad frames all draw it.

const COL := Color("ffd66a")            # a ready charge
const LONG_COL := Color("bfe6ff")       # the long dash
const COOL := Color("6fb8ff")           # the tint while the long dash recharges
const DENY_COL := Color("ff4a3a")
const FLASH_T := 0.28                   # s of the "it's back" flash
const SHAKE_T := 0.3                    # s of the shake and red flash on an empty press
const KEEP_T := 5.0                     # s unseen before a bar's state is dropped
const TICK_VOL := -15.0

## nid -> {at, full: Array[bool], flash: Array[float], jolt, completes, denies, seen_n}
var st := {}
## Set (seconds) by tools that step the match faster or slower than real time; else the wall clock.
var clock := -1.0

func _now() -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() * 0.001

## The fill of each segment, 0..1: the short charges first (the recharging one partly full), then the long dash.
static func fills(h: Hunter) -> Array:
	var out: Array = []
	for i in shorts(h):
		out.append(clampf(h.dashes - float(i), 0.0, 1.0))
	if has_long(h):
		out.append(clampf(1.0 - h.ex_cd / long_cd(h), 0.0, 1.0))
	return out

static func shorts(h: Hunter) -> int:
	return int(h.max_dashes())

static func has_long(h: Hunter) -> bool:
	return h.ak == null or h.ak.has_long_dash()

## How long the long dash takes to come back for this hunter (its class data).
static func long_cd(h: Hunter) -> float:
	return maxf(0.01, float(h.cdat.get("ex_cd", Hunter.EX_DASH_CD)))

## Moves one hunter's bar state to `now` (seconds, any steady clock): spots completed segments and
## starts their flash and tick (`audible`: your own bar only). Safe to call twice in one frame.
func update(h: Hunter, now: float, audible := false) -> Dictionary:
	var f := fills(h)
	var s: Dictionary = st.get(h.nid, {})
	if s.is_empty() or (s["full"] as Array).size() != f.size():
		var keep: Dictionary = s
		s = {"at": now, "full": [], "flash": [], "jolt": 0.0}
		s["completes"] = int(keep.get("completes", 0))
		s["denies"] = int(keep.get("denies", 0))
		for v in f:
			(s["full"] as Array).append(float(v) >= 0.999)
			(s["flash"] as Array).append(0.0)
		st[h.nid] = s
	var dt := maxf(0.0, now - float(s["at"]))
	if dt <= 0.0 and now > 0.0:
		return s
	s["at"] = now
	s["jolt"] = maxf(0.0, float(s["jolt"]) - dt)
	var done := false
	for i in f.size():
		var full := float(f[i]) >= 0.999
		if full and not bool((s["full"] as Array)[i]):
			(s["flash"] as Array)[i] = FLASH_T
			s["completes"] = int(s["completes"]) + 1
			done = true
		(s["full"] as Array)[i] = full
		(s["flash"] as Array)[i] = maxf(0.0, float((s["flash"] as Array)[i]) - dt)
	if done and audible:
		Sfx.play("click", null, TICK_VOL, 0.0, 1.9)
	if st.size() > 24:
		for k in st.keys():
			if now - float(st[k]["at"]) > KEEP_T:
				st.erase(k)
	return s

## Dash pressed with nothing to spend: shake and red flash (Hud.ability_feedback calls this).
func deny(h: Hunter) -> void:
	var s: Dictionary = st.get(h.nid, {})
	if s.is_empty():
		update(h, _now())
		s = st[h.nid]
	s["jolt"] = SHAKE_T
	s["denies"] = int(s["denies"]) + 1

## Draws the bar for `h` in `r` (the segments share its width and height).
func draw(c: CanvasItem, r: Rect2, h: Hunter, audible := false) -> void:
	var s := update(h, _now(), audible)
	var f := fills(h)
	var n := f.size()
	var cool := h.ex_cd > 0.0 and has_long(h)
	var gap := 2.0 if r.size.y < 5.0 else 3.0
	var long_w := clampf(r.size.x * 0.14, 8.0, 14.0) if has_long(h) else 0.0
	var ns := n - (1 if has_long(h) else 0)
	var seg_w := (r.size.x - long_w - gap * float(n - 1)) / float(maxi(1, ns))
	var k := float(s["jolt"]) / SHAKE_T
	var x := r.position.x + sin(float(s["jolt"]) * 70.0) * 3.0 * k
	if cool:
		c.draw_rect(Rect2(Vector2(x, r.position.y), Vector2(r.size.x, r.size.y)).grow(2.0), Color(COOL, 0.35))
	for i in n:
		var is_long := has_long(h) and i == n - 1
		var sw := long_w if is_long else seg_w
		var sr := Rect2(Vector2(x, r.position.y), Vector2(sw, r.size.y))
		var col: Color = LONG_COL
		if not is_long:
			col = COL.lerp(COOL, 0.6) if cool else COL
		var fill: float = f[i]
		c.draw_rect(sr.grow(1.5), Color(0.03, 0.03, 0.05, 0.85))
		c.draw_rect(sr, Color(col, 0.2))
		if fill >= 0.999:
			c.draw_rect(sr, col)
			c.draw_rect(Rect2(sr.position, Vector2(sw, 1.0)), Color(1, 1, 1, 0.35))
		elif fill > 0.0:
			c.draw_rect(Rect2(sr.position, Vector2(sw * fill, sr.size.y)), Color(col, 0.75))
			var edge := Rect2(Vector2(sr.position.x + sw * fill - 1.0, sr.position.y), Vector2(1.0, sr.size.y))
			c.draw_rect(edge, Color(1, 1, 1, 0.8))
		if k > 0.0:
			c.draw_rect(sr.grow(1.5), Color(DENY_COL, 0.9 * k))
		var fl := float((s["flash"] as Array)[i]) / FLASH_T
		if fl > 0.0:
			c.draw_rect(sr.grow(1.0 + 2.0 * fl), Color(1, 1, 1, 0.9 * fl))
		x += sw + gap
