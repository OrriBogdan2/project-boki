class_name AimKit
extends RefCounted
## Shared aiming telegraphs and cursor states for the hero kits (docs/AIMKIT.md).
##
## Immediate style: a kit calls a shape every step while it should show, under an id of its own
## ("rmb", "e_drag"...). An entry not refreshed for AimDraw.KEEP (0.1 s of match time) disappears, so
## stopping the calls hides it; `hide` drops it at once, and a `"dur": secs` param keeps a one-off (a
## placed ring, a stuck grenade's cone) up that long without more calls. A second call with the same
## id replaces the first. Everything draws through one pooled ImmediateMesh per match (AimDraw): no
## node is made per call or per frame. A Boki merge clears a hunter's set and keeps it clear: AimDraw
## drops every entry of a merged or transforming hunter (whichever path started the merge), and
## ArchKit.drop_holds() clears it on the spot.
##
## Common params (every shape):
##   col     Color   the hero colour (default: the archetype's "color")
##   col2    Color   the accent (sweet spot, merged V, glints; default: the archetype resource colour)
##   alpha   float   overall strength, 1 = the quiet default
##   hot     float   0..1, brightens toward white (full charge); lanes and Vs go hot by themselves at k = 1
##   lw      float   m, the rim width (0.06)
##   all     bool    foes and allies see it too (an area someone must dodge); default false = your own
##                   aim only. A foe's shows lerped toward the hostile rim colour.
##   dur     float   s, how long it stays without a refresh (default 0.1)
##   fletch  float   lines and Vs only: 0 = plain; > 0 feathers the line with barbs swept back toward
##                   the hunter (Hem's draw), this big

const BH := 1.8           # m in one body height (the hero sheets measure in bh)

static func layer(m: Node) -> AimDraw:
	var d := m.get_node_or_null("AimKit") as AimDraw
	if d == null:
		d = AimDraw.new(m)
		m.add_child(d)
	return d

## Merged, or mid-transformation, or leaping home to merge: the form owns the buttons, nothing shows.
static func blocked(h: Hunter) -> bool:
	return KinMerge.active(h) or KinMerge.transforming(h)

static func hero_col(h: Hunter) -> Color:
	if h.ak != null:
		return Color(String(h.ak.d.get("color", "#ffffff")))
	return Color.WHITE

static func accent_col(h: Hunter) -> Color:
	if h.ak != null:
		return h.ak.res_col()
	return Color("fff1b8")

# ------------------------------------------------------------------ shapes
## A lane from `from` along `dir`: fixed, or growing (len0 -> len with k), narrowing (width -> width_to
## with k), optional fill front, rails only, chevrons, an arrow tip.
## p: from, dir, len (6), width (0.9), k (charge 0..1), len0, width_to, taper (end width k, 1),
##    fill (0..1 front), rails (false), chevrons (0), tip (false), col_full (colour at k = 1)
static func lane(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "lane", p)
	var k := float(p.get("k", -1.0))
	var l := float(p.get("len", 6.0)); var w := float(p.get("width", 0.9))
	if k >= 0.0:
		var kk := clampf(k, 0.0, 1.0)
		if p.has("len0"): l = lerpf(float(p["len0"]), l, kk)
		if p.has("width_to"): w = lerpf(w, float(p["width_to"]), kk)
		_full(e, p, k)
	e["len"] = l; e["width"] = w; e["width_end"] = w * float(p.get("taper", 1.0))
	e["fill"] = float(p.get("fill", -1.0))
	e["rails"] = bool(p.get("rails", false)); e["chevrons"] = int(p.get("chevrons", 0)); e["tip"] = bool(p.get("tip", false))
	_ray(h, e, p)
	_put(h, id, e)

## A dotted lane: a faint strip with dots down its centre (a seed or a slow shot's path).
## p: from, dir, len (8), width (0.72), gap (0.6 m between dots), dot (0.06 m dot radius)
static func dotted(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "dotted", p)
	e["len"] = float(p.get("len", 8.0)); e["width"] = float(p.get("width", 0.72))
	e["gap"] = float(p.get("gap", 0.6)); e["dot"] = float(p.get("dot", 0.06))
	_ray(h, e, p)
	_put(h, id, e)

