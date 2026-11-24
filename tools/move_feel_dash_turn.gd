extends RefCounted
## --move-feel-check, the body and the shot through a ground dash, every Hunter (docs/MOVEMENT_FEEL.md "Dash facing
## and aim"). The cursor is held north and a tap dash goes where the keys point: east (a side dash) and south (back
## the way the cursor faces). Per Hunter, the body's angle off the cursor at the press, in the middle of the side
## dash, one step after it ends and 6 steps after it, the widest it turns away from the cursor in the back dash, and
## the direction of the first round (or swing) of an LMB pressed in the middle of the side dash and held.
## Source rule (briefs/hero-ref, venator.md:88-90 "he fires the rifle during the slide ... the upper body keeps
## aiming"; dredge.md:296 "he turns back to the aim within about 0.1 s after a dash"): a Hunter whose LMB fires in
## the dash keeps the body on the cursor; every other body turns along the dash at the source's yaw rate
## (RotationRate 1280 deg/s, 21 deg a step) and is back on the cursor 6 steps after it ends. A press that waits
## (buffer) goes out along the live cursor once the dash is over, never along the dash. Gil has no source hero:
## [?], the shared rule.

const DT := 1.0 / 60.0
const ON_AIM_DEG := 5.0  # the body or a round counts as on the cursor within this
const ALONG_DEG := 10.0  # the body counts as along the dash within this
const FAN_DEG := 25.0  # a round's widest miss of the cursor (the widest shotgun fan, the widest sway)
const SIDE_STEPS := 6  # steps after a side dash by which the body is back on the cursor (90 deg, 4.3 steps)
const BACK_STEPS := 9  # the same after a back dash (180 deg, 8.4 steps)
const SETTLE := 30  # steps standing on the cursor before the press
const FIRE_AT := 3  # the dash step the LMB goes down on (every dash lasts longer than this)
const RELEASE_AFTER := 40  # steps after the dash that a held LMB comes up (a charged or drawn shot goes then)
const MAX_STEPS := 200  # the dash, its buffered press and the first round
## Hunters with no source frame of a dash or an LMB through it (hero-ref has no hero for them).
const NO_SOURCE := {"gil": "our own Hunter, no source hero"}

var c  # the move-feel check (its hunter, match and rec/ok)
var hunter: Hunter


func _init(check) -> void:
	c = check
	hunter = check.p_v


func run() -> void:
	var cls_was := hunter.cls
	var arch_was := hunter.arch
	var wid_was := hunter.wid
	var worst_home := 0.0
	for id in Arch.ids():
		hunter.reclass(Arch.weight(id), id)
		var own := _probe(Vector2(1, 0), false, [])  # what the dash itself throws or swings, and where
		var side := _probe(Vector2(1, 0), true, own["events"])
		var back := _probe(Vector2(0, 1), false, [])
		var row := (
			"dash facing %-10s off cursor: press %.0f, mid %.0f, end+1 %.0f, end+%d %.0f deg; "
			% [id, side["start"], side["mid"], side["end1"], SIDE_STEPS, side["home"]]
		)
		row += (
			"back dash (%.0f deg off the cursor) turns %.0f deg; LMB mid-dash: %s"
			% [back["went"], back["widest"], _shot_text(side)]
		)
		if NO_SOURCE.has(id):
			row += " [?] " + String(NO_SOURCE[id])
		var mid_ok: bool = float(side["last"]) <= ON_AIM_DEG if side["aims"] else float(side["mid_along"]) <= ALONG_DEG
		var along_ok: bool = back["aims"] or float(back["widest"]) >= float(back["went"]) - ALONG_DEG
		var shot_ok: bool = float(side["shot"]) < 0.0 or float(side["shot"]) <= FAN_DEG
		var home_ok := float(side["home"]) <= ON_AIM_DEG and float(back["home"]) <= ON_AIM_DEG
		var ran_ok := float(side["dash_s"]) > 0.0 and float(back["dash_s"]) > 0.0
		c.ok(ran_ok and float(side["start"]) <= ON_AIM_DEG and mid_ok and along_ok and home_ok and shot_ok, row)
		worst_home = maxf(worst_home, maxf(float(side["home"]), float(back["home"])))
	c.rec("dash_back_on_cursor_deg", worst_home)
	hunter.reclass(cls_was, arch_was, wid_was)
	c._reset(c.flat)


func _shot_text(r: Dictionary) -> String:
	if float(r["shot"]) < 0.0:
		return "no round (own stream or lane, aimed by the cursor)"
	return "round %.1f deg off the cursor, %s the dash" % [r["shot"], "in" if r["shot_in_dash"] else "after"]


## Angle between the body and the cursor (north), degrees.
func _face_off() -> float:
	return absf(rad_to_deg(Vector2(-sin(hunter.face), -cos(hunter.face)).angle_to(Vector2(0, -1))))


