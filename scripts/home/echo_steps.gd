class_name EchoSteps
extends RefCounted
## Echo Steps (briefs/design/GARDEN_MODERN.md section 4.2, game 2), a call-and-answer dance; only with
## farm_build.json base_mode on. Four humming stones lie by the Training post, one note each. Press
## interact there: the lead hops a pattern across the stones on the beat and you answer it with W, A,
## S, D. Three rounds (4, 6 and 8 beats a phrase, at 100 bpm); in the last you lead and the rival copies,
## missing by its Focus. Focus widens your hit window, trust fixes misses (Close one a round, Soulbound
## two: "it remembered"), and a Sound type or lean keeps a streak through one miss. Hits and streaks
## score. With two rested Boki out it is a versus against the second (it leads); with one, a solo where
## the stones lead. Tuning: content/rules/base_echo.json.
##
## Time is the audio clock: the beat bed's playback position (EchoSteps._clock), never frame time, so
## presses are judged against what you hear. The dance is one explicit state machine
## (briefs/STATE_MACHINES.md), Run.state: only Run.go() writes it, and a move the TABLE lacks is refused
## and counted.
##   CALL   -> ANSWER  the lead hops the pattern (in the last round: you make it)
##   ANSWER -> CALL    you answer it (in the last round: the rival copies), then the next phrase
##          -> SCORE   after the round's last phrase: the tally
##   SCORE  -> CALL    the next round
##          -> RESULT  after the last round
## Run has no nodes, so --echo-steps-check (tools/echo_steps_check.gd) plays whole dances headless.

const STONES_OFF := Vector3(-3.6, 0, -2.4)   # m from the Training post to the middle of the stones
const SPREAD := 1.0                           # m from the middle to each stone
const STONE_R := 0.36                         # m, a stone's radius
const STONE_H := 0.14                         # m, its height
const SIDE := Vector3(1.6, 0, 1.6)            # m from the middle to where you (-x) and the rival (+x) wait
const HOP_H := 0.35                           # m a hop rises
const REACH := 2.2                            # m from the middle to start a dance
const MIX_RATE := 22050                       # Hz of the generated notes and bed
const TONE_AMP := 30000.0                     # a generated tone's peak, of the 16-bit 32767
const KEYS := ["up", "left", "down", "right"]  # the move action that answers on each stone (W, A, S, D)
const STONE_AT := [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)]
const STONE_COL := [Color("7ad0ff"), Color("8ae07a"), Color("ffb05a"), Color("e08aff")]
const YOU := 0
const RIVAL := 1

static func rules() -> Dictionary:
	return Content.rules("base_echo")

## A dancer's spin lasts two beats.
static func spin_s() -> float:
	return 2.0 * 60.0 / float(rules()["bpm"])

static func _focus(rec: Dictionary) -> float:
	return clampf(float(rec.get("stats", {}).get("focus", 0)) / 100.0, 0.0, 1.0)

## s either side of a beat a press still counts: Focus widens it.
static func window_s(rec: Dictionary) -> float:
	var w: Array = rules()["window_ms"]
	return lerpf(float(w[0]), float(w[1]), _focus(rec)) / 1000.0

## Misses a round this Boki fixes for you, by its bond rank.
static func fixes(rec: Dictionary) -> int:
	return int(rules()["fixes"].get(Care.bond(rec)[1], 0))

## Misses a round this Boki's streak survives: its Sound type or lean.
static func streak_saves(rec: Dictionary) -> int:
	var R := rules()
	var ln := Evo.lean(rec)
	var sound: bool = (R["sound_themes"] as Array).has(BaseShove.theme(rec)) \
			or (ln[0] == "sound" and float(ln[1]) >= float(R["sound_lean"]))
	return int(R["sound_saves"]) if sound else 0

## The chance the rival misses a step it copies.
static func copy_miss(rec: Dictionary) -> float:
	var m: Array = rules()["rival_miss"]
	return lerpf(float(m[0]), float(m[1]), _focus(rec))

