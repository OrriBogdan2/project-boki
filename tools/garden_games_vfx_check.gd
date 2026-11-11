extends RefCounted
## --garden-games-vfx-check: the world cues of Echo Steps, Tumble, the Relay Cup and the Show Ring
## (scripts/home/garden_cues.gd), each played on the real base with base_mode on, on a fixed 30 fps clock:
##   1. Echo Steps, round 1: the lead's stone lights on the frame of its beat, at that stone, in the lead's type
##      colour; each beat you answer pulses the ring round the stones on its frame; a press on the beat
##      flashes a hit there in your colour; the beat left out flashes a miss on the frame its window closes
##   2. Tumble: the icon shows the move the tell shows, over the rival, from the frame the tell starts for
##      the tell's 1.5 s (to a frame); it is never solid: its alpha is the chance the tell is honest
##   3. Relay Cup: each baton rides over its runner; every hand-off bursts on its frame at the Boki taking it,
##      bright on a clean pass and dull on a fumble
##   4. Show Ring: each round's score pops on the frame the round ends with the score the judges gave (the
##      Trick round ended by its third press, the others by time), and both totals with the Bond score
## No cue spawns on any other frame. Never touches the real save.

const DT := 1.0 / 30.0           # s per step: one frame of the clips
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building
const NEAR := 0.05               # m a cue may sit from where it belongs
const TELLS := 3                 # tells watched before the bout is stopped
const LEFT_OUT := 2              # the answer beat (of the first phrase) the player leaves out
const MAX_S := 240.0             # s of game time any game may take

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("GGVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _stage()
	_echo()
	_tumble()
	_relay()
	_show()
	FarmUnlocks.rules()["base_mode"] = false
	print("GGVFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The base with three rested Boki of three types out.
func _stage() -> void:
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["zapple", "cindle", "kestrike"][i], ["Pip", "Ash", "Bo"][i])
		k["level"] = 5
		Care.ensure(k)
		k["needs"]["energy"] = 95.0
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	for k in home.kins:
		k.erase("indoors")

static func near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) <= NEAR

## Freed, or freed at the end of this frame.
static func gone(n: Node) -> bool:
	return not is_instance_valid(n) or n.is_queued_for_deletion()

static func same(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)

func _echo() -> void:
	var es: EchoSteps = home.hecho
	es.use()
	var r := es.run
	var cue := es.cue
	var you := GardenCues.type_colour(es.dancers[EchoSteps.YOU]["rec"])
	var lead := GardenCues.type_colour(es.dancers[EchoSteps.RIVAL]["rec"])
	var n := {"lead": 0, "pulse": 0, "hit": 0, "miss": 0, "wrong": 0}
	var skipped := -1                  # grid beat left out
	var now := 0.0
	while r.round_i == 0 and now < MAX_S:
		now += DT
		var pressed := -1
		if r.state == EchoSteps.Run.S.ANSWER:
			var i := floori(now / r.beat_s) - r.first
			if i >= 0 and i < r.pattern.size() and not r.done[i] and now - DT < r.at(r.first + i):
				if r.phrase == 0 and i == LEFT_OUT:
					skipped = r.first + i
				else:
					pressed = r.pattern[i]
					r.press(now, pressed)
		var was := [cue.beats.spawns, cue.pulses.spawns, cue.flashes.spawns]
		es.step_to(now, DT)
		if r.over():
			break
		var b := floori(now / r.beat_s)
		var i := b - r.first
		var on_beat := now - DT < r.at(b) and i >= 0 and i < r.pattern.size() \
				and (r.state == EchoSteps.Run.S.CALL or r.state == EchoSteps.Run.S.ANSWER)
		var lit: int = cue.beats.spawns - was[0]
		var pulsed: int = cue.pulses.spawns - was[1]
		var flashed: int = cue.flashes.spawns - was[2]
		if on_beat and not r.mine():
			n["lead"] += lit
			var stone_at := es._stone_at(r.pattern[i]) + GardenCues.EchoCue.UP
			var lead_col := Color(lead, GardenCues.BRIGHT)
			if lit != 1 or not near(cue.beats.last_at, stone_at) or not same(cue.beats.last_col, lead_col):
				n["wrong"] += 1
		elif lit != 0:
			n["wrong"] += 1
		if on_beat and r.mine():
			n["pulse"] += pulsed
			if pulsed != 1 or not same(cue.pulses.last_col, Color(you, GardenCues.DIM)):
				n["wrong"] += 1
		elif pulsed != 0:
			n["wrong"] += 1
		var closed := skipped >= 0 and now - DT <= r.at(skipped) + r.window and now > r.at(skipped) + r.window
		if pressed >= 0:
			n["hit"] += flashed
			var flash_at := es._stone_at(pressed) + GardenCues.EchoCue.UP
			var hit_col := Color(you.lightened(0.35), 1.0)
			if flashed != 1 or not near(cue.flashes.last_at, flash_at) or not same(cue.flashes.last_col, hit_col):
				n["wrong"] += 1
		elif closed:
			n["miss"] += flashed
			if flashed != 1 or not same(cue.flashes.last_col, Color(GardenCues.MISS, GardenCues.BRIGHT)):
				n["wrong"] += 1
		elif flashed != 0:
			n["wrong"] += 1
	var beats := int(EchoSteps.rules()["rounds"][0]) * int(EchoSteps.rules()["phrases"])
	ok(n["lead"] == beats, "echo: the lead's stone lit on each of its %d beats (%d)" % [beats, n["lead"]])
	ok(n["pulse"] == beats, "echo: the ring round the stones pulsed on your %d beats (%d)" % [beats, n["pulse"]])
	ok(n["hit"] == beats - 1, "echo: a hit flashed on the frame of each of %d presses (%d)" % [beats - 1, n["hit"]])
	ok(n["miss"] == 1, "echo: the beat left out flashed a miss as its window closed")
	ok(n["wrong"] == 0, "echo: every cue on its frame, at its stone, in its colour (%d off)" % n["wrong"])
	es._end(false)
	ok(es.cue == null and gone(cue.root), "echo: the cues go with the dance")

