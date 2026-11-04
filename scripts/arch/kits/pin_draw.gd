class_name PinDraw
extends RefCounted
## Hem's longbow draw (docs/heroes/archer.md, hero sheet pin.md): the reticle, the stages, the perfect
## release and the overdraw. ArcherKit owns one and forwards Hunter's draw hooks to it.
##
## - Stages (content/weapons/longbow.json "draw"): a tap shot before stage 1, Empowered at stage 1,
##   Supercharged at stage 2. A tap or Empowered shot lands at the cursor (clamped to its range); a
##   Supercharged shot flies its full range past the cursor (AimMode via h.shot_aim).
## - Reticle (world, own player; owner item 55b): a thin line to the cursor at rest. Drawing, a bright
##   fill grows out from Hem along that line like a progress bar (full at Supercharged), with a small circle
##   at each perfect-timing point; the circle flashes while the fill sits on it (the perfect window), and
##   releasing then is the perfect shot. The cursor charge ring fills over the whole draw. Supercharged
##   ready: the body flashes, a thick mint line runs past the cursor to the shot's full range, the first
##   foe under it ringed at the feet. Overdrawn: it dims to a thin pale line.
## - Perfect release: let go within perfect_t of a stage coming up: the next draw runs quick_k faster
##   until its stage 1 (no extra damage), a brief gold fletch burst with a ring at the bow hand.
## - Overdraw: held overdraw_t past the last stage, the arrow does overdraw_k of its damage.

const LINE_A := 0.35           # the faint resting aim line's strength
const FILL_START := 0.6        # m ahead of Hem where the filling line begins
const MIN_LEN := 2.5           # m: the shortest the filling line runs, so its circles stay apart
const SUPER_COL := Color("a8ffe0")
const STAGE_COL := Color("e6ffd0")
## the feather barbs on her draw lines (m at the bow end)
const FLETCH := 0.22
const TGT_COL := Color("d8ff6a")

var k: ArcherKit
var h: Hunter
var was := -1.0                # last step's draw time
var quick := false             # a perfect release: the next draw is faster until stage 1
var quick_used := false        # (checks) the draw now running was a quick one
var perfects := 0
var overdraws := 0
var supers := 0
var last_kind := ""            # the kind of the last arrow loosed: tap, arrow, super, over
var pending := ""              # the kind the next shot of ours gets skinned as
var tgt: Ent = null            # the foe under the Supercharged line
var perfect_now := false       # the arrow just loosed was a perfect release (its own move)
var loosed_at := -9.0          # match time the last arrow left the string (a cancelled draw loosed nothing)

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h

func wpn_draw() -> Array:
	return h.wpn.get("draw", [])

## The draw time each stage comes up [stage 1, stage 2].
func stage_t() -> Vector2:
	var st := wpn_draw()
	if st.is_empty():
		return Vector2(0.6, 1.15)
	return Vector2(float((st[0] as Array)[0]), float((st[-1] as Array)[0]))

func perfect_t() -> float:
	return float(k.res_def().get("perfect_t", 0.15))

func over_t() -> float:
	return stage_t().y + float(h.wpn.get("overdraw_t", 0.5))

## Hunter.trigger scales the draw by this: faster after a perfect release, until stage 1.
func rate() -> float:
	if quick and h.draw_t >= 0.0 and h.draw_t < stage_t().x:
		quick_used = true
		return float(h.wpn.get("quick_k", 1.6))
	return 1.0

## Hunter._loose asks once per arrow: where it goes (h.shot_aim) and its damage factor.
func bonus(t: float) -> float:
	var s := stage_t()
	var pt := perfect_t()
	loosed_at = k.m.time
	quick = false
	quick_used = false
	perfect_now = false
	var kind := "tap"
	if t >= s.y: kind = "super"
	elif t >= s.x: kind = "arrow"
	var f := 1.0
	if t > over_t():
		kind = "over"
		overdraws += 1
		f = float(h.wpn.get("overdraw_k", 0.5))
	h.shot_aim = AimMode.MAX if kind in ["super", "over"] else AimMode.CURSOR
	pending = kind
	last_kind = kind
	if kind == "super": supers += 1
	if (t >= s.x and t <= s.x + pt) or (t >= s.y and t <= s.y + pt):
		_perfect()
	return f

