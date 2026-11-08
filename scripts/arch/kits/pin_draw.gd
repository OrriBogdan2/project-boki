class_name PinDraw
extends RefCounted
## Hem's longbow draw (docs/heroes/archer.md, hero sheet pin.md): the reticle, the stages, the perfect
## release and the overdraw. ArcherKit owns one and forwards Hunter's draw hooks to it.
##
## - Stages (content/weapons/longbow.json "draw"): a tap shot before stage 1, Empowered at stage 1,
##   Supercharged at stage 2. A tap or Empowered shot lands at the cursor (clamped to its range); a
##   Supercharged shot flies its full range past the cursor (AimMode via h.shot_aim).
## - Reticle (world, own player; owner item 55b): a thin line to the cursor at rest. Drawing, a bright
##   fill grows out from Hem along that line like a progress bar (full at Supercharged), with one small
##   circle on the line at the next perfect point; it flashes gold when the fill reaches it and for the
##   perfect window, and releasing then is the perfect shot. Then it moves on to the end of the line for
##   Supercharged. Nothing else: no V, no glints, no cursor ring or other UI. Supercharged ready: the body
##   flashes, a thick white line runs past the cursor to the shot's full range, the first foe under it
##   ringed at the feet. Overdrawn: it dims to a thin pale line.
## - Perfect release: let go within the perfect window (tuning.json lace.perfect_window_s) of a stage coming
##   up: the next draw runs quick_k faster until its stage 1 (no extra damage), a brief gold fletch burst
##   with a ring at the bow. While the window is open her body and bow carry a gold rim glow (the toon
##   shaders' rim, set once on entry and put back on exit) with the stage's soft cue; a perfect release
##   pulses that rim harder for a moment (the payoff flash).
## - Overdraw: held overdraw_t past the last stage, the arrow does overdraw_k of its damage.

const LINE_A := 0.8            # the thin aim line's strength (a paler red, it has to show on grass at the match zoom)
const FILL_START := 0.6        # m ahead of Hem where the filling line begins
const MIN_LEN := 2.5           # m: the shortest the filling line runs, so a short aim still reads
const SUPER_COL := Color("fff6f0")
const FLASH_R := Vector2(0.5, 0.32)  # m: the circle's flash, as it pops and as it settles over the window
const MARK_R := 0.22           # m: the quiet circle
const REST_LW := 0.045        # m: the thin line under the fill
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
var glow_on := false           # the perfect window's rim glow is on her body and bow
var payoff_t := 0.0            # s left of the perfect release's rim pulse
var _rim0 := {}                # material -> [rim_amount, rim_color] before the glow, to put back

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
	return float(Tuning.of("lace")["perfect_window_s"])

## Is draw time t inside a stage's perfect window?
func in_window(t: float) -> bool:
	var s := stage_t()
	var pt := perfect_t()
	return (t >= s.x and t <= s.x + pt) or (t >= s.y and t <= s.y + pt)

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
	if in_window(t):
		_perfect()
	return f

func _perfect() -> void:
	perfects += 1
	quick = true
	perfect_now = true
	payoff_t = float(Tuning.of("lace")["perfect_payoff_s"])
	_rim(float(Tuning.of("lace")["perfect_payoff_rim"]))
	k.fx.fletch_burst(bow_at(), 1.1, PinFx.GOLD, 0.13, 0.07, 1.0)
	k.m.sfx("pin_perfect", h.pos, -3.0 if h.is_local() else -8.0, 1.25)

## The rim glow on her body and bow: on at `amount` (the toon rim, gold), off puts every material back.
## Set only when it changes (a render-server call per material).
func _rim(amount: float) -> void:
	var on := amount > 0.0
	if on and _rim0.is_empty():
		for mt in h.mats:
			if mt is ShaderMaterial:
				_rim0[mt] = [mt.get_shader_parameter("rim_amount"), mt.get_shader_parameter("rim_color")]
	for mt in _rim0:
		if not is_instance_valid(mt):
			continue
		mt.set_shader_parameter("rim_amount", amount if on else _rim0[mt][0])
		var gold := Color(String(Tuning.of("lace")["perfect_glow_col"]))
		mt.set_shader_parameter("rim_color", gold if on else _rim0[mt][1])
	glow_on = on
	if not on:
		_rim0.clear()

## The bow's nock point: the model's bow anchor (HeroVfx "bow_root", riding the bow bone), where the Heavy
## Shot and Starpiercer leave and where the bow's bursts sit.
func bow_at() -> Vector3:
	return HeroVfx.of(k.m).anchor_pos(h, "bow_root")