func _tumble() -> void:
	var tb: BaseTumble = home.htumble
	tb.use()
	var cue := tb.cue
	var col := GardenCues.type_colour(tb.pair[1]["rec"])
	var tell_s := float(BaseTumble.rules()["tell_s"])
	var tells := 0
	var wrong := 0
	var started := 0.0
	var spans: Array = []
	var t := 0.0
	while tb.run != null and tells <= TELLS and t < MAX_S:
		var was := tb.run.state
		tb.tick(DT)
		t += DT
		if tb.run == null:
			break
		var state := tb.run.state
		if state == "tell" and was != "tell":
			tells += 1
			started = t
			var shown: bool = cue.shown == tb.run.tell and cue.icons[tb.run.tell].visible
			var alpha := cue.mat.albedo_color.a
			var weight := is_equal_approx(alpha, GardenCues.BRIGHT * tb.run.honest(0)) and alpha < GardenCues.BRIGHT
			var hue := same(Color(cue.mat.albedo_color, 1.0), Color(col, 1.0))
			var over := near(cue.root.position, tb.pair[1]["pos"] + Vector3(0, GardenCues.LIFT, 0))
			if not (shown and weight and hue and over):
				wrong += 1
		elif was == "tell" and state != "tell":
			spans.append(t - started)
			if cue.shown != "" or cue.icons.values().any(func(n): return n.visible):
				wrong += 1
	ok(spans.size() >= TELLS, "tumble: %d tells watched" % spans.size())
	ok(spans.all(func(s): return absf(s - tell_s) <= DT + 0.001),
			"tumble: each icon showed for the tell's %.1f s to a frame %s" % [tell_s, str(spans)])
	ok(wrong == 0, "tumble: the tell's move over the rival in its colour, alpha = its honesty (%d off)" % wrong)
	tb._end(false)
	ok(tb.cue == null and gone(cue.root), "tumble: the icon goes with the bout")

func _relay() -> void:
	var rl: BaseRelay = home.hrace.relay
	rl.use()
	var cue := rl.cue
	var legs := [0, 0]
	var passes := 0
	var wrong := 0
	var t := 0.0
	while rl.run != null and t < MAX_S:
		var was := cue.rings.spawns
		rl.tick(DT)
		t += DT
		if rl.run == null:
			break
		var changed := 0
		for team in 2:
			var ents: Array = rl.mine if team == 0 else rl.visitors
			var leg := int(rl.run.leg[team])
			var k: Dictionary = ents[leg]
			if not near(cue.batons[team].position, k["pos"] + Vector3(0, GardenCues.LIFT - 0.4, 0)):
				wrong += 1
			if leg == legs[team]:
				continue
			legs[team] = leg
			changed += 1
			passes += 1
			var c := GardenCues.type_colour(k["rec"])
			var clean := float(rl.run.lost[team][-1]) == 0.0
			var tone := Color(c.lightened(0.4), 1.0) if clean else Color(GardenCues.MISS, GardenCues.BRIGHT)
			if not near(cue.rings.last_at, k["pos"] + Vector3(0, 0.06, 0)) or not same(cue.rings.last_col, tone):
				wrong += 1
		if cue.rings.spawns - was != changed:
			wrong += 1
	ok(passes == 4, "relay: four hand-offs, two a team (%d)" % passes)
	ok(wrong == 0, "relay: batons over their runners, each hand-off burst on its frame at the taker (%d off)" % wrong)
	ok(rl.run == null and rl.cue == null and gone(cue.root), "relay: the batons go with the race")

func _press(game) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	game.input(ev)

func _show() -> void:
	var sr: ShowRing = home.hshow
	sr.use()
	var cue := sr.cue
	var rounds := 0
	var wrong := 0
	var t := 0.0
	while sr.run != null and sr.run.phase != ShowRing.Run.Phase.JUDGE and t < MAX_S:
		var was := sr.run.phase
		var popped := cue.spawns
		if sr.run.can_trick():
			_press(sr)
		else:
			sr.tick(DT)
		t += DT
		var r := sr.run
		if r.phase == was:
			if cue.spawns != popped:
				wrong += 1
			continue
		rounds += 1
		var shown: Dictionary = r.recs[r.backed]
		var want: Array = []
		match was:
			ShowRing.Run.Phase.LOOK:
				want = ["Look %.1f" % ShowRing.sum(ShowRing.look(shown))]
			ShowRing.Run.Phase.TRICK:
				want = ["Trick %.1f" % ShowRing.trick(shown, r.grades)]
			ShowRing.Run.Phase.BOND:
				var s := r.scores()
				want = ["Bond %.1f" % ShowRing.bond(shown, r.calls), "%.1f" % float(s[0]["total"]),
						"%.1f" % float(s[1]["total"])]
		var texts: Array = cue.labels.map(func(l): return l.text)
		if cue.spawns - popped != want.size() or not want.all(func(w): return texts.has(w)):
			wrong += 1
			print("GGVFX   round %d popped %s, wanted %s" % [was, str(texts), str(want)])
	ok(rounds == 3, "show: Look, Trick and Bond ended (%d)" % rounds)
	ok(wrong == 0, "show: each round's score popped on the frame it ended, the totals with the Bond (%d off)" % wrong)
	sr._end(false)
	ok(sr.cue == null and gone(cue.root), "show: the pops go with the show")
