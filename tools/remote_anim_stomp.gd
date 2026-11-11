class_name RemoteAnimStomp
extends RefCounted
## --remote-anim-check, the stomp rows (docs/decisions/0061-stomp-lock.md): the host's hunter stomps a downed bot
## wisp on the host's game, and the guest's game, fed by the stomp event and the snapshots, shows what the host
## shows: the stomper locked in its spot and playing the stomp, the wisp held and lying down, the stomp cut off
## the moment a stun breaks it, and the wisp gone when the stomp runs out.

const SEE_S := 0.5       # s for the event, a snapshot and the eased pose to reach the guest
const MOVED := 0.3       # m: the most a locked body may drift on the guest's copy
const GONE_K := 0.3      # the stomp pose is eased out below this

## The guest: what its copies of the stomper (the host's hunter) and the wisp ("B") look like right now.
static func look(c: RemoteAnimCheck) -> Dictionary:
	var S := c._copy()
	var B := c.m.ents_by_id.get("B", null) as Hunter
	var out := {"stomp": not S.stomp.is_empty(), "style": S.stomp.get("style", ""), "k": S.anim.stomp_k,
		"beat": S.anim_s.get("stomp", -1.0), "at": [S.pos.x, S.pos.y, S.pos.z], "wisp": B != null}
	if B:
		out.merge({"down": B.downed, "out": B.out, "by": B.has_meta("stomped_by") and B.get_meta("stomped_by") == S,
			"lies": HunterWisp.hides(B), "bat": [B.pos.x, B.pos.y, B.pos.z]})
	out.merge({"dive": S.diving, "dive_s": S.anim_s.get("diving", false), "dk": S.anim.dive_k})
	return out

static func host(c: RemoteAnimCheck, G: Hunter) -> void:
	var P := c.m.player
	c._kit("archer")
	await c._place(G, c.home + RemoteAnimCheck.PARK)
	var at: Vector3 = c.home + Vector3(3.0, 0, 0)
	var B: Hunter = c.m.make_hunter("B", 1, "medium", "Wisp", "idle", {}, at, {"arch": "none"})
	for k in [B.kin, B.kin2]:
		if k: (k as Kin).dead = true
	c._fresh(B)
	B.lives = 1
	c.m.knock(B, P, {})
	P.teleport(at + Vector3(0.6, 0, 0))
	var sid := StompLook.style_id(P)
	var seen := await _see(c, 0.4)
	c.ok(seen.get("wisp", false) and seen["down"] and not seen["stomp"] and not seen["by"],
		"stomp: before it the wisp lies on the guest, nobody stomps", str(seen))
	var p_at := P.pos
	at = B.pos
	Stomp.start(c.m, P, B)
	seen = await _see(c, SEE_S)
	c.ok(seen["stomp"] and seen["style"] == sid, "stomp: the guest's copy of the stomper stomps in its style (%s)" % sid, str(seen))
	c.ok(seen["k"] > 0.7 and seen["beat"] >= 0.0, "stomp: and plays the stomp pose (k %.2f, beat %.2f)" % [seen["k"], seen["beat"]])
	c.ok(seen["by"] and seen["lies"], "stomp: the wisp's copy is marked stomped and shows as a wisp")
	for i in 60:
		P.inp["move"] = Vector2(1, 0)
		B.inp["move"] = Vector2(-1, 0)
		await c._run(RemoteAnimCheck.DT)
	seen = await _see(c, 0.2)
	c.ok(c._v(seen["at"]).distance_to(p_at) < MOVED and P.pos.distance_to(p_at) < 0.05,
		"stomp: the stomper is locked in its spot, on the host and on the guest's copy", "host %.2f m" % P.pos.distance_to(p_at))
	c.ok(c._v(seen["bat"]).distance_to(at) < MOVED and B.pos.distance_to(at) < 0.05,
		"stomp: the wisp is held in its spot on both too", "host %.2f m" % B.pos.distance_to(at))
	P.hurt(5.0, B, {"stun": 0.6})
	seen = await _see(c, SEE_S)
	c.ok(P.stomp.is_empty() and not seen["stomp"], "stomp: a stun on the stomper cuts the stomp on the guest's copy too", str(seen))
	c.ok(seen["k"] < GONE_K and seen["down"] and not seen["out"] and not seen["by"],
		"stomp: the pose eases out (k %.2f), the wisp lives on the guest and is let go" % seen["k"], str(seen))
	await c._run(0.8)      # (the stun runs out)
	Stomp.start(c.m, P, B)
	seen = await _see(c, Stomp.TIME * 0.5)
	c.ok(seen["stomp"] and not seen["out"], "stomp: a second stomp is on the guest halfway, the wisp still down", str(seen))
	seen = await _see(c, Stomp.TIME * 0.5 + 0.3)
	c.ok(not seen["stomp"] and seen["out"] and B.out,
		"stomp: left alone it ends and the wisp is executed on the guest too", str(seen))

## Let the match run `secs`, then ask the guest what its copies look like.
static func _see(c: RemoteAnimCheck, secs: float) -> Dictionary:
	await c._run(secs)
	c.replies.clear()
	Net.lobby_emit("ra", {"c": "look"})
	await c._reply()
	return c.replies[0].get("look", {}) if not c.replies.is_empty() else {}

## The skydive (the rocket's free fall and the opening drop use it): the guest's copy of a hunter diving plays it.
## The poses aboard the rocket do not exist yet: its riders are hidden (Hunter.visible), see docs/DEBT.md.
static func skydive(c: RemoteAnimCheck, G: Hunter) -> void:
	var P := c.m.player
	c._kit("archer")
	await c._place(G, c.home + RemoteAnimCheck.PARK)
	P.teleport(c.home + Vector3(0, 90.0, 0))
	P.grounded = false
	P.dropping = true
	P.diving = true
	P.gliding = true
	var seen := await _see(c, SEE_S)
	c.ok(seen["dive"] and seen["dive_s"] and seen["dk"] > 0.5,
		"skydive: the guest's copy of a diving hunter plays the skydive (k %.2f)" % seen["dk"], str(seen))
	P.diving = false
	seen = await _see(c, SEE_S)
	c.ok(not seen["dive"] and seen["dk"] < 0.5, "skydive: and stops when the glider opens (k %.2f)" % seen["dk"], str(seen))
	P.dropping = false
	P.gliding = false
	P.teleport(c.home)
