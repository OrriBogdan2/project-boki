class_name DuoTutorial
extends RefCounted
## The 2v2 tutorial (briefs/TUTORIAL_2V2.md): you and a guide against two sparring bots in a walled ring
## (content/maps/duo_arena.json), one beat at a time. The guide fights beside you and says one short line
## per beat; the rivals start still and ramp up (DuoTutorialCast trims what each may do). A beat passes on
## what you did in the fight (slides, hits, casts, a capture, a revive), never on a button in a menu; a
## stall gets a nag line and, after a while, the beat passes itself. The words and numbers are data:
## content/rules/duo_tutorial.json. Match owns one of these as `duo` and calls tick() after the bots think.

const RING_C := Vector2(20.0, 20.0)      # the ring's centre on the map (tiles)
const YOU_AT := Vector2(20.0, 28.0)      # your start, south of the centre
const GUIDE_AT := Vector2(20.0, 21.5)    # the guide waits mid-ring for the first beat
const FOE_AT := [Vector2(16.5, 12.0), Vector2(23.5, 12.0)]     # the rivals' corners, north
const MEET_R := 3.0          # m from the guide that counts as "came over"
const DANGER_R := 6.0        # m: a rival shot this close and coming at you makes a slide a dodge
const MELEE_R := 2.6         # m: a rival this close makes a slide a dodge too
const GAP_T := 2.2           # s between a beat's done line and the next beat
const NAG_PULSE_T := 1.6     # s the tip pill pulses after a nag

var m: Match
var cfg: Dictionary
var beats: Array = []        # the beats this hunter can do (no Boki: the Boki beats drop out)
var beat := -1
var got := 0                 # this beat's count so far (shown as got/need)
var beat_t := 0.0            # s in this beat
var stall_t := 0.0           # s since the last progress (or the last nag)
var quiet_t := 0.0           # s since the last progress: skip_s of it passes the beat
var gap_t := 0.0             # s left before the next beat starts (the done line stands)
var nagging := 0.0           # s left of the tip's pulse after a nag
var finished := false
var end_t := 0.0             # s since the last beat ended (the end card)
var guide: Hunter = null
var foes: Array = []         # [Hunter, Hunter]
var focus: Hunter = null     # the rival the guide has marked
var wild: Kin = null         # the capture beat's wild Boki
var cast: DuoTutorialCast
var hud: DuoTutorialHud
var line := ""               # what the guide is saying
var line_t := 0.0            # s since she said it
var _bark_t := 0.0           # s since her last line
var _base := {}              # counters as the beat started (casts, throws, catches)
var _roll_was := 0.0
var _down_was := {}          # Hunter -> downed last tick
var _knocked := {}           # rivals knocked this beat
var _dazed_said := false     # the capture beat's "it's dazed" line is out

## The match options: the ring, you and nobody else (the tutorial places the other three). test: the
## driver plays it (DuoTutorialDrive) with a stock Boki.
static func opts(arch_id := "", test := false) -> Dictionary:
	var o := {"arena": true, "training": true, "duo_tut": true, "arena_map": "duo_arena", "teams": 1, "squad": 1,
		"tier": 0, "length": 1e9, "seed": 4747, "no_drop": true, "fresh_t": 0.0}
	if test:
		o["duo_test"] = true
		o["demo_kin"] = "cindle"
	if Arch.exists(arch_id):
		o["arch"] = arch_id
		o["cls"] = Arch.weight(arch_id)
		o["weapon"] = Arch.signature(arch_id)
	return o

func _init(match_node: Match) -> void:
	m = match_node
	cfg = Content.rules("duo_tutorial")
	cast = DuoTutorialCast.new(self)
	var p := m.player
	p.teleport(_ground(YOU_AT))
	p.face = PI
	m.cam.snap(p.pos)
	guide = cast.spawn_guide(_ground(GUIDE_AT))
	for i in FOE_AT.size():
		foes.append(cast.spawn_foe(i, _ground(FOE_AT[i])))
	for b in cfg["beats"]:
		if applies(String(b["id"])):
			beats.append(b)
	hud = DuoTutorialHud.new(self)
	m.add_child(hud)
	if m.hud:
		m.hud.guide_hidden = true
	_next()

## Whether this hunter can do a beat (the Boki beats need a Boki).
func applies(bid: String) -> bool:
	return m.player.kin != null or bid not in ["boki", "ult"]

## The beat under way ({} once it's over).
func cur() -> Dictionary:
	return beats[beat] if beat >= 0 and beat < beats.size() else {}

func id() -> String:
	return String(cur().get("id", ""))

## Called by Match every step, after the bots have chosen what to do.
func tick(dt: float) -> void:
	var p := m.player
	if p == null:
		return
	if m.opts.get("duo_test", false):
		DuoTutorialDrive.drive(m, self)
	line_t += dt
	_bark_t += dt
	nagging = maxf(0.0, nagging - dt)
	cast.tick(dt)
	_watch_downs()
	if finished:
		end_t += dt
		return
	if gap_t > 0.0:
		gap_t -= dt
		if gap_t <= 0.0:
			_next()
		return
	beat_t += dt
	stall_t += dt
	quiet_t += dt
	var now := _progress()
	if now > got:
		got = now
		stall_t = 0.0
		quiet_t = 0.0
	if got >= int(cur()["need"]):
		_done(String(cur()["done"]))
	elif quiet_t >= float(cfg["skip_s"]):
		_done(_pick(cfg["skip"]))
	elif stall_t >= float(cfg["nag_s"]):
		stall_t = 0.0
		nagging = NAG_PULSE_T
		say(String(cur()["nag"]))