## The dance itself, stepped by the audio clock. Sides: YOU (recs[0]) and RIVAL (recs[1], {} solo).
class Run:
	enum S { CALL, ANSWER, SCORE, RESULT }
	const TABLE := {S.CALL: [S.ANSWER], S.ANSWER: [S.CALL, S.SCORE], S.SCORE: [S.CALL, S.RESULT], S.RESULT: []}

	var R: Dictionary
	var recs: Array
	var versus := false
	var rng: RandomNumberGenerator
	var state := S.CALL
	var refused := 0                # moves the TABLE turned down
	var beat_s := 0.6               # s a beat
	var window := 0.12              # s either side of a beat that a press counts
	var round_i := 0
	var phrase := 0
	var pattern: Array = []         # the phrase's stone per beat; -1 for a rest you left in your lead
	var done: Array = []            # per beat of the phase: judged (or played) already
	var first := 0                  # grid beat of this phase's first pattern beat
	var end_beat := 0               # grid beat the phase ends on (it hands over half a beat early)
	var score: Array = [0, 0]
	var hits: Array = [0, 0]
	var beats: Array = [0, 0]       # beats each side was judged on
	var streak: Array = [0, 0]
	var best: Array = [0, 0]        # longest streak
	var fixes_left := 0             # trust fixes left this round
	var fixed := 0                  # misses trust fixed in all
	var saves: Array = [0, 0]       # streak saves left this round
	var events: Array = []          # [kind, side, stone] for the base to show: hop, hit, fixed, kept, miss
	var end_t := 0.0                # s on the clock the dance ended

	func _init(you: Dictionary, rival: Dictionary, r: RandomNumberGenerator) -> void:
		R = EchoSteps.rules()
		recs = [you, rival]
		versus = not rival.is_empty()
		rng = r
		beat_s = 60.0 / float(R["bpm"])
		window = EchoSteps.window_s(you)
		_start_round(0)

	## The only writer of `state`: false (and counted) when the TABLE lacks the move.
	func go(next: S) -> bool:
		if not TABLE[state].has(next):
			refused += 1
			return false
		state = next
		return true

	## s on the clock of grid beat b.
	func at(b: int) -> float:
		return b * beat_s

	func you_lead() -> bool:
		return round_i == (R["rounds"] as Array).size() - 1

	## Is it your turn to press: answering, or making the pattern in the last round.
	func mine() -> bool:
		return (state == S.CALL and you_lead()) or (state == S.ANSWER and not you_lead())

	func over() -> bool:
		return state == S.RESULT

	## One number per phase, so the base sees a new one without building anything.
	func phase_key() -> int:
		return (round_i * 100 + phrase) * 10 + state

	## Points per judged beat: what a versus compares, since you dance more beats than the rival.
	func rate(side: int) -> float:
		return float(score[side]) / maxf(1.0, float(beats[side]))

	func winner() -> int:
		return YOU if rate(YOU) >= rate(RIVAL) else RIVAL

	func _start_round(b0: int) -> void:
		phrase = 0
		fixes_left = EchoSteps.fixes(recs[YOU])
		saves = [EchoSteps.streak_saves(recs[YOU]), EchoSteps.streak_saves(recs[RIVAL]) if versus else 0]
		_start_call(b0 + int(R["count_in"]))

	func _start_call(b: int) -> void:
		var n := int(R["rounds"][round_i])
		first = b
		end_beat = b + n + int(R["gap"])
		pattern = []
		for i in n:
			pattern.append(-1 if you_lead() else rng.randi() % 4)
		done = []
		done.resize(n)
		done.fill(false)

	func _start_answer() -> void:
		first = end_beat
		end_beat = first + pattern.size()
		done.fill(false)

	## Moves the clock to now: plays and judges the beats due, then hands over each finished phase.
	func step(now: float) -> void:
		while state != S.RESULT:
			_beats(now)
			if now < at(end_beat) - beat_s * 0.5:
				return
			_finish_phase()

	func _beats(now: float) -> void:
		if state != S.CALL and state != S.ANSWER:
			return
		for i in pattern.size():
			if done[i]:
				continue
			var t := at(first + i)
			if mine():
				if now <= t + window:
					return
				done[i] = true
				var kind := _judge(YOU, pattern[i], false)
				if kind == "fixed" and pattern[i] < 0:
					pattern[i] = rng.randi() % 4
					events[-1][2] = pattern[i]
				continue
			if now < t:
				return
			done[i] = true
			if state == S.CALL:
				events.append(["hop", RIVAL, pattern[i]])
			elif pattern[i] >= 0:
				_copy(pattern[i])

	func _finish_phase() -> void:
		match state:
			S.CALL:
				go(S.ANSWER)
				_start_answer()
			S.ANSWER:
				if phrase + 1 < int(R["phrases"]):
					phrase += 1
					go(S.CALL)
					_start_call(end_beat)
				else:
					go(S.SCORE)
					end_beat += int(R["score_beats"])
			S.SCORE:
				if round_i + 1 < (R["rounds"] as Array).size():
					round_i += 1
					go(S.CALL)
					_start_round(end_beat)
				else:
					go(S.RESULT)
					end_t = at(end_beat) - beat_s * 0.5

	## A press of stone at now. Your Boki hops on any press in your turn; one inside a beat's window
	## that beat has not had yet is judged.
	func press(now: float, stone: int) -> void:
		step(now)
		if not mine():
			return
		events.append(["hop", YOU, stone])
		var i := roundi((now - at(first)) / beat_s)
		if i < 0 or i >= pattern.size() or done[i] or absf(now - at(first + i)) > window:
			return
		done[i] = true
		if state == S.CALL:
			pattern[i] = stone
		_judge(YOU, pattern[i], pattern[i] == stone)

	## The rival copies one step of your pattern; its Focus decides if it misses.
	func _copy(stone: int) -> void:
		if not versus:
			events.append(["hop", RIVAL, stone])
			return
		var miss := rng.randf() < EchoSteps.copy_miss(recs[RIVAL])
		events.append(["hop", RIVAL, (stone + 1 + rng.randi() % 3) % 4 if miss else stone])
		_judge(RIVAL, stone, not miss)

	## Scores one beat for side: a hit, or a miss that trust fixes, a Sound streak keeps, or that ends
	## the streak. Returns the kind it showed.
	func _judge(side: int, stone: int, hit: bool) -> String:
		beats[side] += 1
		var kind := "hit"
		if not hit:
			if side == YOU and fixes_left > 0:
				fixes_left -= 1
				fixed += 1
				kind = "fixed"
			elif saves[side] > 0 and streak[side] > 0:
				saves[side] -= 1
				kind = "kept"
			else:
				streak[side] = 0
				kind = "miss"
		if kind == "hit" or kind == "fixed":
			hits[side] += 1
			streak[side] += 1
			best[side] = maxi(best[side], streak[side])
			score[side] += int(R["hit_pts"]) + int(R["streak_pts"]) * mini(streak[side] - 1, int(R["streak_cap"]))
		events.append([kind, side, stone])
		return kind

