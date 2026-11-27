class_name Wpicks
extends RefCounted
## Weapon, gear and tuning pickups lying on the ground (Match.wpicks): their spin and bob, and who walks
## over one. Only those near the local player are animated: nobody sees the rest turn, and each turn
## moves a node tree (a 2x match holds dozens; animating them all cost as much as the hunters' steps).
const ANIM_M := 70.0  # m (flat) from the local player: past the match camera's view


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
	var rules := PickupReach.rules()  # (read once a step: PickupReach.near's first test runs here, not a call per pair)
	for h in m.hunters:
		if h.out or h.downed or h.dropping or h.riding or h.remote:
			continue
		var rule := "bot" if h.ctrl == "bot" else "tune"
		var reach := float(rules[rule]["radius"])
		var reach_h := float(rules[rule]["height"])
		for wp in m.wpicks:
			var at: Vector3 = wp["pos"]
			if Vector2(at.x - h.pos.x, at.z - h.pos.z).length() >= reach or absf(h.pos.y - at.y) >= reach_h:
				continue
			if wp.has("val") or not PickupReach.near(m, h, at, rule):
				continue
			if wp.has("tune") or (h.ctrl == "bot" and GearDrops.bot_wants(h, String(wp["gear"]), int(wp["rar"]))):
				m.take_pick(h, wp)
				break
