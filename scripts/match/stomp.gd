class_name Stomp
extends RefCounted
## The stomp (docs/decisions/0061-stomp-lock.md): holding interact on an enemy wisp for COMMIT starts
## a fixed TIME-long finisher. Stomper and wisp are locked to their spots for all of it; the stomper
## has no move, attack, ability or dodge and takes damage as usual. It ends one of three ways:
##   done    the time runs out: the wisp dies (executed)
##   broken  the stomper is stunned or hard-crowd-controlled (breaks()), or goes down: it stops at
##           once and the wisp lives
##   gone    the wisp stopped being a wisp some other way (revived, bled out)
## Online the stomper's game decides and sends ["stomp", stomper, wisp, "go" | why, style]; every game
## plays it, and the wisp's own game pins its wisp and, on "done", eliminates it.
## How it looks is the stomper's stomp style (StompLook); the timing is the same for every style.

const COMMIT := 0.2        # s: hold interact this long on an enemy wisp to start it (a tap never commits you)
const TIME := 3.0          # s, start to kill: Supervive's ~3 s execute (SUPERVIVE_DATA.md "Execute")
const BEATS := 3           # foot slams in TIME, one per beat
const SLAM := 0.8          # where in a beat the foot lands (0..1)
const NET_GRACE := 2.0     # s past TIME a stomp from another game may wait for its "done" before it's dropped here
const LOCKED_INPUTS := ["dash", "jump", "sig", "skill", "sec", "ult", "swap", "util1", "util2", "util3", "util4",
		"gear1", "gear2", "fire", "throw", "kin_ab"]

## Hard crowd control that breaks a stomp: a stun, a hex, or a real knock or launch. Plain damage and
## the small shove most hits carry don't (the stomper stays put through them).
static func breaks(h: Hunter) -> bool:
	return h.stun_t > 0.0 or Hex.active(h) or h.m.time - h.launched_at < Capture.LAUNCH_AGE

## Where the stomp is in beats (0..BEATS), -1 when not stomping: HunterAnim's "stomp".
static func beat(h: Hunter) -> float:
	return float(h.stomp["t"]) / (TIME / BEATS) if not h.stomp.is_empty() else -1.0

## Start stomping o. The stomper's own game calls it from the interact hold; "go" from the net too.
static func start(m: Match, h: Hunter, o: Hunter, style_id := "") -> void:
	var sid := style_id if style_id != "" or h.remote else StompLook.style_id(h)
	h.stomp = {"o": o, "t": 0.0, "at": h.pos, "o_at": o.pos, "style": sid}
	h.finish_t = 0.0
	o.set_meta("stomped_by", h)
	Life.trace(m, "stomp start %s on %s" % [h.pname, o.pname])
	m.fx.word(h.pos + Vector3(0, 2.3, 0), "STOMP", Color("ff8a6a"), false)
	StompSfx.commit(m, h)
	if o == m.player and m.hud:
		m.hud.toast("%s is stomping you! Only a stun on them saves you" % h.pname, Color("ff6a5a"))
	if m.net_on and not h.remote:
		m.net_event(["stomp", h.nid, o.nid, "go", sid])

static func end(m: Match, h: Hunter, why: String) -> void:
	if h.stomp.is_empty():
		return
	var o: Hunter = h.stomp["o"]
	h.stomp = {}
	if is_instance_valid(o) and o.has_meta("stomped_by") and o.get_meta("stomped_by") == h:
		o.remove_meta("stomped_by")
	Life.trace(m, "stomp end %s (%s)" % [h.pname, why])
	if m.net_on and not h.remote:
		m.net_event(["stomp", h.nid, o.nid if is_instance_valid(o) else "", why])
	if why == "broken":
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "INTERRUPTED", Color("cfeaff"), false)
		StompSfx.crack(m, h, o)
	elif why == "done" and is_instance_valid(o) and o.downed and not o.out:
		m.fx.burst(o.pos + Vector3(0, 0.8, 0), Color("ff6a5a"), 20, 4.0, 0.5, -3.0)
		StompSfx.crush(m, o)
		if not o.remote:
			m.eliminate(o, h, "executed")

## Mid-stomp none of the stomper's own buttons do anything; a wisp being stomped can't drift.
static func guard_inputs(h: Hunter) -> void:
	if not h.stomp.is_empty():
		for key in LOCKED_INPUTS:
			h.inp[key] = false
		h.inp["move"] = Vector2.ZERO
	elif h.downed and h.has_meta("stomped_by"):
		h.inp["move"] = Vector2.ZERO
		h.inp["dash"] = false

## Every frame, after the bodies moved: hold both to their spots, play the slams, and (on the
## stomper's own game) end it when it's broken, gone or done.
static func tick(m: Match, dt: float) -> void:
	for h in m.hunters:
		if h.stomp.is_empty():
			continue
		var o: Hunter = h.stomp["o"]
		if not h.remote: _pin(h, h.stomp["at"])
		if is_instance_valid(o) and not o.remote and o.downed: _pin(o, h.stomp["o_at"])
		var b0 := beat(h)
		h.stomp["t"] = float(h.stomp["t"]) + dt
		if fposmod(b0, 1.0) < SLAM and fposmod(beat(h), 1.0) >= SLAM:
			_slam(m, h, o)
		if h.remote:
			if float(h.stomp["t"]) > TIME + NET_GRACE: end(m, h, "gone")      # its game went quiet
			continue      # its own game says how it ends
		if h.downed or h.out or breaks(h):
			end(m, h, "broken")
		elif not is_instance_valid(o) or o.out or not o.downed:
			end(m, h, "gone")
		elif float(h.stomp["t"]) >= TIME:
			end(m, h, "done")

static func _pin(h: Hunter, at: Vector3) -> void:
	h.pos = at
	h.vel = Vector3.ZERO

static func _slam(m: Match, h: Hunter, o: Hunter) -> void:
	m.fx.dust(h.pos, 10)
	m.fx.ring(h.pos + Vector3(0, 0.05, 0), 1.2, Color(1, 0.8, 0.7, 0.6), 0.25)
	StompSfx.strike(m, h, int(beat(h)))
	if is_instance_valid(o):
		m.fx.burst(o.pos + Vector3(0, 0.5, 0), Color("ff6a5a"), 10, 3.0, 0.5, -4.0)

## ["stomp", stomper, wisp, "go" | why, style] from the stomper's game.
static func net_in(m: Match, x: Array) -> void:
	if x.size() < 4:
		return
	var h := m.ents_by_id.get(String(x[1]), null) as Hunter
	if h == null or not h.remote:
		return
	if String(x[3]) != "go":
		end(m, h, String(x[3]))
		return
	var o := m.ents_by_id.get(String(x[2]), null) as Hunter
	if o and o.downed and not o.out:
		start(m, h, o, String(x[4]) if x.size() > 4 else "")
