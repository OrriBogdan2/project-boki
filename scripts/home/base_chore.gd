class_name BaseChore
extends RefCounted
## The Chore state of base life (GARDEN.md section 4): a work knack (scripts/core/work.gd) becomes something a Boki
## does because of who it is, not a Job Board. Ember minds the egg in the Nook (the rest of its home hatch time
## halves, once per egg), Mend cheers up a glum friend (joy up) and Haul fetches the ball back to the toy spot.
## Watering waits for the snack patch. Save: Save.d["egg"]["minded"] is an optional key, no migration.
## BaseLife runs this from its machine: k["life_chore"] = {kind, ...}.
## Each chore ends with one journal line on the Boki, in the shape CareJournal.note writes (rec["journal"]).

const KINDS := {"ember": "mind", "mend": "cheer", "haul": "fetch"}      # knack -> chore
const GLUM_AT := 40.0       # joy need below which a Boki counts as glum
const CHEER_JOY := 18.0     # joy a cheered-up Boki gains
const CHEER_BOND := 0.05    # added to both Boki's bond when one cheers the other up
const AT_EGG := 1.3         # m: a Boki this close to the egg is minding it
const AT_BALL := 0.6        # m: close enough to pick up or put down the ball
const BALL_FAR := 4.5       # m: how far from the toy spot the ball lies
const HATCH_CUT := 0.5      # share of the egg's remaining home hatch time that is left after minding
const JOURNAL_KEEP := 20    # lines kept per Boki (CareJournal.KEEP)

## The chore this Boki would do now ("" for none): its best knack among Ember, Mend and Haul whose chore can run.
static func pick(life: BaseLife, k: Dictionary) -> String:
	for kn in Work.list(k["rec"]):
		var kind := String(KINDS.get(kn[0], ""))
		if kind != "" and can_do(life, k, kind):
			return kind
	return ""

static func can_do(life: BaseLife, k: Dictionary, kind: String) -> bool:
	match kind:
		"mind":
			var egg: Dictionary = Save.d.get("egg", {})
			return not egg.is_empty() and not egg.get("rare", false) and not egg.get("minded", false) \
				and not life.h._egg_ready() and is_instance_valid(life.h.nest)
		"cheer":
			return not glum(life, k).is_empty()
		"fetch":
			return not life.toys.is_empty()
	return false

## Starts the chosen chore: where it is going and what it carries.
static func begin(life: BaseLife, k: Dictionary, kind: String) -> void:
	var c := {"kind": kind}
	match kind:
		"mind":
			k["goal"] = life.h.nest.position
		"cheer":
			c["to"] = glum(life, k)
		"fetch":
			c["spot"] = life.toys[0]
			c["ball"] = _drop_ball(life, c["spot"])
			c["carry"] = false
	k["life_chore"] = c

static func tick(life: BaseLife, k: Dictionary, m: Fsm, dt: float) -> void:
	var c: Dictionary = k["life_chore"]
	var done := false
	match String(c["kind"]):
		"mind": done = _mind(life, k, m, dt)
		"cheer": done = _cheer(life, k, c)
		"fetch": done = _fetch(life, k, c)
	if done or m.since >= float(life.R["max"]["chore"]):
		m.go(BaseLife.S.ROAM, "%s done" % c["kind"] if done else "%s gave up" % c["kind"])

static func label(k: Dictionary) -> String:
	return String(k["life_chore"]["kind"]) if k.has("life_chore") else ""

## Leaving the state (done or called away): the ball goes, the chore is forgotten.
static func end(k: Dictionary) -> void:
	var ball = k.get("life_chore", {}).get("ball", null)
	if is_instance_valid(ball):
		(ball as Node).queue_free()
	k.erase("life_chore")

## A glum Boki on this one's island that the farm isn't driving: the glummest, or {} for none.
static func glum(life: BaseLife, k: Dictionary) -> Dictionary:
	var here: int = life.h.world.island_of(k["pos"].x, k["pos"].z)
	var best := {}
	var low := GLUM_AT
	for o in life.h.kins:
		var joy := Care.need(o["rec"], "joy")
		if o != k and joy < low and not BaseLife._taken(o) and not o.has("life_chore") \
				and life.h.world.island_of(o["pos"].x, o["pos"].z) == here:
			low = joy
			best = o
	return best

static func _mind(life: BaseLife, k: Dictionary, m: Fsm, dt: float) -> bool:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty() or egg.get("minded", false):
		return true
	var at: Vector3 = life.h.nest.position
	k["goal"] = at
	if Vector2(at.x - k["pos"].x, at.z - k["pos"].z).length() > AT_EGG:
		return false
	k["hop"] = float(k.get("hop", 0.0)) + dt * 4.0       # warms it, bobbing
	if m.since < float(life.R["chore_mind"]):
		return false
	var left := float(egg.get("t", 0.0)) - Time.get_unix_time_from_system()
	egg["t"] = float(egg["t"]) - maxf(0.0, left) * (1.0 - HATCH_CUT)
	egg["minded"] = true
	_note(k, "minded the egg: it hatches sooner")
	life.h._emote(k, "♥")
	return true

static func _cheer(life: BaseLife, k: Dictionary, c: Dictionary) -> bool:
	var to: Dictionary = c["to"]
	if BaseLife._taken(to) or Care.need(to["rec"], "joy") >= GLUM_AT:
		return true       # it cheered up already, or the farm has it
	k["goal"] = to["pos"]
	if BaseLife._dist(k, to) > AT_EGG:
		return false
	Care.change(to["rec"], "joy", CHEER_JOY)
	BaseLife.add_bond(k["rec"], to["rec"], CHEER_BOND)
	life.h._emote(k, "♥")
	life.h._emote(to, "♪")
	_note(k, "cheered up %s" % to["rec"]["name"])
	return true

static func _fetch(life: BaseLife, k: Dictionary, c: Dictionary) -> bool:
	var ball: Node3D = c["ball"]
	var pos: Vector3 = k["pos"]
	if not c["carry"]:
		k["goal"] = ball.position
		if Vector2(ball.position.x - pos.x, ball.position.z - pos.z).length() < AT_BALL:
			c["carry"] = true
		return false
	ball.position = pos + Vector3(0, 0.75, 0)
	var spot: Vector3 = c["spot"]
	k["goal"] = spot
	if Vector2(spot.x - pos.x, spot.z - pos.z).length() > AT_BALL:
		return false
	Care.change(k["rec"], "joy", 6.0)
	life.h._emote(k, "★")
	_note(k, "fetched the ball back")
	return true

## The ball lies BALL_FAR m from the toy spot, on ground.
static func _drop_ball(life: BaseLife, spot: Vector3) -> Node3D:
	var at: Vector3 = life.h.world.free_spot_near(spot + Vector3(BALL_FAR, 0, 0), [], 0.5)
	var ball := MeshInstance3D.new()
	ball.mesh = Models.sphere(0.16, 12)
	ball.material_override = Models.toon(Color("ff6a5a"))
	life.h.add_child(ball)
	ball.position = at + Vector3(0, 0.16, 0)
	return ball

static func _note(k: Dictionary, words: String) -> void:
	var rec: Dictionary = k["rec"]
	var lines: Array = rec.get("journal", [])
	lines.append({"t": Time.get_unix_time_from_system(), "words": words})
	if lines.size() > JOURNAL_KEEP:
		lines.pop_front()
	rec["journal"] = lines
