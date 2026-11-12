class_name MergeKit
extends RefCounted
## The ultimate of a merge (docs/decisions/0003, 0004). Created with the merge (KinMerge.cast), live once the
## transformation ends. Your own LMB, RMB, E and Shift stay yours (their augments are MergeAugment's); this is only
## R again: after a short lock (content/rules/merge_forms.json ult_lock_s) it fires the form's ultimate, a timeline of
## `beats` (ops and Effects) after a tell, which ends the merge and drains the Boki. A Boki without a form file has a
## basic burst. The merge calls tick() and press_ult().

var h: Hunter
var m: Match
var form: Dictionary
var fd: Dictionary                       # the form's data ({} for a Boki without a form file)
var live := false
var age := 0.0                           # seconds since the form went live
var ult: Dictionary = {}                 # the ultimate running: {t, done, r}
var rise: Dictionary = {}                # the ultimate's climb into the air: {base, h}
var anim_n := 0                          # counts plays, so the same pose twice in a row is a new play for other games
var anim_id := ""                        # the keyed pose playing on the hunter (MergeMoves)
var anim_at := -9.0

func _init(hunter: Hunter, f: Dictionary) -> void:
	h = hunter
	m = hunter.m
	form = f
	fd = f["def"]

static func of(hunter: Hunter) -> MergeKit:
	return hunter.merge_st.get("kit", null) if not hunter.merge_st.is_empty() else null

## Is the form live (a merge past its transformation)?
static func is_live(hunter: Hunter) -> bool:
	var k := of(hunter)
	return k != null and k.live

func start() -> void:
	live = true
	age = 0.0

## The merge ended.
func stop() -> void:
	live = false
	ult = {}
	rise = {}
	anim_id = ""

func ulting() -> bool:
	return not ult.is_empty()

func play(move: String) -> void:
	anim_id = move
	anim_n += 1          # (a repeat of the same pose still replays in other games, KinNet)
	anim_at = m.time

## A cast for the other games to see (Net event "mcast"): slot, where it was aimed, a radius and a time for tells.
func announce(slot: String, at := Vector3.INF, radius := 0.0, secs := 0.0) -> void:
	var t: Vector3 = h.inp.get("aim", h.pos) if at == Vector3.INF else at
	KinNet.event(m, "mcast", h, h.pos, "%s|%.1f|%.1f|%.1f|%.2f" % [slot, t.x, t.z, radius, secs])

# ------------------------------------------------------------------ the ultimate
func ult_def() -> Dictionary:
	if MergeForm.has_kit(form):
		return fd["r"]
	var fb: Dictionary = MergeForm.data()["fallback"]
	var b: Dictionary = fb["burst"]
	var w := float(fb["ult_s"])
	var col: String = (form["glow"] as Color).to_html(false)
	return {"name": "Burst", "icon": "burst", "end": w + 0.25, "range": 0.0, "bot_range": float(b["radius"]), "desc": "The merge bursts outward and ends.",
		"beats": [{"at": 0.0, "effects": [{"type": "telegraph", "at": "self", "radius": float(b["radius"]), "time": w, "color": col}]},
			{"at": w, "effects": [{"type": "area", "at": "self", "radius": float(b["radius"]), "dmg": float(b["dmg"]), "kb": float(b["kb"]), "color": col}]}]}

func lock_left() -> float:
	return maxf(0.0, float(MergeForm.data()["ult_lock_s"]) - age)

func ult_text() -> String:
	if ulting() or not live:
		return ""
	if lock_left() > 0.0:
		return "%s ready in %.1fs" % [String(ult_def()["name"]), lock_left()]
	return ""

## R while merged: the ultimate, once the lock is over. It separates you when it lands.
func press_ult() -> bool:
	if not live or ulting() or lock_left() > 0.0 or h.downed or h.out or h.stun_t > 0.0 or h.dropping:
		return false
	var r := ult_def()
	ult = {"t": 0.0, "done": 0, "r": r}
	h.cast_at = m.time
	h.cast_slot = "ult"
	h.used["r"] = int(h.used.get("r", 0)) + 1
	var col: Color = form["glow"]
	m.fx.word(h.pos + Vector3(0, 3.0, 0), String(r["name"]).to_upper(), col, true)
	m.sfx("charge", h.pos, 0.0, 0.6)
	m.sfx("warn", h.pos, -4.0, 0.7)
	play("mf_ult")
	var tx: Vector3 = _ult_target(r)
	announce("ult", tx, _tell_radius(r), float(r.get("end", 1.0)))
	CombatBus.ability_used.emit(h, "%s_r" % form["id"], "ult")
	_run_beats()
	return true

func _ult_target(r: Dictionary) -> Vector3:
	var a: Vector3 = h.inp.get("aim", h.pos)
	var reach := float(r.get("range", 0.0))
	if reach > 0.0 and (r["beats"][0]["effects"][0] as Dictionary).get("type", "") == "leap":
		var d := Vector2(a.x - h.pos.x, a.z - h.pos.z)
		if d.length() > reach:
			d = d.normalized() * reach
		return Vector3(h.pos.x + d.x, h.pos.y, h.pos.z + d.y)
	return h.pos

func _tell_radius(r: Dictionary) -> float:
	var best := 0.0
	for b in r["beats"]:
		for e in (b as Dictionary).get("effects", []):
			var ed: Dictionary = e
			best = maxf(best, float(ed.get("radius", 0.0)))
			for e2 in ed.get("on_land", []):
				best = maxf(best, float((e2 as Dictionary).get("radius", 0.0)))
	return best

