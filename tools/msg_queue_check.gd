extends RefCounted
## --msg-queue-check: every short message on screen goes through one lane (MsgLane).
##   1. five lines fired at once: at most MAX_SHOWN show, the rest wait, no two cards overlap
##   2. a repeat merges into the line on show or waiting ("Ember  x3") instead of a second card
##   3. a waiting important line goes before a waiting small one; a small one that waits too long goes
##   4. while held (the tutorial banner) nothing new shows; it comes in when the hold lifts
##   5. in a fight fewer lines show (FIGHT_SHOWN) and none lives past FIGHT_LIFE unless it asked to
##   6. the match HUD's toast, toast_small, tip and level_up and the farm's UI.toast all use a lane
##   7. a world label under a card fades back
##   8. the match HUD's lane is single: six banners fired in one frame (a Boki line, Ways Out, a steal, a
##      level-up, a pickup, a Boki status) show one at a time, most important first, each its minimum
##      time; the pickup waiting behind them is dropped
## Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("MSGQ %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(host)
	_layout(host)
	_merge(host)
	_priority(host)
	_hold(host)
	_fight(host)
	await _wiring()
	_yield()
	host.queue_free()
	print("MSGQ DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fresh(host: Control) -> MsgLane:
	var lane := MsgLane.of(host)
	lane.clear()
	lane.hold = false
	lane.fight = false
	return lane

# ------------------------------------------------------------------ 1. five at once
func _layout(host: Control) -> void:
	var lane := _fresh(host)
	for t in ["Bramble Isle", "Chest key found", "ARMOR BROKEN", "Drop wave incoming", "LEVEL 8"]:
		lane.push(t, Color.WHITE)
	lane._process(0.016)
	var rects := lane.rects()
	ok(rects.size() == MsgLane.MAX_SHOWN and lane.waiting() == 5 - MsgLane.MAX_SHOWN,
		"five at once: %d show, %d wait" % [rects.size(), lane.waiting()])
	ok(_no_overlap(rects), "the cards on show never overlap (%s)" % str(rects))
	ok(rects.all(func(r: Rect2): return r.position.y >= lane.top), "they stack down from the lane's top")
	for i in 60:
		lane._process(0.1)      # the first ones go, the waiting ones come in and the rest slide up
		if not _no_overlap(lane.rects()):
			ok(false, "cards overlap while the column closes up (%.1fs)" % (i * 0.1))
			return
	ok(lane.count() == 0, "every line goes within a few seconds (%d left)" % lane.count())

func _no_overlap(rects: Array[Rect2]) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				return false
	return true

# ------------------------------------------------------------------ 2. repeats merge
func _merge(host: Control) -> void:
	var lane := _fresh(host)
	for i in 3:
		lane.push("Ember", Color.ORANGE)
	ok(str(lane.texts()) == str(["Ember  x3"]), "three Embers make one card: %s" % str(lane.texts()))
	for t in ["A", "B", "C", "C"]:
		lane.push(t, Color.WHITE)
	ok(lane.count() == 4 and lane.waiting() == 1, "a repeat of a waiting line merges too (%d)" % lane.count())

# ------------------------------------------------------------------ 3. priority and old news
func _priority(host: Control) -> void:
	var lane := _fresh(host)
	for t in ["one", "two", "three"]:
		lane.push(t, Color.WHITE)
		lane._process(0.5)      # (so the rows free one at a time)
	lane.push("small", Color.WHITE, MsgLane.LOW)
	lane.push("LEVEL 4", Color.GOLD, MsgLane.HIGH)
	for i in 30:
		lane._process(0.1)
		if lane.texts().has("LEVEL 4"):
			break
	ok(lane.texts().has("LEVEL 4") and not lane.texts().has("small"), "the important line takes the first free row")
	lane = _fresh(host)
	for t in ["one", "two", "three"]:
		lane.push(t, Color.WHITE, MsgLane.HIGH)
	lane.push("old news", Color.WHITE, MsgLane.LOW)
	lane._process(MsgLane.STALE + 0.1)
	ok(lane.waiting() == 0, "a small line that waited past %.0fs is dropped" % MsgLane.STALE)
	for t in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]:
		lane.push(t, Color.WHITE)
	ok(lane.waiting() == MsgLane.WAIT_CAP, "at most %d wait (%d)" % [MsgLane.WAIT_CAP, lane.waiting()])

# ------------------------------------------------------------------ 4. hold
func _hold(host: Control) -> void:
	var lane := _fresh(host)
	lane.hold = true
	lane.push("check 1", Color.WHITE)
	lane._process(0.5)
	ok(lane.texts().is_empty() and lane.waiting() == 1, "held: the line waits")
	lane.hold = false
	ok(str(lane.texts()) == str(["check 1"]), "the hold lifts: it shows at once")

# ------------------------------------------------------------------ 5. in a fight
func _fight(host: Control) -> void:
	var lane := _fresh(host)
	lane.fight = true
	for t in ["a", "b", "c"]:
		lane.push(t, Color.WHITE, MsgLane.HIGH)
	lane.push("hint", Color.WHITE, MsgLane.NORMAL, 6.0)
	ok(lane.texts().size() == MsgLane.FIGHT_SHOWN,
		"a fight: %d lines at most (%d)" % [MsgLane.FIGHT_SHOWN, lane.texts().size()])
	lane._process(MsgLane.FIGHT_LIFE + 0.05)
	ok(not lane.texts().has("a") and not lane.texts().has("b"), "a fight: lines go after %.1fs" % MsgLane.FIGHT_LIFE)
	lane._process(MsgLane.FIGHT_LIFE + 0.05)
	ok(lane.texts().has("hint"), "a fight: a hint keeps its own life (%s)" % str(lane.texts()))
	lane.clear()
	lane.fight = false

