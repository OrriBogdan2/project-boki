extends RefCounted
## --boss-anim-check: the three lair bosses move in every state (BossAnim). Tables: every state and every attack's
## wind-up and strike has tracks that name real pivots, really move, loop cleanly and meet without a pop. Live: each
## attack's blow lands on the frame its ground tell fills, the wind-up move is the same fraction as the tell and
## ends exactly there, each state picks its own move, a posed pivot sits on its key, and the death move is over
## before the body is gone.
## Never touches the save.

const MIN_MOVE := 0.02        # rad / m / scale: a move whose largest track moves less than this is static
const MIN_WINDUP := 0.3       # rad / m: a wind-up must swing at least this much to read at the match camera
const MEET := 0.05            # the wind-up's last pose and the strike's first may differ by at most this
const SLACK_S := 0.02         # s: how close the blow and the tell's end must be
const LOOPS := ["sleep", "idle", "walk", "stagger"]
## attacks whose first ground tell ends on the blow (the others throw or hatch, so their tell ends later)
const GROUND_TELL := ["slam", "fissure", "dash", "storm", "static", "spit", "burrow"]
const PERF_MS := 0.5          # ms: posing the three bosses in a frame
const PERF_FRAMES := 300
const DT := 1.0 / 60.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOSSANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_tables()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "god": true})
	m.set_process(false)
	var bosses: Array = []
	for id in Data.BOSSES:
		var L: Dictionary = m.lairs.list.filter(func(x): return x["boss"] == id)[0]
		m.lairs.activate(L)
		var b: Boss = L["boss_mob"]
		bosses.append(b)
		b.dormant = false
		b.tgt = m.player
		m.player.teleport(Vector3(b.pos.x + 3.0, b.pos.y, b.pos.z))
		_states(b)
		for atk in BossAnim.ATTACKS[id]:
			_attack(b, atk, false)
			_attack(b, atk, true)
		_posed(b)
	_perf(bosses)
	m.queue_free()
	print("BOSSANIM DONE, failures: %d" % bad)
	main.get_tree().quit(mini(bad, 1))

func _moves_of(kind: String) -> Array:
	var out: Array = BossAnim.STATES.duplicate()
	for atk in BossAnim.ATTACKS[kind]:
		out.append(atk + "_windup")
		out.append(atk + "_strike")
	return out

## The value of every pivot channel a move poses, at phase p.
func _values(kind: String, move_name: String, p: float) -> Dictionary:
	var out := {}
	for tr in BossAnim.tracks(kind, move_name):
		var v := BossAnim.sample(tr[2], p)
		for j in (tr[0] as PackedInt32Array).size():
			out[(tr[0] as PackedInt32Array)[j]] = v * (tr[1] as PackedFloat32Array)[j]
	return out

## How far the largest track of a move travels over the whole move.
func _travel(kind: String, move_name: String) -> float:
	var far := 0.0
	for tr in BossAnim.tracks(kind, move_name):
		var keys: PackedFloat32Array = tr[2]
		var lo := keys[1]
		var hi := keys[1]
		for i in range(1, keys.size(), 2):
			lo = minf(lo, keys[i])
			hi = maxf(hi, keys[i])
		far = maxf(far, hi - lo)
	return far

func _tables() -> void:
	for kind in Data.BOSSES:
		var body := BossModels.build(kind).get_node("Body")
		var want := _moves_of(kind)
		var have: Array = (BossAnim.MOVES[kind] as Dictionary).keys()
		ok(want.size() == have.size() and want.all(func(w): return have.has(w)),
			"%s: a move for each of its %d states and attack halves, and no stray ones" % [kind, want.size()])
		var bare := BossAnim.pairs(kind).filter(func(pc): return pc[0] != "." and body.get_node_or_null(pc[0]) == null)
		ok(bare.is_empty(), "%s: every pivot the moves name is on the model %s" % [kind, str(bare)])
		for mv in want:
			var span := _travel(kind, mv)
			ok(span >= MIN_MOVE, "%s %s moves (%.2f)" % [kind, mv, span])
			if mv.ends_with("_windup"):
				ok(span >= MIN_WINDUP, "%s %s swings enough to read (%.2f >= %.2f)" % [kind, mv, span, MIN_WINDUP])
			if LOOPS.has(mv):
				ok(_loops(kind, mv), "%s %s loops without a seam" % [kind, mv])
			if mv.ends_with("_windup"):
				var strike: String = mv.replace("_windup", "_strike")
				var meets := _meets(_values(kind, mv, 1.0), _values(kind, strike, 0.0))
				ok(meets, "%s %s hands over to its strike" % [kind, mv])
	_clips()

func _loops(kind: String, move_name: String) -> bool:
	return BossAnim.tracks(kind, move_name).all(func(tr): return absf(tr[2][1] - tr[2][tr[2].size() - 1]) < 0.001)

func _meets(a: Dictionary, b: Dictionary) -> bool:
	for k in a.keys() + b.keys():
		if absf(float(a.get(k, 0.0)) - float(b.get(k, 0.0))) > MEET:
			return false
	return true

## The Colossus's clips: each move cues one the pack has, and the scrub stretches cover the clip.
func _clips() -> void:
	var cued: Array = (BossAnim.CLIP as Dictionary).keys()
	var want := _moves_of("colossus")
	ok(want.size() == cued.size() and want.all(func(w): return cued.has(w)), "colossus: every move cues a clip")
	var model := BossModels.colossus()
	if not model.has_meta("clips"):
		print("BOSSANIM note: no pack model here, clips not checked")
		return
	var spec: Dictionary = model.get_meta("clips")
	var ap: AnimationPlayer = model.get_meta("anim")
	var names := {}
	for cue in BossAnim.CLIP.values():
		names[cue[0]] = true
	for key in names:
		ok(spec.has(key) and ap.has_animation(String(spec[key])), "colossus clip '%s' exists" % key)