## A V of two lines that close into one as a draw charges (k 0 -> 1); at k >= 1 one bright line.
## p: from, dir, len (to the cursor, clamped 1.5-20), k, open (deg, 25), glint (0..1 along the line, -1 off)
static func vee(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "vee", p)
	var k := clampf(float(p.get("k", 0.0)), 0.0, 1.0)
	e["len"] = float(p.get("len", clampf(AimMode.cursor_dist(h), 1.5, 20.0)))
	e["half"] = deg_to_rad(float(p.get("open", 25.0))) * 0.5 * (1.0 - k)
	e["merged"] = k >= 1.0
	e["glint"] = float(p.get("glint", -1.0))
	_full(e, p, float(p.get("k", 0.0)))
	_ray(h, e, p)
	_put(h, id, e)

## A cone (wedge) from `from` along `dir`; "edges" draws only the two edge lines (a shotgun spread).
## p: from, dir, len (4), deg (60), inner (0.3 m), edges (false), fill (0..1 radial front)
static func cone(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "cone", p)
	e["len"] = float(p.get("len", 4.0)); e["deg"] = float(p.get("deg", 60.0)); e["inner"] = float(p.get("inner", 0.3))
	e["edges"] = bool(p.get("edges", false)); e["fill"] = float(p.get("fill", -1.0))
	_ray(h, e, p)
	_put(h, id, e)

## A landing or area circle. p: at (the cursor point, clamped to `range`), range (1e9), self (true:
## around the hunter), r (1.35), fill (0..1 radial), ticks (4 cardinal), star (centre glint),
## dashed, core (inner ring radius, m), pointer (a Vector2: a chevron on the rim pointing that way)
static func circle(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "circle", p)
	_disc(h, e, p)
	e["core"] = float(p.get("core", -1.0))
	_put(h, id, e)

## A circle with a growing inner sweet-spot ring: core grows core0 -> core1 with k (0.5 -> 1 bh).
## p: as circle (r defaults to 2.5 bh = 4.5 m) plus k, core0 (0.9), core1 (1.8)
static func sweet(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "circle", p)
	var q := p.duplicate()
	if not q.has("r"): q["r"] = 2.5 * BH
	_disc(h, e, q)
	var k := clampf(float(p.get("k", 0.0)), 0.0, 1.0)
	e["core"] = lerpf(float(p.get("core0", 0.5 * BH)), float(p.get("core1", BH)), k)
	_full(e, p, float(p.get("k", 0.0)))
	_put(h, id, e)

## A curved wall concentric to `center`, centred on the aim, at the cursor distance by default.
## p: center (the hunter), dir, radius (cursor distance clamped to rmin..rmax), rmin (2), rmax (9),
##    deg (120), thick (0.9 m band), panels (7)
static func arc_wall(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "arc_wall", p)
	var c: Vector3 = p.get("center", h.pos)
	e["center"] = Vector2(c.x, c.z); e["y"] = AimMode.ground(h.m, c).y
	e["dir"] = _dir(h, p)
	e["radius"] = float(p.get("radius", clampf(AimMode.cursor_dist(h), float(p.get("rmin", 2.0)), float(p.get("rmax", 9.0)))))
	e["deg"] = float(p.get("deg", 120.0)); e["thick"] = float(p.get("thick", 0.9)); e["panels"] = int(p.get("panels", 7))
	_put(h, id, e)

## A two-end marker for swaps and returns: a ring at `a`, a ring at `b`, a dashed link with arrows both
## ways, and a sigil that fills at the destination. p: a (the hunter), b (the cursor point, clamped to
## `range`), range (1e9), r (1.35), fill (0..1)
static func swap(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "swap", p)
	var a: Vector3 = p.get("a", h.pos)
	var b: Vector3 = p.get("b", AimMode.point(h, float(p.get("range", 1e9))))
	e["a"] = Vector2(a.x, a.z); e["b"] = Vector2(b.x, b.z); e["y"] = AimMode.ground(h.m, a).y
	e["r"] = float(p.get("r", 1.35)); e["fill"] = float(p.get("fill", -1.0))
	_put(h, id, e)

