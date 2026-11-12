class_name BaseRelay
extends RefCounted
## The Relay Cup (briefs/design/GARDEN_MODERN.md 4.2 game 5), hosted by the Dash (BaseRace): three of your
## rested Boki against a visiting team of three, one leg each of the Dash loop (the straight, the water, the
## climb). The order comes from stats and leans (order()). Your two hand-offs are the Dash's cheer press on
## the timing bar: the grade sets the seconds the next runner loses taking the baton; rivals fumble unless the
## press is great, and duo friends (BaseDuo) hand off cleanly on their own and run the next leg faster.
## The visitors mirror your three at the cup round's strength (rivals()), so every win is a cup win in
## content/rules/garden_prizes.json "relay". The runners' body language (hand-off contact, launch burst, finish
## cheer and sulk) is RelayBeats. Tuning: content/rules/base_relay.json. Run has no nodes, so
## --relay-cup-check (tools/relay_cup_check.gd) runs it headless with a seed.

const STAND_OFF := Vector3(-1.3, 0, -2.4)   # m from the loop's start line to the relay stand
const REACH := 1.2                          # m from the stand to start a relay
const DONE_SIDE := 0.6                      # m further out a runner stands once its leg is run

static func rules() -> Dictionary:
	return Content.rules("base_relay")

## Seconds `rec` takes over leg `leg` with no wobble.
static func leg_time(rec: Dictionary, leg: int) -> float:
	var st: Array = BaseRace.rules()["stretches"]
	var out := 0.0
	for s in rules()["legs"][leg]:
		out += float(st[s]["len"]) / BaseRace.stretch_pace(rec, int(s))
	return out

## The three in leg order: the arrangement with the lowest expected total, so leans pick their stretch.
static func order(team: Array) -> Array:
	var best: Array = team
	var best_t := INF
	for p in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var total := 0.0
		for leg in 3:
			total += leg_time(team[p[leg]], leg)
		if total < best_t:
			best_t = total
			best = [team[p[0]], team[p[1]], team[p[2]]]
	return best

## The visiting team: one Boki per runner of yours, same species, level, joy and lean, stats times `ratio`.
static func rivals(team: Array, ratio: float) -> Array:
	var out: Array = []
	for rec in team:
		var r := Save.new_kin(String(rec["species"]))
		r["level"] = rec["level"]
		r["needs"]["joy"] = Care.need(rec, "joy")
		r["lean"] = rec.get("lean", {}).duplicate()
		for s in Care.STATS:
			r["stats"][s] = ceili(float(rec["stats"].get(s, 0)) * ratio)
		out.append(r)
	return out

## The cup round `rec` runs next: its min_ratio sets the visitors' strength.
static func cup_round(rec: Dictionary) -> Dictionary:
	return GardenPrizes.rules()["cup"]["rounds"][GardenPrizes.stage(rec, "relay")]

