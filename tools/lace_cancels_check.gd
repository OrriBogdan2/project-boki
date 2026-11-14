extends "res://tools/pin_bjorn_owner_check.gd"
## Lace's cancel pairs (docs/heroes/archer.md "Cancels"), run from --archer-combo-check: every row of
## content/dash_flow/archer.json names its source, the rows no source frame or card line settles are
## marked [?] and run owner item 51's default (combine), and the pairs that live only in the Cancels table
## do what it says: a press during the draw, during the Heavy Shot's hold and during Spirit Walk all go at
## once and the first action runs on (the X cast is the one that drops a draw). The LMB + Heavy Shot pair is
## ext/lace-one-bow's. Prints AKCHECK lines like --archetype-check.

## [file path to a row, the mode it runs]: the rows the source can't settle.
const UNSETTLED := [
	[["dash", "ground", "lmb"], "fire"], [["dash", "ground", "rmb"], "fire"], [["dash", "ground", "e"], "fire"],
	[["dash", "ground", "x"], "fire"], [["dash", "ground", "q"], "fire"],
	[["dash", "air", "lmb"], "fire"], [["dash", "air", "rmb"], "fire"], [["dash", "air", "e"], "fire"],
	[["dash", "air", "x"], "fire"], [["dash", "air", "q"], "fire"],
	[["into_dash", "rmb"], "fire"], [["into_dash", "e"], "fire"],
	[["hold", "rmb", "ground"], "keep"], [["hold", "rmb", "air"], "keep"], [["hold", "rmb", "jump"], "keep"],
]
const HOLD_S := 0.5             # s: a draw or a Heavy Shot hold well under way before the second press

func cancels() -> void:
	_rows()
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	P.lvl = 6
	step(m, 0.3)
	_during_draw(m, P, T, K)
	_during_heavy(m, P, T, K)
	_during_walk(m, P, T, K)
	await done(m)

func _row(path: Array) -> Dictionary:
	var at: Variant = DashFlow.file_of("archer")
	for key in path:
		at = (at as Dictionary).get(key, {})
	return at

func _rows() -> void:
	var file := DashFlow.file_of("archer")
	var bare := []
	for part in ["dash", "into_dash", "hold"]:
		_bare_rows(file.get(part, {}), part, bare)
	ok("lace cancels: every dash-flow row names its source", bare.is_empty(), str(bare))
	var off := []
	for u in UNSETTLED:
		var row := _row(u[0])
		if not (String(row.get("source", "")).begins_with("[?]") and String(row.get("mode", "")) == u[1]):
			off.append("/".join(u[0]))
	ok("lace cancels: the %d rows no source settles are [?] and run item 51's default" % UNSETTLED.size(),
		off.is_empty(), str(off))
	var named := ["ground", "air", "jump"].all(func(mv):
		return String(_row(["hold", "lmb", mv]).get("source", "")).contains("item 51"))
	ok("lace cancels: the draw through a jump or a dash is the owner's (item 51 names it)", named)

## The leaf rows under `node` (dicts with a mode) that have no source.
func _bare_rows(node: Dictionary, path: String, out: Array) -> void:
	if node.has("mode"):
		if String(node.get("source", "")) == "":
			out.append(path)
		return
	for key in node:
		if node[key] is Dictionary:
			_bare_rows(node[key], path + "/" + String(key), out)

func _start_draw(m: Match, P: Hunter, T: Hunter) -> void:
	step(m, 1.2)
	ready_bow(P)
	step(m, HOLD_S, press_at.bind(P, T.pos))

func _start_heavy(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	step(m, 1.2)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 2.0
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, HOLD_S, rmb_at.bind(P, T.pos))

func _let_go_all(m: Match, P: Hunter, K: ArcherKit) -> void:
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	step(m, 0.6)
	K.ult.end()

