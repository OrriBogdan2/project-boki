class_name ShowRing
extends RefCounted
## Show Ring (briefs/design/GARDEN_MODERN.md 4.2 game 3), a judged show on a small stage by the Training
## post; only with farm_build.json base_mode on. Your partner and a rival show in three rounds of up to 10
## points: Look (joy, cleanliness, a full lean, grown parts, an aura, keepsakes), Trick (three presses on
## the drill's timing bar, the trick picked by its best stat) and Bond (it walks to you past a snack, a toy
## and the rival; call it as it passes each; trust and loyalty shrink the pull). Three judges post the
## week's taste on the stage's board; each one the Boki fits adds a bonus. Scores come only from the
## records and the presses, and a show pays out once. Tuning: content/rules/show_ring.json.
## Run is the show itself (no nodes), so --show-ring-check (tools/show_ring_check.gd) runs it headless.

const STAGE_OFF := Vector3(-3.2, 0, 3.4)     # m from the Training post to the stage's middle
const STAGE_R := 1.1                          # m, the stage's radius
const STAGE_H := 0.14                         # m, its height
const BOARD_OFF := Vector3(1.6, 0, -0.9)      # m from the stage's middle to the judges' board
const TASTE_H := 2.3                          # m, the height of the tastes over the board
const REACH := 1.8                            # m from the stage to start a show
const SPIN := 0.9                             # rad/s the Boki turns while the judges look
const SIDE := 1.4                             # m from the stage's middle to where the rival waits
const LURE_SIDE := 0.9                        # m from the walk line to each lure
const STRAY_S := 1.2                          # s either side of a lure over which it veers toward it
const ROUND_MAX := 10.0                       # points a round gives at most
const TRICK_PRESSES := 3

static func rules() -> Dictionary:
	return Content.rules("show_ring")

## Look, part by part (joy, clean, lean, parts, aura, keepsakes): points that add up to 10 at most.
static func look(rec: Dictionary) -> Dictionary:
	var L: Dictionary = rules()["look"]
	var levels := 0
	for m in rec.get("muts", []):
		levels += int(m["lv"])
	var aura := String(rec.get("aura", "")) != ""
	return {
		"joy": float(L["joy"]) * Care.need(rec, "joy") / 100.0,
		"clean": float(L["clean"]) * Care.need(rec, "clean") / 100.0,
		"lean": float(L["lean"]) * _lean_share(rec),
		"parts": minf(float(L["parts"]), float(levels)),
		"aura": float(L["aura"]) if aura else 0.0,
		"keepsakes": minf(float(L["keepsakes"]), float(rec.get("ribbons", {}).size())),
	}

## 1 at a full lean, 0.5 at half or more, else 0.
static func _lean_share(rec: Dictionary) -> float:
	var strength := float(Evo.lean(rec)[1])
	if strength >= 1.0:
		return 1.0
	return 0.5 if strength >= float(rules()["half_lean"]) else 0.0

static func sum(parts: Dictionary) -> float:
	var total := 0.0
	for p in parts:
		total += float(parts[p])
	return total

## Its highest trained stat, the first in Care.STATS on a tie: the stat its trick shows off.
static func best_stat(rec: Dictionary) -> String:
	var best := ""
	for s in Care.STATS:
		if best == "" or int(rec["stats"].get(s, 0)) > int(rec["stats"].get(best, 0)):
			best = s
	return best

static func trick_of(rec: Dictionary) -> Dictionary:
	return rules()["tricks"][best_stat(rec)]

## Trick points: the three presses' grades plus a little for the trick's stat.
static func trick(rec: Dictionary, grades: Array) -> float:
	var R := rules()
	var pts := 0.0
	for g in grades:
		pts += float(R["press"][g])
	var stat := float(rec["stats"].get(best_stat(rec), 0))
	return pts + minf(1.0, stat * float(R["stat_per_point"]))

## How far a lure pulls it off the walk (0..1) before your call: trust and loyalty shrink it.
static func pull(rec: Dictionary, lure: Dictionary) -> float:
	var R := rules()
	var trust := float(rec.get("trust", 0.0)) / 100.0
	var loyal := float(rec.get("traits", {}).get("loyalty", 0.5))
	var shrink := trust * float(R["trust_shrink"]) + loyal * float(R["loyal_shrink"])
	return float(lure["pull"]) * maxf(0.0, 1.0 - shrink)

## How far it strays at a lure after a call graded `grade` (great, good or miss).
static func stray(rec: Dictionary, lure: Dictionary, grade: String) -> float:
	return pull(rec, lure) * float(rules()["call"][grade])

