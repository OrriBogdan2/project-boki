class_name BaseGreet
extends RefCounted
## The Greet state of base life (GARDEN.md section 4): when you arrive in a garden zone, by the teleporter or
## after a long absence (KinWelcome hands it over in base_mode), every awake Boki within radius_m of you
## reacts once. A close or soulbound one runs to you and hops, a sulking one turns its back and walks off,
## a shy one peeks at you and waves; a friendly one in between runs with a chance from how clingy it is,
## else it peeks. Napping Boki sleep on. You are never held: it is only the Boki's own state.
## BaseLife runs this from its machine: k["life_greet"] = {how, wait, on, slot}. Tuning: base_life.json "greet".

## Every awake, free Boki near you picks its one reaction; the keenest notice you first.
static func arrive(life: BaseLife) -> void:
	var gr: Dictionary = life.R["greet"]
	var h = life.h
	var near: Array = h.kins.filter(func(k): return life.awake_free(k) \
		and Vector2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z).length() <= float(gr["radius_m"]))
	near.sort_custom(func(a, b): return float(a["rec"]["trust"]) > float(b["rec"]["trust"]))
	for i in near.size():
		var k: Dictionary = near[i]
		var how := pick(k["rec"], k.get("pers", {}), life.R)
		var wait := float(gr["notice_s"]) + i * float(gr["stagger_s"])
		k["life_greet"] = {"how": how, "wait": wait, "on": false, "slot": i}
		k["t"] = wait + float(gr["give_up_s"])
		if not life.machine(k).go(BaseLife.S.GREET, how):
			k.erase("life_greet")

## "run", "peek" or "sulk" for this Boki, from its trust, its joy and how clingy it is (pers.cling). Sulky and
## shy are the whistle's own lines (base_life.json "whistle"), so a Boki is one mood to both.
static func pick(rec: Dictionary, pers: Dictionary, rules: Dictionary) -> String:
	var gr: Dictionary = rules["greet"]
	var trust := float(rec["trust"])
	if trust >= float(gr["soulbound_trust"]):
		return "run"      # soulbound: never refuses you, sulky or not
	if Care.need(rec, "joy") < float(rules["whistle"]["sulky_joy"]):
		return "sulk"
	if trust >= float(gr["close_trust"]):
		return "run"
	if trust < float(rules["whistle"]["shy_trust"]):
		return "peek"
	return "run" if randf() < float(pers.get("cling", 0.25)) * float(gr["cling_run"]) else "peek"

static func tick(life: BaseLife, k: Dictionary, m: Fsm) -> void:
	var gr: Dictionary = life.R["greet"]
	var h = life.h
	var g: Dictionary = k["life_greet"]
	if m.since < float(g["wait"]):
		k["goal"] = k["pos"]      # it has not noticed you yet
		return
	if not g["on"]:
		g["on"] = true
		_notice(h, k, g, gr)
	var acted := m.since - float(g["wait"])
	match g["how"]:
		"run":
			if g.has("hopped"):
				k["goal"] = k["pos"]
				if acted - float(g["hopped"]) >= float(gr["hop_s"]):
					m.go(BaseLife.S.ROAM, "greeted")
				return
			var angle: float = TAU * int(g["slot"]) / 6.0 + 0.4
			k["goal"] = h.ppos + Vector3(cos(angle), 0, sin(angle)) * float(gr["slot_m"])
			if Vector2(k["goal"].x - k["pos"].x, k["goal"].z - k["pos"].z).length() < float(gr["reach_m"]):
				g["hopped"] = acted
				_hop(h, k)
			elif acted >= float(gr["give_up_s"]):
				m.go(BaseLife.S.ROAM, "gave up")
		"peek":
			k["goal"] = k["pos"]      # an idle Boki faces you (home.gd _move_kin)
			if acted >= float(gr["peek_s"]):
				m.go(BaseLife.S.ROAM, "peeked")
		"sulk":
			if acted >= float(gr["sulk_s"]):
				m.go(BaseLife.S.ROAM, "sulked")

## The moment it notices you: a mark over its head, and a sulking one turns its back and walks a few steps off.
static func _notice(h, k: Dictionary, g: Dictionary, gr: Dictionary) -> void:
	match g["how"]:
		"run":
			h._emote(k, "!", true)
			k["greet_run"] = true      # runs at the come-to-you pace (home.gd _move_kin)
			Sfx.play("kin_alert", k["pos"], -12.0, 0.15, Unique.voice(k["rec"]))
		"peek":
			h._emote(k, "?", true)
			k["joy_t"] = float(gr["wave_s"])      # a little bounce: its wave
		"sulk":
			h._emote(k, "…", true)
			var away := Vector3(k["pos"].x - h.ppos.x, 0, k["pos"].z - h.ppos.z).normalized()
			var to: Vector3 = k["pos"] + away * float(gr["away_m"])
			k["goal"] = to if not h.world.is_void(to.x, to.z) else k["pos"]

static func _hop(h, k: Dictionary) -> void:
	k["joy_t"] = 0.9
	h._emote(k, "♥", true)
	Sfx.play("kin_happy", k["pos"], -10.0, 0.15, Unique.voice(k["rec"]))
	h._say(k, BokiLines.say(k["rec"], "greet"))
