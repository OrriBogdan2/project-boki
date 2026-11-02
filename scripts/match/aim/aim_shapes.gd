class_name AimShapes
extends RefCounted
## The telegraph shapes (docs/AIMKIT.md), drawn into an AimGeo from a resolved entry (AimKit fills the
## defaults). Kept quiet on purpose: a faint fill, a thin rim and a brighter accent only where the
## state matters (the charge front, a merged V, the sweet spot). "hot" (0..1) brightens toward white.

const FILL_A := 0.18      # the fill's alpha: readable over grass and sand, never a solid sheet
const RIM_A := 0.7        # the rim's alpha
const LW := 0.06          # m: the rim's line width

static func build(g: AimGeo, e: Dictionary) -> void:
	g.at_height(float(e["y"]))
	match String(e["kind"]):
		"lane": _lane(g, e)
		"dotted": _dotted(g, e)
		"vee": _vee(g, e)
		"cone": _cone(g, e)
		"circle": _circle(g, e)
		"arc_wall": _arc_wall(g, e)
		"swap": _swap(g, e)
		"line": _line(g, e)
		"span": _span(g, e)
		"star": g.star(e["at"], float(e["size"]), _hot(e, 1.0), float(e.get("rot", 0.0)))

# ------------------------------------------------------------------ colours
static func _fill(e: Dictionary, k := 1.0) -> Color:
	var c: Color = e["col"]
	return Color(c, FILL_A * k * float(e["alpha"]))

static func _rim(e: Dictionary, k := 1.0) -> Color:
	var c: Color = (e["col"] as Color).lerp(Color.WHITE, 0.55 * float(e["hot"]))
	return Color(c, minf(1.0, (RIM_A + 0.35 * float(e["hot"])) * k * float(e["alpha"])))

static func _hot(e: Dictionary, k := 1.0) -> Color:
	var c: Color = (e["col2"] as Color).lerp(Color.WHITE, 0.4 + 0.4 * float(e["hot"]))
	return Color(c, minf(1.0, 0.85 * k * float(e["alpha"])))

static func _lw(e: Dictionary) -> float:
	return float(e["lw"]) * (1.0 + 0.6 * float(e["hot"]))

# ------------------------------------------------------------------ shapes
static func _lane(g: AimGeo, e: Dictionary) -> void:
	var o: Vector2 = e["from"]; var u: Vector2 = e["dir"]
	var n := Vector2(-u.y, u.x)
	var l := float(e["len"]); var w0 := float(e["width"]); var w1 := float(e["width_end"])
	var end := o + u * l
	var lw := _lw(e)
	if not e["rails"]:
		g.band(o, end, w0, w1, _fill(e))
	var f := float(e["fill"])
	if f > 0.0:
		g.band(o, o + u * l * f, w0, lerpf(w0, w1, f), _fill(e, 1.6), _fill(e, 2.6))
		g.ribbon(o + u * l * f - n * lerpf(w0, w1, f) * 0.5, o + u * l * f + n * lerpf(w0, w1, f) * 0.5, lw, _hot(e, 0.7))
	var tip := end + u * w1 * 0.55
	for s in [-1.0, 1.0]:
		g.ribbon(o + n * w0 * 0.5 * s, end + n * w1 * 0.5 * s, lw, _rim(e, 0.8), _rim(e))
		if e["tip"]:
			g.ribbon(end + n * w1 * 0.5 * s, tip, lw, _rim(e))
	if not e["tip"] and not e["rails"]:
		g.ribbon(end - n * w1 * 0.5, end + n * w1 * 0.5, lw, _rim(e))
	var ch := int(e["chevrons"])
	for i in ch:
		var t := (float(i) + 0.75) / float(ch + 0.5)
		g.chevron(o + u * l * t, u, clampf(minf(w0, w1) * 0.32, 0.14, 0.4), lw * 0.9, _rim(e, 0.75))

static func _dotted(g: AimGeo, e: Dictionary) -> void:
	var o: Vector2 = e["from"]; var u: Vector2 = e["dir"]
	var l := float(e["len"]); var w := float(e["width"])
	var n := Vector2(-u.y, u.x)
	g.band(o, o + u * l, w, w, _fill(e, 0.8))
	for s in [-1.0, 1.0]:
		g.ribbon(o + n * w * 0.5 * s, o + u * l + n * w * 0.5 * s, _lw(e) * 0.7, _rim(e, 0.5))
	var gap := maxf(0.2, float(e["gap"]))
	var t := gap * 0.5
	while t < l:
		g.disc(o + u * t, float(e["dot"]), _rim(e, 0.9))
		t += gap

static func _vee(g: AimGeo, e: Dictionary) -> void:
	var o: Vector2 = e["from"]; var u: Vector2 = e["dir"]
	var l := float(e["len"]); var half := float(e["half"])
	if e["merged"]:
		g.ribbon(o, o + u * l, _lw(e) * 1.6, _hot(e, 0.9), _hot(e, 0.55))
	else:
		for s in [-1.0, 1.0]:
			g.ribbon(o, o + u.rotated(half * s) * l, _lw(e), _rim(e), _rim(e, 0.45))
	var st := float(e["glint"])
	if st >= 0.0:
		g.star(o + u * l * st, 0.32 + 0.12 * float(e["hot"]), _hot(e), PI * 0.25)

