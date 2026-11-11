extends RefCounted
## --camp-pace-check: how fast bot squads level on the early camps, against the level-by-minute table of
## EARLY_CAMPS_DROP 2.5 (bot_camps.gd, decision 0060). Twenty seeded headless matches on the 2x map, 10 bot
## trios, no god mode, played to 10:00. Squad 9 of every match never fights (its Hunters stand where they
## land, their Boki benched): the table's "never kills anything" row. One table per seed: each squad's
## region kind (rim, mid, hot, crown, or none: no camp region was free), mean level at every mark (- once
## it is out, * once it has a knock), and the XP earned per source (camp monsters / knocks / other).
## Asserts over all seeds:
##   par (2.8): bot squads average level 3.5-4.5 at 2:30, and no Hunter has the ultimate (level 6) by then
##   in 4 of 5 seeds; camps are 85% of the XP earned by 2:30 (6.2);
##   the band (2.5): at 2:00, 4:00, 5:15, 8:00 and 10:00 the median squad still up sits between the table's
##   lowest fighting row (hot zone, lost) and its highest (hot zone, won); the median quiet rim-drop squad
##   and quiet mid-drop squad (still up, no knock yet) are within one level of their own rows, at every
##   mark that has MIN_POOL of them (fewer: printed as "few", not judged);
##   limits (6.5): the best squad is at most 2 levels over the median at 4:00 and 3 at 8:00, in 4 of 5 seeds;
##   the squad that never fights is level 1 at every mark;
##   picks (2.8): no two bot squads ping a camp in one region, so the Crown goes at most once a match.
## A match takes minutes of machine time, so the seeds can be split: --seed=N or --seeds=A-B plays only
## those and prints one "CAMPPACE ROW" line each; --rows=FILE judges the ROW lines of saved logs instead of
## playing. --feed also prints the match feed. Never touches the save.
## (Main holds this object in a meta: it awaits frames.)

const SEEDS := [11, 30]    # first and last seed of the full run
const MARKS := {"2:00": 120.0, "2:30": 150.0, "4:00": 240.0, "5:15": 315.0, "8:00": 480.0, "10:00": 600.0}
## The spec's table (2.5): [lowest, highest] level per row at each band mark.
const BAND := {
	"any": {"2:00": [2, 5], "4:00": [4, 7], "5:15": [5, 7], "8:00": [7, 9], "10:00": [8, 10]},
	"rim": {"2:00": [3, 3], "4:00": [4, 5], "5:15": [5, 6], "8:00": [7, 7], "10:00": [8, 8]},
	"mid": {"2:00": [4, 4], "4:00": [5, 5], "5:15": [6, 6], "8:00": [7, 8], "10:00": [8, 9]},
}
const ROW_SLACK := 1.0     # levels a rim or mid median may sit outside its own row (a row is one squad's story)
const PAR := [3.5, 4.5]    # mean bot squad level at 2:30 (2.8)
const ULT_LVL := 6         # the ultimate's level: nobody by 2:30
const CAMP_SHARE := 0.85   # share of all XP earned by 2:30 that comes from camp monsters (6.2)
const MIN_POOL := 8        # quiet squads over all seeds a rim or mid row needs (a median of fewer is noise)
const LEAD := {"4:00": 2.0, "8:00": 3.0}     # levels the best squad may be over the median (6.5)
const MOST := 0.8          # share of seeds a per-seed rule must hold in
const IDLE_TEAM := 9
const FRAME_EVERY := 120   # steps between frames (freed nodes only go between frames)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAMPPACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds: Array = range(SEEDS[0], SEEDS[1] + 1)
	var rows: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seeds = [int(a.substr(7))]
		if a.begins_with("--seeds="):
			var ends := a.substr(8).split("-")
			seeds = range(int(ends[0]), int(ends[1]) + 1)
		if a.begins_with("--rows="):
			seeds = []
			for line in FileAccess.get_file_as_string(a.substr(7)).split("\n"):
				if line.begins_with("CAMPPACE ROW "): rows.append(JSON.parse_string(line.substr(13)))
	for sd in seeds:
		rows.append(await _play(main, int(sd)))
	for o in rows: _table(o)
	_judge(rows)
	print("CAMPPACE DONE, %d matches, failures: %d" % [rows.size(), bad])
	main.get_tree().quit(0 if bad == 0 else 1)

