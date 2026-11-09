class_name BaseShove
extends RefCounted
## Stump Shove (briefs/design/GARDEN.md section 5.2), the Boki base's second minigame; only with
## farm_build.json base_mode on. A stump stands by the Training post. Press interact at it and two
## rested Boki out on the base (your partner and the next one) push on it from opposite sides until
## one is shoved off balance. Push comes from Power, held off by the other's Guard; mood and trust
## nudge it, a species theme that beats the other's gives a 10% edge (content/rules/base_shove.json
## "beats"). You back your partner and press once on the Training post's timing bar for a burst of
## push. The winner gains joy, trust and you a few gems; the loser sulks and remembers.
## Tuning: content/rules/base_shove.json. Run is the bout itself (no nodes), so --shove-check
## (tools/shove_check.gd) runs it headless.

const STUMP_OFF := Vector3(-2.4, 0, 0.6)     # m from the Training post to the stump
const STUMP_H := 0.55                         # m, the stump's height
const STUMP_R := 0.3                          # m, its radius
const GAP := 0.55                             # m from the stump's middle to each pusher
const SLIDE := 0.5                            # m the pair slides along the push at full balance
const TILT := 0.5                             # rad the stump leans at full balance
const REACH := 1.6                            # m from the stump to start a bout

static func rules() -> Dictionary:
	return Content.rules("base_shove")

static func theme(rec: Dictionary) -> String:
	return String(Data.KIN.get(String(rec.get("species", "")), {}).get("theme", ""))

## Does a's species theme beat b's?
static func has_edge(a: Dictionary, b: Dictionary) -> bool:
	return rules()["beats"].get(theme(a), []).has(theme(b))

## What a Boki pushes with against another, before the wobble and your press.
static func push(rec: Dictionary, foe: Dictionary) -> float:
	var R := rules()
	var power := float(rec.get("stats", {}).get("power", 0))
	var mood: Array = R["mood"]
	var p := float(R["push"]) * (1.0 + power * float(R["power_per_point"]))
	p *= lerpf(float(mood[0]), float(mood[1]), Care.need(rec, "joy") / 100.0)
	p *= lerpf(1.0, float(R["trust_max"]), float(rec.get("trust", 0.0)) / 100.0)
	return p * (float(R["edge"]) if has_edge(rec, foe) else 1.0)

## How firmly it holds against a push.
static func hold(rec: Dictionary) -> float:
	return 1.0 + float(rec.get("stats", {}).get("guard", 0)) * float(rules()["guard_per_point"])

## a's net drift over b's: above 0 the expected winner is a, below 0 it is b.
static func expected(a: Dictionary, b: Dictionary) -> float:
	return push(a, b) / hold(b) - push(b, a) / hold(a)

## The bout itself: the stump's balance, stepped in time. balance runs -1 (b wins) to 1 (a wins).
class Run:
	var R: Dictionary
	var recs: Array                 # two records: a (index 0) and b (index 1)
	var backed := 0                 # index in recs: the Boki you back
	var rng: RandomNumberGenerator
	var t := 0.0
	var balance := 0.0
	var roll: Array = [1.0, 1.0]    # each side's wobble
	var roll_t := 0.0               # s until the next wobble
	var shoved := false             # your one press is used
	var boost := 1.0                # your press, on the backed Boki's push
	var boost_t := 0.0              # s of boost left
	var base: Array = []            # each side's push over the other's hold

	func _init(pair: Array, back: int, r: RandomNumberGenerator) -> void:
		R = BaseShove.rules()
		recs = pair
		backed = back
		rng = r
		for i in 2:
			base.append(BaseShove.push(recs[i], recs[1 - i]) / BaseShove.hold(recs[1 - i]))

	func can_shove() -> bool:
		return not shoved and not over()

	func shove(grade: String) -> void:
		shoved = true
		boost = float(R["shove"][grade])
		boost_t = float(R["shove_s"])

	func over() -> bool:
		return absf(balance) >= 1.0 or t >= float(R["max_s"])

	## 0 or 1: who stands, by the balance (a on a dead level).
	func winner() -> int:
		return 0 if balance >= 0.0 else 1

	func step(dt: float) -> void:
		t += dt
		roll_t -= dt
		if roll_t <= 0.0:
			roll_t = float(R["wobble_s"])
			for i in 2:
				roll[i] = rng.randf_range(1.0 - float(R["wobble"]), 1.0 + float(R["wobble"]))
		var force: Array = []
		for i in 2:
			var f := float(base[i]) * float(roll[i])
			if i == backed and boost_t > 0.0:
				f *= boost
			force.append(f)
		boost_t = maxf(0.0, boost_t - dt)
		balance = clampf(balance + (float(force[0]) - float(force[1])) * float(R["rate"]) * dt, -1.0, 1.0)

