extends RefCounted
## --camp-clear-check: PvE pacing. Each of the 12 Hunters (bot-driven, normal kit use, no Boki summon)
## clears a skitter, a spitter and a brute camp at level 1 and level 5 in a headless sim. A trial
## starts with the camp alerted, 6 m away on the hunter's own level, so it times the fight, not the
## bot's walk around the map. Each cell is the median of REPS trials (bots roll dice: single runs
## swing 3x). Asserts every Hunter clears every camp, and per camp and level the slowest median
## clear is at most SPREAD_MAX x the fastest. The target is BAND; today's spread is 4-12x and comes
## from how the bots use the slow kits, not mob numbers (doubling mob hp leaves it at 5-7x; see
## docs/EXPEDITION_SPEC.md "Camp clear pacing"). SPREAD_MAX is a ratchet: lower it toward BAND as
## the bots improve. Mob hp/damage live in Data.MOBS; never tune kit numbers for this.
## --arch=<id> runs one Hunter (prints its rows, skips the band).

const BAND := 1.6        # target: slowest median clear time / fastest, per camp and level
const SPREAD_MAX := 14.0 # ratchet on that ratio (worst seen 11.9x on brute@5)
const REPS := 5          # trials per cell; the cell is their median
const REST := 3.0        # s the hunter idles between trials (cooldowns tick, as between camps)
const GAP := 6.0         # m from the hunter to the camp
const TIMEOUT := 30.0    # s a trial may take; a timed-out trial counts as TIMEOUT
const LEVELS := [1, 5]
const CAMPS := {
	"skitter": ["skitter", "skitter"],
	"spitter": ["spitter", "skitter"],
	"brute": ["brute", "skitter", "bomber"],
}

var bad := 0
var res := {}     # "camp@level" -> {arch: [median seconds, median damage]}

func ok(cond: bool, what: String) -> void:
	print("CAMPCLEAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arch="): only = a.substr(7)
	for arch in Arch.ids():
		if only == "" or only == arch:
			await _hero(main, String(arch))
	if only == "":
		_band()
	print("CAMPCLEAR DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _hero(main: Node, arch: String) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "autoplay": true,
		"blight": false, "arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	var p: Hunter = m.player
	var home := p.pos
	for lv in LEVELS:
		while p.lvl < lv:
			p.gain_xp(Hunter.XP_TO[p.lvl] - p.xp)
		for camp in CAMPS:
			var ts: Array = []
			var dmg: Array = []
			for i in REPS:
				var r := _trial(m, p, home, CAMPS[camp], i)
				ts.append(r[0])
				dmg.append(r[1])
			var cell := [_median(ts), _median(dmg)]
			res.get_or_add("%s@%d" % [camp, lv], {})[arch] = cell
			var runs := " ".join(ts.map(func(t): return "%.1f" % t))
			ok(cell[0] < TIMEOUT, "%s clears the %s camp at level %d" % [arch, camp, lv])
			print("CAMPCLEAR row %s %s@%d %.1fs %d dmg (runs %s)" % [arch, camp, lv, cell[0], int(cell[1]), runs])
	m.queue_free()
	await main.get_tree().process_frame

## One alerted camp GAP m from home on the same level; returns [seconds to clear, damage taken].
func _trial(m: Match, p: Hunter, home: Vector3, comp: Array, i: int) -> Array:
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var rest_end := m.time + REST
	while m.time < rest_end:
		m.step(Match.DT)
	if p.downed or p.out:
		m.revive_hunter(p, p)
	p.teleport(home)
	p.hp = p.max_hp
	var at := _camp_spot(m, home, i)
	var made: Array = []
	for kk in comp:
		var mb := m.spawn_mob(kk, at)
		mb.tgt = p
		mb.st = "chase"
		made.append(mb)
	var t0 := m.time
	var dmg := 0.0
	var prev := p.hp
	while m.time - t0 < TIMEOUT and made.any(func(x): return not x.dead):
		m.step(Match.DT)
		dmg += maxf(0.0, prev - p.hp)
		prev = p.hp
		if p.downed or p.out:
			m.revive_hunter(p, p)
	return [minf(m.time - t0, TIMEOUT), dmg]

## A clear spot GAP m from home, level with it and in its line of sight (turning a bit each trial).
func _camp_spot(m: Match, home: Vector3, i: int) -> Vector3:
	for k in 12:
		var q := m.world.free_spot_near(home + Vector3(GAP, 0, 0).rotated(Vector3.UP, (i + k) * 1.3), [], 1.0, 0.5, 2.0)
		if absf(q.y - home.y) < 0.3 and m.world.los(home, q, home.y + 0.95):
			return q
	ok(false, "no level camp spot near %s" % home)
	return home + Vector3(GAP, 0, 0)

func _median(xs: Array) -> float:
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])

func _band() -> void:
	for key in res:
		var ts: Array = res[key].values().map(func(r): return r[0])
		var lo: float = ts.min()
		var hi: float = ts.max()
		var spread := hi / maxf(lo, 0.01)
		var limits := "ratchet %.1fx, target %.1fx" % [SPREAD_MAX, BAND]
		ok(spread <= SPREAD_MAX, "%s: slowest %.1fs vs fastest %.1fs (%.2fx, %s)" % [key, hi, lo, spread, limits])