## Starts the boss's attack by name; `rage` runs it enraged in the last phase (shorter wind-ups).
func _start(b: Boss, atk: String, rage: bool) -> void:
	b._clear_attack()
	b.stagger_t = 0.0
	b.phase = 2 if rage else 0
	b.enraged = rage
	b.call("_atk_" + atk)

## One attack: the blow, the tell and the body all agree on when it lands.
func _attack(b: Boss, atk: String, rage: bool) -> void:
	_start(b, atk, rage)
	var tag := "%s %s%s" % [b.mkind, atk, " (enraged, phase 3)" if rage else ""]
	var hit := BossAnim.hit_t(b)
	ok(b.atk == atk and hit > 0.0, "%s: wind-up %.2f s" % [tag, hit])
	var born: Array = b.teles.map(func(_tl): return 0.0)      # when each tell appeared, by index
	var steps := b.steps.duplicate()
	steps.sort_custom(func(x, y): return float(x["t"]) < float(y["t"]))
	for s in steps:
		if float(s["t"]) < hit - SLACK_S:
			b.atk_t = float(s["t"])
			(s["f"] as Callable).call()
			s["done"] = true
			while born.size() < b.teles.size():
				born.append(b.atk_t)
	var blows := steps.filter(func(s): return absf(float(s["t"]) - hit) <= SLACK_S)
	ok(not blows.is_empty(), "%s: the blow lands at the wind-up's end (%.2f s)" % [tag, hit])
	if GROUND_TELL.has(atk):
		var ends: Array = []
		for i in b.teles.size():
			ends.append(float(born[i]) + float(b.teles[i]["dur"]))
		ok(ends.any(func(e): return absf(e - hit) <= SLACK_S), "%s: the ground tell fills at %.2f s too" % [tag, hit])
	_phases(b, tag, hit)
	b._clear_attack()

## The move follows the attack's clock: wind-up 0..1 over the tell, strike from its end.
func _phases(b: Boss, tag: String, hit: float) -> void:
	var at := {0.0: "_windup", 0.5: "_windup", 0.999: "_windup", 1.0: "_strike", 1.2: "_strike"}
	for f in at:
		b.atk_t = hit * float(f)
		BossAnim.pick(b)
		var right := BossAnim.cur_move == b.atk + String(at[f])
		var k_ok := absf(BossAnim.cur_k - float(f)) < 0.01 if String(at[f]) == "_windup" else BossAnim.cur_k >= 0.0
		var what := "%s: %.0f%% of the way to the hit plays %s at %.2f"
		ok(right and k_ok, what % [tag, float(f) * 100.0, BossAnim.cur_move, BossAnim.cur_k])

## Each state asks for its own move.
func _states(b: Boss) -> void:
	b._clear_attack()
	b.stagger_t = 0.0
	b.awake_t = 5.0
	b.vel = Vector3.ZERO
	_picks(b, "idle")
	b.vel = Vector3(3.0, 0, 0)
	_picks(b, "walk")
	b.vel = Vector3.ZERO
	b.awake_t = 0.0
	_picks(b, "wake")
	b.awake_t = 5.0
	b.stagger_t = 2.0
	_picks(b, "stagger")
	b.stagger_t = 0.0
	b.dormant = true
	_picks(b, "sleep")
	b.dormant = false
	b.atk = "phase"
	b.atk_t = 1.0
	_picks(b, "phase")
	b.atk = ""
	b.dead = true
	b.death_t = BossAnim.DEATH_S
	_picks(b, "death")
	var over := BossAnim.cur_k == 1.0 and BossAnim.DEATH_S <= Boss.DEATH_FADE_S
	ok(over, "%s: the death move is over before the body is gone" % b.mkind)
	b.dead = false

func _picks(b: Boss, want: String) -> void:
	BossAnim.pick(b)
	ok(BossAnim.cur_move == want, "%s: %s picks '%s'" % [b.mkind, want, BossAnim.cur_move])

## A posed pivot sits on its key: the wind-up's last frame, held, leaves the first track's pivot there.
func _posed(b: Boss) -> void:
	var atk: String = BossAnim.ATTACKS[b.mkind][0]
	_start(b, atk, false)
	b.atk_t = BossAnim.hit_t(b) - 0.001
	for i in 90:
		BossAnim.pose(b, DT)
	var rig: BossAnim.Rig = b.model.get_meta("boss_rig")
	var tr: Array = BossAnim.tracks(b.mkind, atk + "_windup")[0]
	var i0: int = (tr[0] as PackedInt32Array)[0]
	var want: float = rig.base[i0] + BossAnim.sample(tr[2], 1.0) * (tr[1] as PackedFloat32Array)[0]
	var got := BossAnim.rest_of(rig.nodes[i0], rig.chans[i0])
	ok(absf(got - want) < 0.01, "%s: the pivot sits on its key (%.3f vs %.3f)" % [b.mkind, got, want])
	b._clear_attack()

func _perf(bosses: Array) -> void:
	var t0 := Time.get_ticks_usec()
	for f in PERF_FRAMES:
		for b in bosses:
			BossAnim.pose(b, DT)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / PERF_FRAMES
	ok(ms < PERF_MS, "posing %d bosses costs %.3f ms a frame (< %.1f)" % [bosses.size(), ms, PERF_MS])