func _perfect() -> void:
	perfects += 1
	quick = true
	perfect_now = true
	var d := h.aim_dir()
	k.fx.fletch_burst(bow_at(), 1.1, PinFx.GOLD, 0.13, 0.07, 1.0)
	AimKit.perfect(h)
	k.m.sfx("pin_perfect", h.pos, -3.0 if h.is_local() else -8.0, 1.25)

func _sc() -> float:
	return float(h.cdat.get("scale", 1.0))

## Where the draw cues sit: on the aim line just ahead of her, low (the camera looks down, so anything held
## up at the bow hand would show beside the line instead of on it).
func bow_at() -> Vector3:
	var d := h.aim_dir()
	return h.pos + Vector3(d.x * 0.9, 0.25 * _sc(), d.y * 0.9)

## Every step: the stage tells, the reticle, the bow's own moves.
func tick() -> void:
	var t := h.draw_t
	var drawing := t >= 0.0 and h.wpn.has("draw")
	var s := stage_t()
	var col := Color(String(k.d.get("color", "#9fe0a8")))
	if h.wpn.has("draw") and not drawing and k.tells_visible() and h.can_fire():
		AimKit.line(h, "draw_rest", {"alpha": LINE_A, "col": col, "fletch": FLETCH * 0.6})
	if drawing:
		if was < s.x and t >= s.x:
			k.m.sfx("pin_stage", h.pos, -6.0 if h.is_local() else -10.0)
			k.fx.fletch_burst(bow_at(), 0.8, PinFx.GREEN, 0.05, 0.1, 0.0, 5.0)
			AimKit.flare(h, {"col2": STAGE_COL})
		if was < s.y and t >= s.y:
			k.m.sfx("pin_super", h.pos, -3.0 if h.is_local() else -7.0)
			h.flash_t = 0.12           # the whole body flashes once
			k.fx.fletch_burst(bow_at(), 1.0, SUPER_COL, 0.06, 0.12, 0.6, 5.0)
			AimKit.flare(h, {"col2": SUPER_COL})
			k.net_ring(h.pos, 1.3, k.res_col())
		if was < over_t() and t >= over_t():
			k.m.sfx("pin_overdraw", h.pos, -10.0, 0.9)
			k.play("arc_over")
		_reticle(t, s, col)
	elif was >= 0.0:
		k.fx.bow_glint_at(Vector3.ZERO, 0.0, col)
		tgt = null
	if drawing and was < 0.0:
		k.play("arc_draw")
		k.m.sfx("pin_draw", h.pos, -9.0 if h.is_local() else -13.0)
	elif drawing and k.anim_id == "arc_draw":
		k.anim_at = k.m.time - t           # the pull-back runs on the draw's clock (a quick draw too)
	elif not drawing and was >= 0.0 and k.anim_id in ["arc_draw", "arc_over"]:
		if k.m.time - loosed_at > 0.1:
			k.anim_id = ""                 # the draw was cancelled (a stun, a dash): nothing left the string
			was = t
			return
		k.play(release_move())
		var loose_sfx := "pin_loose_super" if last_kind == "super" else "pin_loose"
		k.m.sfx(loose_sfx, h.pos, -3.0 if h.is_local() else -7.0)
	was = t

## Each release has its own move: a tap's snap, Empowered's loose, Supercharged's kick, a perfect's
## flourish, an overdrawn droop.
func release_move() -> String:
	if perfect_now:
		return "arc_perfect"
	return {
		"tap": "arc_tap",
		"arrow": "arc_loose",
		"super": "arc_super",
		"over": "arc_over_loose"
	}.get(last_kind, "arc_loose")