## Bond points: an equal share of 10 for each lure, less what it strayed there.
static func bond(rec: Dictionary, calls: Array) -> float:
	var lures: Array = rules()["lures"]
	var pts := 0.0
	for i in lures.size():
		pts += ROUND_MAX / lures.size() * (1.0 - stray(rec, lures[i], calls[i]))
	return pts

## A call `off` seconds from the moment it is level with a lure.
static func call_grade(off: float) -> String:
	var R := rules()
	if absf(off) <= float(R["call_great"]):
		return "great"
	return "good" if absf(off) <= float(R["call_good"]) else "miss"

## The three tastes the judges post in a given week.
static func tastes(week: int) -> Array:
	var all: Array = rules()["tastes"]
	var out: Array = []
	for i in 3:
		out.append(all[(week * 3 + i) % all.size()])
	return out

static func fits(rec: Dictionary, taste: Dictionary) -> bool:
	var R := rules()
	if String(taste["kind"]) == "trait":
		return float(rec.get("traits", {}).get(taste["id"], 0.0)) >= float(R["taste_trait"])
	var ln := Evo.lean(rec)
	return String(ln[0]) == String(taste["id"]) and float(ln[1]) >= float(R["half_lean"])

## The bench: retired mentors in the roster first, then the stand-in judges, three in all.
static func judges(roster: Array) -> Array:
	var out: Array = []
	for rec in roster:
		if Mentor.is_mentor(rec) and out.size() < 3:
			out.append(String(rec["name"]))
	for n in rules()["judges"]:
		if out.size() < 3:
			out.append(String(n))
	return out

## The rival's handler: each trick press graded by how much of the trick's stat it has.
static func rival_grades(rec: Dictionary) -> Array:
	var at: Dictionary = rules()["rival_press"]
	var stat := int(rec["stats"].get(best_stat(rec), 0))
	var grade := "miss"
	if stat >= int(at["great"]):
		grade = "great"
	elif stat >= int(at["good"]):
		grade = "good"
	var out: Array = []
	out.resize(TRICK_PRESSES)
	out.fill(grade)
	return out

## The whole show for one Boki: {look, trick, bond, fits (one bool a judge), total}.
static func score(rec: Dictionary, grades: Array, calls: Array, week: int) -> Dictionary:
	var out := {"look": sum(look(rec)), "trick": trick(rec, grades), "bond": bond(rec, calls), "fits": []}
	var total := float(out["look"]) + float(out["trick"]) + float(out["bond"])
	for t in tastes(week):
		var fit := fits(rec, t)
		out["fits"].append(fit)
		if fit:
			total += float(rules()["taste_bonus"])
	out["total"] = total
	return out

## The show itself, stepped in time: Look, Trick, Bond, then the judges.
class Run:
	enum Phase { LOOK, TRICK, BOND, JUDGE, DONE }
	var R: Dictionary
	var recs: Array                 # two records: a (index 0) and b (index 1)
	var backed := 0                 # index in recs: the Boki you show
	var week := 0
	var phase := Phase.LOOK
	var t := 0.0                    # s into the current round
	var total_t := 0.0              # s into the show
	var grades: Array = []          # your trick presses
	var calls: Array = []           # your call at each lure, "" until made or missed
	var paid := false               # settle has paid this show

	func _init(pair: Array, back: int, week_no: int) -> void:
		R = ShowRing.rules()
		recs = pair
		backed = back
		week = week_no
		calls.resize((R["lures"] as Array).size())
		calls.fill("")

	func over() -> bool:
		return phase == Phase.DONE

	func can_trick() -> bool:
		return phase == Phase.TRICK and grades.size() < ShowRing.TRICK_PRESSES

	func press_trick(grade: String) -> void:
		grades.append(grade)
		if grades.size() == ShowRing.TRICK_PRESSES:
			_next()

	## s into the walk at which it is level with lure i.
	func lure_t(i: int) -> float:
		return float(R["lures"][i]["at"]) * float(R["walk_s"])

	## Your call during the walk: graded against the nearest lure not yet called. Returns its index or -1.
	func call_out() -> int:
		if phase != Phase.BOND:
			return -1
		for i in calls.size():
			if calls[i] == "" and absf(t - lure_t(i)) <= float(R["call_good"]):
				calls[i] = ShowRing.call_grade(t - lure_t(i))
				return i
		return -1

	func step(dt: float) -> void:
		t += dt
		total_t += dt
		match phase:
			Phase.LOOK:
				if t >= float(R["look_s"]):
					_next()
			Phase.TRICK:
				if t >= float(R["trick_s"]):
					while grades.size() < ShowRing.TRICK_PRESSES:
						grades.append("miss")
					_next()
			Phase.BOND:
				for i in calls.size():
					if calls[i] == "" and t > lure_t(i) + float(R["call_good"]):
						calls[i] = "miss"
				if t >= float(R["walk_s"]):
					_next()
			Phase.JUDGE:
				if t >= float(R["judge_s"]):
					_next()

	func _next() -> void:
		phase = (phase + 1) as Phase
		t = 0.0

	## Both scores, recs order: yours from your presses, the rival's from its handler.
	func scores() -> Array:
		var out: Array = []
		for i in 2:
			if i == backed:
				out.append(ShowRing.score(recs[i], grades, calls, week))
			else:
				var good: Array = []
				good.resize(calls.size())
				good.fill("good")
				out.append(ShowRing.score(recs[i], ShowRing.rival_grades(recs[i]), good, week))
		return out

	## 0 or 1: the higher total, then the better Look, then a.
	func winner() -> int:
		var s := scores()
		if is_equal_approx(float(s[0]["total"]), float(s[1]["total"])):
			return 0 if float(s[0]["look"]) >= float(s[1]["look"]) else 1
		return 0 if float(s[0]["total"]) > float(s[1]["total"]) else 1

