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
	var gm := await _host_up()
	if gm == null:
		return _finish()
	var pl := m.player
	_kit("archer")
	await _place(gm, home + PARK)
	var at := home + Vector3(3.0, 0, 0)
	var wisp: Hunter = m.make_hunter("B", 1, "medium", "Wisp", "idle", {}, at, {"arch": "none"})
	for k in [wisp.kin, wisp.kin2]:
		if k:
			(k as Kin).dead = true
	_fresh(wisp)
	wisp.lives = 1
	m.knock(wisp, pl, {})
	pl.teleport(at + Vector3(0.6, 0, 0))
	var view := await _see(0.4)
	for i in 10:
		if view.get("wisp", false) and view["down"]:
			break
		view = await _see(0.5)  # (the wisp is a late spawn: the guest builds its copy from the snapshots)
	ok(
		view.get("wisp", false) and view["down"] and not view["stomp"],
		"before it the wisp is down and nobody stomps",
		str(view)
	)
	Life.start_stomp(m, pl, wisp)
	view = await _see(SEE_S)
	ok(view["stomp"], "the guest's copy of the stomper is stomping", str(view))
	ok(
		view["k"] > POSE_K and view["beat"] >= 0.0,
		"...and plays the stomp pose (k %.2f, beat %.2f)" % [view["k"], view["beat"]]
	)
	pl.hurt(5.0, wisp, {"stun": 0.6})
	view = await _see(SEE_S)
	ok(
		pl.stomp.is_empty() and not view["stomp"],
		"a stun on the stomper cuts the stomp on the guest's copy too",
		str(view)
	)
	ok(
		view["k"] < GONE_K and view["down"] and not view["out"],
		"the pose eases out (k %.2f) and the wisp lives on the guest" % view["k"],
		str(view)
	)
	await _run(0.8)  # (the stun runs out)
	Life.start_stomp(m, pl, wisp)
	view = await _see(Life.R["stomp_time"] * 0.5)
	ok(view["stomp"] and not view["out"], "a second stomp is on the guest halfway, the wisp still down", str(view))
	view = await _see(Life.R["stomp_time"] * 0.5 + 0.3)
	ok(
		not view["stomp"] and view["out"] and wisp.out,
		"left alone it ends and the wisp is executed on the guest too",
		str(view)
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
	var stomper: Hunter = m.player
	for h in m.hunters:
		if h.remote and h.nid.begins_with("P"):
			stomper = h
	for i in EASE_FRAMES:
		stomper.render(DT, 1.0)  # (Match's own render pass is off in the checks)
	var wisp := m.ents_by_id.get("B", null) as Hunter
	var out := {
		"stomp": not stomper.stomp.is_empty(),
		"k": stomper.anim.stomp_k,
		"beat": stomper.anim_s.get("stomp", -1.0),
		"wisp": wisp != null
	}
	if wisp:
		out.merge({"down": wisp.downed, "out": wisp.out})
	return out
