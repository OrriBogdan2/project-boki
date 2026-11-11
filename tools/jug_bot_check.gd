extends RefCounted
## Bot Kael's RMB (docs/BOT_KIT_USE.md): a bot taps the Finishing Slam only with the foe in the
## lane it locks at the press, and the strike lands; a foe beside that lane gets no tap. Runs inside
## --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
const SIDE := 1.5      # m: the foe this far beside the aim line, well outside the 0.72 m lane plus his body
var A: AKCheck

func run(a) -> void:
	A = a
	var r := A.setup("juggernaut", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	A.step(m, 0.5)
	# only the Smash can answer: no ult, no chain, no Rampage charge
	K.cd["x"] = 99.0
	K.cd["e"] = 99.0
	# a foe beside the lane: the aim straight ahead, the foe off to the side
	_arm(K, P)
	T.teleport(home + Vector3(2.5, 0, SIDE))
	A.aim_at(P, home + Vector3(2.5, 0, 0))
	K.bot_use(T, P.flat_dist(T), true)
	var beside_sec: bool = P.inp["sec"]
	P.inp["sec"] = false
	A.step(m, 1.0)
	A.ok("jug bot: no tap at a foe beside the locked lane (aim ahead, foe %.1fm aside)" % SIDE,
			not beside_sec and K.slam_w.is_empty() and K.last_variant != "tap",
			"sec %s variant %s" % [beside_sec, K.last_variant])
	# a foe standing in the lane: the tap, and the Slam lands on them
	_arm(K, P)
	T.teleport(home + Vector3(3.0, 0, 0))
	var hp0 := T.hp
	K.bot_use(T, P.flat_dist(T), true)
	var lane_sec: bool = P.inp["sec"]
	var held := float(K.bot_hold["rmb"])
	A.step(m, Match.DT)
	P.inp["sec"] = false
	A.step(m, 1.0)
	var tapped := K.last_variant == "tap"
	A.ok("jug bot: a foe in the lane gets the tap (no hold) and the Finishing Slam lands",
			lane_sec and tapped and held <= 0.0 and T.hp < hp0,
			"sec %s tapped %s hp %.0f -> %.0f" % [lane_sec, tapped, hp0, T.hp])
	await A.done(m)

## The Smash ready, no Rampage charge, nothing pressed.
func _arm(K: JuggernautKit, P: Hunter) -> void:
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.last_variant = ""
	P.dashes = 0.0
	P.inp["sec"] = false
