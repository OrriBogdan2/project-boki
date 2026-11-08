extends RefCounted
## --drop-launch-check: owner item 163, the squad's rocket launch off the skyship (DropLaunch).
##  1. The squad leaves together: every member who jumps with the leader stays in formation (within
##     FORMATION_M) for the whole lock.
##  2. Keys are ignored for DropLaunch.LOCK_S: steering, jump (the glider), dash. Still diving, still flying the
##     launch's heading.
##  3. Separate is refused before SEPARATE_AFTER_S.
##  4. When the lock ends everyone breaks off on their own and their glider opens.
##  5. A Separate after SEPARATE_AFTER_S breaks that member off at once, glider open.
##  6. Drop-solo gate: Separate is refused for everyone aboard until the team drop is made (the leader has
##     jumped), allowed after, and a member who breaks off early and steers lands inside the glide reach.

const FORMATION_M := 9.0         # m: the widest drop slot and some slack
const HEADING_DOT := 0.95        # the launch keeps the ship's heading this closely, whatever the keys say

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("LAUNCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A squad match, the planning phase skipped, everyone still aboard.
func _start() -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242})
	m.set_process(false)
	for i in 30:
		m.step(Match.DT)
	if m.skydrop:
		m.skydrop.planning = false

func _squad(l: Hunter) -> Array:
	var out: Array = []
	for h in m.hunters:
		if h.team == l.team and h.riding:
			out.append(h)
	return out

func _launch() -> Hunter:
	var l: Hunter = m.skydrop.leader(m.player.team) if m.skydrop else m.player
	m.ship_jump(l, true)
	return l

func _locked_flight() -> void:
	await _start()
	ok(m.skydrop != null, "a squad match has a skyship drop")
	if m.skydrop == null:
		return
	var squad := _squad(m.skydrop.leader(m.player.team))
	var l := _launch()
	ok(squad.size() >= 2, "the squad jumps together (%d members)" % squad.size())
	var sd: Vector3 = m.ship_of(l).get("dir", Vector3.FORWARD)
	var head := Vector2(sd.x, sd.z).normalized()
	var P: Hunter = m.player
	var spread := 0.0
	var off_heading := 1.0
	var acted := false
	var refused := true
	var t := 0.0
	while t < DropLaunch.LOCK_S - 0.05:
		P.inp["move"] = Vector2(-head.y, head.x)       # hard sideways
		P.inp["jump"] = int(t / Match.DT) % 6 == 0
		P.inp["dash"] = int(t / Match.DT) % 9 == 0
		m.step(Match.DT)
		t += Match.DT
		for h: Hunter in squad:
			spread = maxf(spread, h.flat_dist(l))
		var hv := Vector2(P.vel.x, P.vel.z)
		if hv.length() > 1.0:
			off_heading = minf(off_heading, hv.normalized().dot(head))
		acted = acted or not P.diving or P.roll_t > 0.0
		if t < DropLaunch.SEPARATE_AFTER_S - 0.1:
			for h: Hunter in squad:
				if h != l and m.skydrop.separate(h):
					refused = false
	ok(spread <= FORMATION_M, "the squad stays together through the launch (widest %.1f m)" % spread)
	ok(not acted, "keys do nothing in the launch: still diving, no dash")
	ok(off_heading >= HEADING_DOT, "steering does nothing: it flies the ship's heading (dot %.3f)" % off_heading)
	ok(refused, "Separate is refused in the first %.1f s" % DropLaunch.SEPARATE_AFTER_S)
	_clear(P)
	for i in 12:
		m.step(Match.DT)
	var opened := true
	var solo := true
	for h: Hunter in squad:
		if h.dropping:
			opened = opened and not h.diving and h.launch_at < 0.0
			solo = solo and (h == l or h.drop_solo)
	ok(opened, "the lock over, every member's glider opens")
	ok(solo, "the lock over, everyone breaks off on their own")

func _early_separate() -> void:
	await _start()
	if m.skydrop == null:
		return
	var l := _launch()
	var f: Hunter = null
	for h: Hunter in m.hunters:
		if h.team == l.team and h != l and h.dropping:
			f = h
	ok(f != null, "a follower to break off")
	if f == null:
		return
	for i in int((DropLaunch.SEPARATE_AFTER_S + 0.1) / Match.DT):
		m.step(Match.DT)
	ok(m.skydrop.separate(f), "Separate works after %.1f s" % DropLaunch.SEPARATE_AFTER_S)
	m.step(Match.DT)
	m.step(Match.DT)
	ok(not DropLaunch.locked(f) and not f.diving, "a Separate breaks you off at once, glider open")

## Separate before the drop is refused (the player as follower, and a bot); after it, it works and the
## early solo glider comes down within the reach its height allows.
func _solo_gate() -> void:
	await _start()
	if m.skydrop == null:
		return
	var P: Hunter = m.player
	var bot: Hunter = null
	for h: Hunter in m.hunters:
		if h.team == P.team and h != P and h.ctrl == "bot":
			bot = h
	ok(bot != null, "a squad bot to lead the drop")
	if bot == null:
		return
	m.skydrop.leads[P.team] = bot
	ok(not m.skydrop.separate(P) and not P.drop_solo, "solo is refused before the drop (player)")
	ok(not m.skydrop.separate(bot, false), "solo is refused for the leader")
	m.ship_jump(bot)
	ok(bot.dropping and P.dropping, "the drop is made: the leader and the follower are out")
	ok(not m.skydrop.separate(P), "solo waits out the first %.1f s of the launch" % DropLaunch.SEPARATE_AFTER_S)
	for i in int((DropLaunch.SEPARATE_AFTER_S + 0.1) / Match.DT):
		m.step(Match.DT)
	ok(m.skydrop.separate(P) and P.drop_solo, "solo is allowed after the drop is made")
	var from := Vector2(P.pos.x, P.pos.z)
	var reach := maxf(0.0, (P.pos.y + 1.0) / Hunter.DROP_FALL * Hunter.DROP_SPEED)
	var t := 0.0
	while P.dropping and t < 40.0:
		P.inp["move"] = Vector2.LEFT
		m.step(Match.DT)
		t += Match.DT
	var went := from.distance_to(Vector2(P.pos.x, P.pos.z))
	var what := "the early solo lands %.0f m away, inside the %.0f m glide reach" % [went, reach]
	ok(not P.dropping and went <= reach + 1.0, what)

func _clear(h: Hunter) -> void:
	for k in ["jump", "dash", "glide", "glide_btn"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	await _locked_flight()
	await _early_separate()
	await _solo_gate()
	if m:
		m.queue_free()
	print("LAUNCH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
