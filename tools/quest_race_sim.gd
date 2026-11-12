extends RefCounted
## --quest-race-sim: seeded bot trio matches, headless, to time the two quest seats of Limited Ways Out
## (docs/decisions/0051, docs/QUEST_TIMES.md). Per match and seat it prints when the seat opened, when
## the first squad engaged it (first IN_USE), when it finished (TAKEN or SHUT), how many squads came
## near it while it was open, and whether it stalled (shut unused, or fizzled back to OPEN).
## Options: --seeds=1,2,3 (default 1-10), --teams=N (default 10), --squad=N (default 3), --tier=N (default 1).
## Never touches the save. Fails if a match ends with a refused seat edge.

const NEAR_R := 30.0           # m: a squad this close to a seat while it is open counts as contesting it
const SAMPLE_S := 1.0          # s: how often squads are counted near a seat

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("QRACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds: Array = range(1, 11)
	var teams := 10
	var squad := 3
	var tier := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		if a.begins_with("--teams="): teams = int(a.substr(8))
		if a.begins_with("--squad="): squad = int(a.substr(8))
		if a.begins_with("--tier="): tier = int(a.substr(7))
	for sd in seeds:
		await _one(main, int(sd), teams, squad, tier)
	print("QRACE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _one(main: Node, seed_v: int, teams: int, squad: int, tier: int) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": teams, "squad": squad, "tier": tier, "seed": seed_v, "autoplay": true, "sim_keep": true})
	m.set_process(false)
	var seats: Array = []
	var near := {}                       # kind -> {team: true}
	var first := {}                      # kind -> the squad on the seat the first time it was IN_USE
	var next_sample := 0.0
	var t0 := Time.get_ticks_msec()
	var n_step := 0
	while not m.over and m.time < m.length + 1.0 and not _settled(seats):
		m.step(Match.DT)
		n_step += 1
		if seats.is_empty():
			seats = m.exits.seats.seats()      # (picked on the exits' first tick)
		if n_step % 120 == 0:
			await main.get_tree().process_frame      # (freed nodes only go between frames)
		for s: QuestSeat in seats:
			if s.state == QuestSeat.S.IN_USE and not first.has(s.kind):
				first[s.kind] = s.team
		if m.time >= next_sample:
			next_sample = m.time + SAMPLE_S
			for s: QuestSeat in seats:
				if s.state in [QuestSeat.S.OPEN, QuestSeat.S.IN_USE]:
					_count_near(m, s, near)
	for s: QuestSeat in seats:
		_report(m, s, near, int(first.get(s.kind, -1)), Time.get_ticks_msec() - t0)
		ok(s.refused == 0, "seed %d %s: no refused edge" % [seed_v, s.kind])
	m.queue_free()
	await main.get_tree().process_frame

## Both seats have finished (taken or shut): nothing more to time, so the match stops there.
func _settled(seats: Array) -> bool:
	var done := [QuestSeat.S.TAKEN, QuestSeat.S.SHUT]
	return not seats.is_empty() and seats.all(func(s: QuestSeat): return s.state in done)

func _count_near(m: Match, s: QuestSeat, near: Dictionary) -> void:
	var at: Vector3 = s.ref.get("c", s.ref.get("pos", Vector3.ZERO))
	var d: Dictionary = near.get(s.kind, {})
	var aim: Dictionary = near.get(s.kind + "_aim", {})
	for h in m.hunters:
		if h.out or h.extracted:
			continue
		if Vector2(h.pos.x - at.x, h.pos.z - at.z).length() < NEAR_R:
			d[h.team] = true
		if _aims_at(h, s.kind):
			aim[h.team] = true
	near[s.kind] = d
	near[s.kind + "_aim"] = aim

## A Hunter's bot goal is one of this seat's: any "lair_*", or the uplink's console and yard.
func _aims_at(h: Hunter, kind: String) -> bool:
	var gk := String(h.ai.get("goal_kind", ""))
	return gk.begins_with("lair") if kind == "lair" else gk in ["uplink", "yard"]

## Two lines per seat: when it opened, engaged (by which squad) and ended (taken by which),
## the squads near and aiming at it, then its state, entry kinds, stalls and wall time.
func _report(m: Match, s: QuestSeat, near_all: Dictionary, first_team: int, ms: int) -> void:
	var near: Dictionary = near_all.get(s.kind, {})
	var aim: Dictionary = near_all.get(s.kind + "_aim", {})
	var opened := _first(s, "LOCKED>OPEN")
	var engaged := _first(s, "OPEN>IN_USE")
	var end := _first(s, ">TAKEN")
	if end.is_empty():
		end = _first(s, ">SHUT")
	var fizzles := s.trail.filter(func(l): return ("IN_USE>OPEN" in l)).size()
	var ended := String(end.get("to", "NONE"))
	var stalled := ended != "TAKEN" or fizzles > 0
	var win := s.team if ended == "TAKEN" else -1
	var entry := "/".join(PackedStringArray(s.ref.get("entry", [])))
	print("QRACE seed=%d seat=%s open=%.0f engage=%.0f eteam=%d end=%.0f state=%s fteam=%d near=%d aim=%d" % [
		m.seed_val, s.kind, float(opened.get("t", -1.0)), float(engaged.get("t", -1.0)), first_team,
		float(end.get("t", -1.0)), ended, win, near.size(), aim.size()])
	var ref_state := String(s.ref.get("state", ""))
	print("QRACE   ref=%s entry=%s stalled=%s fizzles=%d wall_ms=%d" % [ref_state, entry, str(stalled), fizzles, ms])

## The first trail line with `edge` in it: {t, to}. The line shape is QuestSeat._force: "%7.2f A>B why".
func _first(s: QuestSeat, edge: String) -> Dictionary:
	for line in s.trail:
		if edge in line:
			var parts := String(line).strip_edges().split(" ", false)
			return {"t": float(parts[0]), "to": String(parts[1]).split(">")[1]}
	return {}