func _in_dash() -> bool:
	return hunter.roll_t > 0.0 or (hunter.ak != null and hunter.ak.in_dash())


func _aim_north() -> void:
	hunter.inp["aim"] = hunter.pos + Vector3(0, 0.9, -8)


## A round of this Hunter made since the last look: its angle off the cursor, or -1. A swing's fan of rays counts as
## one round going along their mean.
func _new_round() -> float:
	var sum := Vector2.ZERO
	var swing = null
	var n := 0
	for s in c.m.shots:
		if s["by"] != hunter or s.has("_seen"):
			continue
		var tag = (s["x"] as Dictionary).get("swing")
		if n > 0 and (tag == null or tag != swing):
			continue
		swing = tag
		s["_seen"] = true
		sum += (s["vel"] as Vector2)
		n += 1
	return absf(rad_to_deg(sum.angle_to(Vector2(0, -1)))) if n > 0 else -1.0


## One tap dash along `dir` with the cursor north; `fire`: LMB down from FIRE_AT, up RELEASE_AFTER steps after the dash.
## `own`: the steps a round or swing already came on without the LMB (the dash's own), which are not the LMB's.
## {start, mid, end1 (deg off the cursor), last (the dash's final step), home (SIDE_STEPS or BACK_STEPS after the dash),
## widest (the most it turned off the cursor), went (the dash's own heading, off the cursor), mid_along (the body
## off that heading mid-dash), aims (the kit keeps the body on the cursor mid-dash), dash_s, shot (deg off the cursor,
## -1 none), shot_in_dash, events (the steps a round or swing came on)}.
func _probe(dir: Vector2, fire: bool, own: Array) -> Dictionary:
	c._reset(c.flat + (Vector3(-3, 0, 0) if dir.x > 0.0 else Vector3(0, 0, -3)))
	c._clear_mobs()
	_aim_north()
	c._steps(SETTLE)
	for s in c.m.shots:
		s["_seen"] = true  # (a round of the last Hunter still flying is not this one's)
	var r := {
		"aims": false,
		"dash_s": 0.0,
		"mid": 0.0,
		"end1": 0.0,
		"last": 0.0,
		"home": 0.0,
		"widest": 0.0,
		"went": 0.0,
		"mid_along": 0.0,
		"shot": -1.0,
		"shot_in_dash": false,
		"start": _face_off(),
		"events": []
	}
	var offs: Array = []
	var faces: Array = []
	var aims: Array = []
	var ended := -1
	var home_at := SIDE_STEPS if dir.x > 0.0 else BACK_STEPS
	var swing_was := hunter.swing_t
	var from := Vector2(hunter.pos.x, hunter.pos.z)
	var to := from
	hunter.inp["move"] = dir
	hunter.inp["dash"] = true
	hunter.inp["dash_down"] = true
	for i in MAX_STEPS:
		_aim_north()
		hunter.ammo = int(hunter.wpn.get("mag", 30))
		if fire and offs.size() == FIRE_AT:
			hunter.inp["fire"] = true
		if fire and ended >= 0 and i == ended + RELEASE_AFTER:
			hunter.inp["fire"] = false
		c.m.step(DT)
		hunter.inp["dash"] = false
		hunter.inp["dash_down"] = false
		var dashing := _in_dash()
		if dashing and ended < 0:
			offs.append(_face_off())
			faces.append(Vector2(-sin(hunter.face), -cos(hunter.face)))
			aims.append(hunter.ak != null and hunter.ak.aims_in_dash())
			to = Vector2(hunter.pos.x, hunter.pos.z)
			r["widest"] = maxf(float(r["widest"]), float(offs.back()))
		elif not offs.is_empty() and ended < 0:
			ended = i
			r["end1"] = _face_off()
		if ended >= 0 and i == ended + home_at:
			r["home"] = _face_off()
		var hit := _new_round()
		if hit < 0.0 and hunter.swing_t > swing_was + 0.0001:
			hit = _face_off()  # a swing goes along the body
		swing_was = hunter.swing_t
		if hit >= 0.0:
			(r["events"] as Array).append(i)
			if fire and offs.size() > FIRE_AT and float(r["shot"]) < 0.0 and not own.has(i):
				r["shot"] = hit
				r["shot_in_dash"] = dashing
		if ended >= 0 and i >= ended + home_at and (not fire or float(r["shot"]) >= 0.0):
			break
	r["dash_s"] = offs.size() * DT
	if not offs.is_empty():
		r["mid"] = offs[offs.size() / 2]
		r["last"] = offs.back()
		r["aims"] = aims[aims.size() / 2]
		var went := to - from
		if went.length() > 0.3:
			r["went"] = absf(rad_to_deg(went.angle_to(Vector2(0, -1))))
			r["mid_along"] = absf(rad_to_deg((faces[faces.size() / 2] as Vector2).angle_to(went)))
	hunter.inp["fire"] = false
	hunter.inp["move"] = Vector2.ZERO
	return r