## Pays out a finished dance: joy, trust, memories, energy and gems. Returns what the card shows.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var you: Dictionary = run.recs[YOU]
	for rec in run.recs:
		if not rec.is_empty():
			Care.change(rec, "energy", -float(R["energy"]))
	var res := {"score": run.score, "best": run.best[YOU]}
	if run.versus:
		var win: Dictionary = run.recs[run.winner()]
		var lose: Dictionary = run.recs[1 - run.winner()]
		Care.change(win, "joy", float(R["win_joy"]))
		Care.change(lose, "joy", float(R["lose_joy"]))
		Save.remember(win, "echo", "out-danced %s at Echo Steps" % lose["name"], float(R["win_trust"]))
		Save.remember(lose, "echo", "lost Echo Steps to %s" % win["name"])
		res.merge({"win": win, "lose": lose, "good": win == you})
	else:
		var good := float(run.hits[YOU]) >= float(R["solo_good"]) * float(run.beats[YOU])
		if good:
			Care.change(you, "joy", float(R["win_joy"]))
		var trust := float(R["win_trust"]) if good else 0.0
		Save.remember(you, "echo", "danced Echo Steps for %d points" % run.score[YOU], trust)
		res["good"] = good
	res["gems"] = int(R["gems_win"]) if res["good"] else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + res["gems"]
	return res

