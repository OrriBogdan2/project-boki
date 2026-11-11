extends RefCounted
## --mob-death-check: the seven monsters and the lair bosses die the same way (MobDissolve): a dissolve of
## 0.3-0.6 s by size on pooled materials, no blast, a rippling stagger when a camp is wiped, and the drops
## spill after it. The Low preset skips the shader and the ash. Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const BOSSES := ["colossus", "serpent", "brood"]
const DT := 1.0 / 60.0
const ASH_WIPE_MAX := 72      # ash particles a wiped 6-camp may emit in all (12 per body)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MOBDEATH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		if not mb is Boss: mb.queue_free()
	m.mobs.assign(m.mobs.filter(func(x): return x is Boss))      # (the lair bosses stay for _boss)
	if m.biomes:
		m.biomes.hazards.clear()      # (a lightning rod's strike is a burst too; fx.radial must count deaths only)
	for o in m.hunters:
		if o != m.player: o.ctrl = "idle"
	_sizes()
	for k in KINDS:
		_kill_one(m, k)
	_boss(m)
	_wipe(m)
	_particles(m)
	_low(m)
	m.queue_free()
	print("MOBDEATH DONE, failures: %d" % bad)
	main.get_tree().quit(mini(bad, 1))

func _frames(m: Match, sec: float) -> void:
	for i in int(ceil(sec / DT)):
		m.step(DT)
		for mb in m.mobs: mb.render(DT, 1.0)

## 0.3 s for the smallest, 0.6 s for a boss, never shorter for something bigger.
func _sizes() -> void:
	var last := 0.0
	var sorted := KINDS + BOSSES
	sorted.sort_custom(func(a, b): return float(Data.MOBS[a]["r"]) < float(Data.MOBS[b]["r"]))
	var in_range := true
	for k in sorted:
		var t := MobDissolve.duration(float(Data.MOBS[k]["r"]))
		in_range = in_range and t >= MobDissolve.DUR_MIN - 0.001 and t <= MobDissolve.DUR_MAX + 0.001 and t >= last
		last = t
	ok(in_range, "all 10 durations sit in 0.3-0.6 s and grow with size")
	var small := MobDissolve.duration(float(Data.MOBS["skitter"]["r"]))
	var big := MobDissolve.duration(float(Data.MOBS["brood"]["r"]))
	ok(is_equal_approx(small, 0.3) and is_equal_approx(big, 0.6), "skitter 0.3 s, a boss 0.6 s")

func _spot(m: Match, i: int) -> Vector3:
	return m.player.pos + Vector3(6.0 + i * 1.6, 0, 3.0)

func _kill_one(m: Match, k: String) -> void:
	var mb := m.spawn_mob(k, _spot(m, 0))
	var pk0 := m.pickups.size()
	var radial0 := m.fx.radial
	Juice.mob_dead(m, mb, null, mb.r > 0.8)
	ok(m.fx.radial == radial0, "%s: the kill feel adds no burst or ring" % k)
	mb.hurt(mb.hp + mb.max_hp, m.player, {"src": "shot"})
	_frames(m, 0.05)
	radial0 = m.fx.radial
	var mat = mb.get_meta("dis_mat", null)
	ok(mb.dead and mb.visible and mat != null, "%s: dies and starts its dissolve (still drawn)" % k)
	var meshes := mb.model.find_children("*", "MeshInstance3D", true, false)
	var worn: bool = meshes.all(func(n): return (n as MeshInstance3D).material_override == mat)
	ok(not meshes.is_empty() and worn, "%s: every part wears the dissolve material" % k)
	var dur := MobDissolve.duration(mb.r)
	var k_mid: float = 0.0
	_frames(m, dur * 0.5)
	k_mid = float(mat.get_shader_parameter("k"))
	ok(k_mid > 0.3 and k_mid < 0.8 and mb.visible, "%s: half way through the dissolve (k %.2f)" % [k, k_mid])
	ok(m.pickups.size() == pk0, "%s: nothing spilled yet" % k)
	ok(m.fx.radial == radial0, "%s: no burst or ring while it dissolves" % k)
	_frames(m, dur * 0.5 + 0.1)
	ok(not mb.visible, "%s: gone within %.2f s" % [k, dur + 0.15])
	_frames(m, 0.3)
	ok(m.pickups.size() > pk0, "%s: the drops spilled after it (%d)" % [k, m.pickups.size() - pk0])

