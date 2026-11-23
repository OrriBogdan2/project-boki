class_name TruceCalmCheck
extends RefCounted
## Part of --truce-check: a bot's truce offer waits for a calm moment (no hit dealt or taken by either
## squad for calm_s), is dropped if the fight goes on past HOLD_MAX, and is never shown in the
## first-match guide. Squad 0 holds the player; squad 1's bot waves the flag.

static func run(m: Match, near: Vector3) -> bool:
	var T: Truce = m.truce
	var calm := float(Content.rules("truce")["calm_s"])
	var good := true
	var by: Hunter = m.hunters.filter(func(x): return x.team == 1)[0]
	var me: Hunter = m.hunters.filter(func(x): return x.team == 0)[0]
	me.teleport(near + Vector3(-3.0, 0, 0))
	by.teleport(near + Vector3(3.0, 0, 0))
	for h in m.hunters: h.ctrl = "bot"
	m.player.ctrl = "bot"
	T.pacts.clear()
	T.offers.clear()
	T._held.clear()
	T._cool.clear()
	T._fight.clear()
	m.guide = null
	var shown := func() -> bool:
		T.tick(0.0)
		return T.offers.has(0)
	# a fight (the squads hit each other) holds the offer back, however long it lasts
	T.on_damage(by, me, 3.0)
	T.emote(by, "truce")
	m.time += calm - 1.0
	if shown.call():
		good = false
		print("TCHECK FAIL offer shown %.1fs after a hit" % (calm - 1.0))
	m.time += 0.5
	T.on_damage(me, by, 3.0)
	m.time += calm - 1.0
	if shown.call():
		good = false
		print("TCHECK FAIL offer shown, a new hit came %.1fs ago" % (calm - 1.0))
	# calm for calm_s: it goes out
	m.time += 1.1
	if not shown.call():
		good = false
		print("TCHECK FAIL no offer after %.1fs calm" % calm)
	# a fight that never ends: the held offer is dropped, never shown
	T.offers.clear()
	T._cool.clear()
	T.emote(by, "truce")
	var t_end := m.time + Truce.HOLD_MAX + 1.0
	while m.time < t_end:
		m.time += 1.0
		T.on_damage(me, by, 1.0)
		if shown.call():
			good = false
			print("TCHECK FAIL offer shown mid-fight")
			break
	if not T._held.is_empty():
		good = false
		print("TCHECK FAIL held offer kept past the timeout")
	# the first-match guide: no offer at all
	T.offers.clear()
	T._cool.clear()
	m.time += calm + 1.0
	m.guide = FirstMatchGuide.new()
	T.emote(by, "truce")
	m.time += calm + 1.0
	if shown.call() or not T._held.is_empty():
		good = false
		print("TCHECK FAIL offer in the first-match guide")
	m.guide = null
	print("TCHECK calm offers: ", "ok" if good else "FAIL")
	return good