## The guide says a line (filled in with your keys and names) in the bubble over her head.
func say(txt: String) -> void:
	line = fill(txt)
	line_t = 0.0
	_bark_t = 0.0

## A line's tokens: the beat's key, your Boki, your abilities, the guide and the rivals.
func fill(txt: String) -> String:
	var p := m.player
	var key := String(cur().get("key", ""))
	var boki := String(p.kin.rec.get("name", "your Boki")) if p.kin else "your Boki"
	var rmb := String(p.ak.rmb_def().get("name", "right click")) if p.ak else "right click"
	txt = txt.replace("%K", Settings.key_cap(key) if key != "" else "").replace("%s", boki).replace("%A", rmb)
	txt = txt.replace("%G", guide.pname).replace("%1", foes[0].pname).replace("%2", foes[1].pname)
	return TutorialText.fill(txt, p)

# ------------------------------------------------------------------ beats
func _next() -> void:
	beat += 1
	if beat >= beats.size():
		finished = true
		return
	got = 0
	beat_t = 0.0
	stall_t = 0.0
	quiet_t = 0.0
	_knocked.clear()
	var p := m.player
	_roll_was = p.roll_t
	_base = {"sec": int(p.used.get("utility", 0)), "kin": int(p.used.get("k1", 0)), "caught": p.caught.size(),
		"throws": (p.kin as Kin).st_throws if p.kin else 0, "hp": foes[0].hp}
	cast.begin(String(cur()["foes"]), String(cur()["guide"]))
	match id():
		"focus":
			focus = foes[1]
			m.squad_ping(guide, focus.pos, false, "enemy")
		"capture":
			wild = cast.spawn_wild()
		"ult":
			p.lvl = maxi(p.lvl, int(Hunter.ULT_AT[0]))
			p.ult = 1.0
	say(String(cur()["say"]))

func _done(txt: String) -> void:
	say(txt)
	if id() == "focus":
		m.unping(guide, true)
		focus = null
	gap_t = GAP_T if beat < beats.size() - 1 else float(cfg["done_hold"])

## This beat's count from what happened in the fight.
func _progress() -> int:
	var p := m.player
	var slid := p.roll_t > 0.0 and _roll_was <= 0.0
	_roll_was = p.roll_t
	match id():
		"meet": return 1 if p.grounded and p.flat_dist(guide) < MEET_R else 0
		"slide": return got + (1 if slid else 0)
		"dodge": return got + (1 if slid and danger() else 0)
		"attack": return got + _hit_count()
		"sec": return int(p.used.get("utility", 0)) - int(_base["sec"])
		"kin": return int(p.used.get("k1", 0)) - int(_base["kin"])
		"boki": return (p.kin as Kin).st_throws - int(_base["throws"]) if p.kin else 1
		"capture": return _capture_count()
		"revive": return 1 if not guide.downed and beat_t > 0.5 else 0
		"ult": return 1 if KinMerge.active(p) else 0
		"focus": return 1 if _knocked.has(foes[1]) else 0
		"finale": return _knocked.size()
	return 0

## A hit on the first rival since the last step (the guide holds fire on this beat, so it was you).
func _hit_count() -> int:
	var f: Hunter = foes[0]
	var hit := f.hp < float(_base["hp"]) - 0.01
	_base["hp"] = f.hp
	return 1 if hit else 0

func _capture_count() -> int:
	if wild and is_instance_valid(wild) and wild.state == "wild" and beat_t > float(cfg["daze_s"]):
		cast.daze(wild)
		say(String(cur()["tripped"]))
	elif wild and is_instance_valid(wild) and wild.state == "dazed" and not _dazed_said:
		_dazed_said = true
		say(String(cur()["dazed"]))
	return m.player.caught.size() - int(_base["caught"])

## Something of a rival's is coming at you right now: a shot closing in, or a rival at arm's length.
func danger() -> bool:
	var p := m.player
	for s in m.shots:
		if int(s["team"]) == p.team:
			continue
		var at: Vector3 = s["pos"]
		var to := Vector2(p.pos.x - at.x, p.pos.z - at.z)
		if to.length() < DANGER_R and to.dot(s["vel"]) > 0.0:
			return true
	return foes.any(func(f): return not f.downed and p.flat_dist(f) < MELEE_R)

# ------------------------------------------------------------------ the fight's moments
## Knocks and get-ups, by watching who is down: her barks, and each knocked rival's count for the beat.
func _watch_downs() -> void:
	var p := m.player
	for h in [p, guide] + foes:
		var was: bool = _down_was.get(h, false)
		_down_was[h] = h.downed
		if not h.downed or was:
			continue
		if h in foes:
			_knocked[h] = true
			bark("you_knock" if h.last_hit_by == p else "guide_knock")
		elif h == p:
			bark("you_down")

## One of her fight lines, unless she spoke a moment ago or a beat line is still fresh.
func bark(kind: String) -> void:
	if _bark_t < float(cfg["bark_gap"]) or gap_t > 0.0:
		return
	say(_pick(cfg["barks"][kind]))

func _pick(lines: Array) -> String:
	return String(lines[m.rng.randi_range(0, lines.size() - 1)])

## A spot on the ring's floor (map tiles), on the ground.
func _ground(xz: Vector2) -> Vector3:
	return Vector3(xz.x, m.world.ground_at(xz.x, xz.y), xz.y)

## The corner a rival goes back to.
func foe_home(i: int) -> Vector3:
	return _ground(FOE_AT[i])