## A lair boss goes the same way, over its 0.6 s.
func _boss(m: Match) -> void:
	var L: Dictionary = m.lairs.list[0]
	m.lairs.activate(L)
	if L["state"] == "sealed":
		m.lairs.open(L, m.player, "dial")
	var b: Boss = L["boss_mob"]
	b.dormant = false
	b.stagger_t = 0.0
	b.invul_t = 0.0
	if b.buried: b._surface()
	b.hurt(b.hp + b.max_hp, m.player, {"src": "shot"})
	_frames(m, 0.05)
	ok(b.dead and b.visible and b.has_meta("dis_mat"), "%s boss: dies and dissolves" % b.mkind)
	_frames(m, MobDissolve.DUR_MAX + 0.15)
	ok(not b.visible, "%s boss: gone within %.2f s" % [b.mkind, MobDissolve.DUR_MAX + 0.2])

## A camp wiped in one frame ripples instead of flashing out together, and the loot follows each body.
func _wipe(m: Match) -> void:
	var pack: Array = []
	for i in 6:
		pack.append(m.spawn_mob("skitter", m.player.pos + Vector3(-6.0 - (i % 3) * 0.8, 0, i / 3 * 0.8)))
	for mb in pack:
		mb.hurt(mb.hp + mb.max_hp, m.player, {"src": "shot"})
	var lags: Array = pack.map(func(mb): return float(mb.get_meta("dis_lag", -1.0)))
	var rising := true
	for i in range(1, lags.size()):
		rising = rising and float(lags[i]) >= float(lags[i - 1])
	var last_lag: float = MobDissolve.STAGGER_S * MobDissolve.STAGGER_MAX
	var ripple := rising and float(lags[0]) == 0.0 and float(lags[5]) == last_lag
	ok(ripple, "six wiped together queue 0 .. %.2f s behind each other (%s)" % [last_lag, str(lags)])
	var shared := false
	for f in 30:
		_frames(m, DT)
		var mats := {}
		for mb in pack:
			if mb.has_meta("dis_mat") and not mb.has_meta("dis_done"):
				shared = shared or mats.has(mb.get_meta("dis_mat"))
				mats[mb.get_meta("dis_mat")] = true
	ok(not shared, "no two bodies dissolve on the same material at once")
	_frames(m, 1.0)
	var made := MobDissolve.made
	for i in 6:
		m.spawn_mob("skitter", m.player.pos + Vector3(-6.0 - i * 0.8, 0, 2.0)).hurt(999.0, m.player, {"src": "shot"})
	_frames(m, 1.0)
	ok(MobDissolve.made == made, "a second wipe reuses the pooled materials (%d built in all)" % made)
	ok(pack.all(func(mb): return not mb.visible), "the whole camp is gone after the ripple")

## The particles row: the ash is the only particle cost of a death, small per body, none on Low.
func _particles(m: Match) -> void:
	var ash0 := m.fx.ash
	for i in 6:
		m.spawn_mob("skitter", _spot(m, i)).hurt(999.0, m.player, {"src": "shot"})
	_frames(m, 1.0)
	var wipe := m.fx.ash - ash0
	ok(wipe > 0 and wipe <= ASH_WIPE_MAX, "particles: a 6-camp wipe emits %d ash (budget %d)" % [wipe, ASH_WIPE_MAX])
	Settings.v["quality"] = "low"
	ash0 = m.fx.ash
	m.spawn_mob("brute", _spot(m, 2)).hurt(999.0, m.player, {"src": "shot"})
	_frames(m, 1.0)
	ok(m.fx.ash == ash0, "particles: Low emits no ash")
	Settings.v.erase("quality")

## The Low preset: no shader swap and no ash, a shorter fade, the drops still spill.
func _low(m: Match) -> void:
	Settings.v["quality"] = "low"
	var mb := m.spawn_mob("brute", _spot(m, 3))
	var pk0 := m.pickups.size()
	mb.hurt(mb.hp + mb.max_hp, m.player, {"src": "shot"})
	_frames(m, 0.05)
	ok(not mb.has_meta("dis_mat") and mb.visible, "Low: no dissolve material, no ash, still fading")
	var brute_s := MobDissolve.duration(mb.r)
	ok(brute_s < 0.6 * MobDissolve.LOW_DUR_K + 0.001, "Low: the fade is shorter (%.2f s)" % brute_s)
	_frames(m, 1.0)
	ok(not mb.visible and m.pickups.size() > pk0, "Low: gone, and the drops spilled")
	Settings.v.erase("quality")