## Every step: the stage tells, the reticle, the bow's own moves.
func tick() -> void:
	var t := h.draw_t
	var drawing := t >= 0.0 and h.wpn.has("draw")
	var s := stage_t()
	var col := Color(String(k.d.get("color", "#e8483e")))
	if h.wpn.has("draw") and not drawing and k.tells_visible() and h.can_fire():
		AimKit.line(h, "draw_rest", {"from": line_start(), "alpha": LINE_A, "col": col.lightened(0.35), "lw": REST_LW})
	if drawing:
		if was < s.x and t >= s.x:
			k.m.sfx("pin_stage", h.pos, -6.0 if h.is_local() else -10.0)
		if was < s.y and t >= s.y:
			k.m.sfx("pin_super", h.pos, -3.0 if h.is_local() else -7.0)
			h.flash_t = 0.12           # the whole body flashes once
			k.net_ring(h.pos, 1.3, k.res_col())
		if was < over_t() and t >= over_t():
			k.m.sfx("pin_overdraw", h.pos, -10.0, 0.9)
			k.play("arc_over")
		_reticle(t, s, col)
	elif was >= 0.0:
		tgt = null
	_glow(t, drawing)
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

## The rim glow: on her body and bow only while a perfect window is open, then the payoff pulse after a
## perfect release runs out on its own.
func _glow(t: float, drawing: bool) -> void:
	if payoff_t > 0.0:
		payoff_t -= Match.DT
		if payoff_t <= 0.0:
			_rim(0.0)
		return
	var want := drawing and in_window(t)
	if want and not glow_on:
		_rim(float(Tuning.of("lace")["perfect_glow_rim"]))
	elif glow_on and not want:
		_rim(0.0)

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
	AimKit.hide(h, "draw_rest")
	var o := line_start()
	var d := h.aim_dir()
	var cur := cursor_len()
	if t < s.y:
		# the filling line: the faint line to the cursor with the bright fill growing out of Hem along it
		var thin := {"from": o, "len": cur, "col": col.lightened(0.35), "alpha": LINE_A, "lw": REST_LW}
		thin["arrow"] = false
		AimKit.line(h, "draw", thin)
		var bright := {"from": o, "len": maxf(0.05, cur * fill_frac(t)), "col": col, "lw": 0.16, "alpha": 1.4}
		bright["arrow"] = false
		AimKit.line(h, "draw_fill", bright)
		tgt = null
	else:
		# Supercharged: the thick white line to max range (dims once overdrawn); the fill is full
		AimKit.hide(h, "draw_fill")
		var over := t > over_t()
		var rng := float((wpn_draw()[-1] as Array)[2]) if not wpn_draw().is_empty() else 16.0
		var far := {"from": o, "len": rng - FILL_START, "col": SUPER_COL, "lw": 0.11, "hot": 0.25, "alpha": 1.3}
		if over:
			far.merge({"col": Color("e8d8d4"), "lw": 0.03, "hot": 0.0, "alpha": 0.55}, true)
		AimKit.line(h, "draw", far)
		tgt = _under_line(rng)
		if tgt != null and not over:
			AimKit.circle(h, "draw_tgt", {"at": tgt.pos, "r": 0.85, "col": TGT_COL, "hot": 0.5})
	_circle(t, s, o, d, cur, col)

## The one perfect-timing circle: on the next stage's point, flashing from the frame the fill reaches it
## to the end of that stage's perfect window. Past the last window there's nothing left to time.
func _circle(t: float, s: Vector2, o: Vector3, d: Vector2, cur: float, col: Color) -> void:
	var stage := mark_stage(t)
	if stage == 0:
		AimKit.hide(h, "draw_mark")
		return
	var p := o + Vector3(d.x, 0, d.y) * (cur * mark_frac(stage))
	var reached := s.x if stage == 1 else s.y
	if t < reached:
		AimKit.circle(h, "draw_mark", {"at": p, "r": MARK_R, "col": col, "hot": 0.15, "alpha": 1.3})
		return
	var r := lerpf(FLASH_R.x, FLASH_R.y, clampf((t - reached) / perfect_t(), 0.0, 1.0))
	AimKit.circle(h, "draw_mark", {"at": p, "r": r, "col": PinFx.GOLD, "hot": 1.0, "fill": 1.0, "alpha": 1.3})

## How far along the draw's fill is (0..1 over the whole draw to Supercharged).
func fill_frac(t: float) -> float:
	return clampf(t / stage_t().y, 0.0, 1.0)

## Where along the line the perfect-timing circle for a stage sits (0..1, the same scale as fill_frac).
func mark_frac(stage: int) -> float:
	var s := stage_t()
	return s.x / s.y if stage == 1 else 1.0

## Which stage's circle is up at draw time t: 1, then 2 once stage 1's perfect window has passed, 0 after both.
func mark_stage(t: float) -> int:
	var s := stage_t()
	if t <= s.x + perfect_t():
		return 1
	return 2 if t <= s.y + perfect_t() else 0

## Where the aim line starts: just ahead of Hem, so it reads as leaving her.
func line_start() -> Vector3:
	var d := h.aim_dir()
	return h.pos + Vector3(d.x, 0, d.y) * FILL_START

## The filling line's length: out to the cursor (clamped to the Empowered range), never shorter than MIN_LEN.
func cursor_len() -> float:
	var rng1 := float((wpn_draw()[0] as Array)[2]) if not wpn_draw().is_empty() else 12.0
	return maxf(MIN_LEN, AimMode.point(h, rng1).distance_to(line_start()))

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

## A merge (or any hold drop) ends the draw: the reticle and the glow go, the quick draw stays banked.
func drop() -> void:
	was = -1.0
	tgt = null
	payoff_t = 0.0
	_rim(0.0)