func _reticle(t: float, s: Vector2, col: Color) -> void:
	AimKit.charge(h, clampf(t / s.y, 0.0, 1.0), {"col": col, "flare": false})
	AimKit.hide(h, "draw_rest")
	var pt := perfect_t()
	var d := h.aim_dir()
	var o := h.pos + Vector3(d.x, 0, d.y) * FILL_START
	var cur := cursor_len()
	if t < s.y:
		# the filling line: the faint line to the cursor, a bright fill growing out from Hem over the draw,
		# a small circle at each perfect-timing point that flashes while the fill sits on it
		var faint := {"from": o, "len": cur, "col": col, "alpha": LINE_A, "lw": 0.03, "arrow": false}
		AimKit.line(h, "draw", faint)
		var f := fill_frac(t)
		var bright := {"from": o, "len": maxf(0.05, cur * f), "col": col, "hot": 0.7, "lw": 0.09, "alpha": 1.3}
		bright["fletch"] = FLETCH * 0.8
		bright["arrow"] = false
		AimKit.line(h, "draw_fill", bright)
		var m1 := s.x / s.y
		if t <= s.x + pt:
			_mark("draw_mark", o, d, cur * m1, t >= s.x, col)
		else:
			AimKit.hide(h, "draw_mark")
		_mark("draw_mark2", o, d, cur, false, col)
		k.fx.bow_glint_at(bow_at(), 0.55 if t >= s.x else 0.0, PinFx.GREEN)
		tgt = null
		return
	# Supercharged: the thick white line to max range (dims once overdrawn); the fill is full
	AimKit.hide(h, "draw_fill")
	AimKit.hide(h, "draw_mark")
	var over := t > over_t()
	var rng := float((wpn_draw()[-1] as Array)[2]) if not wpn_draw().is_empty() else 16.0
	AimKit.line(
		h,
		"draw",
		{
			"len": rng,
			"col": SUPER_COL if not over else Color("9fb8a0"),
			"lw": 0.03 if over else 0.09,
			"hot": 0.0 if over else 0.25,
			"alpha": 0.45 if over else 1.3,
			"fletch": FLETCH * (0.5 if over else 1.3)
		}
	)
	if over:
		AimKit.hide(h, "draw_mark2")
	else:
		_mark("draw_mark2", o, d, cur, t <= s.y + pt, SUPER_COL)
	k.fx.bow_glint_at(bow_at() + Vector3(0, 0.05, 0), 0.3 if over else 1.0, SUPER_COL)
	tgt = _under_line(rng)
	if tgt != null and not over:
		AimKit.circle(h, "draw_tgt", {"at": tgt.pos, "r": 0.85, "col": TGT_COL, "hot": 0.5})

## How far along the draw's fill is (0..1 over the whole draw to Supercharged).
func fill_frac(t: float) -> float:
	return clampf(t / stage_t().y, 0.0, 1.0)

## Where along the line the perfect-timing circle for a stage sits (0..1, the same scale as fill_frac).
func mark_frac(stage: int) -> float:
	var s := stage_t()
	return s.x / s.y if stage == 1 else 1.0

## The filling line's length: out to the cursor (clamped to the Empowered range), never shorter than MIN_LEN.
func cursor_len() -> float:
	var rng1 := float((wpn_draw()[0] as Array)[2]) if not wpn_draw().is_empty() else 12.0
	var o := h.pos + Vector3(h.aim_dir().x, 0, h.aim_dir().y) * FILL_START
	return maxf(MIN_LEN, AimMode.point(h, rng1).distance_to(o))

## A small perfect-timing circle `at` m out along the line; `lit` flashes it (the fill just reached it).
func _mark(id: String, o: Vector3, d: Vector2, at: float, lit: bool, col: Color) -> void:
	var p := o + Vector3(d.x, 0, d.y) * at
	var r := 0.22
	var hot := 0.15
	var fill := -1.0
	if lit:
		r = 0.36
		hot = 1.0
		fill = 1.0
	AimKit.circle(h, id, {"at": p, "r": r, "col": col, "hot": hot, "fill": fill, "star": lit})

## The first foe under the aim line within reach (the Supercharged target highlight).
func _under_line(rng: float) -> Ent:
	var best: Ent = null
	var bd := 1e9
	var d := h.aim_dir()
	for f in k.m.foes_of(h.team):
		if not f.hittable() or not AimMode.in_lane(h.pos, d, rng, 1.0, f.pos, f.r):
			continue
		var dd := h.flat_dist(f)
		if dd < bd:
			bd = dd
			best = f
	return best

## A merge (or any hold drop) ends the draw: the reticle goes, the quick draw stays banked.
func drop() -> void:
	was = -1.0
	tgt = null
	k.fx.bow_glint_at(Vector3.ZERO, 0.0, Color.WHITE)
