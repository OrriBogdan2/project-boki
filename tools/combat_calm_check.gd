extends RefCounted
## --combat-calm-check: the combat HUD stays calm. Hit or hitting back: toasts and hints queue and
## only an urgent line shows; once 3 s pass without a hit they show one at a time, under the top row, never in
## the centre 40% of the screen or over the hunter; a rival's name shows only under the mouse. Never touches the save.

const CENTRE := 0.4  # of the screen's width and height: the middle nothing pops into
const QUIET_S := 3.1  # s without a hit that end a fight (Hud.MSG_FIGHT_S is 3)

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("CALM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	RenderingServer.render_loop_enabled = false
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 9, "no_drop": true})
	m.set_process(false)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	_lane(m)
	await _level_card(m)
	_names(m)
	m.queue_free()
	print("CALM DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _lane(m: Match) -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	m.player.hurt_at = m.time
	m.hud._place_msgs()
	ok(m.hud.in_fight() and lane.fight, "a hit puts the HUD in a fight")
	m.hud.toast("Picked up a gem", Color.WHITE)
	m.hud.tip("Hold F to open the chest")
	lane._process(0.5)
	ok(lane.texts().is_empty() and lane.waiting() == 2, "in a fight toasts and hints wait (%s)" % str(lane.texts()))
	lane.push("Your Boki is down", Color.WHITE, MsgLane.URGENT)
	lane._process(0.1)
	ok(lane.texts() == ["Your Boki is down"], "an urgent line still shows (%s)" % str(lane.texts()))
	lane.clear()
	m.hud.toast("Picked up a gem", Color.WHITE)
	m.hud.tip("Hold F to open the chest")
	m.hud.toast("Picked up a coin", Color.WHITE)
	m.time += QUIET_S
	m.hud._place_msgs()
	ok(not m.hud.in_fight(), "%.1f s without a hit ends the fight" % QUIET_S)
	lane._process(0.1)
	ok(lane.texts().size() == 1 and lane.waiting() == 2, "after it, one card at a time (%s)" % str(lane.texts()))
	var sz: Vector2 = m.hud.c.size
	var centre := Rect2(sz * (1.0 - CENTRE) * 0.5, sz * CENTRE)
	var worst := 0
	for i in 12:
		lane._process(1.0)
		for r in lane.rects():
			if r.intersects(centre) or r.intersects(HunterZone.rect(m)):
				worst += 1
		ok(lane.texts().size() <= 1, "second %d: at most one card (%d)" % [i, lane.texts().size()])
	ok(worst == 0, "no card entered the centre %d%% or the hunter's zone (%d frames)" % [int(CENTRE * 100.0), worst])
	ok(lane.count() == 0, "the queue drains (%d left)" % lane.count())
	lane.clear()


func _level_card(m: Match) -> void:
	m.player.hurt_at = m.time
	m.hud.level_up(2, {})
	for i in 30:
		await main.get_tree().process_frame
	var cue: LevelUpCue = m.hud.lvl_cue
	ok(cue.t == LevelUpCue.LIFE, "the level-up card waits while you fight (%.2f s left)" % cue.t)
	m.time += QUIET_S
	for i in 30:
		await main.get_tree().process_frame
	ok(cue.t < LevelUpCue.LIFE, "... and runs once it is quiet (%.2f s left)" % cue.t)


func _names(m: Match) -> void:
	var foe: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	foe.pos = m.player.pos + Vector3(3, 0, 0)  # well inside the old 9 m "close enough to read" range
	var far: Vector2 = m.hud.c.size * 0.9
	ok(not m.hud._np_show_name(far, foe), "a rival's name stays hidden with the mouse away, even up close")
	var near: Vector2 = m.hud.c.get_local_mouse_position()
	ok(m.hud._np_show_name(near, foe), "... and shows under the mouse")
	foe.downed = true
	ok(m.hud._np_show_name(far, foe), "a downed rival's plate still says who")
	foe.downed = false