## A generated tone: a sine of hz fading at decay per second, secs long. With every > 0 it restarts
## each `every` s and loops (the beat bed).
static func tone(hz: float, decay: float, secs: float, every := 0.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		if every > 0.0:
			t = fmod(t, every)
		data.encode_s16(i * 2, int(sin(TAU * hz * t) * exp(-decay * t) * TONE_AMP))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.data = data
	if every > 0.0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var middle: Node3D = null
var stones: Array = []         # MeshInstance3D per stone
var glow: Array = [0.0, 0.0, 0.0, 0.0]   # s of glow left per stone
var voices: Array = []         # AudioStreamPlayer per stone, playing its note
var bed: AudioStreamPlayer = null
var run: Run = null
var dancers: Array = []        # the home's kin entries: you, the rival ({} solo)
var hops: Array = []           # per side: [from, to, start s on the clock]
var acts: Array = [["", 0.0], ["", 0.0]]   # per side: the rig clip it plays and the clock s it ends
var clock := 0.0               # s since the bed started, from its playback position
var bed_pos := 0.0             # the bed's last playback position (to count its loops)
var bed_loops := 0
var bar_s := 0.0               # s in one loop of the bed
var seen := -1                 # the phase the readout last showed (Run.phase_key)
var readout: Control = null
var lbl: Label = null
var card: Control = null
var card_t := 0.0
var cue: GardenCues.EchoCue = null   # the beat rings and hit/miss flashes while a dance runs
var cued := -1                 # the grid beat the cue last marked

func _init(home) -> void:
	h = home

## The four stones beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(middle):
		middle.queue_free()
	middle = null
	stones = []
	if h.YARD_AT.x < -100.0:
		return
	middle = Node3D.new()
	middle.name = "EchoStones"
	middle.position = h.YARD_AT + STONES_OFF
	h.add_child(middle)
	for s in 4:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = STONE_R * 0.9
		cm.bottom_radius = STONE_R
		cm.height = STONE_H
		mi.mesh = cm
		var m := BaseRace.mat(STONE_COL[s].darkened(0.35))
		m.emission_enabled = true
		m.emission = STONE_COL[s]
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		mi.position = STONE_AT[s] * SPREAD + Vector3(0, STONE_H * 0.5, 0)
		middle.add_child(mi)
		stones.append(mi)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(middle):
		return {}
	if p2.distance_to(Vector2(middle.position.x, middle.position.z)) > REACH:
		return {}
	return {"kind": "echo"}

func label() -> String:
	return "Dance Echo Steps (%s)" % Settings.key_cap("interact")

func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.is_empty():
		h._toast("Echo Steps needs a rested Boki out on the base")
		return
	dancers = [ks[0], ks[1] if ks.size() > 1 else {}]
	for k in dancers:
		if not k.is_empty():
			k["busy"] = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run = Run.new(dancers[YOU]["rec"], dancers[RIVAL].get("rec", {}), rng)
	hops = [[_spot(YOU), _spot(YOU), 0.0], [_spot(RIVAL), _spot(RIVAL), 0.0]]
	cue = GardenCues.EchoCue.new(h, middle.position, SPREAD + STONE_R + 0.15)
	cued = -1
	_sound_up()
	_open_readout()
	GardenSfx.cue("garden_go", null)

## The notes and the bed: generated once a dance; the bed's position is the dance's clock.
func _sound_up() -> void:
	var R := rules()
	var beat := 60.0 / float(R["bpm"])
	if voices.is_empty():
		for s in 4:
			var v := AudioStreamPlayer.new()
			v.bus = "SFX"
			v.stream = tone(float(R["notes_hz"][s]), float(R["note_decay"]), float(R["note_s"]))
			v.volume_db = float(R["note_db"])
			h.add_child(v)
			voices.append(v)
		bed = AudioStreamPlayer.new()
		bed.bus = "SFX"
		bed.stream = tone(float(R["bed_hz"]), float(R["bed_decay"]), beat * 4.0, beat)
		bed.volume_db = float(R["bed_db"])
		h.add_child(bed)
	bar_s = beat * 4.0
	clock = 0.0
	bed_pos = 0.0
	bed_loops = 0
	bed.play()

## s since the bed started: its playback position over its loops, plus the time since the last mix,
## less the output latency, so the beat is when you hear it. Never runs backwards.
func _clock() -> float:
	var pos := bed.get_playback_position()
	if pos < bed_pos:
		bed_loops += 1
	bed_pos = pos
	var now := bed_loops * bar_s + pos + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	clock = maxf(clock, now)
	return clock

## A press: true when the dance took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	for s in 4:
		if event.is_action_pressed(KEYS[s]):
			run.press(_clock(), s)
			return true
	return false

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run != null:
		step_to(_clock(), d)

## One frame of the dance at `now` on its clock (the checks pass their own).
func step_to(now: float, d: float) -> void:
	run.step(now)
	_beat_cue(now)
	for e in run.events:
		_show(e, now)
	run.events.clear()
	cue.step(d)
	var R := rules()
	for s in stones.size():
		glow[s] = maxf(0.0, glow[s] - d)
		var m: StandardMaterial3D = stones[s].material_override
		m.emission_energy_multiplier = float(R["glow_energy"]) * glow[s] / float(R["glow_s"])
	_place(now)
	if run.phase_key() != seen:
		_phase_turn(now)
	if run.over():
		_end(true)

func _show(e: Array, now: float) -> void:
	var side: int = e[1]
	var stone: int = e[2]
	match String(e[0]):
		"hop", "fixed":
			_hop(side, stone, now)
			voices[stone].play()
			glow[stone] = float(rules()["glow_s"])
			if e[0] == "fixed":
				h._emote(dancers[side], "!", true)
				cue.hit(_stone_at(stone), _col(side, stone))
		"hit":
			GardenSfx.cue("echo_hit", null)
			cue.hit(_stone_at(stone), _col(side, stone))
			if not dancers[side].is_empty() and run.streak[side] % int(rules()["cheer_every"]) == 0:
				GardenSfx.cue("echo_streak", null)
				h._emote(dancers[side], "♪", true)
		"kept":
			cue.miss(_stone_at(stone))
			h._emote(dancers[side], "♫", true)
			_act(side, "spin", spin_s(), now)
		"miss":
			GardenSfx.cue("echo_miss", null)
			cue.miss(_stone_at(stone))
			if not dancers[side].is_empty():
				h._emote(dancers[side], "?", true)
	lbl.text = _line()

func _hop(side: int, stone: int, now: float) -> void:
	_act(side, "stonehop", float(rules()["hop_s"]), now)
	hops[side] = [_at(side, now), _stone_at(stone) if stone >= 0 else _spot(side), now]

## A stone's middle; the stones' middle for a beat you left empty in your lead.
func _stone_at(stone: int) -> Vector3:
	return middle.position + STONE_AT[stone] * SPREAD if stone >= 0 else middle.position

## A cue's colour for side: its Boki's type colour, or the stone's own when the stones lead a solo.
func _col(side: int, stone: int) -> Color:
	return STONE_COL[stone] if dancers[side].is_empty() else GardenCues.type_colour(dancers[side]["rec"])

## On the first frame at or past each grid beat of a phase: the lead's stone lights in its colour; on a beat
## you dance, a ring round the stones keeps time without showing the stone.
func _beat_cue(now: float) -> void:
	var b := floori(now / run.beat_s)
	if b == cued:
		return
	cued = b
	var i := b - run.first
	if (run.state != Run.S.CALL and run.state != Run.S.ANSWER) or i < 0 or i >= run.pattern.size():
		return
	if run.mine() or run.pattern[i] < 0:
		cue.pulse(_col(YOU, 0))
	else:
		cue.beat(_stone_at(run.pattern[i]), _col(RIVAL, run.pattern[i]))

## The dancer plays a rig clip for `secs` (a spin is not cut short by a hop).
func _act(side: int, clip: String, secs: float, now: float) -> void:
	if dancers[side].is_empty() or (acts[side][0] == "spin" and now < float(acts[side][1])):
		return
	(dancers[side]["node"] as Node3D).set_meta("kact", clip)
	acts[side] = [clip, now + secs]

## Where side waits off the stones.
func _spot(side: int) -> Vector3:
	return middle.position + Vector3(SIDE.x * (-1.0 if side == YOU else 1.0), 0, SIDE.z)

## Where side is now: on its hop's arc.
func _at(side: int, now: float) -> Vector3:
	var hp: Array = hops[side]
	var u := clampf((now - float(hp[2])) / float(rules()["hop_s"]), 0.0, 1.0)
	var p: Vector3 = (hp[0] as Vector3).lerp(hp[1], u)
	var g: float = h._ground_h(p.x, p.z)
	p.y = (g if g > -50.0 else 0.0) + sin(u * PI) * HOP_H
	return p

func _place(now: float) -> void:
	for side in 2:
		if dancers[side].is_empty():
			continue
		var n: Node3D = dancers[side]["node"]
		n.position = _at(side, now)
		if now >= float(acts[side][1]):
			n.remove_meta("kact")
		var look: Vector3 = middle.position - n.position
		n.rotation.y = atan2(look.x, look.z)
		dancers[side]["pos"] = n.position

## A new phase: whoever is not dancing it goes back to its spot, and the readout says whose turn.
func _phase_turn(now: float) -> void:
	seen = run.phase_key()
	var dancing := YOU if run.mine() else RIVAL
	for side in 2:
		if side != dancing or run.state == Run.S.SCORE:
			_hop(side, -1, now)
	lbl.text = _line()

func _who(side: int) -> String:
	return String(dancers[side]["rec"]["name"]) if not dancers[side].is_empty() else "the stones"

func _line() -> String:
	var n := (rules()["rounds"] as Array).size()
	var head := "Round %d of %d" % [run.round_i + 1, n]
	var what := ""
	match run.state:
		Run.S.CALL:
			what = "Lead: make a pattern on the beat" if run.you_lead() else "Watch %s" % _who(RIVAL)
		Run.S.ANSWER:
			what = "%s copies you" % _who(RIVAL) if run.you_lead() else "Your turn: answer on the beat"
		_:
			what = "Round done"
	var tally := "%d points, streak %d" % [run.score[YOU], run.streak[YOU]]
	if run.versus:
		tally += "   %s %d" % [_who(RIVAL), run.score[RIVAL]]
	return "%s  ·  %s\n%s" % [head, what, tally]

func _open_readout() -> void:
	readout = UI.card(Color(0.06, 0.07, 0.1, 0.92), 12, 14)
	readout.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	readout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	readout.grow_vertical = Control.GROW_DIRECTION_BEGIN
	readout.offset_top = -64
	readout.offset_bottom = -64
	var col := UI.vbox(6)
	readout.add_child(col)
	lbl = UI.label("", 15)
	col.add_child(lbl)
	col.add_child(UI.label("%s %s %s %s on the stones, %s to stop" % [Settings.key_cap("up"), Settings.key_cap("left"),
			Settings.key_cap("down"), Settings.key_cap("right"), Settings.key_cap("menu")], 12, UI.MUTED))
	h.root_ui.add_child(readout)
	seen = -1

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	for k in dancers:
		if not k.is_empty():
			k["busy"] = false
			k["t"] = float(rules()["rest_s"])
			(k["node"] as Node3D).remove_meta("kact")
	acts = [["", 0.0], ["", 0.0]]
	bed.stop()
	cue.clear()
	cue = null
	if is_instance_valid(readout):
		readout.queue_free()
	if finished:
		GardenSfx.cue("garden_finish", null)
		_card(res)
		if res.has("win"):
			h._emote(h._kin_entry(res["win"]), "♥", true)
			h._emote(h._kin_entry(res["lose"]), "…", true)
		Save.save_game()
	run = null
	dancers = []

func _card(res: Dictionary) -> void:
	var you: Dictionary = dancers[YOU]["rec"]
	var rows: Array = []
	if res.has("win"):
		rows.append(["%s wins Echo Steps!" % res["win"]["name"], 18, UI.ACCENT_HI])
		var line := "%s %d points, %s %d" % [you["name"], res["score"][YOU], _who(RIVAL), res["score"][RIVAL]]
		rows.append([line, 14, UI.INK])
	else:
		rows.append(["%s danced Echo Steps: %d points" % [you["name"], res["score"][YOU]], 18, UI.ACCENT_HI])
	rows.append(["Best streak %d" % res["best"], 14, UI.INK])
	rows.append(["+%d gems" % res["gems"], 14, UI.GOLD])
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(h, rows)
	card_t = float(rules()["card_s"])