# ------------------------------------------------------------------ 6. one lane everywhere
func _wiring() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	await main.get_tree().process_frame
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	m.hud.toast("Bramble Isle", Color.GOLD)
	m.hud.toast_small("Chest key found", Color.WHITE)
	m.hud.level_up(3)
	lane._process(0.01)
	ok(lane.count() == 2 and lane.texts() == ["Bramble Isle"] and lane.single,
		"Hud.toast and level_up land in the HUD's single lane, the small line behind the level-up goes (%s)" % str(lane.texts()))
	lane.clear()
	m.hud.tip("Hold left click to shoot")
	ok(lane.count() == 1, "a hint lands in the same lane")
	ok(lane.get_parent() == m.hud, "the lane is part of the HUD")
	_burst(m)
	m.queue_free()
	var farm := Control.new()
	main.add_child(farm)
	UI.toast(farm, "Not enough wood")
	UI.toast(farm, "Not enough wood")
	ok(str(MsgLane.of(farm).texts()) == str(["Not enough wood  x2"]) and UI.toast_busy(farm),
		"UI.toast (the farm, town, houses) uses a lane too, repeats merged")
	farm.queue_free()

# ------------------------------------------------------------------ 8. six banners in one frame
const STEP := 0.05     # s per simulated frame

func _burst(m: Match) -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	lane.fight = false
	m.hud.toast_small("Dropped it", Color.WHITE)                              # Boki line, LOW
	m.hud.toast("Uplink started: hold the yard", Color.CYAN)                  # Ways Out, NORMAL
	lane.push("Rook stole the Warden", StealCall.LOSER_COL, MsgLane.HIGH)     # a boss steal, HIGH
	m.hud.level_up(3)                                                         # HIGH
	m.hud.toast_small("Chest key found", Color.WHITE)                         # pickup, LOW
	m.hud.toast("Your Boki is resting", Color.CYAN)                           # Boki status, NORMAL
	var order: Array[String] = []
	var shown_s: Array[float] = []
	var most := 0
	var overlap := false
	var t := 0.0
	while lane.count() > 0 and t < 30.0:
		lane._process(STEP)
		lane.fight = false
		t += STEP
		var now := lane.texts()
		most = maxi(most, now.size())
		var live: Array[Rect2] = []
		for ch in lane.get_children():
			if ch is Control and not ch.is_queued_for_deletion() and (ch as Control).modulate.a > 0.0:
				live.append((ch as Control).get_rect())
		overlap = overlap or not _no_overlap(live) or live.size() > 1
		if now.is_empty():
			continue
		if order.is_empty() or order.back() != now[0]:
			order.append(now[0])
			shown_s.append(0.0)
		shown_s[-1] += STEP
	var want: Array[String] = ["Dropped it", "Rook stole the Warden", "LEVEL 3  ·  +1 skill point",
		"Uplink started: hold the yard", "Your Boki is resting"]
	ok(most == 1 and not overlap, "six in one frame: one banner at a time, never two cards on screen")
	ok(order == want, "six in one frame: most important first, the pickup behind them dropped (%s)" % str(order))
	ok(shown_s.size() == 5 and shown_s.all(func(s): return s >= MsgLane.MIN_SHOW),
		"six in one frame: each stays its minimum %.1fs (%s)" % [MsgLane.MIN_SHOW, str(shown_s)])
	if shown_s.size() == 5:
		var cut := MsgLane.MIN_SHOW + MsgLane.FADE_OUT
		ok(absf(shown_s[0] - cut) < 2.0 * STEP,
			"six in one frame: the Boki line is cut short at its minimum (%.2fs, want %.2fs)" % [shown_s[0], cut])
		ok(absf(shown_s[1] - MsgLane.LIFE[MsgLane.HIGH]) < 2.0 * STEP and absf(shown_s[3] - MsgLane.LIFE[MsgLane.NORMAL]) < 2.0 * STEP,
			"six in one frame: nothing more important waiting, a banner keeps its full life (%s)" % str(shown_s))
	lane.clear()

# ------------------------------------------------------------------ 7. world labels yield
func _yield() -> void:
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.look_at_from_position(Vector3(0, 10, 10), Vector3.ZERO)
	var lbl := Label3D.new()
	lbl.text = "Chop me"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	main.add_child(lbl)
	var under: Array[Rect2] = [MsgLane.label_rect(lbl, cam)]
	for i in 30:
		MsgLane.yield_label(lbl, cam, under, 0.05)
	ok(lbl.transparency > 0.8, "a label under a card fades back (%.2f)" % lbl.transparency)
	var clear: Array[Rect2] = []
	for i in 30:
		MsgLane.yield_label(lbl, cam, clear, 0.05)
	ok(lbl.transparency < 0.05, "and comes back when the card goes")
	cam.queue_free()
	lbl.queue_free()
