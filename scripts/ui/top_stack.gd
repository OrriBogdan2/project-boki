class_name TopStack
extends RefCounted
## The top-centre of a real match is one column, so two prompts never sit on each other: the Ways Out
## strip, then the one-line banner (the first-match guide, else the crouch hint), then the message lane
## (and the lines under it). A new banner line is fresh for Tutorial.CARD_T: the lane holds its lines
## (URGENT passes) and shows them after, under the banner. The tutorial lays its own lanes (TutorialHud).


## Seconds the banner line has been up, -1 when none is drawn (the counters group, which holds it, may be staged off).
static func strip_age(m: Match) -> float:
	if not HudReveal.on(m, "counters"):
		return -1.0
	var age: float = m.guide.strip_age() if m.guide else -1.0
	if age < 0.0 and m.crouch_hint:
		age = m.crouch_hint.strip_age()
	return age


## Lays the message lane under the banner and holds it while the banner is fresh.
static func place(h) -> void:
	h.msgs.max_shown = 1
	h.msgs.one_hint = true
	var age := strip_age(h.m)
	var fresh := age >= 0.0 and age < Tutorial.CARD_T
	if h.msgs.hold != fresh:
		h.msgs.hold = fresh
	if age >= 0.0:
		h.msgs.top = maxf(h.msgs.top, FirstMatchGuide.strip_rect(h.m, h.c.size).end.y + TutorialStrip.GAP)
	rail(h)


## Toasts ("Fever is lit", "Bond full!") go to the right rail, under the alive counter and the kill feed, so they
## never sit over the fight in the top centre or over the HUD's level and HP (docs/COMBAT_CLARITY.md).
static func rail(h) -> void:
	var sz: Vector2 = h.c.size
	var fr := SafeArea.frame(sz)   # (on 21:9 and wider the corner groups keep to a centred 16:9 frame)
	var pad := HudStyle.safe_pad(fr.size)
	var y: float = maxf(h.feed_top, pad.y)
	if not KillFeed.shown.is_empty():
		y = maxf(y, (KillFeed.shown.back()["rect"] as Rect2).end.y + KillFeed.GAP)
	h.msgs.right_edge = fr.end.x - pad.x
	h.msgs.max_w = fr.size.x * RAIL_W
	h.msgs.top = maxf(h.msgs.top, y)


const RAIL_W := 0.22   # of the screen width: the widest a rail card gets (a longer line wraps)
