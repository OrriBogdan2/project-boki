extends "res://tools/pin_bjorn_owner_check.gd"
## Lace's cancel pairs (docs/heroes/archer.md "Cancels"), run from --archer-combo-check: every row of
## content/dash_flow/archer.json names its source, the rows no source frame or card line settles are
## marked [?] and run owner item 51's default (combine), and the pairs that live only in the Cancels table
## do what it says: a press during the draw, during the Heavy Shot's hold and during Spirit Walk all go at
## once and the first action runs on (the X cast is the one that drops a draw). The LMB + Heavy Shot pair is
## ext/lace-one-bow's. Prints AKCHECK lines like --archetype-check.

## [file path to a row, the mode it runs]: the rows the source can't settle.
const UNSETTLED := [
	[["dash", "ground", "lmb"], "fire"],
	[["dash", "ground", "rmb"], "fire"],
	[["dash", "ground", "e"], "fire"],
	[["dash", "ground", "x"], "fire"],
	[["dash", "ground", "q"], "fire"],
	[["dash", "air", "lmb"], "fire"],
	[["dash", "air", "rmb"], "fire"],
	[["dash", "air", "e"], "fire"],
	[["dash", "air", "x"], "fire"],
	[["dash", "air", "q"], "fire"],
	[["into_dash", "rmb"], "fire"],
	[["into_dash", "e"], "fire"],
	[["hold", "rmb", "ground"], "keep"],
	[["hold", "rmb", "air"], "keep"],
	[["hold", "rmb", "jump"], "keep"],
]
const HOLD_S := 0.5  # s: a draw or a Heavy Shot hold well under way before the second press


func cancels() -> void:
	_rows()
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: ArcherKit = p.ak
	p.equip("longbow", 0)
	p.lvl = 6
	step(m, 0.3)
	_during_draw(m, p, t, k)
	_during_heavy(m, p, t, k)
	_during_walk(m, p, t, k)
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
	ok(
		"lace cancels: the %d rows no source settles are [?] and run item 51's default" % UNSETTLED.size(),
		off.is_empty(),
		str(off)
	)
	var named := ["ground", "air", "jump"].all(
		func(mv): return String(_row(["hold", "lmb", mv]).get("source", "")).contains("item 51")
	)
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


func _start_draw(m: Match, p: Hunter, t: Hunter) -> void:
	step(m, 1.2)
	ready_bow(p)
	step(m, HOLD_S, press_at.bind(p, t.pos))


func _start_heavy(m: Match, p: Hunter, t: Hunter, k: ArcherKit) -> void:
	step(m, 1.2)
	k.cd["rmb"] = 0.0
	k.ch_rmb = 2.0
	p.inp["sec_hold"] = true
	k.press_rmb()
	step(m, HOLD_S, rmb_at.bind(p, t.pos))


func _let_go_all(m: Match, p: Hunter, k: ArcherKit) -> void:
	p.inp["fire"] = false
	p.inp["sec_hold"] = false
	step(m, 0.6)
	k.ult.end()


## The draw, then E (both: the wall goes up, the draw keeps charging) and then X (the cast drops the draw with
## no arrow; the held button nocks the first empowered shot at once).
func _during_draw(m: Match, p: Hunter, t: Hunter, k: ArcherKit) -> void:
	_start_draw(m, p, t)
	var t0 := p.draw_t
	cast_e_at(p, k, t.pos)
	step(m, 0.2, press_at.bind(p, t.pos))
	ok(
		"lace cancels: draw > E: the wall goes up and the draw keeps charging",
		float(k.cd["e"]) > 0.0 and p.draw_t > t0 + 0.15,
		"e cd %.1f draw %.2f -> %.2f" % [k.cd["e"], t0, p.draw_t]
	)
	_let_go_all(m, p, k)
	_start_draw(m, p, t)
	var loosed0 := k.draw.loosed_at
	k.cd["x"] = 0.0
	p.inp["fire"] = true
	press_x(m, p)
	step(m, 0.1, press_at.bind(p, t.pos))
	ok(
		"lace cancels: draw > X: the draw is dropped with no arrow, the held button nocks an empowered shot",
		k.ult.active() and p.draw_t < 0.0 and k.draw.loosed_at == loosed0 and k.ult.nock_t >= 0.0,
		"ult %s draw %.2f loosed %s nock %.2f" % [k.ult.active(), p.draw_t, k.draw.loosed_at != loosed0, k.ult.nock_t]
	)
	_let_go_all(m, p, k)


