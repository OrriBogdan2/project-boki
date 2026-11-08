class_name Wpicks
extends RefCounted
## Weapon, gear and tuning pickups lying on the ground (Match.wpicks): their spin and bob, and who walks
## over one. Only those near the local player are animated: nobody sees the rest turn, and each turn
## moves a node tree (a 2x match holds dozens; animating them all cost as much as the hunters' steps).
const ANIM_M := 70.0        # m (flat) from the local player: past the match camera's view

static func update(m: Match, dt: float) -> void:
	var me: Hunter = m.player
	for wp in m.wpicks:
		if me == null or me.flat_dist(wp["pos"]) > ANIM_M:
			continue
		var n: Node3D = wp["node"]
		var sp: Node3D = n.get_node("Spin")
		sp.rotation.y += dt * 1.6
		sp.position.y = 0.7 + sin(m.time * 2.4 + float(wp["pos"].x)) * 0.08
	# tunings are taken by walking over them; bots also grab gear that beats what they wear
	for h in m.hunters:
		if h.out or h.downed or h.dropping or h.riding or h.remote:
			continue
		for wp in m.wpicks:
			if wp.has("val") or h.flat_dist(wp["pos"]) >= 1.4 or absf(h.pos.y - float(wp["pos"].y)) >= 1.0:
				continue
			if wp.has("tune") and (h.flat_dist(wp["pos"]) < 1.1 or h.ctrl == "bot"):
				m.take_pick(h, wp)
				break
			if wp.has("gear") and h.ctrl == "bot" and GearDrops.bot_wants(h, String(wp["gear"]), int(wp["rar"])):
				m.take_pick(h, wp)
				break
