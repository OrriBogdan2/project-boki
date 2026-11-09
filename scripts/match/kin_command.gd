class_name KinCommand
extends RefCounted
## The Boki commands (docs/decisions/0001, 0002): what G does for the player, and the ability cast for bots.
##   G tap   Boki out beside you: Sic, it leaps at the cursor (its landing staggers what it lands on).
##           Boki away (far, guarding, running back): Call back, it leaps to your side and hits what is on its path.
##           Boki on you (Return): it is thrown at the cursor as before.
##   G hold  the flick wheel (KinWheel): Chase, Guard, Return, Follow
##   The Boki casts its own ability by itself (KinTactics.think_abilities); bots press it through cast_c.
##   X       the Merge (KinMerge.press)
## A tap is judged on release (so a hold can be told apart); the press is polled each frame (poll),
## the result is queued in Match.pending_input and applied on the fixed step (tap); a wheel pick waits in
## h.inp["wheel_pick"] until apply_pick runs on the fixed step.
## Numbers: content/rules/boki_system.json.

static func rules() -> Dictionary:
	return Content.rules("boki_system")

## R runs the classes' own ultimate (ArchKit.use_r) instead of the Merge. Off: R is the Merge for every class.
static func class_ults() -> bool:
	return bool(rules().get("class_ults", false))

## The G key, polled every frame for the local player. Returns "tap" on the frame a short press is released,
## else "". A press held past g_hold_s opens the wheel (KinWheel), and letting go picks. `blocked`: a menu
## or map is up (the press is ignored).
static func poll(h: Hunter, dt: float, blocked: bool) -> String:
	if blocked or KinLoss.rescuing(h) != null:
		h.inp["g_t"] = 0.0; h.inp["g_fired"] = true      # swallow the rest of this press: no tap on release
		h.inp.erase("wheel")
		return ""
	var down := Input.is_action_pressed("throw")
	var t := float(h.inp.get("g_t", 0.0))
	var out := ""
	var mouse: Vector2 = h.get_viewport().get_mouse_position()
	if down:
		t += dt
		if t >= float(rules().get("g_hold_s", 0.35)) and not h.inp.get("g_fired", false):
			h.inp["g_fired"] = true
			if h.kin != null and (h.kin as Kin).ready_to_fight():
				KinWheel.open(h, mouse)
			elif h.kin != null:
				say(h, resting_text(h.kin) if (h.kin as Kin).resting() else "Your Boki can't take orders right now", Color("ffd89a"))     # (down, away or fused: not a silent swallow)
		if KinWheel.is_open(h):
			KinWheel.update(h, mouse, dt)
			h.inp["fire"] = false           # a flick is not a shot
	else:
		if KinWheel.is_open(h):
			h.inp["wheel_pick"] = KinWheel.close(h)
		elif t > 0.0 and not h.inp.get("g_fired", false):
			out = "tap"
		t = 0.0
		h.inp["g_fired"] = false
	h.inp["g_t"] = t
	return out

## 0..1: how far into a hold G is (for the HUD's fill ring before the wheel opens).
static func hold_frac(h: Hunter) -> float:
	if h.inp.get("g_fired", false):
		return 1.0
	return clampf(float(h.inp.get("g_t", 0.0)) / maxf(0.05, float(rules().get("g_hold_s", 0.35))), 0.0, 1.0)

## Is it far enough from you that a tap calls it back (else a tap sends it at the cursor)?
static func is_away(h: Hunter, k: Kin) -> bool:
	var d := k.flat_dist(h)
	return k.state == "returning" or d > float(rules()["follow"]["away_dist"]) or (k.cmd in ["guard", "chase"] and d > 4.0)

## Sent out or fighting something: a G tap now calls it back rather than sending it again.
static func is_engaged(k: Kin) -> bool:
	if bool(k.fly.get("sic", false)):
		return true
	return k.target != null and is_instance_valid(k.target) and not k.disengaged

## G tap toggles: beside you it goes (Sic at the cursor); out or fighting it comes back.
static func tap(h: Hunter) -> void:
	var k: Kin = h.kin
	if k == null or k.owner_h != h or h.downed or h.dropping or h.riding:
		return
	if k.resting():
		say(h, resting_text(k), Color("a2a8bb"))
		return
	if KinMerge.in_form(h):
		say(h, "%s is part of you while you are fused" % k.rec.get("name", "Your Boki"), Color("a2a8bb"))
		return
	if KinMerge.active(h) and not h.merge_st.get("surge", false):
		KinMerge.end(h, "throw")        # sending your Boki ends the merge, and it goes
	if k.state == "shoulder":
		if k.throw_cd > 0.0:
			return
		k.throw_to(h._ground_aim())
	elif k.state in ["active", "returning"]:
		if is_away(h, k) or is_engaged(k):
			call_back(h)          # out or fighting: G brings it back; tap again to send it
		elif k.throw_cd <= 0.0:
			k.throw_to(h._ground_aim())
	elif k.state == "downed":
		say(h, ("%s is down: run into it to pick it up" % k.rec.get("name", "Your Boki")) if not k.down_void else "%s fell: it will come round on its own" % k.rec.get("name", "Your Boki"), Color("ffb0a0"))