## One match, as its ROW: {seed, landed, shared: bot squads past the first in a region, top230: highest
## Hunter level at 2:30, home: {team: region kind}, lv: {mark: {team: mean level}}, up: {mark: [teams with a
## Hunter still in]}, kn: {mark: {team: knocks so far}}, xp: {mark: {source: xp}}}. Through JSON, so a
## played row and a read one are the same.
func _play(main: Node, sd: int) -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "plan_t": 0.5, "length": 1e9,
		"sim_keep": true})
	m.set_process(false)
	var out := {"seed": sd, "landed": -1.0, "shared": 0, "top230": 0, "home": {}, "lv": {}, "up": {}, "kn": {},
		"xp": {}}
	var src := {"camp": 0.0, "knock": 0.0, "other": 0.0}
	var last_xp := {}
	var last_alive := m.camps.alive()
	var last_knocks := 0
	var marks: Array = MARKS.keys()
	var n := 0
	var t0 := Time.get_ticks_msec()
	while not marks.is_empty() and not m.over:
		_idle(m)
		m.step(Match.DT)
		n += 1
		if n % FRAME_EVERY == 0: await main.get_tree().process_frame
		if n % 3600 == 0:
			print("CAMPPACE   ... seed %d t=%.0f s, %d s" % [sd, m.time, (Time.get_ticks_msec() - t0) / 1000])
		if out["landed"] < 0.0 and m.hunters.all(func(h): return not h.riding and not h.dropping):
			out["landed"] = m.time
			_homes(m, out)
		var camp_now: int = m.camps.alive()
		var knocks := 0
		for h in m.hunters: knocks += h.knocks
		var from := "other"
		if camp_now < last_alive: from = "camp"
		elif knocks > last_knocks: from = "knock"
		for h in m.hunters:
			var d: float = h.xp - float(last_xp.get(h, h.xp))
			last_xp[h] = h.xp
			if d > 0.0: src[from] += d
		last_alive = camp_now
		last_knocks = knocks
		if m.time >= float(MARKS[marks[0]]):
			var mk: String = marks.pop_front()
			out["lv"][mk] = _levels(m)
			out["up"][mk] = _up(m)
			out["kn"][mk] = _knocks(m)
			out["xp"][mk] = src.duplicate()
			if mk == "2:00" or mk == "2:30":
				for t in range(9):
					var sq: Array = m.hunters.filter(func(x): return x.team == t)
					var home := int(m.skydrop.picks.get(t, -1))
					var hc: Array = m.camps.camps.filter(func(c): return c["region"] == home)
					var st: Array = hc.map(func(c): return "%s:%d" % [str(c["size"]).substr(0, 2), c["state"]])
					var dd: Array = sq.map(func(x): return int(x.flat_dist(sq[0])))
					var cd: Array = hc.map(func(c): return int(sq[0].flat_dist(c["pos"])))
					var lr: Array = sq.map(func(x): return int(m.biomes.hot.region_at(x.pos)))
					print("DBGSQ %s t%d home=%d camps=%s lv=%s xp=%s out=%s mate_d=%s camp_d=%s at_reg=%s goal=%s" % [mk, t, home, st, sq.map(func(x): return x.lvl), sq.map(func(x): return int(x.xp)), sq.map(func(x): return x.out), dd, cd, lr, str(sq[0].ai.get("goal_k", ""))])
			if mk == "2:30":
				for h in m.hunters: out["top230"] = maxi(out["top230"], h.lvl)
	if "--feed" in OS.get_cmdline_user_args():
		for line in m.feed_all: print("CAMPPACE   feed ", line)
	m.queue_free()
	await main.get_tree().process_frame
	print("CAMPPACE ROW ", JSON.stringify(out))
	return JSON.parse_string(JSON.stringify(out))

## The idle squad stands still once on the ground, its Boki benched (a Boki's kill is its Hunter's).
func _idle(m: Match) -> void:
	for h in m.hunters:
		if h.team == IDLE_TEAM and not h.riding and not h.dropping:
			h.ctrl = "idle"       # (no bot tick: it just stands)
			h.inp["move"] = Vector2.ZERO
			h.inp["fire"] = false
			if h.kin and h.kin.state != "bench": h.kin.bench()

func _levels(m: Match) -> Dictionary:
	var sum := {}
	for h in m.hunters:
		sum[h.team] = sum.get(h.team, 0.0) + h.lvl / 3.0
	return sum

func _knocks(m: Match) -> Dictionary:
	var sum := {}
	for h in m.hunters:
		sum[h.team] = sum.get(h.team, 0) + h.knocks
	return sum

func _up(m: Match) -> Array:
	var out := {}
	for h in m.hunters:
		if not h.out or h.extracted: out[h.team] = true
	return out.keys()

## Each bot squad's region kind from its leader's camp ping, and the squads doubling up on a region.
func _homes(m: Match, out: Dictionary) -> void:
	var sizes := {}       # region -> {camp size: true}
	var crown := -1
	for c in m.camps.list():
		if not sizes.has(c["region"]): sizes[c["region"]] = {}
		sizes[c["region"]][c["size"]] = true
	for ii in m.world.islands.size():
		if String(m.world.islands[ii].get("role", "")) == "heart": crown = m.biomes.hot.region_of[ii]
	var per := {}
	for t in range(10):
		var r := int(m.skydrop.picks.get(t, -1))
		var kind := "none"
		if r >= 0:
			per[r] = per.get(r, 0) + 1
			kind = "mid" if sizes.get(r, {}).size() >= 3 else "rim"
			if r == crown: kind = "crown"
			if r == m.biomes.hot.hot: kind = "hot"
		out["home"][t] = "idle" if t == IDLE_TEAM else kind
	for r in per:
		out["shared"] += per[r] - 1

