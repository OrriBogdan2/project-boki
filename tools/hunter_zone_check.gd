extends RefCounted
## --hunter-zone-check: nothing in a match prints over your own hunter, and far less text is up at once.
##   1. the zone is a real screen area round the hunter's body and plate
##   2. a damage number you take, a heal number and a floating word all end up clear of it (HunterZone via Fx)
##   3. a message card dropped right on the hunter slides aside; the knock banner does too
##   4. the lane shows 2 cards (none in a fight but urgent ones); a small line never sits beside another and is dropped in a fight
##   5. armour breaking (yours or theirs) and a wall slam toast nothing: the bar and the number already say it
## Never touches the save.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("HZONE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	RenderingServer.render_loop_enabled = false  # nothing here is looked at: slow soft-renderer frames only cost time
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4,
			"no_drop": true,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief")
		}
	)
	m.set_process(false)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var zone := HunterZone.rect(m)
	_zone(m, zone)
	_numbers(m, zone)
	_cards(m, zone)
	_lane_budget(m)
	_no_duplicate_toasts(m)
	m.queue_free()
	print("HZONE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _zone(m: Match, zone: Rect2) -> void:
	var feet := m.cam.unproject_position(m.player.position)
	ok(
		zone.has_area() and zone.has_point(feet),
		"the zone covers your hunter's feet (%s, feet %s)" % [str(zone), str(feet)]
	)
	ok(zone.size.x >= HunterZone.MIN_HALF_W * 2.0, "and is at least %d px wide" % int(HunterZone.MIN_HALF_W * 2.0))


func _label_boxes(m: Match) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in m.fx.nums:
		var l := n["node"] as Label3D
		if l.visible:
			out.append(MsgLane.label_rect(l, m.cam))
	return out


func _numbers(m: Match, zone: Rect2) -> void:
	var foe: Hunter = m.hunters.filter(func(x): return x != m.player)[0]
	m.player.hp = m.player.max_hp
	m.fx.damage_number(m.player, foe, 31.0, {}, m.player)      # damage you take: over your own head
	m.fx.healed(m.player, 12.0)
	m.fx.word(m.player.pos + Vector3(0, 1.3, 0), "COMBO", Color.WHITE)
	m.fx.number(m.player.pos + Vector3(0, 1.0, 0), 80.0, Color.RED, true)
	var shown := _label_boxes(m).size()
	ok(shown >= 3, "numbers and a word are up over the hunter (%d)" % shown)
	var worst := 0
	for i in 40:
		m.fx._process(0.016)
		for r in _label_boxes(m):
			if r.intersects(zone):
				worst += 1
	ok(worst == 0, "no number or word ever overlaps the zone over 40 frames (%d overlaps)" % worst)


func _cards(m: Match, zone: Rect2) -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	lane.fight = false
	lane.top = zone.position.y + 4.0  # the column starts right on the hunter
	lane.avoid = zone
	lane.push("Bramble Isle  ·  low ground, lots of cover", Color.GOLD)
	lane._process(0.5)
	var rects := lane.rects()
	ok(
		rects.size() == 1 and not rects[0].intersects(zone),
		"a card dropped on the hunter slides aside (%s)" % str(rects)
	)
	lane.clear()
	lane.avoid = Rect2()
	lane.push("Bramble Isle  ·  low ground, lots of cover", Color.GOLD)
	lane._process(0.5)
	ok(lane.rects()[0].intersects(zone), "(control: with no zone the same card does cover it)")
	lane.clear()
	var at := Vector2(zone.get_center().x, zone.position.y + 30.0)  # a banner opening right on the hunter
	var moved := KnockBanner.slid(at, zone)
	var reach := Vector2(KnockBanner.BOX_HALF_W, KnockBanner.FACE_R + KnockBanner.RING_W + KnockBanner.BOX_BELOW)
	var box := Rect2(moved - Vector2(reach.x, KnockBanner.FACE_R + KnockBanner.RING_W), reach * 2.0)
	ok(
		moved != at and not box.intersects(zone),
		"the knock banner slides off your hunter (%s -> %s)" % [str(at), str(moved)]
	)


func _lane_budget(m: Match) -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	lane.avoid = Rect2()
	lane.fight = false
	for t in ["one", "two", "three"]:
		lane.push(t, Color.WHITE)
	lane._process(0.1)
	ok(lane.texts().size() == 2 and MsgLane.MAX_SHOWN == 2, "at most 2 cards on show (%d)" % lane.texts().size())
	lane.clear()
	lane.push("big", Color.WHITE)
	lane.push("small", Color.WHITE, MsgLane.LOW)
	lane._process(0.1)
	ok(
		str(lane.texts()) == str(["big"]),
		"a small line waits instead of sitting beside another card (%s)" % str(lane.texts())
	)
	lane._process(MsgLane.LIFE[MsgLane.NORMAL] + 0.1)
	ok(str(lane.texts()) == str(["small"]), "... and shows once the lane is empty")
	lane.clear()
	lane.fight = true
	lane.push("small", Color.WHITE, MsgLane.LOW)
	ok(lane.count() == 0, "in a fight a small line is dropped outright")
	lane.push("one", Color.WHITE)
	lane.push("two", Color.WHITE)
	lane._process(0.1)
	ok(lane.texts().is_empty() and lane.waiting() == 2, "in a fight no card shows, both wait (%d)" % lane.texts().size())
	lane.clear()
	lane.fight = false


func _no_duplicate_toasts(m: Match) -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	var foe: Hunter = m.hunters.filter(func(x): return x != m.player)[0]
	m.on_armor_break(foe, m.player)
	m.on_armor_break(m.player, foe)
	m.on_wall_slam(m.player, Vector2.RIGHT)
	ok(lane.count() == 0, "armour breaking and a wall slam add no toast (%s)" % str(lane.texts()))
