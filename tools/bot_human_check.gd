extends RefCounted
## --bot-human-check [--bh-diff=<easy|medium|hard|expert>] [--bh-seeds=a,b] [--bh-t=<s>] [--bh-wall=<s>]
## [--bh-teams=<n>] [--bh-log=<n>] [--bh-measure] [--bh-plain]:
## full bot expeditions (10 teams of 3, every hunter a bot) watched for the things a person would
## never do: fighting on at low health with heals in the belt, wandering away from the squad,
## looting beside a teammate's fight, taking a fight outnumbered, letting a weak rival walk off.
## Prints one "BOTHUMAN <metric> <value>" line per measure and a short decision log ("BOTLOG ...")
## of the knocks with their context (docs/BOTS_HUMAN_1111.md has the before/after table).
## Fails when a behaviour this branch fixed slips back past its limit. Never touches the save.

const SAMPLE_S := 0.5           # seconds between two samples of every hunter
const WARMUP_S := 70.0          # seconds skipped at the start: the skyship ride and the drop
const NEAR_M := 20.0            # metres: a rival this close is "in the fight"
const MATE_M := 35.0            # metres: a teammate this close could help in a fight
const APART_M := 30.0           # metres: a teammate further than this is not playing with you
const LOW_HP := 0.35            # health share under which a person backs off and heals
const HURT_HP := 0.7            # health share under which a person tops up when it is calm
const HIT_FRESH_S := 2.5        # seconds a hit keeps a hunter "under fire"
const CALM_S := 6.0             # seconds without a hit before a hunter counts as calm
const BACK_M := 0.8             # metres moved straight away from the nearest rival in one sample = backing off
const EP_HP := 0.5              # health share under which a fight has "turned" on a hunter
const MIN_SAMPLES := 2000       # squad samples per expedition under which there is too little to judge

## Limits the fixed behaviours must stay inside (medium bots, the default run).
const MAX_APART := 0.3          # share of samples with no teammate within APART_M (3 runs in 14: 0.14 to 0.22)
const MAX_CALM_UNHEALED := 0.7  # share of calm, hurt samples with a heal in the belt and no drink started
                                # (0.03 to 0.58 measured on fourteen runs; the old behaviour 0.42 to 0.95)
const MIN_ASSIST := 0.6         # share of near teammates that join a squadmate's fight (0.74 to 0.91 measured)

var n := {}                     # counters
var log_left := 30
var st := {}                    # hunter -> its state between samples
var teams := 10
var wall_ms := 900000           # the run stops and reports after this much real time (a loaded server is slow)
var t0_ms := 0
var cut := false                # the wall clock ended a run before its match time was up
var plain := false              # --bh-plain: bots without squad play or retreats (BotSquad.on), to compare

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var diff := "medium"
	var seeds := [3]
	var secs := 730.0               # a whole expedition (720 s) and its last seconds
	var strict := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bh-diff="): diff = a.substr(10)
		if a.begins_with("--bh-seeds="): seeds = Array(a.substr(11).split(",")).map(func(x): return int(x))
		if a.begins_with("--bh-t="): secs = float(a.substr(7))
		if a.begins_with("--bh-log="): log_left = int(a.substr(9))
		if a.begins_with("--bh-teams="): teams = int(a.substr(11))
		if a.begins_with("--bh-wall="): wall_ms = int(a.substr(10)) * 1000
		if a == "--bh-measure": strict = false
		if a == "--bh-plain":
			plain = true
			strict = false
	t0_ms = Time.get_ticks_msec()
	for sd in seeds:
		_expedition(main, int(sd), diff, secs)
	var bad := _report(diff, seeds.size())
	if not strict:
		bad = 0
	print("BOTHUMAN done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _expedition(main: Node, sd: int, diff: String, secs: float) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": teams, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "bot_diff": diff, "sim_keep": true,
		"bot_plain": plain})
	m.set_process(false)
	st = {}
	var cb_use := func(who, _id, slot):
		if who is Hunter and st.has(who) and st[who].get("fight", false):
			_add("abil " + String(slot))
	CombatBus.ability_used.connect(cb_use)
	var acc := 0.0
	while m.time < secs and not m.over and Time.get_ticks_msec() - t0_ms < wall_ms:
		m.step(Match.DT)
		_edges(m)
		acc += Match.DT
		if acc >= SAMPLE_S:
			acc = 0.0
			if m.time > WARMUP_S:
				_sample(m)
	if m.time < secs and not m.over:
		cut = true
	CombatBus.ability_used.disconnect(cb_use)
	for h in m.hunters:
		_add("end " + _end_state(h))
		if h.extracted: _add("gems home", int(h.gems))
	print("BOTHUMAN run seed=%d diff=%s t=%d extracted=%d out=%d" % [sd, diff, int(m.time),
			m.hunters.filter(func(x): return x.extracted).size(),
			m.hunters.filter(func(x): return x.out and not x.extracted).size()])
	m.queue_free()