## The relay itself: two teams' batons along the lap, stepped in time. Team 0 is yours.
class Run:
	var R: Dictionary
	var legs: Array
	var teams: Array                # [yours, theirs], each three recs in leg order
	var rng: RandomNumberGenerator
	var t := 0.0
	var ends: Array = []            # m along the lap where each stretch ends
	var leg := [0, 0]               # the leg each team's baton is on
	var stretch := [0, 0]
	var dist := [0.0, 0.0]          # m along the lap
	var pace := [0.0, 0.0]          # m/s rolled for the stretch
	var wait := [0.0, 0.0]          # s left taking the baton
	var boost := [false, false]     # the runner took the baton from a duo friend
	var done_t := [-1.0, -1.0]
	var grades: Array = []          # your hand-off presses, in order
	var lost := [[], []]            # s lost at each hand-off, per team
	var duo: Array = []             # [from, to] pairs of yours that handed off as duo friends

	func _init(mine: Array, theirs: Array, r: RandomNumberGenerator) -> void:
		R = BaseRelay.rules()
		legs = R["legs"]
		teams = [mine, theirs]
		rng = r
		var at := 0.0
		for s in BaseRace.rules()["stretches"]:
			at += float(s["len"])
			ends.append(at)
		for team in 2:
			_roll(team)

	func runner(team: int) -> Dictionary:
		return teams[team][leg[team]]

	func _roll(team: int) -> void:
		var w := float(BaseRace.rules()["wobble"])
		var p := BaseRace.stretch_pace(runner(team), int(stretch[team])) * rng.randf_range(1.0 - w, 1.0 + w)
		if boost[team]:
			p *= float(BaseDuo.rules()["handoff_pace"])
		pace[team] = p

	## One press a hand-off, while the runner before it is on its leg.
	func can_press() -> bool:
		return float(done_t[0]) < 0.0 and grades.size() == int(leg[0]) and int(leg[0]) < legs.size() - 1

	func press(grade: String) -> void:
		grades.append(grade)

	func over() -> bool:
		return float(done_t[0]) >= 0.0 and float(done_t[1]) >= 0.0

	func won() -> bool:
		return float(done_t[0]) <= float(done_t[1])

	func step(dt: float) -> void:
		t += dt
		for team in 2:
			if float(done_t[team]) >= 0.0:
				continue
			if float(wait[team]) > 0.0:
				wait[team] = float(wait[team]) - dt
				continue
			_advance(team, dt)

	func _advance(team: int, dt: float) -> void:
		dist[team] = float(dist[team]) + float(pace[team]) * dt
		while float(dist[team]) >= float(ends[stretch[team]]):
			var s := int(stretch[team])
			if s == ends.size() - 1:
				done_t[team] = t - (float(dist[team]) - float(ends[s])) / maxf(float(pace[team]), 0.01)
				dist[team] = float(ends[s])
				return
			stretch[team] = s + 1
			if int(leg[team]) < legs.size() - 1 and s + 1 == int(legs[leg[team] + 1][0]):
				_hand_off(team)
			_roll(team)

	func _hand_off(team: int) -> void:
		var from := runner(team)
		leg[team] = int(leg[team]) + 1
		var to := runner(team)
		var grade := _rival_grade()
		if team == 0:
			if grades.size() < int(leg[0]):
				grades.append("miss")            # no press before the mark
			grade = grades[int(leg[0]) - 1]
		var s := float(R["handoff"][grade])
		boost[team] = BaseDuo.friends(from, to)
		if boost[team]:
			s = 0.0
			if team == 0:
				duo.append([from, to])
		elif BaseRace.bond(from, to) <= float(BaseRace.rules()["rival_at"]) and grade != "great":
			s += float(R["fumble"])
		wait[team] = s
		lost[team].append(s)

	func _rival_grade() -> String:
		var w: Dictionary = R["rival_grades"]
		var at := rng.randi_range(1, int(w["great"]) + int(w["good"]) + int(w["miss"]))
		for g in ["great", "good", "miss"]:
			at -= int(w[g])
			if at <= 0:
				return g
		return "miss"

## Pays out a finished relay to your team: joy, trust, memories, bonds, gems and the prize roll for
## `anchor` (one of yours) against its mirror. Returns what the card shows.
static func settle(run: Run, anchor: Dictionary) -> Dictionary:
	var R := rules()
	var RR := BaseRace.rules()
	var mine: Array = run.teams[0]
	var won := run.won()
	for rec in mine:
		Care.change(rec, "energy", -float(RR["energy"]))
		if won:
			Care.change(rec, "joy", float(RR["win_joy"]))
			Save.remember(rec, "relay", "won the Relay Cup with %s" % _mates(mine, rec), float(RR["win_trust"]))
		else:
			Care.change(rec, "joy", float(RR["lose_joy"]))
			Save.remember(rec, "relay", "lost the Relay Cup to the %s" % R["rival_team"])
	for i in run.grades.size():
		if run.grades[i] == "great" or BaseDuo.friends(mine[i], mine[i + 1]):
			BaseRace.nudge_bond(mine[i], mine[i + 1], float(R["close_step"]))
	for pair in run.duo:
		BaseDuo.note_first(pair[0], pair[1], "handed the baton cleanly to")
	var gems := int(R["gems_win"]) if won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	var foe: Dictionary = run.teams[1][mine.find(anchor)]
	var prize := GardenPrizes.settle("relay", anchor, foe, won)
	return {"won": won, "gems": gems, "prize": prize, "gap": absf(float(run.done_t[0]) - float(run.done_t[1]))}

