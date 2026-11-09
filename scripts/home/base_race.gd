class_name BaseRace
extends RefCounted
## The Dash (briefs/design/GARDEN.md section 5): two to four of your Boki race a short loop from the
## start post beside the Training post: a straight, a pond, a climb and a gap to jump. Pace comes from
## Care stats, the element lean (a lean speeds up the stretch that suits it) and mood, plus a random
## wobble. You cheer for one Boki with three timed presses on the Training post's drill bar
## (TimingDrill). The winner gets a heart, joy and trust; losers sulk and remember; you get a few gems.
## Tuning lives in content/rules/race.json.
##
## The race itself (new_run, step, cheer, settle) is plain data, so --race-check runs it headless.
## home.gd calls build(), tick(d), input(event), near(p2), prompt() and start().

const POST_OFF := Vector3(1.9, 0, 1.6)      # the start post, from the Training post (metres)
const POST_REACH := 1.6                     # how close you stand to use the post (metres)
const LANE_W := 0.55                        # metres between runners side by side
const CLIMB_H := 0.7                        # top of the climb (metres); the gap drops back to the ground
const HOP_H := 0.8                          # extra height of the jump over the gap (metres)
const CARD_S := 6.0                         # how long the result card stays up (seconds)
const MAX_RUNNERS := 4
const RACED := "dash_raced"                 # Save.d["tutorial"] flag: a Dash has been run on this save
const HINT := "dash_hint"                   # Save.d["tutorial"] flag: the first-race card was shown
const WORD_S := 1.2                         # how long the Great / Early / Late word floats (seconds)

static var _rules := {}
static var _course: Array = []              # stretches with "a", "b" (Vector2), "len", "start"
static var _loop_len := 0.0

var h                                       # the Home screen
var node: Node3D = null                     # the start post and the course, placed off the yard
var run := {}                               # the race in progress (empty when there is none)
var kins_in: Array = []                     # home kin entries, in the same order as run["runners"]
var drill := {}                             # the cheer bar in progress, a TimingDrill state plus "t"
var bar: Control = null
var bar_draw: Control = null
var card: Control = null
var card_t := 0.0
var glow: MeshInstance3D = null             # the first race's glowing first mark, until the bar opens

func _init(home) -> void:
	h = home

# ------------------------------------------------------------------ the rules and the course
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = Content.rules("race")
	return _rules

static func course() -> Array:
	if _course.is_empty():
		var at := Vector2.ZERO
		for s in rules()["stretches"]:
			var st: Dictionary = (s as Dictionary).duplicate()
			var to := Vector2(float(s["to"][0]), float(s["to"][1]))
			st["a"] = at
			st["b"] = to
			st["len"] = at.distance_to(to)
			st["start"] = _loop_len
			_loop_len += float(st["len"])
			_course.append(st)
			at = to
	return _course

static func loop_len() -> float:
	course()
	return _loop_len

static func stretch_at(dist: float) -> Dictionary:
	for s in course():
		if dist < float(s["start"]) + float(s["len"]):
			return s
	return course()[-1]

## The element a Boki leans to: its strongest food lean (rec["lean"], GARDEN.md 9.1) once it has
## one, otherwise its species' type.
static func lean_of(rec: Dictionary) -> String:
	var best := ""
	var most := 0.0
	var lean: Dictionary = rec.get("lean", {})
	for el in lean:
		if float(lean[el]) > most:
			most = float(lean[el])
			best = String(el)
	return best if best != "" else BokiLines.element_of(String(rec.get("species", "")))

## Metres a second on one stretch, before the wobble and cheers.
static func pace(rec: Dictionary, s: Dictionary) -> float:
	var r := rules()
	var stats: Dictionary = rec.get("stats", {})
	var pts := 0.0
	for k in s["stats"]:
		pts += float(stats.get(k, 0)) * float(s["stats"][k])
	var v := float(r["base_mps"]) + pts * float(r["stat_mps"])
	if (s["lean"] as Array).has(lean_of(rec)):
		v *= 1.0 + float(r["lean_edge"])
	var mood := (Care.condition(rec) - 50.0) / 50.0
	return v * (1.0 + float(r["mood_edge"]) * mood)

