extends RefCounted
## --combat-calm-check: the combat HUD stays calm. Hit or hitting back: toasts and hints queue and
## only an urgent line shows; once 3 s pass without a hit they show one at a time, under the top row, never in
## the centre 40% of the screen or over the hunter. Never touches the save.

const CENTRE := 0.4      # of the screen's width and height: the middle nothing pops into
const QUIET_S := 3.1     # s without a hit that end a fight (Hud.MSG_FIGHT_S is 3)

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
