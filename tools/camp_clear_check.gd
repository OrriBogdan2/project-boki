extends RefCounted
## --camp-clear-check: PvE pacing. Each of the 12 Hunters (bot-driven, normal kit use, no Boki summon)
## clears a skitter, a spitter and a brute camp at level 1 and level 5 in a headless sim. Prints the
## time to clear and the damage taken, and asserts the band: per camp and level the slowest Hunter
## takes at most SPREAD_MAX x the fastest, and the target band (TARGET_BAND) is printed beside it.
## The measured spread today is far above the target (bot and kit behaviour, not mob numbers; see
## docs/EXPEDITION_SPEC.md "Camp clear pacing"), so SPREAD_MAX is a ratchet: lower it as kits and
## bots converge, until it equals TARGET_BAND. Tune mob hp/damage in Data.MOBS, never kit numbers.

const TARGET_BAND := 1.6   # goal: slowest clear time / fastest clear time, per camp and level
const SPREAD_MAX := 12.0   # ratchet: the spread may not get worse than this (runs vary, worst seen 8.2x)
const TIMEOUT := 40.0      # s a camp may take before the trial counts as a failure (worst seen 24 s)
const LEVELS := [1, 5]
const CAMPS := {
	"skitter": ["skitter", "skitter"],
	"spitter": ["spitter", "skitter"],
	"brute": ["brute", "skitter", "bomber"],
}

var bad := 0
var res := {}     # "camp@level" -> {arch: [seconds, damage]}

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
	for lv in LEVELS:
		while p.lvl < lv:
			p.gain_xp(Hunter.XP_TO[p.lvl] - p.xp)
		for camp in CAMPS:
			var r := _trial(m, p, CAMPS[camp])
			res.get_or_add("%s@%d" % [camp, lv], {})[arch] = r
			var what := "%s clears the %s camp at level %d" % [arch, camp, lv]
			ok(r[0] < TIMEOUT, "%s in %.1fs, %d damage taken" % [what, r[0], int(r[1])])
	m.queue_free()
	await main.get_tree().process_frame

## Fresh camp 6 m from the hunter on open ground; returns [seconds to clear, damage taken].
func _trial(m: Match, p: Hunter, comp: Array) -> Array:
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	p.hp = p.max_hp
	var at := m.world.free_spot_near(p.pos + Vector3(6, 0, 0), [], 1.0, 0.5, 8.0)
	var made: Array = []
	for kk in comp:
		made.append(m.spawn_mob(kk, at))
	var t0 := m.time
	var dmg := 0.0
	var prev := p.hp
	while m.time - t0 < TIMEOUT and made.any(func(x): return not x.dead):
		m.step(Match.DT)
		dmg += maxf(0.0, prev - p.hp)
		prev = p.hp
		if p.downed or p.out:
			m.revive_hunter(p, p)
	return [m.time - t0, dmg]

func _band() -> void:
	for key in res:
		var ts: Array = res[key].values().map(func(r): return r[0])
		var lo: float = ts.min()
		var hi: float = ts.max()
		var what := "%s: slowest %.1fs vs fastest %.1fs" % [key, hi, lo]
		var spread := hi / maxf(lo, 0.01)
		var limits := "ratchet %.1fx, target %.1fx" % [SPREAD_MAX, TARGET_BAND]
		ok(spread <= SPREAD_MAX, "%s (%.2fx, %s)" % [what, spread, limits])
