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
	var host := await _host_up()
	if host == null:
		return _finish()
	var ply := m.player
	_kit("archer")
	await _place(host, home + PARK)
	var at := home + Vector3(3.0, 0, 0)
	var bot: Hunter = m.make_hunter("B", 1, "medium", "Wisp", "idle", {}, at, {"arch": "none"})
	for k in [bot.kin, bot.kin2]:
		if k:
			(k as Kin).dead = true
	_fresh(bot)
	bot.lives = 1
	m.knock(bot, ply, {})
	ply.teleport(at + Vector3(0.6, 0, 0))
	var seen_l := await _see(0.4)
	for i in 10:
		if seen_l.get("wisp", false) and seen_l["down"]:
			break
		seen_l = await _see(0.5)  # (the wisp is a late spawn: the guest builds its copy from the snapshots)
	ok(
		seen_l.get("wisp", false) and seen_l["down"] and not seen_l["stomp"],
		"before it the wisp is down and nobody stomps",
		str(seen_l)
	)
	Life.start_stomp(m, ply, bot)
	seen_l = await _see(SEE_S)
	ok(seen_l["stomp"], "the guest's copy of the stomper is stomping", str(seen_l))
	ok(
		seen_l["k"] > POSE_K and seen_l["beat"] >= 0.0,
		"...and plays the stomp pose (k %.2f, beat %.2f)" % [seen_l["k"], seen_l["beat"]]
	)
	ply.hurt(5.0, bot, {"stun": 0.6})
	seen_l = await _see(SEE_S)
	ok(
		ply.stomp.is_empty() and not seen_l["stomp"],
		"a stun on the stomper cuts the stomp on the guest's copy too",
		str(seen_l)
	)
	ok(
		seen_l["k"] < GONE_K and seen_l["down"] and not seen_l["out"],
		"the pose eases out (k %.2f) and the wisp lives on the guest" % seen_l["k"],
		str(seen_l)
	)
	await _run(0.8)  # (the stun runs out)
	Life.start_stomp(m, ply, bot)
	seen_l = await _see(Life.R["stomp_time"] * 0.5)
	ok(
		seen_l["stomp"] and not seen_l["out"],
		"a second stomp is on the guest halfway, the wisp still down",
		str(seen_l)
	)
	seen_l = await _see(Life.R["stomp_time"] * 0.5 + 0.3)
	ok(
		not seen_l["stomp"] and seen_l["out"] and bot.out,
		"left alone it ends and the wisp is executed on the guest too",
		str(seen_l)
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
	var src: Hunter = m.player
	for h in m.hunters:
		if h.remote and h.nid.begins_with("P"):
			src = h
	for i in EASE_FRAMES:
		src.render(DT, 1.0)  # (Match's own render pass is off in the checks)
	var bot := m.ents_by_id.get("B", null) as Hunter
	var out := {
		"stomp": not src.stomp.is_empty(),
		"k": src.anim.stomp_k,
		"beat": src.anim_s.get("stomp", -1.0),
		"wisp": bot != null
	}
	if bot:
		out.merge({"down": bot.downed, "out": bot.out})
	return out
