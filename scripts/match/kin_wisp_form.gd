class_name KinWispForm
extends RefCounted
## While its Hunter is down, a Boki comes back to them and rides as its wisp (docs/decisions/0019).
## Kin state "wisp":
##   - the moment its Hunter is knocked, every Boki of theirs that is up (on the shoulder, out fighting, in
##     the air) zips back to them; from farther than ZIP_RANGE, or a Boki the way is blocked for, it blinks
##     straight there (a puff where it was)
##   - it circles the Hunter Wisp as a small Boki wisp (BokiWispLook: critter outline, round = Hunter): it
##     does not attack, cast or take orders, and nothing can hit or target it (Kin.hittable)
##   - after a short wait (loyal, trusting Boki sooner) it pulls its Hunter up over Life.R kin_revive_time,
##     and the bleed-out pauses while it does; an enemy on the Wisp (the stomp) stops the pull
##   - revived: it pops back onto the shoulder with its old order. Bled out or finished: the Hunter's death
##     rules take it from there (Life.kin_on_death -> KinLoss)
## A downed Boki stays down where it fell (KinDowned) and joins once it comes round. Remote Boki show the
## state their owner's game sends (Kin state "wisp", Match.KIN_STATES).

const STATE := "wisp"
const JOINS := ["shoulder", "active", "flying", "flying_home", "returning"]   # states a Boki leaves to ride as a wisp
const ZIP_S := 0.3           # s: the flight back to its Hunter
const ZIP_RANGE := 14.0      # m: farther (or out of walking reach), it blinks there instead
const ORBIT_R := 0.75        # m from the Hunter Wisp's centre
const ORBIT_UP := 0.95       # m over the Hunter's feet: shoulder height, above the low Hunter Wisp
const ORBIT_HZ := 0.35       # turns per second round the Hunter
const POP_RING := 0.6        # m: the little ring where it lands or leaves
const SIZE := 1.5            # the Boki wisp's scale in a match (BokiWispLook builds it gallery-sized)

## A Boki of a downed Hunter that should be riding as their wisp but is not yet.
static func wants(k: Kin) -> bool:
	var h := k.owner_h
	return h != null and h.downed and not h.out and not k.dead and k.state in JOINS

## Leaves whatever it was doing and comes back to its Hunter.
static func join(k: Kin) -> void:
	var h := k.owner_h
	var far := k.flat_dist(h) > ZIP_RANGE or not k.walkable_to(h.pos)
	var on_you := k.state == "shoulder" and not k.beside
	if not on_you:
		k.m.fx.burst(k.pos + Vector3(0, 0.4, 0), k.sp["color"], 8, 2.5, 0.35)
	k.set_meta("wisp_cmd", k.cmd)
	k.set_meta("wisp_from", k.pos if not (far or on_you) else Vector3.INF)
	k.set_meta("wisp_t", 0.0)
	k.state = STATE
	k.target = null
	k.chase_target = null
	k.fly = {}
	k.hold_at = Vector3.INF
	k.pend_skill = Vector3.INF
	k.pend_slot = ""
	k.hesitate_t = 0.0
	k.hesitate_to = Vector3.INF
	k.vel = Vector3.ZERO
	k.beside = false
	# loyal Boki start pulling sooner, one that doesn't trust you takes a moment
	k.revive_wait = 0.1 + (1.0 - k.t("loyalty")) * 1.2 + (1.0 - k.trust / 100.0) * 1.8
	k.bark("revive")
	_place(k, 1.0)

## Every step while it rides as a wisp (local Boki only).
static func tick(k: Kin, dt: float) -> void:
	var h := k.owner_h
	if h == null or h.out or h.extracted:
		return                   # (the death rules move it on: KinLoss)
	if not h.downed:
		leave(k)
		return
	var zt := float(k.get_meta("wisp_t", 0.0)) + dt
	k.set_meta("wisp_t", zt)
	_place(k, clampf(zt / ZIP_S, 0.0, 1.0))
	_pull_up(k, h, dt)

## Its Hunter is back up: onto the shoulder with the order it had.
static func leave(k: Kin) -> void:
	k.state = "shoulder"
	k.settle = 1.0
	k.cmd = String(k.get_meta("wisp_cmd", "follow"))
	k.revive_wait = 0.0
	k.m.fx.ring(k.pos, POP_RING, Color(k.sp["color"], 0.8), 0.25)

## Pulling its Hunter up now (the bleed-out pauses while it does)?
static func pulling(k: Kin) -> bool:
	return k.state == STATE and k.revive_wait <= 0.0 and k.hp > 0.0 and k.owner_h != null \
		and not k.owner_h.get_meta("stomped", false)

## Where it circles: its own side of the Hunter (a second Boki rides opposite the first).
static func orbit_at(k: Kin) -> Vector3:
	var h := k.owner_h
	var a: float = k.m.time * TAU * ORBIT_HZ + (PI if h.kin2 == k else 0.0)
	return h.pos + Vector3(cos(a) * ORBIT_R, ORBIT_UP, sin(a) * ORBIT_R)

static func _place(k: Kin, zip: float) -> void:
	var to := orbit_at(k)
	var from := k.get_meta("wisp_from", Vector3.INF) as Vector3
	k.pos = to if from == Vector3.INF or zip >= 1.0 else from.lerp(to, 1.0 - pow(1.0 - zip, 3.0))
	k.prev = k.pos
	k.grounded = false

static func _pull_up(k: Kin, h: Hunter, dt: float) -> void:
	if k.hp <= 0.0 or h.get_meta("stomped", false):
		return                   # an enemy on the Wisp stops the pull
	k.revive_wait -= dt
	if k.revive_wait > 0.0:
		return
	h.revive += dt / Life.R["kin_revive_time"] * (0.8 + k.trust / 100.0 * 0.4)
	if h.revive >= 1.0:
		k.m.revive_hunter(h, k)
		k.note("revived", "pulled you back up when you were down", 4.0)

# ------------------------------------------------------------------ the picture
## Draws it as its wisp while in the state (the Boki model hidden); true when it did. Back in any other
## state, the wisp node goes and the model comes back.
static func render(k: Kin, model: Node3D) -> bool:
	var node := k.get_node_or_null("FormWisp") as Node3D
	if k.state != STATE:
		if node:
			node.queue_free()
			node.name = "FormWispGone"
			model.visible = true
		return false
	if node == null:
		node = BokiWispLook.build(k.species, k.rec)
		node.name = "FormWisp"          # (a Boki riding as a wisp all match has its model named BokiWisp)
		node.scale = Vector3.ONE * SIZE
		k.add_child(node)
	model.visible = false
	if k.ring:
		k.ring.visible = false
	node.visible = k.visible and not k.unseen
	BokiWispLook.pose(node, k.m.time)
	return true