## Pays out a finished bout: joy, trust, a memory each, energy and gems. Returns what the card shows.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var win: Dictionary = run.recs[run.winner()]
	var lose: Dictionary = run.recs[1 - run.winner()]
	for rec in run.recs:
		Care.change(rec, "energy", -float(R["energy"]))
	Care.change(win, "joy", float(R["win_joy"]))
	Care.change(lose, "joy", float(R["lose_joy"]))
	Save.remember(win, "shove", "shoved %s off the stump" % lose["name"], float(R["win_trust"]))
	Save.remember(lose, "shove", "lost the Stump Shove to %s" % win["name"])
	var backed_won: bool = run.recs[run.backed] == win
	var gems := int(R["gems_win"]) if backed_won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var stump: Node3D = null
var run: Run = null
var pair: Array = []           # the home's kin entries: a, b
var bar: TimingBar = null
var card: Control = null
var card_t := 0.0
var held: Array = []           # the winner and the loser, kept on the spot until the card goes

func _init(home) -> void:
	h = home

## The stump beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(stump):
		stump.queue_free()
	stump = null
	if h.YARD_AT.x < -100.0:
		return
	stump = Node3D.new()
	stump.name = "Stump"
	stump.position = h.YARD_AT + STUMP_OFF
	h.add_child(stump)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = STUMP_R * 0.9
	cm.bottom_radius = STUMP_R
	cm.height = STUMP_H
	trunk.mesh = cm
	trunk.material_override = BaseRace.mat(Color("7a5638"))
	trunk.position.y = STUMP_H * 0.5
	stump.add_child(trunk)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = STUMP_R * 0.9
	tm.bottom_radius = STUMP_R * 0.9
	tm.height = 0.03
	top.mesh = tm
	top.material_override = BaseRace.mat(Color("d9b98a"))
	top.position.y = STUMP_H
	stump.add_child(top)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(stump):
		return {}
	if p2.distance_to(Vector2(stump.position.x, stump.position.z)) > REACH:
		return {}
	return {"kind": "shove"}

func label() -> String:
	return "Start a Stump Shove (back %s)" % Save.active_kin().get("name", "your partner")

func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.size() < 2:
		h._toast("The Stump Shove needs two rested Boki out on the base")
		return
	pair = ks.slice(0, 2)
	for k in pair:
		k["busy"] = true
		BaseRace.act(k, "push")
	var back := maxi(0, [pair[0]["rec"], pair[1]["rec"]].find(Save.active_kin()))
	run = Run.new([pair[0]["rec"], pair[1]["rec"]], back, RandomNumberGenerator.new())
	run.rng.randomize()
	bar = TimingBar.new()
	bar.open(h.root_ui, "Press %s once, with the marker in the gold, to shove" % Settings.key_cap("interact"))
	bar.lbl.text = "Shove with %s" % run.recs[run.backed]["name"]
	_place_pair()
	Sfx.play("whoosh", null, -8.0)

## A press: true when the bout took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if not TimingBar.is_press(event):
		return false
	if run.can_shove():
		var r := bar.press()
		run.shove(r)
		bar.close()
		h._emote(pair[run.backed], {"great": "★", "good": "♪", "miss": "?"}[r], true)
	return true

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
		if card_t <= 0.0:
			BaseRace.let_go(held)
			held = []
	if run == null:
		return
	run.step(d)
	if not run.shoved:
		bar.step(d)
	_place_pair()
	if run.over():
		_end(true)

## The pair slide along the push and the stump leans toward whoever is losing.
func _place_pair() -> void:
	var mid := stump.position + Vector3(run.balance * SLIDE, 0, 0)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var p := mid + Vector3(side * GAP, 0, 0)
		var g: float = h._ground_h(p.x, p.z)
		p.y = g if g > -50.0 else 0.0
		var n: Node3D = pair[i]["node"]
		n.position = p
		n.rotation.y = atan2(side, 0.0)
		pair[i]["pos"] = p
	stump.rotation.z = -run.balance * TILT

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
		BaseRace.act(k, "")
	bar.close()
	stump.rotation.z = 0.0
	if finished:
		_card(res)
		h._emote(h._kin_entry(res["win"]), "♥", true)
		h._emote(h._kin_entry(res["lose"]), "…", true)
		held = BaseRace.hold(h, res)
		Save.save_game()
	run = null
	pair = []

func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var why := " for backing the winner" if res["backed_won"] else ""
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(h, [
		["%s holds the stump!" % win["name"], 18, UI.ACCENT_HI],
		["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
		["%s sulks: \"lost the Stump Shove to %s\"" % [lose["name"], win["name"]], 14, UI.MUTED],
		["+%d gems%s" % [res["gems"], why], 14, UI.GOLD]])
	card_t = float(rules()["card_s"])
