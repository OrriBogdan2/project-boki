class_name StompNetCheck
extends "res://tools/displace_net_check.gd"
## --stomp-net-check: a stomp on the host's game reaches the other player's game (the "stomp" event, Net 0.24.18).
## Two real games over the desktop relay (the --displace-net-check harness, which this extends): the host's
## hunter stomps a downed bot wisp, and the guest's game, fed by the event and the snapshots, must show the
## stomper stomping and playing the stomp pose, the wisp down under it, the stomp cut off the moment a stun
## breaks it (the wisp lives), and the wisp executed when the stomp runs out.
## Lines: STOMPNET ok|FAIL <what>.

const SEE_S := 0.5  # s for the event, a snapshot and the eased pose to reach the guest
const POSE_K := 0.7  # the stomp pose counts as played above this (HunterAnim.stomp_k)
const GONE_K := 0.3  # ...and as eased out below this
const EASE_FRAMES := 30  # guest render frames run before it reports the pose (the pose eases in over ~0.2 s)


func _init() -> void:
	tag = "STOMPNET"
	guest_flag = "--stomp-net-check=guest"


# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	var P := m.player
	_kit("archer")
	await _place(G, home + PARK)
	var at := home + Vector3(3.0, 0, 0)
	var B: Hunter = m.make_hunter("B", 1, "medium", "Wisp", "idle", {}, at, {"arch": "none"})
	for k in [B.kin, B.kin2]:
		if k:
			(k as Kin).dead = true
	_fresh(B)
	B.lives = 1
	m.knock(B, P, {})
	P.teleport(at + Vector3(0.6, 0, 0))
	var seen := await _see(0.4)
	for i in 10:
		if seen.get("wisp", false) and seen["down"]:
			break
		seen = await _see(0.5)  # (the wisp is a late spawn: the guest builds its copy from the snapshots)
	ok(
		seen.get("wisp", false) and seen["down"] and not seen["stomp"],
		"before it the wisp is down and nobody stomps",
		str(seen)
	)
	Life.start_stomp(m, P, B)
	seen = await _see(SEE_S)
	ok(seen["stomp"], "the guest's copy of the stomper is stomping", str(seen))
	ok(
		seen["k"] > POSE_K and seen["beat"] >= 0.0,
		"...and plays the stomp pose (k %.2f, beat %.2f)" % [seen["k"], seen["beat"]]
	)
	P.hurt(5.0, B, {"stun": 0.6})
	seen = await _see(SEE_S)
	ok(
		P.stomp.is_empty() and not seen["stomp"],
		"a stun on the stomper cuts the stomp on the guest's copy too",
		str(seen)
	)
	ok(
		seen["k"] < GONE_K and seen["down"] and not seen["out"],
		"the pose eases out (k %.2f) and the wisp lives on the guest" % seen["k"],
		str(seen)
	)
	await _run(0.8)  # (the stun runs out)
	Life.start_stomp(m, P, B)
	seen = await _see(Life.R["stomp_time"] * 0.5)
	ok(seen["stomp"] and not seen["out"], "a second stomp is on the guest halfway, the wisp still down", str(seen))
	seen = await _see(Life.R["stomp_time"] * 0.5 + 0.3)
	ok(
		not seen["stomp"] and seen["out"] and B.out,
		"left alone it ends and the wisp is executed on the guest too",
		str(seen)
	)
	_finish()


## Let the match run `secs`, then ask the guest what its copies look like.
func _see(secs: float) -> Dictionary:
	await _run(secs)
	replies.clear()
	Net.lobby_emit("sn", {"c": "look"})
	await _reply()
	return replies[0].get("look", {}) if not replies.is_empty() else {}


# ------------------------------------------------------------------ the guest
func _on_msg(topic: String, data, from: String) -> void:
	if topic == "sn" and typeof(data) == TYPE_DICTIONARY and m and m.player:
		Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "look": _look()})
		return
	super._on_msg(topic, data, from)


## The guest's copy of the stomper (the host's hunter) and of the wisp ("B"), as they look now.
func _look() -> Dictionary:
	var S: Hunter = m.player
	for h in m.hunters:
		if h.remote and h.nid.begins_with("P"):
			S = h
	for i in EASE_FRAMES:
		S.render(DT, 1.0)  # (Match's own render pass is off in the checks)
	var B := m.ents_by_id.get("B", null) as Hunter
	var out := {
		"stomp": not S.stomp.is_empty(), "k": S.anim.stomp_k, "beat": S.anim_s.get("stomp", -1.0), "wisp": B != null
	}
	if B:
		out.merge({"down": B.downed, "out": B.out})
	return out