## The ribbon your shown Boki takes: "gold" for the win, else "silver" or "bronze" by its total, else "part".
static func placing(won: bool, total: float) -> String:
	var at: Dictionary = rules()["ribbon_at"]
	if won:
		return "gold"
	if total >= float(at["silver"]):
		return "silver"
	return "bronze" if total >= float(at["bronze"]) else "part"

## Pays out a finished show once: joy, trust, a memory each, energy, gems and the prize roll.
## Returns what the card shows, or {} when this show was already paid.
static func settle(run: Run) -> Dictionary:
	if run.paid:
		return {}
	run.paid = true
	var R := rules()
	var win: Dictionary = run.recs[run.winner()]
	var lose: Dictionary = run.recs[1 - run.winner()]
	for rec in run.recs:
		Care.change(rec, "energy", -float(R["energy"]))
	Care.change(win, "joy", float(R["win_joy"]))
	Care.change(lose, "joy", float(R["lose_joy"]))
	Save.remember(win, "show", "won the Show Ring over %s" % lose["name"], float(R["win_trust"]))
	Save.remember(lose, "show", "came second to %s in the Show Ring" % win["name"])
	var backed_won: bool = run.recs[run.backed] == win
	var gems := int(R["gems_win"]) if backed_won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	var prize := GardenPrizes.settle("show", run.recs[run.backed], run.recs[1 - run.backed], backed_won)
	var scores := run.scores()
	var mine: Dictionary = scores[run.backed]
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won, "prize": prize,
			"scores": scores, "mine": mine, "placing": placing(backed_won, float(mine["total"]))}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var stage: Node3D = null
var board: Label3D = null      # the judges' tastes over their board
var run: Run = null
var pair: Array = []           # the home's kin entries: a, b
var lures: Array = []          # the snack and toy nodes on the walk
var walk_from := Vector3.ZERO
var walk_to := Vector3.ZERO
var bar: TimingBar = null
var card: Control = null
var card_t := 0.0
var marks: ShowMarks = null    # the result's judge marks and ribbon (show_marks.gd)

func _init(home) -> void:
	h = home

## The stage and the judges' board by the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	stage = null
	if h.YARD_AT.x < -100.0:
		return
	stage = Node3D.new()
	stage.name = "ShowRing"
	stage.position = h.YARD_AT + STAGE_OFF
	h.add_child(stage)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = STAGE_R
	floor_mesh.bottom_radius = STAGE_R
	floor_mesh.height = STAGE_H
	var plank := MeshInstance3D.new()
	plank.mesh = floor_mesh
	plank.material_override = BaseRace.mat(Color("b98a5a"))
	plank.position.y = STAGE_H * 0.5
	stage.add_child(plank)
	var post := Models.signpost(["Show Ring"])
	post.position = BOARD_OFF
	stage.add_child(post)
	board = Label3D.new()
	board.font = UI.big
	board.font_size = 36
	board.pixel_size = 0.008
	board.outline_size = 12
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.modulate = UI.GOLD
	board.position = BOARD_OFF + Vector3(0, TASTE_H, 0)
	board.text = board_text(GardenPrizes.week_of(Time.get_unix_time_from_system()))
	stage.add_child(board)