func _add(k: String, by := 1) -> void:
	n[k] = int(n.get(k, 0)) + by

func _up(h: Hunter) -> bool:
	return not (h.out or h.gone or h.extracted or h.downed or h.riding or h.dropping)

func _frac(h: Hunter) -> float:
	return h.hp / maxf(h.max_hp, 1.0)

func _hunter_of(e) -> Hunter:
	if e == null or not is_instance_valid(e):
		return null
	if e is Hunter:
		return e
	if e is Kin and e.owner_h:
		return e.owner_h
	return null

func _near(m: Match, h: Hunter, p: Vector3, r: float, same_team: bool) -> Array:
	var out := []
	for o in m.hunters:
		if o != h and (o.team == h.team) == same_team and _up(o) and Vector2(o.pos.x - p.x, o.pos.z - p.z).length() < r:
			out.append(o)
	return out

func _heals(h: Hunter) -> int:
	return UtilityBelt.count(h, "tonic") + UtilityBelt.count(h, "medkit")

## Every step: the edges a 0.5 s sample would miss (a dash press, the moment of a knock).
func _edges(m: Match) -> void:
	for h in m.hunters:
		var s: Dictionary = st.get(h, {})
		if s.is_empty():
			s = {"down": false, "tgt": null, "low_t": -1.0, "belt": {}, "pos": h.pos, "still": 0.0,
				"fight": false, "back_s": 0.0}
			st[h] = s
		if h.downed and not s["down"]:
			_knocked(m, h, s)
		elif s["down"] and not h.downed and not h.out and not h.gone:
			_add("revived")
		s["down"] = h.downed

func _knocked(m: Match, h: Hunter, s: Dictionary) -> void:
	var by := _hunter_of(h.last_hit_by)
	_add("knocks")
	s["ep"] = false
	if by == null or by.team == h.team:
		_add("knocks other")
		return
	_add("knocks by rival")
	var heals := _heals(h)
	var low_s: float = (m.time - float(s["low_t"])) if float(s["low_t"]) >= 0.0 else 0.0
	var mates := _near(m, h, h.pos, 999.0, true)
	var md := 999.0
	var mwhat := "-"
	for o in mates:
		if o.flat_dist(h) < md:
			md = o.flat_dist(h)
			mwhat = "fighting" if _hunter_of(o.ai.get("tgt")) != null else String(o.ai.get("goal_kind", "?"))
	var allies := _near(m, h, h.pos, NEAR_M, true).size() + 1
	var foes := _near(m, h, h.pos, NEAR_M, false).size()
	if heals > 0: _add("knocked with heals")
	if md > APART_M: _add("knocked alone")
	if foes > allies: _add("knocked outnumbered")
	if low_s > 2.0 and float(s["back_s"]) < 0.5: _add("knocked never backed off")
	if log_left > 0 and m.time > WARMUP_S:
		log_left -= 1
		var mate_s: String = ("%d m (%s)" % [int(md), mwhat]) if md < 900.0 else "none left"
		print("BOTLOG t=%d %s knocked by %s: low %.1f s (backing off %.1f s), heals left %d, %dv%d, nearest mate %s"
			% [int(m.time), h.pname, by.pname, low_s, float(s["back_s"]), heals, allies, foes, mate_s])

