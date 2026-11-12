extends RefCounted
## --bot-kit-check --kit-use-match [--kit-use-t=300] [--kit-use-seeds=3,5] [--kit-use-diff=medium]: one
## seeded 10-trio bot match per seed (every Hunter a bot, at that bot difficulty), logging per Hunter how
## the bots use the ultimate (X) and the Boki in real fights against rival Hunters (table and targets in
## docs/BOT_KIT_USE.md, "Ultimate and Boki in a match"): fights, casts, casts per minute of ready-and-
## useful time, casts that landed, casts into nothing, how long a ready ult sat unused in a fight, Boki
## sends, and fights the Boki was out in. Fails a Hunter below a target. Never touches the save.

const FIGHT_R := 12.0          # m: a rival Hunter the bot targets this close is a fight
const USEFUL_R := 10.0         # m: ...this close, in sight and in the ult's reach, makes a ready ult useful
const FIGHT_GAP := 3.0         # s: out of a fight this long ends it
const REAL_HITS := 2           # hits traded with rival Hunters that make a fight real
const LAND_S := 3.0            # s: a cast lands if it hits a rival Hunter while it runs or this soon after
const NOTHING_R := 15.0        # m: a cast with no foe this close went into nothing
const WAIT_OK := 3.0           # s: target, a ready useful ult goes within this (a wait that closes sooner is no miss)
const START_LVL := 6           # every Hunter starts at the ult level (Hunter.ULT_AT), so each match measures it
const MIN_READY_S := 20.0      # s: Hunters with less ready-and-useful time are listed, not judged
## Targets (docs/BOT_KIT_USE.md): share of ready waits that reach a cast within WAIT_OK (of those that
## either cast in time or ran past it), of casts in a fight that land, of real fights with the Boki out
## (when it could be), and casts into nothing. A match is not repeatable (the bots roll unseeded random
## numbers), so a Hunter fails only below the floor; between floor and target the row is marked "below".
const WITHIN := [0.6, 0.5]     # [target, floor]
const LAND := [0.5, 0.35]
const BOKI := [0.8, 0.7]
const NO_ULT := ["tender"]     # (its ultimate heals a teammate; it waits for one to be hurt)

var bad := 0
var diff := "medium"
var sd_now := 0
var n := {}                    # arch -> counters
var per := {}                  # Hunter -> live state

func run(main: Node) -> void:
	var seeds := [3, 5]
	var secs := 300.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kit-use-t="): secs = float(a.substr(12))
		if a.begins_with("--kit-use-seeds="): seeds = Array(a.substr(16).split(",")).map(func(x): return int(x))
		if a.begins_with("--kit-use-diff="): diff = a.substr(15)
	for sd in seeds:
		await _match(main, int(sd), secs)
	for arch in Arch.ids():
		_report(String(arch))
	print("ULTUSE done, failures: %d" % bad)

func _match(main: Node, sd: int, secs: float) -> void:
	var m := Match.new()
	main.add_child(m)
	seed(sd)
	sd_now = sd
	m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "bot_diff": diff})
	m.set_process(false)
	per.clear()
	for h in m.hunters:
		h.gain_xp(float(Hunter.XP_TO[START_LVL - 1]) - h.xp)
		h._bot_spend()
		per[h] = {"fight": {}, "wait": -1.0, "cast": {}, "kin_out": false}
	var cb_use := func(who, _id, slot): if slot == "ultimate" and per.has(who): _cast(m, who)
	var cb_hit := func(by, t, _d, _tags): _hit(by, t)
	var cb_throw := func(_k, who): if per.has(who): _c(who, "boki sends")
	CombatBus.ability_used.connect(cb_use)
	CombatBus.hit_landed.connect(cb_hit)
	CombatBus.kin_thrown.connect(cb_throw)
	while m.time < secs and not m.over:
		m.step(Match.DT)
		for h in m.hunters:
			_poll(m, h)
	for h in m.hunters:
		_end_fight(h)
	CombatBus.ability_used.disconnect(cb_use)
	CombatBus.hit_landed.disconnect(cb_hit)
	CombatBus.kin_thrown.disconnect(cb_throw)
	print("ULTUSE seed %d: %d s, %d Hunters" % [sd, int(m.time), m.hunters.size()])
	m.queue_free()
	await main.get_tree().process_frame