## Call back: it leaps to your side, hitting what is on its path. Only within the recall range.
static func call_back(h: Hunter) -> void:
	var k: Kin = h.kin
	if k.resting():
		return
	if k.flat_dist(h) > float(rules().get("recall_range", 24.0)):
		say(h, "Too far to call back: it will hop to you on its own", Color("a2a8bb"))
		h._ab_feedback("throw", "deny")
		return
	k.recall()

## The wheel pick, on the fixed step.
static func apply_pick(h: Hunter) -> void:
	var id := String(h.inp.get("wheel_pick", ""))
	if id == "":
		return
	h.inp.erase("wheel_pick")
	order(h, id)

## One of the four orders (the wheel, bots, tests). Returns false if it could not be given.
static func order(h: Hunter, id: String) -> bool:
	var k: Kin = h.kin
	if k == null or k.owner_h != h or h.downed or h.dropping or h.riding:
		return false
	if k.resting():
		say(h, resting_text(k), Color("a2a8bb"))
		return false
	if KinMerge.in_form(h):
		return false          # (merged with a form: your Boki is part of you, orders wait)
	var tgt: Ent = chase_pick(h) if id == "chase" else null
	if id == "chase" and tgt == null:
		say(h, "Nothing to chase", Color("a2a8bb"))
		return false
	if KinMerge.active(h) and not h.merge_st.get("surge", false) and id != "return":
		KinMerge.end(h, "order")
	var ok := KinFollow.set_cmd(k, id, tgt)
	if ok:
		if h.m.tut: h.m.tut.orders += 1
		var what := {"chase": "chasing %s" % target_name(tgt), "guard": "guarding this spot", "return": "back on you", "follow": "at your side"}
		say(h, "%s: %s" % [k.rec.get("name", "Your Boki"), what[id]], k.sp["color"])
		h.m.fx.ring(k.pos, 1.2, Color(k.sp["color"], 0.8), 0.3)
		h.m.sfx("kin_alert" if id in ["guard", "chase"] else "kin_happy", k.pos, -8.0, Unique.voice(k.rec))
	return ok

static func target_name(e: Ent) -> String:
	if e == null:
		return ""
	if e is Hunter:
		return (e as Hunter).pname
	if e is Mob:
		return String((e as Mob).md["name"])
	if e is Kin:
		return String(Data.KIN[(e as Kin).species]["name"])
	return "it"

## What Chase sticks to: the foe under the cursor, else the nearest one to you.
static func chase_pick(h: Hunter) -> Ent:
	var k: Kin = h.kin
	var aim: Vector3 = h.inp.get("aim", h.pos)
	var best: Ent = null
	var bd := 1e9
	for f in h.m.foes_of(h.team):
		if f.dead or not f.hittable() or (f is Hunter and f.downed) or Shrubling.hidden(f):
			continue
		if f.flat_dist(h) > float(rules()["follow"]["engage_range"]) * 2.0:
			continue
		var d := Vector2(f.pos.x - aim.x, f.pos.z - aim.z).length()
		if d < 3.0:
			d -= 100.0           # under the cursor wins over near you
		else:
			d = f.flat_dist(h)
		if d < bd:
			bd = d; best = f
	return best

## The Boki's own ability at the cursor, from wherever the Boki is. Out in the field it casts where
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

## The reason a cast did nothing, for a toast ("" if there is nothing to say).
static func c_deny_text(h: Hunter) -> String:
	var k: Kin = h.kin
	if k == null:
		return ""
	if k.resting():
		return resting_text(k)
	if k.state == "downed":
		return "%s is down: it can't cast" % k.rec.get("name", "Your Boki")
	return ""

## What a drained Boki says to any order (docs/decisions/0004).
static func resting_text(k: Kin) -> String:
	return "%s is resting: %ds" % [k.rec.get("name", "Your Boki"), int(ceil(k.rest_t))]

static func say(h: Hunter, text: String, col: Color) -> void:
	if h.is_local() and h.m.hud:
		h.m.hud.toast_small(text, col)

## Can a bot recall (the Boki is out and within range)?
static func can_recall(h: Hunter) -> bool:
	var k: Kin = h.kin
	return k != null and k.state in ["active", "returning"] and k.flat_dist(h) <= float(rules().get("recall_range", 24.0))