func _sample(m: Match) -> void:
	var fighters := {}          # hunter -> the rival hunter it is fighting
	for h in m.hunters:
		if not _up(h):
			st[h]["fight"] = false
			st[h]["low_t"] = -1.0
			continue
		var s: Dictionary = st[h]
		var tgt := _hunter_of(h.ai.get("tgt"))
		if tgt != null and (not _up(tgt) or tgt.team == h.team or tgt.flat_dist(h) > NEAR_M * 1.5):
			tgt = null
		var hitter := _hunter_of(h.last_hit_by) if m.time - h.hurt_at < HIT_FRESH_S else null
		if hitter != null and (hitter.team == h.team or not _up(hitter)):
			hitter = null
		var foe: Hunter = tgt if tgt != null else hitter
		var fight := foe != null
		s["fight"] = fight
		if fight: fighters[h] = foe
		var frac := _frac(h)
		var rivals := _near(m, h, h.pos, NEAR_M, false)
		var rd := 999.0
		var nr: Hunter = null
		for o in rivals:
			if o.flat_dist(h) < rd:
				rd = o.flat_dist(h)
				nr = o
		_add("up samples")
		# 1. the squad: is anybody playing next to this bot?
		var mates := _near(m, h, h.pos, 999.0, true)
		if not mates.is_empty():
			var md := 999.0
			for o in mates:
				md = minf(md, o.flat_dist(h))
			_add("squad samples")
			_add("squad dist sum", int(md))
			if md > APART_M: _add("squad apart")
		# 2. low health in a fight: stand and trade, or back off?
		if frac < LOW_HP and fight and rd < 900.0:
			if float(s["low_t"]) < 0.0:
				s["low_t"] = m.time
				s["back_s"] = 0.0
			_add("low fight samples")
			var went: Vector3 = h.pos - s["pos"]
			var from: Vector3 = (h.pos - nr.pos).normalized()
			var backing: bool = went.x * from.x + went.z * from.z > BACK_M or h.drink_t > 0.0
			if backing:
				s["back_s"] = float(s["back_s"]) + SAMPLE_S
			else:
				_add("low fight standing")
			if _heals(h) > 0 and h.drink_t <= 0.0: _add("low fight heal unused")
		elif frac >= LOW_HP:
			s["low_t"] = -1.0
		# 2b. a fight that turned (under half health): did the hunter come out of it on its feet?
		if fight and frac < EP_HP and not s.get("ep", false):
			s["ep"] = true
			_add("turned fights")
		elif s.get("ep", false) and (frac >= HURT_HP or m.time - h.hurt_at > CALM_S):
			s["ep"] = false
			_add("turned fights survived")
		# 3. the belt: what gets used, and when
		for i in h.belt.size():
			var id := String(h.belt[i].get("id", ""))
			var c := int(h.belt[i].get("n", 0))
			var was: int = int(s["belt"].get(i, c)) if String(s["belt"].get("id%d" % i, id)) == id else c
			if c < was and id != "":
				_add(("belt fight " if fight or rd < NEAR_M else "belt calm ") + id, was - c)
				_add("belt fight total" if fight or rd < NEAR_M else "belt calm total", was - c)
			s["belt"][i] = c
			s["belt"]["id%d" % i] = id
		# 4. calm and hurt with a heal in the belt
		if not fight and rd > NEAR_M and m.time - h.hurt_at > CALM_S and frac < HURT_HP:
			_add("calm hurt samples")
			if _heals(h) > 0 and h.drink_t <= 0.0: _add("calm hurt heal unused")
		# 5. picking a fight: numbers and health at the moment a rival becomes the target
		var old_gone: bool = s["tgt"] == null or not is_instance_valid(s["tgt"])
		if tgt != null and s["tgt"] != tgt and (old_gone or s["tgt"].team != tgt.team):
			_add("engages")
			var allies := _near(m, h, h.pos, NEAR_M, true).size() + 1
			var foes := _near(m, tgt, tgt.pos, NEAR_M, true).size() + 1
			if foes > allies: _add("engages outnumbered")
			if frac < 0.4: _add("engages low")
		# 6. letting a weak rival go
		var prev: Hunter = s["tgt"] if s["tgt"] != null and is_instance_valid(s["tgt"]) else null
		if prev != null and tgt == null and _up(prev) and _frac(prev) < 0.4 and frac > 0.5:
			_add("weak target dropped")
		if prev != null and tgt != null and prev != tgt and prev.team == tgt.team and _up(prev):
			_add("target flips")
		if fight: _add("fight samples")
		s["tgt"] = tgt
		# 7. standing around
		var moved: float = Vector2(h.pos.x - s["pos"].x, h.pos.z - s["pos"].z).length()
		s["pos"] = h.pos
		var busy: bool = fight or h.drink_t > 0.0 or h.kit_t > 0.0 or h.base_t > 0.0
		s["still"] = float(s["still"]) + SAMPLE_S if moved < 0.15 and not busy else 0.0
		if float(s["still"]) > 3.0:
			_add("idle samples")
			_add("idle at " + String(h.ai.get("goal_kind", "?")))
	# 8. a squadmate's fight: do near teammates join it, and on the same rival?
	for h in fighters:
		var foe: Hunter = fighters[h]
		for o in _near(m, h, h.pos, MATE_M, true):
			_add("assist chances")
			var ot := _hunter_of(o.ai.get("tgt"))
			if ot != null and ot.team == foe.team:
				_add("assists")
				if fighters.has(o) and _hunter_of(h.ai.get("tgt")) != null:
					_add("focus chances")
					if ot == _hunter_of(h.ai.get("tgt")): _add("focus same")
			elif log_left > 0 and int(n.get("assist chances", 0)) % 60 == 7:
				# (a few of them, and no dice: the match's own rolls stay as they are)
				log_left -= 1
				print("BOTLOG t=%d %s fights %s; %s is %d m away doing '%s'" % [int(m.time), h.pname, foe.pname,
					o.pname, int(o.flat_dist(h)), String(o.ai.get("goal_kind", "?"))])

