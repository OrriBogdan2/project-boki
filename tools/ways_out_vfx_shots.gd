extends RefCounted
## --ways-out-vfx-shots --shots-dir=<dir> [--quality=low|high]: does every Ways Out state read at the match camera
## (decision 0051 "Seat looks")? Rows, in match order (the seats' machines only move forward): the Sealed Lair raced
## by a rival squad and won; the Heart locked (its Heartspark charging), unlocked (the spark out, the Gate open) and
## its early seat used; the Uplink open, raced and won; the Blight's edge. Columns: the player 8 m (the seat in
## frame), 20, 40 and 60 m from the seat (from the wall in the Blight row), the seat ahead and to the right where the
## ground allows, the match camera (style, zoom, no lean), two rivals fighting at the player's side. Writes
## <row>_<m>.jpg and sheet_<preset>.jpg (every frame, captioned in the frame). Needs a renderer (jobq submit --needs
## gpu).

const DISTS := [8.0, 20.0, 40.0, 60.0]    # m from the player to the seat (to the wall: the Blight row)
const SETTLE := 40                         # frames each shot runs before the grab
const THUMB := 3                           # the sheet keeps every frame at 1/THUMB size
const RIVAL := 3                           # the squad on the seats (teams 1 and 2 fight at the player's side)

var main: Node
var m: Match
var dir := ""
var P: Hunter
var user: Hunter
var duel: Array = []
var pin := Callable()                      # re-applies the row's state every frame (the host would move it on)
var t_sess := 0.0                          # the session clock the row is shot at
var spot := Vector3.ZERO
var cap: Label
var shots: Array = []                      # one Image per frame, row by row

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var H := m.heart
	var L: Dictionary = m.exits.seats.lair.ref
	var X: Dictionary = m.exits.seats.uplink.ref
	var heart_locked := func():
		H._force(Heart.S.CHARGING, "shots")
		H.charge = 30.0
	var heart_open := func():
		H.charge = Heart.r("charge_s")
		H.spark_pos = H.site
		H._force(Heart.S.READY, "shots")
	var heart_used := func():
		H.early_team = RIVAL
		H._force(Heart.S.WAITING, "shots")
	var lair_racing := func():
		L["state"] = "awake"
		L["locked"] = true
		L["lock_at"] = m.time
		L["sealed_in"] = [user]
	var lair_won := func():
		L["state"] = "cleared"
		L["locked"] = false
		L["won_by"] = RIVAL
		L["victory"] = true
		L["sealed_in"] = []
		L["flown"] = [user]
	var uplink_open := func():
		X["state"] = "idle"
		X["team"] = -1
	var uplink_racing := func():
		X["state"] = "charging"
		X["team"] = RIVAL
		X["prog"] = 0.6
	var uplink_won := func():
		if m.exits.seats.uplink.state != QuestSeat.S.TAKEN:
			m.exits.seats.uplink._force(QuestSeat.S.TAKEN, "shots", RIVAL)      # (the lift ridden)
		X["state"] = "closed"
		X["team"] = RIVAL
		X["taken"] = true
	user.teleport(m.world.free_spot_near(L["c"], [], 1.0, 0.45, 6.0))
	await _row("lair_racing", "Sealed Lair raced (rival)", 180.0, L["c"], lair_racing)
	await _row("lair_won", "Sealed Lair won (rival)", 240.0, L["c"], lair_won)
	await _row("heart_locked", "Heart locked (charging)", 270.0, H.site, heart_locked, false)
	await _row("heart_unlocked", "Heart unlocked (spark out, Gate open)", 330.0, H.site, heart_open, false)
	await _row("heart_early_used", "Heart early seat used", 350.0, H.site, heart_used, false)
	await _row("uplink_open", "Uplink open", 390.0, X["pos"], uplink_open)
	await _row("uplink_racing", "Uplink raced (rival)", 400.0, X["pos"], uplink_racing)
	await _row("uplink_won", "Uplink won (rival)", 450.0, X["pos"], uplink_won)
	await _blight_row()
	_sheet()
	print("WAYSSHOT done quality=%s frames=%d" % [Settings.quality(), shots.size()])
	main.get_tree().quit(0)

func _setup() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "heart": true, "god": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.exits.seats.build()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 50000.0
		h.hp = h.max_hp
		if h.team == RIVAL:
			user = h
		elif h != P and duel.size() < 2:
			duel.append(h)
	var layer := CanvasLayer.new()
	layer.layer = 120
	main.add_child(layer)
	cap = Label.new()
	cap.label_settings = LabelSettings.new()
	cap.label_settings.font_size = 36
	cap.label_settings.outline_size = 12
	cap.label_settings.outline_color = Color.BLACK
	var sz := main.get_viewport().get_visible_rect().size
	cap.position = Vector2(sz.x * 0.29, sz.y - 64.0)      # between the ability bar and the weapon card
	layer.add_child(cap)