## The draw, then E (both: the wall goes up, the draw keeps charging) and then X (the cast drops the draw with
## no arrow; the held button nocks the first empowered shot at once).
func _during_draw(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	_start_draw(m, P, T)
	var t0 := P.draw_t
	cast_e_at(P, K, T.pos)
	step(m, 0.2, press_at.bind(P, T.pos))
	ok("lace cancels: draw > E: the wall goes up and the draw keeps charging",
		float(K.cd["e"]) > 0.0 and P.draw_t > t0 + 0.15, "e cd %.1f draw %.2f -> %.2f" % [K.cd["e"], t0, P.draw_t])
	_let_go_all(m, P, K)
	_start_draw(m, P, T)
	var loosed0 := K.draw.loosed_at
	K.cd["x"] = 0.0
	P.inp["fire"] = true
	press_x(m, P)
	step(m, 0.1, press_at.bind(P, T.pos))
	ok("lace cancels: draw > X: the draw is dropped with no arrow, the held button nocks an empowered shot",
		K.ult.active() and P.draw_t < 0.0 and K.draw.loosed_at == loosed0 and K.ult.nock_t >= 0.0,
		"ult %s draw %.2f loosed %s nock %.2f" % [K.ult.active(), P.draw_t, K.draw.loosed_at != loosed0, K.ult.nock_t])
	_let_go_all(m, P, K)

## The Heavy Shot held, then E, X and Shift: each goes at once and the hold carries on.
func _during_heavy(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	_start_heavy(m, P, T, K)
	cast_e_at(P, K, T.pos)
	step(m, 0.1, rmb_at.bind(P, T.pos))
	ok("lace cancels: Heavy Shot held > E: the wall goes up, the hold carries on",
		float(K.cd["e"]) > 0.0 and K.rmb_down and K.pin_aim, "e cd %.1f held %s" % [K.cd["e"], K.rmb_down])
	_let_go_all(m, P, K)
	_start_heavy(m, P, T, K)
	K.cd["x"] = 0.0
	press_x(m, P)
	step(m, 0.1, rmb_at.bind(P, T.pos))
	ok("lace cancels: Heavy Shot held > X: three shots empowered, the hold carries on",
		K.ult.active() and K.rmb_down, "ult %s held %s" % [K.ult.active(), K.rmb_down])
	_let_go_all(m, P, K)
	_start_heavy(m, P, T, K)
	P.dashes = P.max_dashes()
	P.do_dash()
	var rolling := P.roll_t > 0.0
	step(m, 0.35, rmb_at.bind(P, T.pos))
	ok("lace cancels: Heavy Shot held > Shift: she rolls at once, the hold carries through (into_dash.rmb)",
		rolling and K.rmb_down, "rolling %s held %s" % [rolling, K.rmb_down])
	_let_go_all(m, P, K)
	K.spirit.end("time")

## Spirit Walk under way (the roll over), then each slot: it goes and she walks on.
func _walk(m: Match, P: Hunter, K: ArcherKit) -> bool:
	step(m, 1.2)
	K.spirit.end("time")
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.4)
	return K.spirit.active() and P.roll_t <= 0.0

func _during_walk(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	var walking := _walk(m, P, K)
	ready_bow(P)
	var loosed0 := K.draw.loosed_at
	step(m, 0.3, press_at.bind(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.1)
	ok("lace cancels: Spirit Walk > LMB: she draws and looses, still walking",
		walking and K.draw.loosed_at > loosed0 and K.spirit.active(), "walking %s loosed %s on %s"
			% [walking, K.draw.loosed_at > loosed0, K.spirit.active()])
	walking = _walk(m, P, K)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 2.0
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.3, rmb_at.bind(P, T.pos))
	ok("lace cancels: Spirit Walk > RMB: the Heavy Shot draws, still walking",
		walking and K.rmb_down and K.spirit.active(),
		"walking %s held %s on %s" % [walking, K.rmb_down, K.spirit.active()])
	_let_go_all(m, P, K)
	walking = _walk(m, P, K)
	cast_e_at(P, K, T.pos)
	step(m, 0.1)
	ok("lace cancels: Spirit Walk > E: the wall goes up, still walking",
		walking and float(K.cd["e"]) > 0.0 and K.spirit.active(), "walking %s on %s" % [walking, K.spirit.active()])
	walking = _walk(m, P, K)
	K.cd["x"] = 0.0
	press_x(m, P)
	ok("lace cancels: Spirit Walk > X: three shots empowered, still walking",
		walking and K.ult.active() and K.spirit.active(), "walking %s ult %s on %s"
			% [walking, K.ult.active(), K.spirit.active()])
	K.ult.end()
	K.spirit.end("time")
