class_name TutorialAim
extends RefCounted
## The tutorial's aimed-ability step (STEP: E on the line of monsters). A cast that strikes none of the group within
## AIM_WAIT, judged once its cooldown runs (a chain's starts when it lands), is a miss: the cooldown comes back and the
## miss line stands under the banner for ALERT_T, so the next try is at once. From the HELP_AFTER-th miss on, each
## miss also pings the ground under the group. A hit is the step's move done (Tutorial reads `hit`). A hero whose
## E strikes nothing (a heal, a wall: tutorial.json "kin_no_hit") counts any cast, as before.

const STEP := "kin"
const AIM_WAIT := 1.5        # s after the cast a hit on the group may still land (a shot's flight, a short delay)
const ALERT_T := 1.6         # s the miss line stands under the banner
const NAG_T := 0.6           # s the banner pulses on a miss
const HELP_AFTER := 3        # misses before the ground ping shows where the group is
const HELP_COL := Color(0.56, 0.89, 0.78)
const SEEN_LAG := 0.1        # s: a cast is seen a step or two after it went off (an instant hit lands before that)

var hit := false
var misses := 0
var alert_t := 0.0           # s left of the miss line
var wait := -1.0             # s left for the last cast to strike (< 0: no cast out)
var casts := 0               # E casts seen this step
var cast_at := -1.0
var hit_at := -9.0           # the last time you struck one of the group

func reset() -> void:
	hit = false
	misses = 0
	alert_t = 0.0
	wait = -1.0
	casts = 0

## Every step of the tutorial; `cast_n` is this step's E casts so far.
func update(tu: Tutorial, dt: float, cast_n: int) -> void:
	alert_t = maxf(0.0, alert_t - dt)
	if tu.id() != STEP or hit:
		return
	var p := tu.m.player
	if cast_n > casts:
		casts = cast_n
		cast_at = tu.m.time - SEEN_LAG
		wait = AIM_WAIT
		if p.ak == null or (Content.rules("tutorial")["kin_no_hit"] as Array).has(p.arch):
			hit = true
			return
	if casts > 0 and hit_at >= cast_at:
		hit = true          # (a hit from a two-step E's recast or a lasting zone counts too, even after the miss)
		return
	if wait < 0.0:
		return
	wait = maxf(0.0, wait - dt)
	if wait <= 0.0 and float(p.ak.cd["e"]) > 0.0:
		wait = -1.0
		_miss(tu)

## One of your hits landed on `target` (Tutorial.on_hit).
func on_hit(tu: Tutorial, target: Node) -> void:
	if tu.camps.has(target):
		hit_at = tu.m.time

## The miss line while it stands ("" when none).
func alert() -> String:
	return String(Content.rules("tutorial")["alt"]["kin_miss"]) if alert_t > 0.0 else ""

func _miss(tu: Tutorial) -> void:
	misses += 1
	tu.m.player.ak.cd["e"] = 0.0
	alert_t = ALERT_T
	tu.nag_t = NAG_T
	if misses >= HELP_AFTER:
		var mb := tu.camps.nearest()
		if mb: tu.m.ping(mb.pos, HELP_COL)
