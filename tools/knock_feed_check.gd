extends RefCounted
## --knock-feed-check: the kill feed (KnockFeed) on the real HUD, headless.
##   1. a knock's icon is the slot icon on the knocker's own bar (RMB, E, X, dash), the weapon's for a plain
##      hit, the Boki's ability for a Boki's, KnockFeed.FALLBACK_ICON with nobody to credit
##   2. a knock row shows the knocker's face, that icon and the knocked Hunter's face, the names as they are (a
##      bot's bare tag), each side in its squad's colour; only rows with your squad in them are outlined
##   3. at most KnockFeed.ROWS rows, newest last; each fully shown HOLD_S, then fading, gone after LIFE_S
##   4. its own lane: no row wider than LANE_W (a long name is cut, a long line wraps), and at five window sizes
##      a full feed sits inside the safe margin and off every other HUD group, the widest message card included
##   5. online: the "knock" event carries the icon; a client's row shows it, an older peer's the fallback
## --knock-feed-shots --shots-dir=<dir> [--size=WxH]: a real match with four rows up (your knock, your Boki's, a
## teammate knocked, two rival squads), at 1280x720 and 2560x1080 or the one size: <WxH>_screen.png and the lane
## blown up to twice its logical size, <WxH>_lane.png.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080),
		Vector2i(1024, 640)]
const SHOT_SIZES := [Vector2i(1280, 720), Vector2i(2560, 1080)]
const DT := 1.0 / 60.0
const LONG_NAME := "Grimwhistle_of_the_Long_Hollow"
const LONG_LINE := "The wild Cindle is knocked out. Hold E beside it to scan it before its friends wake up."
const WIDE_TOAST := "A message as wide as the message lane gets: it wraps at the card's widest. "      # (said twice)

var main: Node
var m: Match
var P: Hunter
var bad := 0
var shots := ""
var sizes: Array = []