## One state, shot from each of DISTS. `put` sets it, and again every frame when `keep` (the quest seats' own
## ticks would move a forced state on; the Heart's forced states hold by themselves).
func _row(id: String, word: String, t: float, at: Vector3, put: Callable, keep := true) -> void:
	t_sess = t
	pin = put if keep else Callable()
	_clock()
	put.call()
	for d: float in DISTS:
		spot = _stand(at, d)
		await _shoot(id, word, spot.distance_to(Vector3(at.x, spot.y, at.z)))

## The Blight's wall, 8..60 m off: one spot on the island far enough from the Heart for the closed ring to stand 8 m
## off it (ground under the wall there preferred), the ring set by the clock.
func _blight_row() -> void:
	pin = Callable()
	var site := m.heart.site
	var k := m.heart.ways_scale
	var lo := ceili(Heart.r("tide_r1") * k - float(DISTS[0]))
	var at := _blight_spot(lo, true)
	if at == Vector3.INF:
		at = _blight_spot(lo, false)
	var rs_now := Vector2(at.x - site.x, at.z - site.z).length()
	for d: float in DISTS:
		var f := (Heart.r("tide_r0") - (rs_now + d) / k) / (Heart.r("tide_r0") - Heart.r("tide_r1"))
		t_sess = Heart.r("tide_start_s") + Heart.r("tide_close_s") * f
		spot = at
		await _shoot("blight_edge", "Blight edge", d)

## A spot lo..lo+16 m out from the Heart (farthest first, the bearings as _stand's) on ground, with ground under the
## nearest wall too when `wall`; Vector3.INF when there is none.
func _blight_spot(lo: int, wall: bool) -> Vector3:
	for rs in range(lo + 16, lo - 1, -2):
		for i in 12:
			var b := deg_to_rad(35.0 + 30.0 * i)
			var a := Vector3(sin(b), 0, -cos(b))
			var g := m.heart.site + a * rs
			var w := m.heart.site + a * (rs + float(DISTS[0]))
			if not m.world.is_void(g.x, g.z) and not (wall and m.world.is_void(w.x, w.z)):
				return m.world.free_spot_near(g, [], 1.0, 0.45, 2.0)
	return Vector3.INF

## A spot `d` m from `at`, on ground and inside the Blight's ring: the seat ahead and to the right first.
func _stand(at: Vector3, d: float) -> Vector3:
	var best := Vector3.INF
	for i in 12:
		var a := deg_to_rad(35.0 + 30.0 * i)
		var p := m.world.free_spot_near(at - Vector3(sin(a), 0, -cos(a)) * d, [], 1.0, 0.45, 3.0)
		var off := absf(Vector2(p.x - at.x, p.z - at.z).length() - d)
		if m.world.is_void(p.x, p.z) or off > 3.5:
			continue
		if Heart.tide_out(m, p) <= 0.0:
			return p
		if best == Vector3.INF:
			best = p
	return best if best != Vector3.INF else at

func _clock() -> void:
	m.time = t_sess - m.sess_t0

func _shoot(id: String, word: String, d: float) -> void:
	P.teleport(spot)
	for i in duel.size():
		var h: Hunter = duel[i]
		h.teleport(m.world.free_spot_near(spot + Vector3(-3.0 - 3.0 * i, 0, 2.0), [spot], 1.0, 0.45, 4.0))
		h.ctrl = "bot"
		h.hp = h.max_hp
	cap.text = "%s  ·  %d m  ·  %s" % [word, int(round(d)), Settings.quality()]
	for _f in SETTLE:
		_clock()
		if pin.is_valid():
			pin.call()
		m.step(Match.DT)
		_clock()
		P.teleport(spot)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_jpg(dir.path_join("%s_%dm.jpg" % [id, int(round(d))]), 0.85)
	shots.append(img)
	print("WAYSSHOT ", id, " ", int(round(d)))

## Every frame at 1/THUMB size, one row per state, one column per distance.
func _sheet() -> void:
	var w: int = shots[0].get_width() / THUMB
	var hh: int = shots[0].get_height() / THUMB
	var cols := DISTS.size()
	var sheet := Image.create(w * cols, hh * (shots.size() / cols), false, Image.FORMAT_RGB8)
	for i in shots.size():
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, hh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, w, hh), Vector2i((i % cols) * w, (i / cols) * hh))
	sheet.save_jpg(dir.path_join("sheet_%s.jpg" % Settings.quality()), 0.85)
