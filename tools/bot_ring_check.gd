extends RefCounted
## --bot-ring-check: bots have zone sense (BotRing, scripts/match/bot_ring.gd). A 30-bot trios match
## (ten squads of three, autoplay) runs from the drop through the Blight's whole close; no bot may go
## down to a tide tick while no rival Hunter is within ENEMY_R, and every bot still up ends inside.
## The close is sped up to CLOSE_S (all 11 stages, each stage's damage as in a match; the wall moves
## about 2x faster than in a match, so a pass here is a pass with room). Prints each Blight down with
## its stage, distance past the wall and the bot's goal.
## Args: --ring-seeds=a,b (default 4), --ring-close=<seconds> (default CLOSE_S), --ring-t=<seconds>
## (default: the close plus 10 s).
## Never touches the save.

const ENEMY_R := 20.0          # m: a rival Hunter this close means the bot chose to fight there
const MIN_STAGES := 3          # the run must see at least this many tide stages close
const CLOSE_S := 110.0         # s: the check's whole close (a match: heart.json tide_close_s)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _rival_near(m: Match, h: Hunter) -> bool:
	for o in m.hunters:
		if o.team != h.team and not o.out and not o.downed and not o.extracted and h.flat_dist(o) < ENEMY_R:
			return true
	return false

func _past(m: Match, h: Hunter) -> float:
	var s := m.heart.site
	return Vector2(h.pos.x - s.x, h.pos.z - s.z).length() - Heart.tide_r(m)

func _why_out(m: Match, sd: int, h: Hunter) -> void:
	var g: Vector3 = h.ai.get("goal", Vector3.INF)
	var w := m.world
	var to_isl := w.island_of(g.x, g.z) if g != Vector3.INF else -9
	print("RING   seed %d %s %.1f m past the wall, goal %s %s, island %d -> %d, grounded %s, hp %.0f, cross %s" % [
		sd, h.pname, _past(m, h), String(h.ai.get("goal_kind", "")), str(g.snapped(Vector3.ONE)),
		w.island_of(h.pos.x, h.pos.z), to_isl, h.grounded, h.hp, str(h.ai.has("cross"))])

func _one(main: Node, sd: int, dur: float) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "length": dur + 60.0})
	m.set_process(false)
	ok(m.hunters.size() == 30 and m.heart != null, "seed %d: 30 bots and a Heart (%d)" % [sd, m.hunters.size()])
	if m.heart == null:
		m.queue_free()
		return
	var up := {}
	for h in m.hunters:
		up[h] = true
	var downs := 0
	var fought := 0
	var tide_downs := 0
	var stage0 := Heart.tide_stage(m)
	while m.sess_time() < dur and not m.over:
		var tick_t := m.heart._tide_t
		m.step(Match.DT)
		var ticked := m.heart._tide_t < tick_t
		for h in m.hunters:
			if h.extracted:
				up[h] = false        # (left by an exit: not a down, and not on the map)
				continue
			var now_up: bool = not (h.downed or h.out or h.dead)
			if up[h] and not now_up:
				downs += 1
				if ticked and h.last_hit_by == null and _past(m, h) > 0.0:
					if _rival_near(m, h):
						fought += 1
					else:
						tide_downs += 1
						print("RING down to the Blight: seed %d t=%.0f stage %d %s" % [
							sd, m.sess_time(), Heart.tide_stage(m), h.pname])
						_why_out(m, sd, h)
			up[h] = now_up
	var stages := Heart.tide_stage(m) - stage0
	var inside := 0
	var alive := 0
	for h in m.hunters:
		if up[h]:
			alive += 1
			if _past(m, h) <= 0.0:
				inside += 1
			else:
				print("RING outside at the end:")
				_why_out(m, sd, h)
	print("RING seed %d: %.0f s, stages %d..%d, downs %d (Blight with a rival near %d), up %d, inside %d" % [sd,
		m.sess_time(), stage0, Heart.tide_stage(m), downs, fought, alive, inside])
	ok(stages >= MIN_STAGES, "seed %d: the run saw %d tide stages close" % [sd, stages])
	ok(tide_downs == 0, "seed %d: no bot went down to the Blight with no rival within %.0f m (%d did)" % [
		sd, ENEMY_R, tide_downs])
	ok(inside == alive, "seed %d: every bot still up stands inside the ring (%d of %d)" % [sd, inside, alive])
	m.queue_free()
	await main.get_tree().process_frame

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds := [4]
	var close := CLOSE_S
	var dur := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ring-seeds="): seeds = Array(a.substr(13).split(",")).map(func(x): return int(x))
		if a.begins_with("--ring-close="): close = float(a.substr(13))
		if a.begins_with("--ring-t="): dur = float(a.substr(9))
	var rl := Heart.rules()
	var keep := float(rl["tide_close_s"])
	rl["tide_close_s"] = close
	if dur < 0.0:
		dur = Heart.r("tide_start_s") + close + 10.0
	for sd in seeds:
		await _one(main, sd, dur)
	rl["tide_close_s"] = keep
	print("RING done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
