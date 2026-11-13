extends RefCounted
## --music-combat-check: the score's drive layer follows your own fights (scripts/match/music_dir.gd).
## A hit dealt brings drive in within 0.5 s, a hit taken keeps it, 8 s of calm fades it out, and
## across the whole run the drive goal changes at most once per 2 s (no flicker).

var main: Node
var fails := 0
var n := 0
var pl: Hunter
var dealt := 0.0      # the trades the check scripts (the autoplay bot's own are overwritten)
var hurt := -9.0
const DT := 1.0 / 60.0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MUSICCOMBAT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77,
		"no_drop": true})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	pl = P
	for h in m.hunters:
		if h.team != P.team:
			h.unseen = true      # no rival lifts the drive layer: only our own trades do
	var md: MusicDir = m.music_dir
	ok(md != null and md.started, "setup: a normal match has the layered score")
	var changes: Array[float] = []
	_run(m, 1.0, changes)
	ok(md.heat == 0.0, "calm start: drive is out (%.2f)" % md.heat)
	dealt += 20.0      # a hit dealt
	var hit_t := m.time
	var rose := -1.0
	while m.time - hit_t < 1.0:
		_step(m, changes)
		if rose < 0.0 and md.heat >= 0.99:
			rose = m.time - hit_t
	ok(rose >= 0.0 and rose <= 0.5, "a hit dealt sets drive within 0.5 s (took %.2f s)" % rose)
	_run(m, 4.0, changes)
	hurt = m.time      # a hit taken restarts the hold
	_run(m, 7.0, changes)
	ok(md.heat >= 0.99, "7 s after a hit taken the drive is still on (%.2f)" % md.heat)
	_run(m, 2.0, changes)      # (a hit taken counts for 0.6 s: 8.6 s in all)
	ok(md.goal == 0.0 and md.heat < 0.99, "8+ s of calm starts the fade (goal %.2f, drive %.2f)" % [md.goal, md.heat])
	_run(m, 4.5, changes)
	ok(md.heat == 0.0, "...and the drive is out after the fade (%.2f)" % md.heat)
	ok(changes.size() == 2, "the drive goal changed %d times: one up, one down" % changes.size())
	var gap := 99.0
	for i in range(1, changes.size()):
		gap = minf(gap, changes[i] - changes[i - 1])
	ok(gap >= 2.0, "no more than one change per 2 s (closest %.1f s)" % gap)
	print("MUSICCOMBAT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Steps the match secs seconds; records the match time of each drive-goal change.
func _run(m: Match, secs: float, changes: Array[float]) -> void:
	var end := m.time + secs
	while m.time < end:
		_step(m, changes)

func _step(m: Match, changes: Array[float]) -> void:
	var before := m.music_dir.goal
	m.step(DT)
	pl.dmg_done = dealt
	pl.hurt_at = hurt
	m.music_dir.tick(m, DT)      # (Match._process ticks it; the check steps by hand)
	if m.music_dir.goal != before:
		changes.append(m.time)