## Seconds a lap should take with no wobble or cheers (lower is the favourite).
static func expected_time(rec: Dictionary) -> float:
	var t := 0.0
	for s in course():
		t += float(s["len"]) / pace(rec, s)
	return t

# ------------------------------------------------------------------ one race, as data
## Is this the save's first Dash? It gets the card, a wider first window and a word on each press.
static func first_race() -> bool:
	return not bool(Save.d["tutorial"].get(RACED, false))

## The bar's window scale for the mark just reached (the mark counter is already one on).
static func window_scale(rn: Dictionary) -> float:
	return float(rules()["first_wide"]) if rn["first"] and int(rn["mark"]) == 1 else 1.0

## A fresh race: runner 0 is the Boki you cheer for.
static func new_run(recs: Array, seed_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var runners: Array = []
	for i in recs.size():
		Care.ensure(recs[i])
		runners.append({"rec": recs[i], "d": 0.0, "wob": 0.0, "wob_t": 0.0, "boost": 0.0, "boost_t": 0.0,
			"lane": float(i) - (recs.size() - 1) * 0.5, "done": -1.0})
	return {"rng": rng, "t": 0.0, "runners": runners, "order": [], "mark": 0, "first": first_race()}

## Moves the race on by dt. Returns the cheer mark the backed Boki just reached, or -1.
static func step(rn: Dictionary, dt: float) -> int:
	var r := rules()
	var rng: RandomNumberGenerator = rn["rng"]
	rn["t"] = float(rn["t"]) + dt
	for ru in rn["runners"]:
		if float(ru["done"]) >= 0.0:
			continue
		ru["wob_t"] = float(ru["wob_t"]) - dt
		if float(ru["wob_t"]) <= 0.0:
			ru["wob_t"] = float(r["wobble_s"])
			ru["wob"] = rng.randf_range(-1.0, 1.0) * float(r["wobble"])
		ru["boost_t"] = maxf(0.0, float(ru["boost_t"]) - dt)
		var boost := float(ru["boost"]) if float(ru["boost_t"]) > 0.0 else 0.0
		var v := pace(ru["rec"], stretch_at(float(ru["d"]))) * (1.0 + float(ru["wob"]) + boost)
		ru["d"] = float(ru["d"]) + v * dt
		if float(ru["d"]) >= loop_len():
			ru["d"] = loop_len()
			ru["done"] = rn["t"]
			(rn["order"] as Array).append(ru["rec"])
	var marks: Array = r["cheer_marks"]
	var m := int(rn["mark"])
	if m < marks.size() and float(rn["runners"][0]["d"]) >= float(marks[m]) * loop_len():
		rn["mark"] = m + 1
		return m
	return -1

static func finished(rn: Dictionary) -> bool:
	return (rn["order"] as Array).size() == (rn["runners"] as Array).size()

## A cheer press for the backed Boki, graded like the Training post drill.
static func cheer(rn: Dictionary, grade: String) -> void:
	var ru: Dictionary = rn["runners"][0]
	ru["boost"] = float(rules()["cheer_boost"][grade])
	ru["boost_t"] = float(rules()["cheer_s"])

## The whole race at once (the check). cheers: the grade for each mark, in order.
static func sim(recs: Array, seed_n: int, cheers: Array = []) -> Dictionary:
	var rn := new_run(recs, seed_n)
	while not finished(rn):
		var m := step(rn, 1.0 / 30.0)
		if m >= 0 and m < cheers.size():
			cheer(rn, String(cheers[m]))
	return rn

## Pays out a finished race: joy and trust for the winner, a sulk and a memory for each loser,
## rivalry nudged where rec["bonds"] exists, gems for you. Returns what the result card shows.
static func settle(rn: Dictionary) -> Dictionary:
	var r := rules()
	Save.d["tutorial"][RACED] = true
	var order: Array = rn["order"]
	var win: Dictionary = order[0]
	var backed: Dictionary = rn["runners"][0]["rec"]
	Care.change(win, "joy", float(r["win_joy"]))
	Save.remember(win, "race", "won the Dash", float(r["win_trust"]))
	for i in range(1, order.size()):
		var lo: Dictionary = order[i]
		Care.change(lo, "joy", float(r["lose_joy"]))
		Save.remember(lo, "race", "lost the Dash to %s" % win["name"])
		_rival(lo, win)
		_rival(win, lo)
	var gems := int(r["gems_backed_win"]) if win == backed else int(r["gems_other_win"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	var line := "%s will remember winning the Dash." % win["name"]
	if win != backed:
		line = "%s will remember losing the Dash to %s." % [backed["name"], win["name"]]
	return {"order": order, "gems": gems, "memory": line}

static func _rival(rec: Dictionary, other: Dictionary) -> void:
	if not rec.has("bonds"):
		return
	var bonds: Dictionary = rec["bonds"]
	var was := float(bonds.get(other["uid"], 0.0))
	bonds[other["uid"]] = clampf(was - float(rules()["rival_nudge"]), -1.0, 1.0)

# ------------------------------------------------------------------ on the farm
func build() -> void:
	node = _course_model()
	node.visible = false
	h.add_child(node)

func near(p2: Vector2) -> bool:
	return node.visible and run.is_empty() and p2.distance_to(Vector2(node.position.x, node.position.z)) < POST_REACH

func prompt() -> String:
	return "Start a Dash race"

## Lines up the Boki out on the farm (the one you have out first) and starts the race.
func start() -> void:
	var ak := Save.active_kin()
	var out: Array = h.kins.filter(func(k): return _can_run(k))
	out.sort_custom(func(a, b): return a["rec"] == ak and b["rec"] != ak)
	kins_in = out.slice(0, MAX_RUNNERS)
	if kins_in.size() < 2:
		h._toast("The Dash needs two Boki out on the farm")
		return
	var recs: Array = []
	for k in kins_in:
		h._care_start(k)
		k["busy"] = true
		recs.append(k["rec"])
	run = new_run(recs, randi())
	_place_runners()
	if run["first"] and not bool(Save.d["tutorial"].get(HINT, false)):
		Save.d["tutorial"][HINT] = true
		_show_tip("Press %s when your Boki reaches a glowing mark" % Settings.key_cap("interact"))
	else:
		h._toast("Cheer %s on: press %s at each of the three marks" % [recs[0]["name"], Settings.key_cap("interact")])
	if run["first"]:
		_light_first_mark()
	Sfx.play("whoosh", null, -8.0)

func _can_run(k: Dictionary) -> bool:
	var n: Node3D = k["node"]
	return not k.has("indoors") and not k.has("leap") and n.visible and not k.get("busy", false)

## A press while racing goes to the cheer bar (or closes the card); true when it was used.
func input(event: InputEvent) -> bool:
	if run.is_empty() and card == null:
		return false
	if not event.is_action_pressed("interact"):
		return false
	if not drill.is_empty():
		_cheer_hit(TimingDrill.grade(drill), TimingDrill.verdict(drill))
	elif card != null:
		_close_card()
	return true

func tick(d: float) -> void:
	var at: Vector3 = h.YARD_AT + POST_OFF
	node.position = at
	node.visible = at.x > -100.0
	if card != null:
		card_t -= d
		if card_t <= 0.0:
			_close_card()
	if run.is_empty():
		return
	if not drill.is_empty():
		TimingDrill.sweep(drill, d)
		drill["t"] = float(drill["t"]) - d
		bar_draw.queue_redraw()
		if float(drill["t"]) <= 0.0:
			_cheer_hit("miss", "Late")
	if is_instance_valid(glow):
		glow.scale = Vector3.ONE * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	if step(run, d) >= 0:
		_open_bar()
	_place_runners()
	if finished(run):
		_finish()

func _place_runners() -> void:
	for i in kins_in.size():
		var ru: Dictionary = run["runners"][i]
		var n: Node3D = kins_in[i]["node"]
		var p := node.position + _course_pos(float(ru["d"]), float(ru["lane"]))
		var dir := p - n.position
		if Vector2(dir.x, dir.z).length() > 0.001:
			n.rotation.y = atan2(-dir.x, -dir.z)
		n.position = p

## Where on the loop a runner is, from the post: along its stretch, out to its lane, up the climb,
## over the gap and wading low through the pond.
static func _course_pos(dist: float, lane: float) -> Vector3:
	var s := stretch_at(dist)
	var a: Vector2 = s["a"]
	var b: Vector2 = s["b"]
	var f := clampf((dist - float(s["start"])) / float(s["len"]), 0.0, 1.0)
	var side := (b - a).normalized().orthogonal() * lane * LANE_W
	var p := a.lerp(b, f) + side
	var y := 0.0
	match String(s["id"]):
		"water": y = -0.12
		"climb": y = CLIMB_H * f
		"jump": y = CLIMB_H * (1.0 - f) + sin(PI * f) * HOP_H
	return Vector3(p.x, y, p.y)

func _open_bar() -> void:
	drill = {"m": 0.0, "dir": 1.0, "speed": 1.1, "zone": randf_range(0.3, 0.7), "t": float(rules()["cheer_window_s"]),
		"wide": window_scale(run)}
	if is_instance_valid(glow):
		glow.queue_free()
	var b := UI.card(Color(0.06, 0.07, 0.1, 0.92), 12, 14)
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.offset_top = -64
	b.offset_bottom = -64
	b.custom_minimum_size.x = 420.0
	var col := UI.vbox(8)
	b.add_child(col)
	var title := "Cheer for %s!  (%s)" % [kins_in[0]["rec"]["name"], Settings.key_cap("interact")]
	col.add_child(UI.label(title, 15, UI.GOLD))
	bar_draw = Control.new()
	bar_draw.custom_minimum_size = Vector2(0, 26)
	bar_draw.draw.connect(_draw_bar)
	col.add_child(bar_draw)
	h.root_ui.add_child(b)
	bar = b

func _draw_bar() -> void:
	if not drill.is_empty():
		TimingDrill.draw(bar_draw, drill)

func _cheer_hit(grade: String, word: String) -> void:
	cheer(run, grade)
	if run["first"]:
		_float_word(word, grade)
	h._emote(kins_in[0], {"great": "★", "good": "♪", "miss": "?"}[grade], true)
	if grade != "miss":
		Sfx.play("jump", (kins_in[0]["node"] as Node3D).position, -8.0)
	drill = {}
	if is_instance_valid(bar):
		bar.queue_free()
	bar = null

func _finish() -> void:
	if not drill.is_empty():
		_cheer_hit("miss", "Late")
	var res := settle(run)
	if is_instance_valid(glow):
		glow.queue_free()
	for k in kins_in:
		k["busy"] = false
		k["t"] = 2.0
		var n: Node3D = k["node"]
		k["pos"] = Vector3(n.position.x, 0, n.position.z)
		n.position = k["pos"]
		h._emote(k, "♥" if k["rec"] == res["order"][0] else "…", true)
	Sfx.play("pickup", null, -6.0)
	Save.save_game()
	_show_card(res)
	run = {}
	kins_in = []

## The word over your Boki where the press landed (first race only).
func _float_word(word: String, grade: String) -> void:
	var t := Label3D.new()
	t.text = word
	t.font = UI.big
	t.font_size = 56
	t.pixel_size = 0.01
	t.outline_size = 12
	t.modulate = UI.GOLD if grade == "great" else UI.INK
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.no_depth_test = true
	t.position = (kins_in[0]["node"] as Node3D).position + Vector3(0, 1.7, 0)
	h.add_child(t)
	var tw := t.create_tween().set_parallel()
	tw.tween_property(t, "position:y", t.position.y + 0.6, WORD_S)
	tw.tween_property(t, "modulate:a", 0.0, WORD_S)
	tw.chain().tween_callback(t.queue_free)

## A glowing disc on the ground where the first cheer comes up.
func _light_first_mark() -> void:
	var at := _course_pos(float(rules()["cheer_marks"][0]) * loop_len(), 0.0)
	glow = Models.part(node, Models.cyl(0.55, 0.55, 0.04), Models.glow_mat(UI.GOLD), at + Vector3(0, 0.06, 0))

func _show_tip(text: String) -> void:
	_close_card()
	var c := UI.card(Color(0.06, 0.07, 0.1, 0.94), 14, 12)
	c.set_anchors_preset(Control.PRESET_CENTER_TOP)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = 70
	c.add_child(UI.label(text, 16, UI.GOLD))
	h.root_ui.add_child(c)
	UI.pop_in(c)
	card = c
	card_t = CARD_S

func _show_card(res: Dictionary) -> void:
	_close_card()
	var c := UI.card(Color(0.06, 0.07, 0.1, 0.94), 16, 14)
	c.set_anchors_preset(Control.PRESET_CENTER_TOP)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = 70
	c.custom_minimum_size.x = 340.0
	var col := UI.vbox(6)
	c.add_child(col)
	var order: Array = res["order"]
	col.add_child(UI.label("%s wins the Dash!" % order[0]["name"], 20, UI.GOLD))
	for i in order.size():
		var mood := "♥" if i == 0 else "sulks"
		col.add_child(UI.label("%d.  %s   %s" % [i + 1, order[i]["name"], mood], 15, UI.INK if i == 0 else UI.MUTED))
	col.add_child(UI.label("+%d gems" % int(res["gems"]), 15, UI.ACCENT))
	col.add_child(UI.para(String(res["memory"]), 12, UI.FAINT))
	h.root_ui.add_child(c)
	UI.pop_in(c)
	card = c
	card_t = CARD_S

func _close_card() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null

# ------------------------------------------------------------------ the look
## The start post (a striped pole and a banner) and simple course pieces: a dirt strip for the
## straight, a pond, a ramp up the climb and two ledges either side of the gap.
static func _course_model() -> Node3D:
	var n := Node3D.new()
	n.name = "DashCourse"
	var wood := Models.toon(Color("a8794a"))
	Models.part(n, Models.cyl(0.07, 0.08, 1.6), wood, Vector3(0, 0.8, 0), Vector3.ONE, Vector3.ZERO, "Post")
	Models.part(n, Models.box(0.7, 0.36, 0.04), Models.toon(Color("f2c24a")), Vector3(0.38, 1.4, 0))
	var tag := Label3D.new()
	tag.text = "The Dash"
	tag.font = UI.big
	tag.font_size = 40
	tag.pixel_size = 0.008
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.0, 0)
	n.add_child(tag)
	var looks := {
		"straight": Color("b99a6a"), "water": Color("4ab0ff"), "climb": Color("8a7458"), "jump": Color("6b4a2e"),
	}
	for s in course():
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var mid := (a + b) * 0.5
		var length := float(s["len"])
		var rot := Vector3(0, atan2(-(b - a).y, (b - a).x), 0)
		var y := 0.02
		if s["id"] == "climb":
			# a ramp up to the top of the climb
			y = CLIMB_H * 0.5
			rot.z = atan2(CLIMB_H, length)
			length = Vector2(length, CLIMB_H).length()
		elif s["id"] == "jump":
			# only the landing pad: the gap is the open ground before it
			mid = a.lerp(b, 0.85)
			length *= 0.3
		var mat := Models.toon(looks.get(s["id"], Color("b99a6a")))
		var piece := Models.box(length, 0.05, LANE_W * MAX_RUNNERS)
		Models.part(n, piece, mat, Vector3(mid.x, y, mid.y), Vector3.ONE, rot, String(s["id"]).capitalize())
	return n