## The Heavy Shot held, then E, X and Shift: each goes at once and the hold carries on.
func _during_heavy(m: Match, p: Hunter, t: Hunter, k: ArcherKit) -> void:
	_start_heavy(m, p, t, k)
	cast_e_at(p, k, t.pos)
	step(m, 0.1, rmb_at.bind(p, t.pos))
	ok(
		"lace cancels: Heavy Shot held > E: the wall goes up, the hold carries on",
		float(k.cd["e"]) > 0.0 and k.rmb_down and k.pin_aim,
		"e cd %.1f held %s" % [k.cd["e"], k.rmb_down]
	)
	_let_go_all(m, p, k)
	_start_heavy(m, p, t, k)
	k.cd["x"] = 0.0
	press_x(m, p)
	step(m, 0.1, rmb_at.bind(p, t.pos))
	ok(
		"lace cancels: Heavy Shot held > X: three shots empowered, the hold carries on",
		k.ult.active() and k.rmb_down,
		"ult %s held %s" % [k.ult.active(), k.rmb_down]
	)
	_let_go_all(m, p, k)
	_start_heavy(m, p, t, k)
	p.dashes = p.max_dashes()
	p.do_dash()
	var rolling := p.roll_t > 0.0
	step(m, 0.35, rmb_at.bind(p, t.pos))
	ok(
		"lace cancels: Heavy Shot held > Shift: she rolls at once, the hold carries through (into_dash.rmb)",
		rolling and k.rmb_down,
		"rolling %s held %s" % [rolling, k.rmb_down]
	)
	_let_go_all(m, p, k)
	k.spirit.end("time")


## Spirit Walk under way (the roll over), then each slot: it goes and she walks on.
func _walk(m: Match, p: Hunter, k: ArcherKit) -> bool:
	step(m, 1.2)
	k.spirit.end("time")
	p.dashes = p.max_dashes()
	p.do_dash()
	step(m, 0.4)
	return k.spirit.active() and p.roll_t <= 0.0


func _during_walk(m: Match, p: Hunter, t: Hunter, k: ArcherKit) -> void:
	var walking := _walk(m, p, k)
	ready_bow(p)
	var loosed0 := k.draw.loosed_at
	step(m, 0.3, press_at.bind(p, t.pos))
	p.inp["fire"] = false
	step(m, 0.1)
	ok(
		"lace cancels: Spirit Walk > LMB: she draws and looses, still walking",
		walking and k.draw.loosed_at > loosed0 and k.spirit.active(),
		"walking %s loosed %s on %s" % [walking, k.draw.loosed_at > loosed0, k.spirit.active()]
	)
	walking = _walk(m, p, k)
	k.cd["rmb"] = 0.0
	k.ch_rmb = 2.0
	p.inp["sec_hold"] = true
	k.press_rmb()
	step(m, 0.3, rmb_at.bind(p, t.pos))
	ok(
		"lace cancels: Spirit Walk > RMB: the Heavy Shot draws, still walking",
		walking and k.rmb_down and k.spirit.active(),
		"walking %s held %s on %s" % [walking, k.rmb_down, k.spirit.active()]
	)
	_let_go_all(m, p, k)
	walking = _walk(m, p, k)
	cast_e_at(p, k, t.pos)
	step(m, 0.1)
	ok(
		"lace cancels: Spirit Walk > E: the wall goes up, still walking",
		walking and float(k.cd["e"]) > 0.0 and k.spirit.active(),
		"walking %s on %s" % [walking, k.spirit.active()]
	)
	walking = _walk(m, p, k)
	k.cd["x"] = 0.0
	press_x(m, p)
	ok(
		"lace cancels: Spirit Walk > X: three shots empowered, still walking",
		walking and k.ult.active() and k.spirit.active(),
		"walking %s ult %s on %s" % [walking, k.ult.active(), k.spirit.active()]
	)
	k.ult.end()
	k.spirit.end("time")