static func _mates(team: Array, rec: Dictionary) -> String:
	var names: Array = []
	for o in team:
		if o != rec:
			names.append(o["name"])
	return " and ".join(names)

# ------------------------------------------------------------------ on the base
var race: BaseRace             # the Dash: its loop, entrants, timing bar press and result card
var h                          # the Home screen
var stand: Node3D = null
var run: Run = null
var mine: Array = []           # your three kin entries, in leg order
var visitors: Array = []       # the visiting team's {rec, node} entries, in leg order
var anchor := {}               # your Boki the prize and cup go to: your partner when it runs
var bar: TimingBar = null
var heard := [0, 0]            # hand-offs sounded so far, per team
var crossed := [false, false]  # each team's finish sounded
var beats := RelayBeats.new()  # the runners' hand-off, launch and finish body language
var finish_left := -1.0        # s the finished teams still show their cheer or sulk (-1: the relay is on)

func _init(dash: BaseRace) -> void:
	race = dash
	h = dash.h

## The relay stand at the loop's far corner (none without the race post); called with BaseRace.place().
func place() -> void:
	if is_instance_valid(stand):
		stand.queue_free()
	stand = null
	if not is_instance_valid(race.post):
		return
	stand = Node3D.new()
	stand.name = "RelayStand"
	stand.position = race.start + STAND_OFF
	h.add_child(stand)
	var g := race.ground(stand.position)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = 1.1
	pole.mesh = cm
	pole.material_override = BaseRace.mat(Color("8a6a4a"))
	pole.position = Vector3(0, g + 0.55, 0)
	stand.add_child(pole)
	var baton := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.05
	bm.bottom_radius = 0.05
	bm.height = 0.4
	baton.mesh = bm
	baton.material_override = BaseRace.mat(Color(String(GardenPrizes.game("relay")["colour"])))
	baton.position = Vector3(0, g + 1.15, 0)
	baton.rotation.z = PI * 0.5
	stand.add_child(baton)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(stand):
		return {}
	if p2.distance_to(Vector2(stand.position.x, stand.position.z)) > REACH:
		return {}
	return {"kind": "relay"}

func label() -> String:
	return "Run the Relay Cup (%s round)" % cup_round(Save.active_kin())["name"]

func use() -> void:
	var ks := race.entrants().slice(0, 3)
	if ks.size() < 3:
		h._toast("The Relay Cup needs three rested Boki out on the base")
		return
	var by_rec := {}
	var recs: Array = []
	for k in ks:
		by_rec[k["rec"]] = k
		recs.append(k["rec"])
	recs = order(recs)
	mine = recs.map(func(r): return by_rec[r])
	anchor = Save.active_kin() if recs.has(Save.active_kin()) else recs[0]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run = Run.new(recs, rivals(recs, float(cup_round(anchor)["min_ratio"])), rng)
	for k in mine:
		k["busy"] = true
	visitors = []
	for rec in run.teams[1]:
		var n := Models.kin(String(rec["species"]), rec)
		h.add_child(n)
		visitors.append({"rec": rec, "node": n})
	bar = TimingBar.new()
	bar.open(h.root_ui, "Press %s before each mark to hand off" % Settings.key_cap("interact"))
	_bar_label("")
	_place_runners()
	heard = [0, 0]
	crossed = [false, false]
	finish_left = -1.0
	GardenSfx.countdown(h, race.start)

func _bar_label(last: String) -> void:
	var to: String = run.teams[0][mini(run.grades.size() + 1, 2)]["name"]
	bar.lbl.text = "Hand-off %d of 2 to %s%s" % [mini(run.grades.size() + 1, 2), to, last]

## A press: true when the relay took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if not TimingBar.is_press(event):
		return false
	if run.can_press():
		var r := bar.press()
		run.press(r)
		var k: Dictionary = mine[run.leg[0]]
		GardenSfx.crowd(r, k["pos"])
		h._emote(k, {"great": "★", "good": "♪", "miss": "?"}[r], true)
		_bar_label("  " + {"great": "★", "good": "●", "miss": "✕"}[r])
	return true

