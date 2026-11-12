extends RefCounted
## Grimble's move timing against the footage (briefs/hero-ref/dredge.md, 5 fps: one frame = 0.2 s), for
## --dredge-combo-check (docs/heroes/dredge.md, "Animation timing"): measured in the match, press to hit frame to
## recovery, plus the .glb clips' lengths against the kit's keyed moves (the clip IS the visible hit frame).

const BH := 1.8                     # m per body height (the sheet's unit: 3.5 bh = the 6.3 m slug stop)
const FRAME := 0.2                  # s per footage frame

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	await _throw_and_reel()
	await _anchor()
	await _barge()
	await _barge_run()
	_clips()

## Abyssal Hand (0121-0129): the arm is out at full reach 0.4 s after the cast (~5 bh), then the pull takes ~1.0 s.
func _throw_and_reel() -> void:
	var r: Array = ak.setup("dredge", 5.0 * BH, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	T.face = PI / 2.0
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	var t: float = ak.DT
	var grab := -1.0
	var arrive := -1.0
	while t < 3.5 and arrive < 0.0:
		m.step(ak.DT)
		t += ak.DT
		if grab < 0.0 and not K.pull.is_empty():
			grab = t
		elif grab >= 0.0 and K.pull.is_empty():
			arrive = t
	var rdf := K.rmb_def()
	var want := float(rdf["windup"]) + 5.0 * BH / float(rdf["speed"])
	ok("timing throw: coil, then 5 bh at hook speed (slowed from the footage 0.4 s on purpose, owner 11-10)",
			grab > 0.0 and absf(grab - want) <= FRAME, "%.2f s, want %.2f" % [grab, want])
	ok("timing reel: a 5 bh pull takes about 1.0 s (footage 0124-0129)",
			arrive > 0.0 and absf(arrive - grab - 1.0) <= FRAME, "%.2f s" % (arrive - grab))
	await ak.done(m)

## Iron Smash (0221-0236): a hop up and about 1 bh forward, the hit at ~0.4 s, over by ~0.8 s.
func _anchor() -> void:
	var r: Array = ak.setup("dredge", 2.2, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	T.teleport(P.pos + Vector3(2.2, 0, 0))
	ak.aim_at(P, T.pos)
	var from := P.pos
	var hp0 := T.hp
	var anchors := K.anchors
	K.cd["e"] = 0.0
	K.use_e()
	var t := 0.0
	var hit := -1.0
	var hop := 0.0
	while t < 1.0 and hit < 0.0:
		m.step(ak.DT)
		t += ak.DT
		if K.anchors > anchors:
			hit = t
			hop = P.flat_dist(from)
	ok("timing anchor: the fist lands 0.4 s after the press (footage 0221-0223)",
			hit > 0.0 and absf(hit - 0.4) <= FRAME and T.hp < hp0, "%.2f s" % hit)
	ok("timing anchor: he hops about 1 bh forward before the slam (footage 0222)",
			hop >= 0.6 * BH and hop <= 1.4 * BH, "%.2f m (%.1f bh)" % [hop, hop / BH])
	await ak.done(m)

## Brute Dash (0188): about 2.5-3 bh in a frame or less, then a crouch and back on the aim within a frame.
func _barge() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	ak.aim_at(P, home + Vector3(0, 0, -6.0))
	var from := P.pos
	P.do_dash()
	var t := 0.0
	while P.roll_t > 0.0 and t < 1.0:
		m.step(ak.DT)
		t += ak.DT
	ok("timing barge: over inside one frame (0.2 s)", t > 0.0 and t <= FRAME, "%.2f s" % t)
	var far := P.flat_dist(from)
	ok("timing barge: short, 1.5-3 bh", far >= 1.5 * BH * 0.8 and far <= 3.0 * BH, "%.2f m" % far)
	await ak.done(m)

## Three shoves with the 0.22 s gap are one burst (owner): each joins the ball still rolling from the last (the move
## stays dr_lunge, restarted at the clip's closed pose), it opens (dr_lunge_out) the moment the last charge is spent,
## and a lone shove opens once the next press is too late.
func _barge_run() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: DredgeKit = P.ak
	ak.aim_at(P, r[4] + Vector3(0, 0, -6.0))
	P.dashes = 3.0
	var seeks: Array = []
	var held := true
	for i in 3:
		while m.time < K.next_barge:
			m.step(ak.DT)
			held = held and K.anim_id == "dr_lunge"
		P.do_dash()
		seeks.append(m.time - K.anim_at)
	var joined := absf(seeks[1] - K.FOLD_T) < 0.001 and absf(seeks[2] - K.FOLD_T) < 0.001 and seeks[0] < 0.001
	ok("barge run: shoves 2 and 3 join the ball at the clip's closed pose, no opening between",
			held and K.anim_id == "dr_lunge" and joined, "%s held %s" % [seeks, held])
	var t := 0.0
	while t < P.roll_t + 0.1 and K.anim_id != "dr_lunge_out":
		m.step(ak.DT)
		t += ak.DT
	ok("barge run: the ball opens as the last shove ends (no charge left)",
			K.anim_id == "dr_lunge_out" and t < 0.3, "%.2f s" % t)
	P.dashes = 3.0
	while m.time < K.next_barge + 0.2:
		m.step(ak.DT)
	P.do_dash()
	var gap := float(K.dash_def()["gap"])
	t = 0.0
	while t < 1.0 and K.anim_id != "dr_lunge_out":
		m.step(ak.DT)
		t += ak.DT
	var after := P.roll_t + gap
	ok("barge run: a lone shove stays closed through the gap, opens just after it",
			t >= after and t <= after + K.CHAIN_GRACE + 0.1, "%.2f s (gap %.2f)" % [t, gap])
	await ak.done(m)

## The clip in the .glb is what is drawn: each held-less move's clip lasts exactly the kit's keyed move, so the hit key
## (shot 0.05, anchor 0.38, lunge 0.18...) is the same instant in both.
func _clips() -> void:
	var glb := (load("res://art/wardens/dredge/dredge.glb") as PackedScene).instantiate()
	var player := glb.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var cfg: Dictionary = WardenClips.data("dredge")
	var off: Array = []
	for k in cfg["kmoves"]:
		var mv: Dictionary = cfg["kmoves"][k]
		if mv.has("hold_from") or not KMovesPair.MOVES.has(k):
			continue
		var keys: Array = KMovesPair.MOVES[k]["keys"]
		var kit_end := float((keys[-1] as Array)[0])
		var clip_end := player.get_animation(String(mv["clip"])).length
		if absf(clip_end - kit_end) > 0.03:
			off.append("%s %.2f/%.2f" % [k, clip_end, kit_end])
	ok("timing clips: every move's .glb clip lasts as long as the kit's keyed move", off.is_empty(), str(off))
	_ball_clip(player)
	glb.free()

## The ball holds closed at the clip's end exactly as at its fold-in (the pose a
## chained shove joins), and the recovery is quick.
func _ball_clip(player: AnimationPlayer) -> void:
	var lunge := player.get_animation("lunge")
	var out := player.get_animation("lunge_out")
	var worst := 0.0
	for tr in lunge.get_track_count():
		var spring := str(lunge.track_get_path(tr)).contains("spring_")
		if lunge.track_get_type(tr) == Animation.TYPE_ROTATION_3D and not spring:
			var from: Quaternion = lunge.rotation_track_interpolate(tr, DredgeKit.FOLD_T)
			worst = maxf(worst, from.angle_to(lunge.rotation_track_interpolate(tr, lunge.length)))
	ok("timing lunge clip: closed at the end as at 0.033 s (a chained shove joins it), the recovery under 0.25 s",
			worst < 0.05 and lunge.length >= 0.38 and out.length <= 0.25,
			"worst %.3f rad, %.2f / %.2f s" % [worst, lunge.length, out.length])