func _c(h: Hunter, key: String, by := 1.0) -> void:
	var c: Dictionary = n.get_or_add(h.ak.id, {})
	c[key] = float(c.get(key, 0.0)) + by

## The rival Hunter this bot is fighting now (null when none).
func _rival(h: Hunter) -> Hunter:
	if h.out or h.downed or h.dead or h.ak == null:
		return null
	var t = h.ai.get("tgt")
	if not (t is Hunter) or not is_instance_valid(t):
		return null
	var r := t as Hunter
	if r.dead or r.out or r.downed or r.team == h.team or h.flat_dist(r) > FIGHT_R:
		return null
	return r

func _poll(m: Match, h: Hunter) -> void:
	var s: Dictionary = per[h]
	var cast: Dictionary = s["cast"]
	if not cast.is_empty() and m.time > float(cast["until"]) and not h.ak.ult_running():
		s["cast"] = {}
	var r := _rival(h)
	var f: Dictionary = s["fight"]
	if r == null:
		if not f.is_empty() and m.time - float(f["last"]) > FIGHT_GAP:
			_end_fight(h)
		_stop_wait(h)
		return
	if f.is_empty():
		f = {"t0": m.time, "hits": 0, "kin_ok": false, "kin_out": false, "ready_s": 0.0, "casts": 0}
		s["fight"] = f
	f["last"] = m.time
	var k: Kin = h.kin
	if k != null and not k.dead and not k.resting() and k.state not in ["downed", "reviving", "bench", "away", "wild"]:
		f["kin_ok"] = true
		if k.state != "shoulder":
			f["kin_out"] = true          # out beside the bot, flying in, or merged into it
	var useful := HeroUlt.ready(h.ak) and h.flat_dist(r) < _reach(h.ak) and m.bot_brain.can_hit(m, h, r)
	if useful and not h.ak.ult_running():
		if float(s["wait"]) < 0.0:
			s["wait"] = 0.0
		s["wait"] = float(s["wait"]) + Match.DT
		f["ready_s"] = float(f["ready_s"]) + Match.DT
		_c(h, "ready s", Match.DT)
	else:
		_stop_wait(h)

## How near a rival has to be for this kit's ult to reach (its data's range, reach, length or radius).
func _reach(k: ArchKit) -> float:
	var xd := k.x_def()
	for key in ["range", "reach", "len", "radius"]:
		if xd.has(key):
			return clampf(float(xd[key]), 4.0, USEFUL_R)
	return USEFUL_R

## A ready useful ult stopped being one without a cast (the fight moved, or it ended).
func _stop_wait(h: Hunter) -> void:
	var w := float(per[h]["wait"])
	if w >= 0.0:
		_c(h, "waits")
		_c(h, "wait s", w)
		if w > WAIT_OK: _c(h, "waits late")
		per[h]["wait"] = -1.0

func _end_fight(h: Hunter) -> void:
	var f: Dictionary = per[h]["fight"]
	per[h]["fight"] = {}
	if f.is_empty() or int(f["hits"]) < REAL_HITS:
		return
	_c(h, "fights")
	if bool(f["kin_ok"]):
		_c(h, "fights boki ok")
		if bool(f["kin_out"]): _c(h, "fights boki out")
	if float(f["ready_s"]) >= WAIT_OK and int(f["casts"]) == 0:
		_c(h, "fights ult left")