## A thin aim line from `from` to the cursor point (or `len` along `dir`, past the cursor), with an
## arrow tick at the end. p: from, to, dir, len, arrow (true), lw (0.035)
static func line(h: Hunter, id: String, p := {}) -> void:
	var q := p.duplicate()
	if not q.has("lw"): q["lw"] = 0.035
	var e := _base(h, "line", q)
	var f: Vector3 = p.get("from", h.pos)
	var t: Vector3
	if p.has("to"):
		t = p["to"]
	elif p.has("len"):
		var d := _dir(h, p)
		t = f + Vector3(d.x, 0, d.y) * float(p["len"])
	else:
		t = h.inp.get("aim", h.pos)
	e["from"] = Vector2(f.x, f.z); e["to"] = Vector2(t.x, t.z); e["y"] = AimMode.ground(h.m, f).y
	e["arrow"] = bool(p.get("arrow", true))
	_put(h, id, e)

## A long placement line centred on `at`, along `dir` (default: across the aim), with chevrons pointing
## in toward a centre ring (a wall or a rift that closes on its middle).
## p: at (the cursor point, clamped to `range`), range, dir, len (8), chevrons (3), ring (true), bend (radians the
## line turns end to end, 0 = straight) and bow (unit normal the middle bulges toward)
static func span(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "span", p)
	var at: Vector3 = p.get("at", AimMode.point(h, float(p.get("range", 1e9))))
	e["at"] = Vector2(at.x, at.z); e["y"] = AimMode.ground(h.m, at).y
	var ad := h.aim_dir()
	var d: Vector2 = p.get("dir", Vector2(-ad.y, ad.x))
	e["dir"] = d.normalized() if d.length() > 0.01 else Vector2(1, 0)
	e["len"] = float(p.get("len", 8.0)); e["chevrons"] = int(p.get("chevrons", 3)); e["ring"] = bool(p.get("ring", true))
	e["bend"] = float(p.get("bend", 0.0))
	e["bow"] = p.get("bow", Vector2.ZERO)
	_put(h, id, e)

## A flat 4-point glint on the ground (a charge riding a line, a lock-on). p: at, size (0.4), rot
static func star(h: Hunter, id: String, p := {}) -> void:
	var e := _base(h, "star", p)
	var at: Vector3 = p.get("at", h.inp.get("aim", h.pos))
	e["at"] = Vector2(at.x, at.z); e["y"] = AimMode.ground(h.m, at).y
	e["size"] = float(p.get("size", 0.4)); e["rot"] = float(p.get("rot", PI * 0.25))
	_put(h, id, e)

# ------------------------------------------------------------------ control
static func hide(h: Hunter, id: String) -> void:
	if h != null and h.m != null:
		layer(h.m).drop(h, id)

## Everything this hunter shows: telegraphs and cursor states (merge start, death, hero swap).
static func clear(h: Hunter) -> void:
	if h != null and h.m != null and h.m.get_node_or_null("AimKit") != null:
		layer(h.m).drop_all(h)

static func shown(h: Hunter, id: String) -> bool:
	if h == null or h.m == null or h.m.get_node_or_null("AimKit") == null:
		return false
	var d := layer(h.m)
	var k := AimDraw.key(h, id)
	return d.entries.has(k) and d.live(d.entries[k])

## The resolved entry (tests, kits reading back a default such as the arc radius); {} when not shown.
static func entry(h: Hunter, id: String) -> Dictionary:
	return layer(h.m).entries.get(AimDraw.key(h, id), {}) if shown(h, id) else {}

# ------------------------------------------------------------------ cursor states
## The charge ring on the cursor, k 0..1, called each step while charging. Crossing 1 fires the flare.
## p: col (hero colour), flare (true: flare on reaching full)
static func charge(h: Hunter, k: float, p := {}) -> void:
	if blocked(h):
		return
	var r := layer(h.m).ret_of(h)
	var was := float(r["k"]) if float(h.m.time) - float(r["t"]) <= AimDraw.KEEP else -1.0
	r["k"] = k; r["t"] = float(h.m.time)
	r["col"] = p.get("col", hero_col(h))
	if k >= 1.0 and was < 1.0 and bool(p.get("flare", true)):
		flare(h, p)

