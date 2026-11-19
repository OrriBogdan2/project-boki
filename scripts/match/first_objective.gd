class_name FirstObjective
extends RefCounted
## "What to do now" on a save's first expedition (content/rules/first_objective.json): one short verb-first line
## that always names the next step, with a pin (or an arrow on the screen edge) on the thing it names:
##   find   a wild Boki  ->  knock   knock it out  ->  scan   hold the interact key beside it  ->  leave   the outpost
## "leave" runs the whole way out: go to the outpost, start the uplink, hold the yard, step into the lift.
## The step is read from the world every half second, so it follows a fight that goes another way (the Boki
## got away: back to "find"). Once a scan has landed, it stays on "leave". It is only drawn (ObjectiveTracker):
## it never pauses or blocks anything. It runs until the save has got out of one expedition (Save.d tutorial
## "first_objective"); a save that has caught a Boki before starts at "leave".
## Match owns one as `objective` (null when this match gets none) and calls tick().

const KEY := "first_objective"
const SKIP := ["tutorial", "duel", "arena", "training", "autoplay"]
const REPICK_S := 0.5      # s between looks at the world

var m: Match
var step := "find"
var target: Kin = null        # the wild Boki the first three steps name
var ticked := ""              # the line of the step just finished (shown under the current one)
var ticked_t := 0.0           # s left on it
var _captured := false
var _near := false            # inside rules "near" of the target (with a "far" margin before it lets go)
var _look := 0.0

static func rules() -> Dictionary:
	return Content.rules("first_objective")

## The objective for a match that is a real expedition and a save that has not got out of one yet, else null.
static func for_match(mt: Match, opts: Dictionary) -> FirstObjective:
	if SKIP.any(func(k: String) -> bool: return opts.get(k, false)) or bool(Save.d["tutorial"].get(KEY, false)):
		return null
	var o := FirstObjective.new()
	o.m = mt
	o._captured = int(Save.d["stats"].get("caught", 0)) > 0
	return o

## A save that has got out of an expedition is not taught: keyed by its own field, so it runs at load for any save.
static func migrate(data: Dictionary) -> void:
	var tut = data.get("tutorial")
	if typeof(tut) == TYPE_DICTIONARY and not tut.has(KEY) and int(data.get("extracts", 0)) > 0:
		tut[KEY] = true

func tick(dt: float) -> void:
	var p := m.player
	ticked_t = maxf(ticked_t - dt, 0.0)
	if p == null or p.out or p.dropping or p.riding:
		return
	if p.extracted:
		Save.d["tutorial"][KEY] = true
		return
	_look -= dt
	if _look > 0.0:
		return
	_look = REPICK_S
	_captured = _captured or not p.caught.is_empty()
	_pick(p)
	_advance(_read(p))

## Which of the four steps the world says it is.
func _read(p: Hunter) -> String:
	if _captured:
		return "leave"
	if target == null:
		return "find"
	if target.state == "dazed":
		return "scan"
	var d := p.flat_dist(target)
	_near = d < float(rules()["near"]) + (float(rules()["far"]) if _near else 0.0)
	return "knock" if _near else "find"

## A step finished (it moved on, not back): tick its line and chime.
func _advance(next: String) -> void:
	if next == step:
		return
	var steps := _lines()
	if steps.find(next) > steps.find(step) and m.hud != null:
		ticked = _row(step)[3]
		ticked_t = float(rules()["done_s"])
		TutorialStrip.chime(m)
	step = next

func _lines() -> Array:
	return (rules()["steps"] as Array).map(func(r: Array) -> String: return r[0])

func _row(id: String) -> Array:
	for r: Array in rules()["steps"]:
		if r[0] == id:
			return r
	return []

## The wild Boki to name: a knocked-out one first, then the nearest; the one already named stays until another
## is `keep` metres closer.
func _pick(p: Hunter) -> void:
	var best: Kin = null
	var best_score := INF
	var cur_score := INF
	for k: Kin in m.kins:
		if not is_instance_valid(k) or not k.is_wild() or k.dead or not _open(k):
			continue
		var score := p.flat_dist(k) - (60.0 if k.state == "dazed" else 0.0)
		if k == target:
			cur_score = score
		if score < best_score:
			best_score = score
			best = k
	if cur_score > best_score + float(rules()["keep"]):
		target = best
		_near = false
	elif cur_score == INF:
		target = best

func _open(k: Kin) -> bool:
	return k.state in ["wild", "dazed"] and not KinLoss.cradled(k)

## The outpost the "leave" step names: the squad's running uplink, else the Uplink seat's outpost, else {}.
func exit_spot() -> Dictionary:
	if m.exits == null:
		return {}
	var x := m.exits.active_for(m.player.team)
	return x if not x.is_empty() else m.exits.uplink_x()

## The line on the card.
func text() -> String:
	if step == "leave":
		return _leave_text()
	return String(_row(step)[1]).replace("%F", Settings.key_cap("interact"))

func _leave_text() -> String:
	var l: Dictionary = rules()["leave"]
	var x := exit_spot()
	var p := m.player
	var key := Settings.key_cap("interact")
	if x.is_empty():
		return String(l["go"])
	match String(x["state"]):
		"open":
			return String(l["lift"])
		"charging":
			if bool(x["contested"]):
				return String(l["contested"])
			var yard := m.exits.in_yard(x, p)
			return String(l["hold"]) % int(float(x["prog"]) * 100.0) if yard else String(l["back"])
	if m.time < float(x["open_at"]):
		return String(l["wait"]) % _clock(float(x["open_at"]) - m.time)
	if p.flat_dist(x["pos"]) < float(rules()["yard"]):
		return String(l["start"]).replace("%F", key)
	return String(l["go"])

static func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

## What the pin over the target says.
func label() -> String:
	return String(_row(step)[2])

## Where the pin goes: the wild Boki, or the outpost; Vector3.INF for none.
func target_pos() -> Vector3:
	if step == "leave":
		var x := exit_spot()
		return x["pos"] if not x.is_empty() else Vector3.INF
	return target.pos if target != null and is_instance_valid(target) else Vector3.INF

## Is the outpost's own waypoint (Hud._draw_exit_labels) already on the target? Then the pin stays off it.
func exit_pinned() -> bool:
	var x := exit_spot()
	return step == "leave" and not x.is_empty() and String(x["state"]) in ["charging", "open"]

## The index of the step on show, and how many there are (for the card's pips).
func progress() -> Vector2i:
	return Vector2i(_lines().find(step), _lines().size())
