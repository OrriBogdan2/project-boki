class_name KinCommand
extends RefCounted
## The Boki commands (docs/decisions/0001): what G and C do, for the player and for bots.
##   G tap   Boki on your shoulder: throw it to the cursor (it holds the spot it lands on, and its landing
##           staggers what it lands on). Boki out: recall it. It leaps back to you and hits anything on its path.
##           Recall only works within recall_range; further out it comes back on its own (leash).
##   G hold  toggle "hold the spot" / "follow & fight" (Kin.hold_mode, Kin.hold_at)
##   C       the Boki's own ability, cast from wherever the Boki is. On your shoulder it is cast through you.
##   R       the Merge (KinMerge.press)
## A tap is judged on release (so a hold can be told apart); the press is polled each frame (poll),
## the result is queued in Match.pending_input and applied on the fixed step (tap, toggle_mode).
## Numbers: content/rules/boki_system.json.

static func rules() -> Dictionary:
	return Content.rules("boki_system")

## R runs the classes' own ultimate (ArchKit.use_r) instead of the Merge. Off: R is the Merge for every class.
static func class_ults() -> bool:
	return bool(rules().get("class_ults", false))

## The G key, polled every frame for the local player. Returns "tap", "hold" on the frame it is decided,
## else "". `blocked`: a menu or map is up (the press is ignored).
static func poll(h: Hunter, dt: float, blocked: bool) -> String:
	if blocked:
		h.inp["g_t"] = 0.0; h.inp["g_fired"] = true      # swallow the rest of this press: no tap on release
		return ""
	var down := Input.is_action_pressed("throw")
	var t := float(h.inp.get("g_t", 0.0))
	var out := ""
	if down:
		t += dt
		if t >= float(rules().get("g_hold_s", 0.35)) and not h.inp.get("g_fired", false):
			h.inp["g_fired"] = true
			out = "hold"
	else:
		if t > 0.0 and not h.inp.get("g_fired", false):
			out = "tap"
		t = 0.0
		h.inp["g_fired"] = false
	h.inp["g_t"] = t
	return out

## 0..1: how far into a hold G is (for the HUD's fill ring).
static func hold_frac(h: Hunter) -> float:
	if h.inp.get("g_fired", false):
		return 1.0
	return clampf(float(h.inp.get("g_t", 0.0)) / maxf(0.05, float(rules().get("g_hold_s", 0.35))), 0.0, 1.0)

## G tap. Throw a shoulder Boki, recall one that is out.
static func tap(h: Hunter) -> void:
	var k: Kin = h.kin
	if k == null or h.downed or h.dropping or h.riding:
		return
	if KinMerge.active(h) and not h.merge_st.get("surge", false):
		KinMerge.end(h, "throw")        # throwing your Boki ends the merge, and it goes
	if k.state == "shoulder":
		if k.throw_cd > 0.0:
			return
		k.throw_to(h._ground_aim())
	elif k.state in ["active", "flying", "returning"]:
		if k.flat_dist(h) > float(rules().get("recall_range", 24.0)):
			say(h, "Too far to recall: it is coming back on its own", Color("a2a8bb"))
			h._ab_feedback("throw", "deny")
			return
		k.recall()
	elif k.state == "downed":
		say(h, ("%s is down: run into it to pick it up" % k.rec.get("name", "Your Boki")) if not k.down_void else "%s fell: it will come round on its own" % k.rec.get("name", "Your Boki"), Color("ffb0a0"))

## Hold G. "hold" (stay where thrown) or "follow" (fight beside you).
static func toggle_mode(h: Hunter) -> void:
	var k: Kin = h.kin
	if k == null or k.dead or k.state in ["downed", "bench", "away", "fused"]:
		return
	set_mode(k, "follow" if k.hold_mode == "hold" else "hold")
	say(h, "%s: %s" % [k.rec.get("name", "Your Boki"), "hold the spot" if k.hold_mode == "hold" else "follow & fight"], k.sp["color"])
	h.m.fx.ring(k.pos, 1.2, Color(k.sp["color"], 0.8), 0.3)
	h.m.sfx("kin_alert" if k.hold_mode == "hold" else "kin_happy", k.pos, -8.0, Unique.voice(k.rec))

static func set_mode(k: Kin, mode: String) -> void:
	k.hold_mode = mode
	if mode == "follow":
		k.hold_at = Vector3.INF
	elif k.state == "active" and k.hold_at == Vector3.INF:
		k.hold_at = k.pos

## C: the Boki's own ability at the cursor, from wherever the Boki is. Out in the field it casts where
## it stands (range-limited by the ability); on the shoulder (or merged) it is cast through you.
static func cast_c(h: Hunter) -> bool:
	var k: Kin = h.kin
	if k == null or h.downed or h.dropping or h.riding:
		return false
	if k.use_ability("k1", h._ground_aim()) or k.pend_slot == "k1":
		h.used["kin_ab"] = int(h.used.get("kin_ab", 0)) + 1
		h.m.fx.ring(k.pos, 1.3, KinText.color(k.runner.def_of("k1")), 0.3)
		return true
	return false

## The reason a C press did nothing, for a toast ("" if there is nothing to say).
static func c_deny_text(h: Hunter) -> String:
	var k: Kin = h.kin
	if k == null:
		return ""
	if k.state == "downed":
		return "%s is down: it can't cast" % k.rec.get("name", "Your Boki")
	return ""

static func say(h: Hunter, text: String, col: Color) -> void:
	if h.is_local() and h.m.hud:
		h.m.hud.toast_small(text, col)

## Can a bot recall (the Boki is out and within range)?
static func can_recall(h: Hunter) -> bool:
	var k: Kin = h.kin
	return k != null and k.state in ["active", "returning"] and k.flat_dist(h) <= float(rules().get("recall_range", 24.0))