## The full-charge flare on the cursor now. p: col (the accent colour)
static func flare(h: Hunter, p := {}) -> void:
	if blocked(h):
		return
	var r := layer(h.m).ret_of(h)
	r["flare"] = AimReticle.FLARE_T
	r["fcol"] = p.get("col2", p.get("col", accent_col(h)))

## The perfect-window star flash on the cursor (released on the ready frame). p: col (gold)
static func perfect(h: Hunter, p := {}) -> void:
	if blocked(h):
		return
	var r := layer(h.m).ret_of(h)
	r["perfect"] = AimReticle.PERFECT_T
	r["pcol"] = p.get("col", Color("ffd25a"))

## This hunter's cursor states now: {charge (-1 = none), flare (s left), perfect (s left)}.
static func reticle(h: Hunter) -> Dictionary:
	var d := layer(h.m)
	if not d.ret.has(h.get_instance_id()):
		return {"charge": -1.0, "flare": 0.0, "perfect": 0.0}
	var r: Dictionary = d.ret[h.get_instance_id()]
	var live := float(h.m.time) - float(r["t"]) <= AimDraw.KEEP
	return {"charge": float(r["k"]) if live else -1.0, "flare": float(r["flare"]), "perfect": float(r["perfect"])}

# ------------------------------------------------------------------ helpers
static func _base(h: Hunter, kind: String, p: Dictionary) -> Dictionary:
	return {"kind": kind, "col": p.get("col", hero_col(h)), "col2": p.get("col2", accent_col(h)),
		"alpha": float(p.get("alpha", 1.0)), "hot": clampf(float(p.get("hot", 0.0)), 0.0, 1.0),
		"lw": float(p.get("lw", AimShapes.LW)), "all": bool(p.get("all", false)),
		"keep": maxf(AimDraw.KEEP, float(p.get("dur", AimDraw.KEEP))), "y": h.pos.y,
		"fletch": float(p.get("fletch", 0.0))}

## At full charge: hot unless the kit set it, and the full colour if it gave one.
static func _full(e: Dictionary, p: Dictionary, k: float) -> void:
	if k >= 1.0:
		if not p.has("hot"): e["hot"] = 1.0
		if p.has("col_full"): e["col"] = p["col_full"]

static func _dir(h: Hunter, p: Dictionary) -> Vector2:
	var d: Vector2 = p.get("dir", h.aim_dir())
	return d.normalized() if d.length() > 0.01 else h.aim_dir()

## from + dir for the ray shapes, on the ground under `from`.
static func _ray(h: Hunter, e: Dictionary, p: Dictionary) -> void:
	var f: Vector3 = p.get("from", h.pos)
	e["from"] = Vector2(f.x, f.z); e["y"] = AimMode.ground(h.m, f).y
	e["dir"] = _dir(h, p)

static func _disc(h: Hunter, e: Dictionary, p: Dictionary) -> void:
	var at: Vector3
	if p.has("at"): at = p["at"]
	elif bool(p.get("self", false)): at = h.pos
	else: at = AimMode.point(h, float(p.get("range", 1e9)))
	e["at"] = Vector2(at.x, at.z); e["y"] = AimMode.ground(h.m, at).y
	e["r"] = float(p.get("r", 1.35)); e["fill"] = float(p.get("fill", -1.0))
	e["ticks"] = bool(p.get("ticks", false)); e["star"] = bool(p.get("star", false)); e["dashed"] = bool(p.get("dashed", false))
	var pd: Vector2 = p.get("pointer", Vector2.ZERO)
	e["pointer"] = pd.normalized() if pd.length() > 0.01 else Vector2.ZERO

static func _put(h: Hunter, id: String, e: Dictionary) -> void:
	if h == null or h.m == null or blocked(h):
		return
	layer(h.m).put(h, id, e)