## What the board says this week: each judge and the taste they posted.
static func board_text(week: int) -> String:
	var lines: Array = ["This week's judges like"]
	var names := judges(Save.d["roster"])
	var likes := tastes(week)
	for i in 3:
		lines.append("%s: %s" % [names[i], likes[i]["text"]])
	return "\n".join(lines)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(stage):
		return {}
	if p2.distance_to(Vector2(stage.position.x, stage.position.z)) > REACH:
		return {}
	return {"kind": "show"}

func label() -> String:
	return "Enter the Show Ring (show %s)" % Save.active_kin().get("name", "your partner")

func use() -> void:
	var ks: Array = h.hrace.entrants()
	var min_energy := float(rules()["min_energy"])
	ks = ks.filter(func(k): return Care.need(k["rec"], "energy") >= min_energy)
	if ks.size() < 2:
		h._toast("The Show Ring needs two rested Boki out on the base")
		return
	pair = ks.slice(0, 2)
	for k in pair:
		k["busy"] = true
	var back := maxi(0, [pair[0]["rec"], pair[1]["rec"]].find(Save.active_kin()))
	var week := GardenPrizes.week_of(Time.get_unix_time_from_system())
	run = Run.new([pair[0]["rec"], pair[1]["rec"]], back, week)
	if is_instance_valid(marks):
		marks.queue_free()
	board.text = board_text(week)
	_enter()
	GardenSfx.countdown(h, stage.position)

func _shown() -> Dictionary:
	return pair[run.backed]

## A press: true when the show took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if not TimingBar.is_press(event):
		return false
	if run.can_trick():
		var r := bar.press()
		run.press_trick(r)
		_cheer(r)
		if not run.can_trick():
			_after_step()
	elif run.phase == Run.Phase.BOND:
		var i := run.call_out()
		if i >= 0:
			_cheer(run.calls[i])
	return true

func _cheer(grade: String) -> void:
	GardenSfx.crowd(grade, _shown()["pos"])
	h._emote(_shown(), {"great": "★", "good": "♪", "miss": "?"}[grade], true)

func tick(d: float) -> void:
	if card_t > 0.0 and run == null:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	var was := run.phase
	run.step(d)
	if run.phase != was:
		_after_step()
		return
	if run.phase == Run.Phase.TRICK:
		bar.step(d)
	_place_pair(d)

## After the round changes: set up the next one, or end the show.
func _after_step() -> void:
	if run.over():
		_end(true)
	else:
		_enter()

## Sets up the round the run is in: its card, the bar or the walk.
func _enter() -> void:
	if bar != null:
		bar.close()
	_clear_lures()
	var shown: Dictionary = run.recs[run.backed]
	var key := Settings.key_cap("interact")
	match run.phase:
		Run.Phase.LOOK:
			_round_card(_look_rows(shown))
		Run.Phase.TRICK:
			var shown_trick := trick_of(shown)
			_round_card([["Trick: %s %s" % [shown["name"], shown_trick["line"]], 18, UI.ACCENT_HI]])
			bar = TimingBar.new()
			bar.open(h.root_ui, "Press %s three times, with the marker in the gold" % key)
			bar.lbl.text = "%s's %s" % [shown["name"], shown_trick["name"]]
		Run.Phase.BOND:
			_round_card([["Bond: %s walks to you" % shown["name"], 18, UI.ACCENT_HI],
					["Press %s as it passes a snack, a toy and its rival" % key, 14, UI.INK]])
			_lay_walk()
		Run.Phase.JUDGE:
			_round_card(_judge_rows())
			GardenSfx.reveal(h, stage.position)
	_place_pair(0.0)

func _look_rows(rec: Dictionary) -> Array:
	var parts := look(rec)
	var bits: Array = []
	for p in parts:
		bits.append("%s %.1f" % [p, float(parts[p])])
	return [["Look: the judges look %s over" % rec["name"], 18, UI.ACCENT_HI],
			["%.1f of 10: %s" % [sum(parts), ", ".join(bits)], 14, UI.INK]]

func _judge_rows() -> Array:
	var s := run.scores()
	var names := judges(Save.d["roster"])
	var likes := tastes(run.week)
	var rows: Array = [["The judges' cards", 18, UI.ACCENT_HI]]
	for i in 2:
		var rec: Dictionary = run.recs[i]
		rows.append(["%s: Look %.1f, Trick %.1f, Bond %.1f = %.1f" % [rec["name"], s[i]["look"], s[i]["trick"],
				s[i]["bond"], s[i]["total"]], 14, UI.INK])
		for j in 3:
			if s[i]["fits"][j]:
				rows.append(["  %s likes %s: +%.0f" % [names[j], likes[j]["text"], rules()["taste_bonus"]], 13,
						UI.TEAL])
	return rows

func _round_card(rows: Array) -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(h, rows)

