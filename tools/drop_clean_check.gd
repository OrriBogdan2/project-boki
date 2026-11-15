extends RefCounted
## --drop-clean-check: the drop is quiet and the bars wait for the jump.
##  1. Aboard the sky ship nobody (own squad or rivals, near or far) gets a plate; a hunter's is back once they jump.
##  2. From the ship to the glide no big ring is spawned (a squadmate's Boki cast Echolocate on the way: an 18 m
##     gold ping at the jump), and on the ground a Boki with that ability still pings.

const BIG_RING_M := 10.0        # m: a ring wider than any drop effect (the landing rings are 3.4 m)
const WATCH_S := 4.0            # s watched after the jump
const PING_WAIT_S := 12.0       # s a grounded Echolocate Boki gets to ping (cue: you fight, a foe within 10 m)

var fails := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("DROPCLEAN %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	await _start({"teams": 4, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "demo_kin": "zapple"})
	m.skydrop.planning = false
	m.time = float(m.ship["dur"]) * 0.5
	await _plates()
	var big := await _watch_rings()
	ok(big == 0, "no big ring from the ship to the glide (%d)" % big)
	await _start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
			"demo_kin": "caecilith"})
	var pinged := _pinged()
	ok(pinged, "on the ground an Echolocate Boki still pings")
	print("DROPCLEAN DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _start(o: Dictionary) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)

func _frames(n: int) -> void:
	for i in n:
		m._process(1.0 / 30.0)
		await main.get_tree().process_frame

func _plate_laid(h: Hunter) -> bool:
	return int(LabelCull.laid.get(h.nid, -9)) >= Engine.get_process_frames() - 2

func _plates() -> void:
	var H = m.hud
	ok(H != null, "setup: the HUD")
	if H == null:
		return
	H.visible = true
	H.process_mode = Node.PROCESS_MODE_INHERIT
	var P: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x != P and x.team == P.team)[0]
	var rival: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in [mate, rival]:
		h.unseen = false
		h.riding = true
		h.ai["jump_at"] = 1e9          # (a bot aboard jumps on its own plan)
		h.teleport(P.pos + Vector3(2.0, 0, 0))      # on the deck, a step away
	m.cam.snap(P.pos)
	await _frames(3)
	ok(not _plate_laid(mate) and not _plate_laid(rival), "aboard: a squadmate and a rival beside you have no plate")
	mate.riding = false
	await _frames(3)
	ok(_plate_laid(mate) and not _plate_laid(rival), "the squadmate's plate is back once they jump; the rival's waits")
	mate.riding = true
	rival.riding = true

## Ride to the jump and on for WATCH_S: how many rings wider than BIG_RING_M were spawned.
func _watch_rings() -> int:
	var seen := {}
	var big := 0
	var jumped := false
	var t := 0.0
	while t < WATCH_S:
		if not jumped and m.player.riding:
			await _frames(30)
			m.ship_jump(m.skydrop.leader(m.player.team), true)
			jumped = true
		await _frames(1)
		t += 1.0 / 30.0 if jumped else 0.0
		for r in m.fx.rings:
			if not seen.has(r["node"]):
				seen[r["node"]] = true
				big += 1 if float(r["r"]) > BIG_RING_M else 0
	return big

func _pinged() -> bool:
	var P: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	foe.teleport(P.pos + Vector3(5.0, 0, 0))
	foe.ctrl = "idle"
	P.max_hp = 5000.0          # (nothing in the match may down the owner meanwhile)
	P.hp = P.max_hp
	for i in int(PING_WAIT_S * 30.0):
		P.idle_fire = 0.0
		m._process(1.0 / 30.0)
		for r in m.fx.rings:
			if float(r["r"]) > BIG_RING_M:
				return true
	return false