func _cast(m: Match, h: Hunter) -> void:
	var s: Dictionary = per[h]
	_c(h, "casts")
	var w := float(s["wait"])
	if w >= 0.0:
		_c(h, "waits")
		_c(h, "wait s", w)
		_c(h, "waits cast" if w <= WAIT_OK else "waits late")
		s["wait"] = -1.0
	var in_fight: bool = not s["fight"].is_empty()
	if in_fight:
		s["fight"]["casts"] = int(s["fight"]["casts"]) + 1
		_c(h, "casts in fight")
	var near := false
	for f in m.foes_of(h.team) + m.hunters.filter(func(o): return o.team != h.team and not o.out):
		if not f.dead and h.flat_dist(f) < NOTHING_R:          # (a downed or briefly untouchable rival counts)
			near = true
			break
	if not near:
		_c(h, "casts into nothing")
		print("ULTUSE nothing %s seed %d t=%.0f" % [h.ak.id, sd_now, m.time])
	s["cast"] = {"until": m.time + LAND_S, "landed": not in_fight}       # (only a cast in a fight is judged)

func _hit(by, t) -> void:
	for h in [by, t]:
		if h is Hunter and per.has(h) and not per[h]["fight"].is_empty():
			var o = t if h == by else by
			if o is Hunter and o.team != h.team:
				per[h]["fight"]["hits"] = int(per[h]["fight"]["hits"]) + 1
	if not (by is Hunter) or not per.has(by) or not (t is Hunter) or t.team == by.team:
		return
	var cast: Dictionary = per[by]["cast"]
	if not cast.is_empty() and not bool(cast["landed"]):
		cast["landed"] = true
		_c(by, "casts landed")

func _g(c: Dictionary, k: String) -> float:
	return float(c.get(k, 0.0))

## Share a / b (0 when b is 0).
func _share(c: Dictionary, a: String, b: String) -> float:
	return _g(c, a) / _g(c, b) if _g(c, b) > 0.0 else 0.0

func _report(arch: String) -> void:
	var c: Dictionary = n.get(arch, {})
	var per_min := _share(c, "casts in fight", "ready s") * 60.0
	var within := _g(c, "waits cast") / maxf(1.0, _g(c, "waits cast") + _g(c, "waits late"))
	var mean_wait := _share(c, "wait s", "waits")
	var landed := _share(c, "casts landed", "casts in fight")
	var boki := _share(c, "fights boki out", "fights boki ok")
	var ult_cells := [_g(c, "casts"), _g(c, "casts in fight"), per_min, _g(c, "casts landed"), int(landed * 100.0),
		_g(c, "casts into nothing"), mean_wait, int(within * 100.0), _g(c, "fights ult left")]
	var boki_cells := [_g(c, "boki sends"), _g(c, "fights boki out"), _g(c, "fights boki ok"), int(boki * 100.0)]
	var row := "ULTUSE | %s | %d | %d | %d | %.1f | %d (%d%%) | %d | %.1f | %d%% | %d | %d | %d/%d (%d%%) |"
	print(row % ([arch, _g(c, "fights")] + ult_cells + boki_cells))
	if _g(c, "fights boki ok") >= 5.0:
		_judge(arch, boki, BOKI, "of fights with the Boki out")
	if not arch in NO_ULT and _g(c, "ready s") >= MIN_READY_S:
		_judge(arch, within, WITHIN, "of ready ults cast within %.0f s" % WAIT_OK)
		if _g(c, "casts in fight") >= 4.0:
			_judge(arch, landed, LAND, "of casts in a fight land")
	if _g(c, "casts into nothing") > 0.0:
		print("ULTUSE FAIL %s: %d casts into nothing" % [arch, int(_g(c, "casts into nothing"))])
		bad += 1

## A share against [target, floor]: under the floor fails, under the target is marked.
func _judge(arch: String, v: float, bar: Array, what: String) -> void:
	if v < float(bar[1]):
		print("ULTUSE FAIL %s: %d%% %s" % [arch, int(v * 100.0), what])
		bad += 1
	elif v < float(bar[0]):
		print("ULTUSE below %s: %d%% %s (target %d%%)" % [arch, int(v * 100.0), what, int(float(bar[0]) * 100.0)])