static func _cone(g: AimGeo, e: Dictionary) -> void:
	var o: Vector2 = e["from"]; var u: Vector2 = e["dir"]
	var l := float(e["len"]); var inner := float(e["inner"])
	var h := deg_to_rad(float(e["deg"])) * 0.5
	var a := atan2(u.y, u.x)
	var lw := _lw(e)
	if not e["edges"]:
		g.sector(o, inner, l, a - h, a + h, _fill(e, 0.6), _fill(e, 1.3))
		g.ring(o, l, lw, _rim(e), a - h, a + h)
		var f := float(e["fill"])
		if f > 0.0:
			g.sector(o, inner, lerpf(inner, l, f), a - h, a + h, _fill(e, 1.4))
	for s in [-1.0, 1.0]:
		var ed := Vector2(cos(a + h * s), sin(a + h * s))
		g.ribbon(o + ed * inner, o + ed * l, lw, _rim(e, 0.9), _rim(e, 0.6 if e["edges"] else 1.0))

static func _circle(g: AimGeo, e: Dictionary) -> void:
	var ctr: Vector2 = e["at"]; var r := float(e["r"])
	var lw := _lw(e)
	g.disc(ctr, r, _fill(e, 0.5), _fill(e, 1.2))
	if e["dashed"]:
		var segs := maxi(8, int(r * TAU / 0.6))
		for i in segs:
			var a0 := TAU * i / segs
			g.ring(ctr, r, lw, _rim(e), a0, a0 + TAU / segs * 0.6)
	else:
		g.ring(ctr, r, lw, _rim(e))
	var f := float(e["fill"])
	if f > 0.0:
		g.disc(ctr, r * f, _fill(e, 1.2), _fill(e, 2.2))
	var core := float(e["core"])
	if core > 0.0:
		var cc: Color = e["col2"]
		g.disc(ctr, core, Color(cc, FILL_A * 1.6 * float(e["alpha"])))
		g.ring(ctr, core, lw * 1.2, _hot(e, 0.9))
	if e["ticks"]:
		for i in 4:
			var d := Vector2.from_angle(i * PI * 0.5 + float(e.get("rot", 0.0)))
			g.ribbon(ctr + d * (r - 0.28), ctr + d * (r + 0.12), lw * 1.3, _rim(e))
	if e["star"]:
		g.star(ctr, minf(0.45, r * 0.3), _hot(e), PI * 0.25)

static func _arc_wall(g: AimGeo, e: Dictionary) -> void:
	var ctr: Vector2 = e["center"]; var u: Vector2 = e["dir"]
	var r := float(e["radius"]); var th := float(e["thick"])
	var h := deg_to_rad(float(e["deg"])) * 0.5
	var a := atan2(u.y, u.x)
	var pn := maxi(1, int(e["panels"]))
	var gap := 0.08 / maxf(1.0, r)      # radians between panels
	var lw := _lw(e)
	for i in pn:
		var a0 := a - h + 2.0 * h * i / pn + (gap if i > 0 else 0.0)
		var a1 := a - h + 2.0 * h * (i + 1) / pn - (gap if i < pn - 1 else 0.0)
		g.sector(ctr, r - th * 0.5, r + th * 0.5, a0, a1, _fill(e, 1.1), _fill(e, 0.7))
		g.ring(ctr, r + th * 0.5, lw, _rim(e), a0, a1)
		g.ring(ctr, r - th * 0.5, lw * 0.7, _rim(e, 0.6), a0, a1)
	for s in [-1.0, 1.0]:
		var ed := Vector2.from_angle(a + h * s)
		g.ribbon(ctr + ed * (r - th * 0.5), ctr + ed * (r + th * 0.5), lw, _rim(e))

static func _swap(g: AimGeo, e: Dictionary) -> void:
	var a: Vector2 = e["a"]; var b: Vector2 = e["b"]; var r := float(e["r"])
	var lw := _lw(e)
	var d := b - a
	var l := d.length()
	g.ring(a, r * 0.8, lw, _rim(e, 0.85))
	g.disc(a, r * 0.8, _fill(e, 0.6))
	g.ring(b, r, lw, _rim(e))
	g.disc(b, r, _fill(e, 0.7))
	var f := float(e["fill"])
	if f > 0.0:
		g.disc(b, r * f, _fill(e, 2.0))
		g.ring(b, r * 0.62, lw * 1.2, _hot(e, 0.8), -PI * 0.5, -PI * 0.5 + TAU * f)
	if l > r * 1.8:
		var u := d / l
		g.dashes(a + u * r * 0.8, b - u * r, lw * 0.8, _rim(e, 0.6))
		var mid := (a + b) * 0.5
		var n := Vector2(-u.y, u.x) * 0.16
		g.arrow(mid + u * 0.3 + n, u, 0.22, lw, _rim(e))
		g.arrow(mid - u * 0.3 - n, -u, 0.22, lw, _rim(e))

static func _line(g: AimGeo, e: Dictionary) -> void:
	var o: Vector2 = e["from"]; var t: Vector2 = e["to"]
	var d := t - o
	if d.length() < 0.05:
		return
	var w := float(e["lw"]) * (0.8 + 0.8 * float(e["hot"]))
	var c := _hot(e, 0.75) if float(e["hot"]) > 0.0 else _rim(e, 0.85)
	g.ribbon(o, t, w, Color(c, c.a * 0.55), c)
	if e["arrow"]:
		g.arrow(t, d.normalized(), 0.2, w * 1.2, c)

static func _span(g: AimGeo, e: Dictionary) -> void:
	var ctr: Vector2 = e["at"]; var u: Vector2 = e["dir"]
	var hl := float(e["len"]) * 0.5
	var lw := _lw(e)
	g.ribbon(ctr - u * hl, ctr + u * hl, lw, _rim(e))
	var ch := int(e["chevrons"])
	for i in ch:
		var t := hl * (float(i) + 1.0) / float(ch + 1)
		g.chevron(ctr + u * t, -u, 0.28, lw, _rim(e, 0.85))
		g.chevron(ctr - u * t, u, 0.28, lw, _rim(e, 0.85))
	if e["ring"]:
		g.ring(ctr, 0.35, lw, _rim(e))