func _table(o: Dictionary) -> void:
	print("CAMPPACE seed %d, landed at %.0f s, squads doubling up on a region %d" % [
		o["seed"], o["landed"], o["shared"]])
	print("CAMPPACE  squad        %s" % "   ".join(MARKS.keys().map(func(k): return "%5s" % k)))
	for t in o["home"]:
		var cells := ""
		for mk in MARKS:
			var tag := "*" if o["kn"][mk].get(t, 0.0) > 0.0 else " "
			cells += "   %4.1f%s" % [o["lv"][mk].get(t, 0.0), tag if (o["up"][mk] as Array).has(float(t)) else "-"]
		print("CAMPPACE  %s %-5s  %s" % [t, o["home"][t], cells])
	for mk in ["2:30", "5:15", "10:00"]:
		var s: Dictionary = o["xp"][mk]
		print("CAMPPACE  XP by %s  camp %d  knock %d  other %d" % [mk, s["camp"], s["knock"], s["other"]])

func _median(a: Array) -> float:
	a.sort()
	if a.is_empty(): return 0.0
	var k: int = a.size() / 2
	return float(a[k]) if a.size() % 2 == 1 else (float(a[k - 1]) + float(a[k])) * 0.5

## The mean levels at a mark of one match's bot squads still up: all of them ("any"), or the quiet ones (no
## knock yet) of one region kind.
func _squads(o: Dictionary, mk: String, kind: String) -> Array:
	var out: Array = []
	for t in o["home"]:
		var mine: bool = o["home"][t] != "idle"
		if kind != "any": mine = o["home"][t] == kind and o["kn"][mk].get(t, 0.0) == 0.0
		if mine and (o["up"][mk] as Array).has(float(t)): out.append(o["lv"][mk][t])
	return out

func _judge(runs: Array) -> void:
	var n := runs.size()
	var need := ceili(n * MOST)
	var at230: Array = []
	var no_ult := 0
	var idle_ok := true
	var shared := 0
	var camp_xp := 0.0
	var all_xp := 0.0
	for o in runs:
		camp_xp += float(o["xp"]["2:30"]["camp"])
		for k in o["xp"]["2:30"]: all_xp += float(o["xp"]["2:30"][k])
		for t in o["home"]:
			if o["home"][t] != "idle": at230.append(o["lv"]["2:30"][t])
		if o["top230"] < ULT_LVL: no_ult += 1
		for mk in MARKS:
			if o["lv"][mk][str(IDLE_TEAM)] > 1.0: idle_ok = false
		shared += int(o["shared"])
	var par := 0.0
	for v in at230: par += float(v) / maxf(1.0, at230.size())
	ok(par >= PAR[0] and par <= PAR[1], "bot squads average level %.2f at 2:30 (%.1f-%.1f)" % [par, PAR[0], PAR[1]])
	ok(no_ult >= need, "no Hunter level %d by 2:30 in %d of %d seeds (%d needed)" % [ULT_LVL, no_ult, n, need])
	var share := camp_xp / maxf(1.0, all_xp)
	ok(share >= CAMP_SHARE, "camps are %.0f%% of the XP earned by 2:30 (%.0f%% wanted)" % [
		share * 100.0, CAMP_SHARE * 100.0])
	for mk in BAND["any"]:
		for kind in BAND:
			var pool: Array = []
			for o in runs: pool.append_array(_squads(o, mk, kind))
			var slack := 0.0 if kind == "any" else ROW_SLACK
			var lo: float = BAND[kind][mk][0] - slack
			var hi: float = BAND[kind][mk][1] + slack
			var med := _median(pool)
			var who := "bot" if kind == "any" else "quiet %s-drop" % kind
			var what := "%s: the median %s squad still up is level %.2f (%.0f-%.0f, %d squads)" % [
				mk, who, med, lo, hi, pool.size()]
			if kind != "any" and pool.size() < MIN_POOL: print("CAMPPACE few  ", what)
			else: ok(not pool.is_empty() and med >= lo and med <= hi, what)
	for mk in LEAD:
		var held := 0
		for o in runs:
			var lv := _squads(o, mk, "any")
			if lv.is_empty() or lv.max() - _median(lv) <= LEAD[mk]: held += 1
		ok(held >= need, "%s: the best squad is within %.0f levels of the median in %d of %d seeds (%d needed)" % [
			mk, LEAD[mk], held, n, need])
	ok(idle_ok, "the squad that never fights is level 1 at every mark")
	ok(shared == 0, "no two bot squads pinged a camp in one region (%d doubling up)" % shared)