func ok(cond: bool, what: String) -> void:
	print("KNOCKFEED %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	sizes = SIZES.duplicate() if mode == "check" else SHOT_SIZES.duplicate()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			sizes = [Vector2i(int(wh[0]), int(wh[1]))]
	if main.fade:
		await main.fade.reveal(0.01)
	m = Match.new()
	main.add_child(m)
	var teams := 4 if mode == "check" else 10
	await m.start({"teams": teams, "squad": 3, "tier": 0, "length": 1e9, "seed": 7, "demo_kin": "cindle",
		"no_drop": true})
	m.set_process(false)
	P = m.player
	for h in m.hunters:
		if h != P:
			h.ctrl = "idle"
			h.inp["move"] = Vector2.ZERO
	if mode == "shots":
		await _shots()
	else:
		await _check()
	print("KNOCKFEED DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _check() -> void:
	_icons()
	await _rows()
	await _cap_and_fade()
	await _lane()
	await _online()

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Redraws the HUD panels and waits for the draw (KnockFeed.shown then holds what it put up).
func _redraw() -> void:
	m.hud.panels.queue_redraw()
	await _frames(3)

## The hunters on squads other than yours, one list per squad.
func _rival_squads() -> Array:
	var by_team := {}
	for h: Hunter in m.hunters:
		if h.team != P.team:
			if not by_team.has(h.team):
				by_team[h.team] = []
			by_team[h.team].append(h)
	return by_team.values()

func _ally() -> Hunter:
	return m.hunters.filter(func(h: Hunter): return h != P and h.team == P.team)[0]

# ------------------------------------------------------------------ 1. the icon
func _icons() -> void:
	var R: Hunter = _rival_squads()[0][0]
	var bar := {"utility": "sec", "k1": "k1", "ult": "x", "dodge": "dash"}
	for ab: String in bar:
		var want := String(R.slot_info(bar[ab]).get("icon", ""))
		var got := KnockFeed.icon_of(R, R, {"src": "abil", "ab": ab})
		ok(want != "" and got == want,
				"a knock by %s's '%s' shows its %s slot icon '%s' (got '%s')" % [R.pname, ab, bar[ab], want, got])
	ok(KnockFeed.icon_of(R, R, {"src": "shot"}) == R.wid and R.wid != "",
			"a plain shot or swing shows the weapon slot's icon '%s'" % R.wid)
	var k: Kin = P.kin
	var boki := KinText.icon(k.runner.def_of("k1"))
	ok(KnockFeed.icon_of(k, P, {"src": "kin", "ab": "k1"}) == boki, "a Boki's ability shows its icon '%s'" % boki)
	ok(KnockFeed.icon_of(k, P, {"src": "kin"}) == "paw", "a Boki's plain bite shows the paw")
	ok(KnockFeed.icon_of(null, null, {}) == KnockFeed.FALLBACK_ICON, "nobody to credit: the fallback icon")

# ------------------------------------------------------------------ 2. the rows
func _rows() -> void:
	m.feed.clear()
	var squads := _rival_squads()
	var A := _ally()
	var R1: Hunter = squads[0][0]
	var R2: Hunter = squads[1][0]
	var R3: Hunter = squads[2][0]
	m.knock(R1, P, {"src": "abil", "ab": "utility"})
	m.knock(A, R2, {"src": "shot"})
	m.knock(R3, squads[0][1], {"src": "abil", "ab": "k1"})
	m.knock(squads[1][1], null, {})
	await _redraw()
	var rows := KnockFeed.shown
	var all_knocks := rows.all(func(r): return r["kind"] == "knock")
	ok(rows.size() == 4 and all_knocks, "four knocks, four knock rows (%d)" % rows.size())
	if rows.size() < 4:
		return
	_row_is(rows[0], P, R1, String(P.slot_info("sec")["icon"]), true, "you knock a rival with RMB")
	_row_is(rows[1], R2, A, R2.wid, true, "a rival knocks your teammate")
	_row_is(rows[2], squads[0][1], R3, String(squads[0][1].slot_info("k1")["icon"]), false, "two rival squads")
	var lone: Dictionary = rows[3]
	ok(lone["left"] == "" and lone["right"] == squads[1][1].pname and lone["icon"] == KnockFeed.FALLBACK_ICON
			and lone["left_col"] == Color.TRANSPARENT and not lone["mine"],
			"nobody credited: the icon and the knocked side only (%s)" % [lone])
	var bare := func(n: String) -> bool: return n == "" or n == P.pname or Names.BOT.has(n)
	var names: Array = rows.map(func(r): return [r["left"], r["right"]])
	var all_bare := names.all(func(pair): return bare.call(pair[0]) and bare.call(pair[1]))
	ok(all_bare, "bots show their bare tags: %s" % [names])
	var faces := rows.map(func(r): return 2 if r["left"] != "" else 1)
	ok(faces == [2, 2, 2, 1], "faces: both sides of a credited knock, the knocked one alone (%s)" % [faces])

## One knock row: the names, the icon, the squad colours of both sides, and whether it is outlined as yours.
func _row_is(row: Dictionary, by: Hunter, who: Hunter, icon: String, mine: bool, what: String) -> void:
	var cols: Array = Data.TEAM_COLORS
	var squad_cols: bool = row["left_col"] == cols[by.team % cols.size()] \
			and row["right_col"] == cols[who.team % cols.size()]
	ok(row["left"] == by.pname and row["right"] == who.pname and row["icon"] == icon and icon != ""
			and squad_cols and bool(row["mine"]) == mine,
			"%s: %s [%s] %s, squad colours, outlined %s (%s)" % [what, by.pname, icon, who.pname, mine, row])

# ------------------------------------------------------------------ 3. how many, how long
## (Every rival squad keeps someone standing: a squad wiped out would add its own lines.)
func _cap_and_fade() -> void:
	var squads := _rival_squads()
	var last: Hunter = squads[1][0]
	m.knock(squads[0][1], squads[2][1], {"src": "shot"})
	m.knock(last, squads[2][2], {"src": "shot"})
	await _redraw()
	var rows := KnockFeed.shown
	ok(m.feed.size() == KnockFeed.ROWS and rows.size() == KnockFeed.ROWS and rows[-1]["right"] == last.pname,
			"six knocks keep the newest %d rows, the newest last (%d)" % [KnockFeed.ROWS, rows.size()])
	m.feed[0]["t"] = KnockFeed.HOLD_S - 0.1
	m.feed[1]["t"] = KnockFeed.HOLD_S + KnockFeed.FADE_S * 0.5
	await _redraw()
	rows = KnockFeed.shown
	var a0 := float(rows[0]["a"])
	var a1 := float(rows[1]["a"])
	ok(a0 == 1.0 and a1 > 0.0 and a1 < 1.0,
			"fully shown for %.1f s, then fading (%.2f, %.2f)" % [KnockFeed.HOLD_S, a0, a1])
	m.feed[0]["t"] = KnockFeed.LIFE_S - 0.0001
	m.hitstop = 0.0      # (the knocks' freeze frame holds the match's clocks, the feed's too)
	m.set_process(true)
	for i in 30:
		if m.feed.size() < KnockFeed.ROWS:
			break
		await _frames(1)
	m.set_process(false)
	ok(m.feed.size() == KnockFeed.ROWS - 1, "gone after %.1f s (%d left)" % [KnockFeed.LIFE_S, m.feed.size()])

# ------------------------------------------------------------------ 4. its own lane
func _lane() -> void:
	m.feed.clear()
	var squads := _rival_squads()
	var long_by: Hunter = squads[0][0]
	var long_who: Hunter = squads[1][0]
	var names := [long_by.pname, long_who.pname]
	long_by.pname = LONG_NAME
	long_who.pname = LONG_NAME + "_Too"
	KnockFeed.add(m, long_by, long_who, "skypierce")
	KnockFeed.add(m, P, long_who, "snare")
	KnockFeed.add(m, long_by, _ally(), "quake")
	m.add_feed(LONG_LINE)
	for win: Vector2i in sizes:
		main.get_tree().root.size = win
		await _frames(3)
		m.hud.msgs.clear()      # (a card takes its widest from the screen it was made on)
		m.hud.toast(WIDE_TOAST.repeat(2), Color.WHITE)
		m.hud.toast(WIDE_TOAST.repeat(3), Color.WHITE)
		var sz := main.get_tree().root.get_visible_rect().size
		SafeArea.seen.clear()
		SafeArea.recording = true
		await _redraw()
		SafeArea.recording = false
		var groups := SafeArea.seen.duplicate()
		groups["toasts"] = m.hud.msgs.rects()
		var clash := SafeArea.problems(groups, sz).filter(func(p: String): return p.contains("feed"))
		var rows := KnockFeed.shown
		var widest := 0.0
		for r: Dictionary in rows:
			widest = maxf(widest, (r["rect"] as Rect2).size.x)
		var tag := "%dx%d (logical %s)" % [win.x, win.y, sz]
		ok(rows.size() == 4 and widest <= KnockFeed.LANE_W and String(rows[0]["left"]).ends_with(KnockFeed.ELLIPSIS),
				"%s: four rows, none wider than %d px, long names cut (widest %.0f, '%s')"
				% [tag, KnockFeed.LANE_W, widest, rows[0]["left"]])
		ok(rows[3]["kind"] == "text" and (rows[3]["rect"] as Rect2).size.y > KnockFeed.TEXT_H,
				"%s: a long line wraps inside the lane" % tag)
		var card_w := 0.0
		for t: Rect2 in groups["toasts"]:
			card_w = maxf(card_w, t.size.x)
		ok(card_w >= sz.x * MsgLane.WIDE, "%s: the message cards are at their widest (%.0f px)" % [tag, card_w])
		ok(groups.has("feed") and clash.is_empty(),
				"%s: the lane sits in the margin, off the %d other groups and two widest message cards %s"
				% [tag, groups.size() - 1, clash.slice(0, 4)])
	long_by.pname = names[0]
	long_who.pname = names[1]

# ------------------------------------------------------------------ 5. online
func _online() -> void:
	m.feed.clear()
	var squads := _rival_squads()
	var who: Hunter = squads[2][1]
	var icon := String(P.slot_info("sec")["icon"])
	Net.out_events.clear()
	m.net_on = true
	m.knock(who, P, {"src": "abil", "ab": "utility"})
	m.net_on = false
	var sent: Array = Net.out_events.filter(func(e): return e[0] == "knock")
	Net.out_events.clear()
	ok(sent.size() == 1 and sent[0] == ["knock", who.nid, P.nid, icon],
			"the knock event carries the icon (%s)" % [sent])
	var by: Hunter = squads[0][0]
	var heard: Hunter = squads[1][2]
	m._net_ev(["knock", heard.nid, by.nid, "barrage"], "peer")
	var older: Hunter = squads[0][2]
	m._net_ev(["knock", older.nid, by.nid], "peer")
	ok(m.feed.size() == 3 and m.feed[1]["icon"] == "barrage" and m.feed[1]["by"] == by and m.feed[1]["who"] == heard,
			"a client's row shows the icon it was sent")
	ok(m.feed.size() == 3 and m.feed[2]["icon"] == KnockFeed.FALLBACK_ICON,
			"an older peer's event (no icon): the fallback")

# ------------------------------------------------------------------ shots
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var home := m.world.random_ground()
	P.teleport(home)
	var squads := _rival_squads()
	for i in 3:
		var h: Hunter = squads[i][0]
		h.teleport(m.world.free_spot_near(home + Vector3(-3.0 + 3.0 * i, 0, -4.0), [], 0.8, 0.4, 3.0))
	P.inp["aim"] = home + Vector3(0, 0.9, -6)
	m.knock(squads[0][0], P, {"src": "abil", "ab": "utility"})
	m.knock(squads[1][0], P.kin, {"src": "kin", "ab": "k1"})
	m.knock(_ally(), squads[2][0], {"src": "abil", "ab": "ult"})
	m.knock(squads[3][0], squads[4][0], {"src": "shot"})
	await _go(1.0)      # (the faces are cut on a worker: give it a moment)
	for win: Vector2i in sizes:
		main.get_tree().root.size = win
		await _go(0.4)
		var sz := main.get_tree().root.get_visible_rect().size
		var img := main.get_viewport().get_texture().get_image()
		var tag := "%dx%d" % [win.x, win.y]
		img.save_png(shots.path_join(tag + "_screen.png"))
		_save_lane(img, sz, tag)
		var drawn := KnockFeed.shown.map(func(r): return [r["left"], r["icon"], r["right"]])
		ok(drawn.size() == 4, "%s: four rows up (%s)" % [tag, drawn])

## The lane cut out of the screen and blown up to twice its logical size.
func _save_lane(img: Image, sz: Vector2, tag: String) -> void:
	var lane := Rect2()
	for r: Dictionary in KnockFeed.shown:
		lane = r["rect"] if lane.size == Vector2.ZERO else lane.merge(r["rect"])
	lane = lane.grow(8.0)
	var k := Vector2(img.get_size()) / sz
	var px := Rect2i(Vector2i(lane.position * k), Vector2i(lane.size * k))
	px = px.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cut := img.get_region(px)
	cut.resize(int(lane.size.x * 2.0), int(lane.size.y * 2.0), Image.INTERPOLATE_LANCZOS)
	cut.save_png(shots.path_join(tag + "_lane.png"))

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		m.hud.panels.queue_redraw()
		await main.get_tree().process_frame