func _share(a: String, b: String) -> float:
	return float(n.get(a, 0)) / maxf(float(n.get(b, 0)), 1.0)

func _report(diff: String, runs: int) -> int:
	var fight_min := maxf(float(n.get("fight samples", 0)) * SAMPLE_S / 60.0, 0.01)
	var rows := [
		["squad apart share (no mate within %d m)" % int(APART_M), _share("squad apart", "squad samples")],
		["squad mean nearest-mate distance m", _share("squad dist sum", "squad samples")],
		["low-hp fight seconds", float(n.get("low fight samples", 0)) * SAMPLE_S],
		["low-hp fight share not backing off", _share("low fight standing", "low fight samples")],
		["low-hp fight share with heal unused", _share("low fight heal unused", "low fight samples")],
		["knocks by a rival", float(n.get("knocks by rival", 0))],
		["knocked with heals left share", _share("knocked with heals", "knocks by rival")],
		["knocked alone share (mate > %d m)" % int(APART_M), _share("knocked alone", "knocks by rival")],
		["knocked outnumbered share", _share("knocked outnumbered", "knocks by rival")],
		["knocked never backed off share", _share("knocked never backed off", "knocks by rival")],
		["fights that turned (under %d%% health)" % int(EP_HP * 100.0), float(n.get("turned fights", 0))],
		["turned fights survived share", _share("turned fights survived", "turned fights")],
		["belt items used in a fight", float(n.get("belt fight total", 0))],
		["belt items used calm", float(n.get("belt calm total", 0))],
		["calm hurt share with heal unused", _share("calm hurt heal unused", "calm hurt samples")],
		["calm hurt seconds", float(n.get("calm hurt samples", 0)) * SAMPLE_S],
		["engages", float(n.get("engages", 0))],
		["engages outnumbered share", _share("engages outnumbered", "engages")],
		["engages under 40% health share", _share("engages low", "engages")],
		["assist share (mates within %d m)" % int(MATE_M), _share("assists", "assist chances")],
		["assist chances per fight sample", _share("assist chances", "fight samples")],
		["focus same-target share", _share("focus same", "focus chances")],
		["weak targets dropped", float(n.get("weak target dropped", 0))],
		["target flips per fight minute", float(n.get("target flips", 0)) / fight_min],
		["fight share of up time", _share("fight samples", "up samples")],
		["idle share of up time", _share("idle samples", "up samples")],
		["revived / knocks", _share("revived", "knocks")],
		["extracted per expedition", float(n.get("end extracted", 0)) / float(runs)],
		["out per expedition", float(n.get("end out", 0)) / float(runs)],
		["alive at the end per expedition", float(n.get("end alive", 0) + n.get("end downed", 0)) / float(runs)],
	]
	for r in rows:
		print("BOTHUMAN %s | %s | %.2f" % [diff, r[0], r[1]])
	var keys := n.keys()
	keys.sort()
	for k in keys:
		if String(k).begins_with("belt ") or String(k).begins_with("idle at ") or String(k).begins_with("abil "):
			print("BOTHUMAN %s | %s | %d" % [diff, k, n[k]])
	if cut or int(n.get("squad samples", 0)) < MIN_SAMPLES * runs:
		print("BOTHUMAN skip limits: the run was cut short (%d samples), too little to judge"
				% int(n.get("squad samples", 0)))
		return 0
	var bad := 0
	bad += _limit("squad apart share", _share("squad apart", "squad samples"), MAX_APART, true)
	bad += _limit("calm hurt with heal unused", _share("calm hurt heal unused", "calm hurt samples"),
			MAX_CALM_UNHEALED, true)
	bad += _limit("assist share", _share("assists", "assist chances"), MIN_ASSIST, false)
	return bad

func _limit(what: String, v: float, lim: float, is_max: bool) -> int:
	var ok := v <= lim if is_max else v >= lim
	var verdict := "ok" if ok else "FAIL"
	print("BOTHUMAN %s %s: %.2f (limit %s %.2f)" % [verdict, what, v, "<=" if is_max else ">=", lim])
	return 0 if ok else 1

func _end_state(h: Hunter) -> String:
	if h.extracted:
		return "extracted"
	if h.out or h.gone:
		return "out"
	return "downed" if h.downed else "alive"