func tick(d: float) -> void:
	if run == null:
		return
	run.step(d)
	bar.step(d)
	_place_runners()
	_hear()
	beats.step(run.t)
	if run.over():
		if finish_left < 0.0:
			finish_left = float(RelayBeats.rules()["finish_s"])
		finish_left -= d
		if finish_left <= 0.0:
			_end(true)

## Sounds for what happened this step, per team: a clean pass (no more lost than a good press) or a fumble at the
## runner taking the baton, and the tape when its last runner is home.
func _hear() -> void:
	var clean_s := float(rules()["handoff"]["good"])
	for team in 2:
		var ents: Array = mine if team == 0 else visitors
		var lost: Array = run.lost[team]
		while int(heard[team]) < lost.size():
			var s := float(lost[heard[team]])
			heard[team] = int(heard[team]) + 1
			GardenSfx.cue("relay_handoff" if s <= clean_s else "relay_fumble", ents[heard[team]]["pos"])
			var at: int = heard[team]
			beats.hand_off(ents[at - 1]["node"], ents[at]["node"], run.t, s, run.boost[team])
		if float(run.done_t[team]) >= 0.0 and not crossed[team]:
			crossed[team] = true
			GardenSfx.cue("relay_finish", ents[-1]["pos"])
			RelayBeats.finish(_nodes(ents), not crossed[1 - team])

func _nodes(ents: Array) -> Array:
	return ents.map(func(e): return e["node"])

func _place_runners() -> void:
	var st: Array = BaseRace.rules()["stretches"]
	var lane := float(BaseRace.rules()["lane"])
	for team in 2:
		var side := lane * (team - 0.5)
		var ents: Array = mine if team == 0 else visitors
		for i in ents.size():
			var s := int(run.legs[i][0])
			var f := 0.0
			var out := 0.0
			if i < int(run.leg[team]) or float(run.done_t[team]) >= 0.0:
				s = int(run.legs[i][-1])
				f = 1.0
				out = DONE_SIDE * signf(side)
			elif i == int(run.leg[team]):
				s = int(run.stretch[team])
				var into := float(run.dist[team]) - (float(run.ends[s - 1]) if s > 0 else 0.0)
				f = clampf(into / float(st[s]["len"]), 0.0, 1.0)
			var p := race.track_at(s, f, side + out)
			var n: Node3D = ents[i]["node"]
			n.position = p
			n.rotation.y = race.heading(s)
			ents[i]["pos"] = p

func _end(finished: bool) -> void:
	var res := {}
	if finished:
		res = settle(run, anchor)
	beats.clear(_nodes(mine) + _nodes(visitors))
	for k in mine:
		k["busy"] = false
		k["t"] = 1.5
	for v in visitors:
		v["node"].queue_free()
	bar.close()
	if finished:
		_card(res)
		var k: Dictionary = h._kin_entry(anchor)
		var pair: Array = [k, visitors[-1]] if res["won"] else [visitors[-1], k]
		GardenSfx.fanfare(h, pair[0], pair[1])
		for m in mine:
			h._emote(m, "♥" if res["won"] else "…", true)
		Save.save_game()
	run = null
	mine = []
	visitors = []

func _card(res: Dictionary) -> void:
	var st: Array = BaseRace.rules()["stretches"]
	var legs: Array = []
	for i in run.legs.size():
		legs.append("%s the %s" % [run.teams[0][i]["name"], st[run.legs[i][0]]["kind"]])
	var hand := ""
	for i in run.grades.size():
		hand += "%s %.1f s  " % [{"great": "★", "good": "●", "miss": "✕"}[run.grades[i]], run.lost[0][i]]
	var title := "Your team wins the Relay Cup!" if res["won"] else "The %s win the Relay Cup" % rules()["rival_team"]
	race.show_card(title, [
		[", ".join(legs), UI.INK],
		["Hand-offs: %s(%.1f s apart at the line)" % [hand, res["gap"]], UI.MUTED],
		["+%d gems" % res["gems"], UI.GOLD]] + GardenPrizes.rows(res["prize"]))
