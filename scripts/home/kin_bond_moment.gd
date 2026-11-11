class_name KinBondMoment
extends RefCounted
## The moment a Boki's bond with you goes up a rank (Care.BONDS: Friendly, Close, Devoted,
## Soulbound): it hops to you with a heart, says so, and a card names what the new rank brings.
## rec["bond_seen"] is the last rank it celebrated, so a rank earned on an expedition plays when
## you get home, and each rank plays once. The rank it has the first time the farm sees it (a
## hatchling, a stray, an old save) is where it starts: nothing to celebrate yet.

## The first farm Boki with a rank it hasn't celebrated yet, or {}.
static func due(kins: Array) -> Dictionary:
	for k in kins:
		var rec: Dictionary = k["rec"]
		if not rec.has("bond_seen"):
			rec["bond_seen"] = Care.bond_index(rec)
		elif Care.bond_index(rec) > int(rec["bond_seen"]):
			return k
	return {}

## Called once a second at home: plays the next due moment when nothing else is on screen.
static func tick(home: Node) -> void:
	if home.panel_open != "" or home.building_now or not home.train.is_empty() or FarmTutorial.active():
		return
	var k := due(home.kins)
	if not k.is_empty() and not k.get("busy", false):
		play(home, k)

static func play(home: Node, k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var rank: Array = Care.bond(rec)
	rec["bond_seen"] = Care.bond_index(rec)
	Save.save_game()
	var at: Vector3 = k["pos"]
	k["goal"] = home.ppos
	k["joy_t"] = 1.4
	home._emote(k, "♥", true)
	home.fx.burst(at + Vector3(0, 0.9, 0), Color("ff8fb0"), 24, 2.6)
	home.fx.ring(at, 2.2, Color(1.0, 0.56, 0.69, 0.9), 0.5)
	Sfx.play("unlock")
	Sfx.play("kin_happy", null, -2.0, 0.1, Unique.voice(rec))
	home._say(k, BokiLines.say(rec, "bond_up"))
	var v: VBoxContainer = home._new_panel("%s is now %s" % [rec["name"], rank[1]], 520)
	v.add_child(UI.label(String(rank[2]), 16, Color("ffb3c6")))
	var nxt: Array = Care.next_bond(rec)
	var more := "Keep looking after it and take it along on expeditions."
	if not nxt.is_empty():
		more = "Next: %s at %d trust. %s" % [nxt[1], int(nxt[0]), more]
	v.add_child(UI.para(more, 13, UI.MUTED))