## The walk from the stage toward you, with the snack and toy beside it and the rival at the last lure.
func _lay_walk() -> void:
	walk_from = stage.position
	var to_you: Vector3 = h.player.position - walk_from
	to_you.y = 0.0
	var dir := Vector3.RIGHT if to_you.length() < 0.5 else to_you.normalized()
	walk_to = walk_from + dir * float(rules()["walk_m"])
	var colours := {"snack": Color("f2a33a"), "toy": Color("5ab8f0")}
	for lure in rules()["lures"]:
		if not colours.has(lure["id"]):
			continue
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		ball.mesh = sphere
		ball.material_override = BaseRace.mat(colours[lure["id"]])
		ball.position = _ground(_lure_at(lure)) + Vector3(0, 0.16, 0)
		h.add_child(ball)
		lures.append(ball)

func _lure_at(lure: Dictionary) -> Vector3:
	var along := walk_from.lerp(walk_to, float(lure["at"]))
	var dir := (walk_to - walk_from).normalized()
	return along + dir.cross(Vector3.UP) * LURE_SIDE

func _clear_lures() -> void:
	for n in lures:
		if is_instance_valid(n):
			n.queue_free()
	lures = []

func _ground(p: Vector3) -> Vector3:
	var g: float = h._ground_h(p.x, p.z)
	p.y = g if g > -50.0 else 0.0
	return p

func _put(k: Dictionary, p: Vector3, yaw: float) -> void:
	var n: Node3D = k["node"]
	n.position = _ground(p)
	n.rotation.y = yaw
	k["pos"] = n.position

## Where the pair stand: the shown Boki on the stage, then walking to you; the rival by the stage,
## then at the last lure.
func _place_pair(d: float) -> void:
	var shown := _shown()
	var rival: Dictionary = pair[1 - run.backed]
	var lift := Vector3(0, STAGE_H, 0)
	match run.phase:
		Run.Phase.LOOK, Run.Phase.TRICK:
			var n: Node3D = shown["node"]
			_put(shown, stage.position, n.rotation.y + SPIN * d)
			n.position += lift
			_put(rival, stage.position + Vector3(SIDE, 0, 0), -PI * 0.5)
		Run.Phase.BOND:
			var last: Dictionary = rules()["lures"].back()
			var at := _lure_at(last)
			_put(rival, at, atan2(walk_from.x - at.x, walk_from.z - at.z))
			var p := _walk_pos()
			_put(shown, p, atan2(walk_to.x - p.x, walk_to.z - p.z))
		Run.Phase.JUDGE:
			_put(shown, stage.position - Vector3(SIDE * 0.4, 0, 0), 0.0)
			shown["node"].position += lift
			_put(rival, stage.position + Vector3(SIDE * 0.4, 0, 0), 0.0)
			rival["node"].position += lift

## The shown Boki on the walk: along the line, veering toward each lure by how far it strays there.
func _walk_pos() -> Vector3:
	var walk_s := float(rules()["walk_s"])
	var p := walk_from.lerp(walk_to, clampf(run.t / walk_s, 0.0, 1.0))
	var rec: Dictionary = run.recs[run.backed]
	var all: Array = rules()["lures"]
	for i in all.size():
		var near := 1.0 - absf(run.t - run.lure_t(i)) / STRAY_S
		if near <= 0.0:
			continue
		var called: String = run.calls[i]
		var drift := pull(rec, all[i]) if called == "" else stray(rec, all[i], called)
		p = p.lerp(_lure_at(all[i]), drift * near)
	return p

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	var shown := _shown()
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
	if bar != null:
		bar.close()
	_clear_lures()
	if is_instance_valid(card):
		card.queue_free()
	if finished:
		_card(res)
		GardenSfx.result(h, res)
		if is_instance_valid(marks):
			marks.queue_free()
		marks = ShowMarks.new(shown, stage.position, res["mine"], res["placing"])
		h.root_ui.add_child(marks)
		h._emote(h._kin_entry(res["win"]), "♥", true)
		h._emote(h._kin_entry(res["lose"]), "…", true)
		Save.save_game()
	run = null
	pair = []

func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var why := " for showing the winner" if res["backed_won"] else ""
	card = BaseRace.result_card(h, [
		["%s wins the Show Ring!" % win["name"], 18, UI.ACCENT_HI],
		["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
		["%s sulks: \"came second to %s\"" % [lose["name"], win["name"]], 14, UI.MUTED],
		["+%d gems%s" % [res["gems"], why], 14, UI.GOLD]] + GardenPrizes.rows(res["prize"], 14))
	card_t = float(rules()["card_s"])