func _tick_ult(dt: float) -> void:
	ult["t"] = float(ult["t"]) + dt
	_run_beats()
	if float(ult["t"]) >= float((ult["r"] as Dictionary).get("end", 1.0)):
		KinMerge.end(h, "ult")

func _run_beats() -> void:
	var r: Dictionary = ult["r"]
	var beats: Array = r["beats"]
	while int(ult["done"]) < beats.size() and float((beats[int(ult["done"])] as Dictionary)["at"]) <= float(ult["t"]):
		var b: Dictionary = beats[int(ult["done"])]
		ult["done"] = int(ult["done"]) + 1
		match String(b.get("op", "")):
			"rise":
				rise = {"base": h.pos.y, "h": float(r.get("rise", 2.5))}
				h.grounded = false
				h.vel.y = 6.0
				h.roll_t = 0.0
			"crack":
				MergeXform.crack(h, form, float(b.get("time", 0.5)))
			"strike_all":
				_strike_all(b)
		if b.has("effects"):
			Effects.run(b["effects"], h, {"slot": "ult", "ability": "%s_ult" % form["id"], "level": 1, "reach": float(r.get("range", 0.0))})

## Thunderhead: one bolt from above on every foe in range.
func _strike_all(b: Dictionary) -> void:
	var col := Color(String(b.get("color", "#fff27a")))
	var rad := float(b.get("radius", 10.0))
	for f in m.foes_of(h.team):
		if not f.hittable() or f.flat_dist(h) > rad + f.r:
			continue
		m.fx.bolt(f.pos + Vector3(0, 8.0, 0), f.pos + Vector3(0, 0.8, 0), col)
		m.fx.flash(f.pos + Vector3(0, 0.9, 0), Color.WHITE, 1.3, 0.12)
		m.fx.ring(f.pos, 1.5, col, 0.3)
		f.hurt(float(b.get("dmg", 40.0)) * m.dmg_mult(h), h, {"src": "abil", "ab": "ult", "tags": ["ult", "strike"], "stun": float(b.get("stun", 0.0)), "dr": true})
	m.sfx("boom", h.pos, -1.0, 0.8)
	m.sfx("zap", h.pos, 0.0, 0.7)
	m.shake(0.6, h.pos)
	if h.is_local() and m.cam:
		m.cam.punch(0.1)

# ------------------------------------------------------------------ every step
func tick(dt: float) -> void:
	if not live:
		return
	age += dt
	if ulting():
		_tick_ult(dt)

# ------------------------------------------------------------------ the ultimate's climb
## Thunderhead rises into the air: the hunter's fall code asks (Hunter._physics).
static func rising(hunter: Hunter) -> bool:
	var k := of(hunter)
	return k != null and k.live and not k.rise.is_empty() and not hunter.grounded

## The vertical speed of the climb this step: up to the marked height and hold there.
static func rise_vy(hunter: Hunter) -> float:
	var k := of(hunter)
	return clampf((float(k.rise["base"]) + float(k.rise["h"]) - hunter.pos.y) * 6.0, -4.0, 6.0)

# ------------------------------------------------------------------ the hunter's views of it
## The HUD's R slot while merged: the ultimate. {} for any other slot (your own abilities are the hero's).
static func slot_info(hunter: Hunter, slot: String) -> Dictionary:
	var k := of(hunter)
	if k == null or not k.live or slot not in ["r", "ult"]:
		return {}
	return k.info()

func info() -> Dictionary:
	var r: Dictionary = ult_def()
	return {"name": r["name"], "short": r["name"], "icon": r.get("icon", "burst"), "desc": r.get("desc", ""), "cd": lock_left(), "cd_max": float(MergeForm.data()["ult_lock_s"]),
		"ready": lock_left() <= 0.0 and not ulting(), "form": form, "plan": "ult", "timer": float(h.merge_st.get("t", 0.0)), "timer_max": float(h.merge_st.get("T", 1.0)), "ulting": ulting(),
		"col": form["glow"], "charges": 0, "max_charges": 0, "verb": "", "level": 1}

## Hunter._anim_state: the keyed pose the form is playing (MergeMoves, through HunterAnim's kit-move channel).
## Other games read the pose id the owner syncs (KinNet) from the hunter's meta.
static func anim_state(hunter: Hunter, s: Dictionary) -> void:
	var id := ""
	var at := 0.0
	var k := of(hunter)
	if k != null:
		id = k.anim_id
		at = k.anim_at
	elif hunter.remote:
		id = String(hunter.get_meta("kpose", ""))
		at = float(hunter.get_meta("kpose_at", -9.0))
	if id.begins_with("mf_"):
		s["kmove"] = id
		s["kmove_t"] = hunter.m.time - at
	elif String(s.get("kmove", "")).begins_with("mf_"):
		s.erase("kmove")
		s.erase("kmove_t")

# ------------------------------------------------------------------ bots
## How a bot plays the window: the ultimate when foes are in its range or the window is about to close (its hero kit is the bot's usual play).
static func bot_use(hunter: Hunter) -> void:
	var k := of(hunter)
	if k == null or not k.live:
		return
	k.bot_think()

func bot_think() -> void:
	if ulting() or h.downed or h.out or h.stun_t > 0.0:
		return
	var reach := float(ult_def().get("bot_range", 8.0))
	var foes := 0
	for f in m.foes_of(h.team):
		if f.hittable() and f.flat_dist(h) <= reach:
			foes += 1
	var ending := float(h.merge_st.get("t", 99.0)) < float(MergeForm.data()["warn_s"]) * 0.5
	if lock_left() <= 0.0 and (foes > 0 or ending):
		press_ult()
