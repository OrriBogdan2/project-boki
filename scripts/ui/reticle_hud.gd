class_name ReticleHud
extends RefCounted
## The in-match cursor reticle with its aim states (the HUD owns one): the Reticle ring that opens with bloom,
## the archetype's resource arc, the charge / warm-up / spin-up / reload arc or the ammo arc round it, the
## full-charge flare, and the hit confirm (thin ticks off the ring, longer and gold on a crit, pale on
## armour, with a ring flash). Thin strokes, a dark edge under every one, the Hunter's accent on the dot
## and arcs. Numbers: content/rules/tuning.json "reticle". The AimKit cursor states are AimReticle.

var hit_t := 0.0               # s left of the hit confirm
var hit_crit := false
var hit_armor := false
var _full := false             # the charge arc was full last frame
var _flare_at := -99.0         # when it last reached full (m.time)

static func _t(key: String) -> float:
	return Reticle.t(key)

static func _tc(key: String) -> Color:
	return Reticle.tc(key)

func tick(delta: float) -> void:
	hit_t = maxf(0.0, hit_t - delta)

## A hit landed (the player's): starts the confirm.
func hit(crit: bool, armor: bool) -> void:
	hit_t = _t("hit_s")
	hit_crit = crit
	hit_armor = armor

## Draws the reticle and its states at `at` on `c` for the player `p`; `time` is the match clock.
func draw(c: CanvasItem, p: Hunter, at: Vector2, time: float) -> void:
	var accent := Reticle.accent(p.arch)
	var spread := p.recoil * 4.0 + p.wbloom * 1.2
	if p.wpn.has("tighten_from_deg") and p.spin > 0.0:
		spread += lerpf(12.0, 0.0, clampf(p.spun_t / float(p.wpn.get("tighten_time", 1.5)), 0.0, 1.0))
	var hc := _hit_color()
	var k := hit_t / _t("hit_s")
	Reticle.draw(c, at, spread, accent, Color(hc, k * _t("hit_ring_flash")))
	if p.ak and p.ak.has_meter():
		var rc := p.ak.res_col()
		var full := p.ak.tell == "full"
		_arc(c, at, _t("res_r"), PI * 1.62, PI * 0.76, p.ak.res_frac(), rc, 0.95 if full else 0.7, full)
	_states(c, p, at, time, accent)
	if hit_t > 0.0:
		_hit(c, at, spread, hc, k)

## The charge, warm-up, spin-up, reload or ammo arc (one at a time).
func _states(c: CanvasItem, p: Hunter, at: Vector2, time: float, accent: Color) -> void:
	var r := _t("charge_r")
	var ck := p.charge_k()
	if ck > 0.0:
		var full := ck >= 1.0
		if full and not _full:
			_flare_at = time
		_arc(c, at, r, -PI * 0.5, TAU, ck, accent.lightened(0.45) if not full else Color.WHITE, 1.0, full)
		_flare(c, at, r, time, accent)
	elif p.warm_t > 0.0:
		var warm := 1.0 - p.warm_t / maxf(0.01, float(p.wpn.get("warmup", 0.6)))
		_arc(c, at, r, -PI * 0.5, TAU, warm, p.wpn["color"], 1.0, false)
	elif p.wpn.has("spin_up") and p.spin > 0.0 and p.spin < 1.0:
		_arc(c, at, r, -PI * 0.5, TAU, p.spin, _tc("col_warm_up"), 1.0, false)
	elif p.wpn.get("melee", false):
		pass
	elif p.reload_t > 0.0:
		_arc(c, at, r, -PI * 0.5, TAU, 1.0 - p.reload_t / float(p.wpn["reload"]), _tc("col_reload"), 1.0, false)
	else:
		var af := float(p.ammo) / maxf(1.0, float(p.wpn["mag"]))
		var low := af <= _t("low_ammo_frac")
		var pulse := 0.5 + 0.5 * sin(time * TAU * _t("low_ammo_pulse_hz"))
		var col := accent.lightened(0.35)
		var alpha := 0.8
		if low:
			col = _tc("col_low")
			alpha = 0.6 + 0.4 * pulse
		_arc(c, at, _t("ammo_r"), PI * 0.62, PI * 0.76, af, col, alpha, false)
	_full = ck >= 1.0

## One arc of `span` radians from `from` with its dark track and the fraction `frac` filled in `col`.
func _arc(c: CanvasItem, at: Vector2, r: float, from: float, span: float, frac: float,
		col: Color, a: float, bold: bool) -> void:
	var w := _t("arc_w_full") if bold else _t("arc_w")
	c.draw_arc(at, r, from, from + span, 32, Color(0, 0, 0, _t("track_a")), _t("arc_w") + 1.6, true)
	if frac > 0.0:
		c.draw_arc(at, r, from, from + span * clampf(frac, 0.0, 1.0), 32, Color(col, a), w, true)

## The ring that snaps out when a charge reaches full (out-cubic, fading).
func _flare(c: CanvasItem, at: Vector2, r: float, time: float, accent: Color) -> void:
	var u := (time - _flare_at) / _t("flare_s")
	if u < 0.0 or u >= 1.0:
		return
	var e := 1.0 - pow(1.0 - u, 3.0)
	var col := Color(accent.lightened(0.5), 0.9 * (1.0 - u))
	c.draw_arc(at, r + 1.5 + e * _t("flare_grow"), 0.0, TAU, 32, col, _t("arc_w"), true)

func _hit_color() -> Color:
	if hit_armor:
		return _tc("col_armor_crit" if hit_crit else "col_armor")
	return _tc("col_crit" if hit_crit else "col_hit")

## The hit confirm: four thin ticks leave the ring on the diagonals, snapping out and settling; a crit's are
## longer and bolder with a pulse ring. `k` runs 1 -> 0 over the hit.
func _hit(c: CanvasItem, at: Vector2, spread: float, hc: Color, k: float) -> void:
	var len_t := _t("hit_len_crit" if hit_crit else "hit_len")
	var w := _t("hit_w_crit" if hit_crit else "hit_w")
	var ring := _t("ring_r") + minf(spread, _t("spread_max"))
	var from := ring + _t("hit_gap") + (1.0 - k) * _t("hit_pop")
	var a := minf(1.0, k * 2.5)
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		c.draw_line(at + n * from, at + n * (from + len_t), Color(0.05, 0.03, 0.08, 0.65 * a), w + 1.6, true)
		c.draw_line(at + n * from, at + n * (from + len_t), Color(hc, a), w, true)
	if hit_crit:
		var pulse_r := from + (1.0 - k) * _t("crit_pulse_grow")
		c.draw_arc(at, pulse_r, 0.0, TAU, 32, Color(hc, 0.7 * k), _t("arc_w"), true)
