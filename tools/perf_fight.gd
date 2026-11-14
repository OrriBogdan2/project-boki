extends RefCounted
## The fight worst case (DECISIONS 2026-11-08 performance budgets: VFX particles under 4,000 on screen, no frame over
## 50 ms after warm-up). First every Hunter alone, casting E then R at a dummy, so the particles and the nodes made
## by each kit are its own; then three trios of Hunters with their Boki sent out, fighting in one camp beside a
## monster camp, every Hunter casting E and R in waves. Run by --perf-bench --bench-fight and --perf-budget-check.
## Particles are counted with ParticleCount (every emitting emitter, on screen or not: an upper bound).

const ARCHS := ["ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "rimewright", "thief"]
const CAMP := ["brute", "skitter", "spitter", "skitter", "bomber", "brute", "skitter", "spitter"]
const SECS := 24.0  # s of the camp fight
const WAVE := 6.0  # s between casting waves (every Hunter: E, then R)
const R_AFTER := 0.6  # s from a wave's E to its R
const SAMPLE := 4  # frames between particle counts (it walks the whole tree)
const KIT_SECS := 4.0  # s a kit's E and R are watched for
const RING := 5.0  # m from the camp's middle to the Hunters

var bench  # the PerfBench: frames are logged and summed by it
var m: Match
var peak := {"n": 0, "by": {}, "t": 0.0, "nodes": 0}
var made := {}  # "Class:name" -> nodes that entered the tree after the warm-up
var kits := {}  # arch -> {n: particles over the quiet floor at its peak, made: nodes made}
var counting := false


func _init(perf_bench) -> void:
	bench = perf_bench


## The whole run; returns the camp fight's frames.
func run() -> Array:
	var main: Node = bench.main
	var o := Match.demo_opts()
	o.merge(
		{
			"teams": 3,
			"squad": 3,
			"total": 9,
			"no_drop": true,
			"god": true,
			"autoplay": true,
			"demo_kin": "cindle",
			"seed": 4101
		},
		true
	)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	while not (main.current is Match and (main.current as Match).is_processing() and main.current.hud != null):
		await main.get_tree().process_frame
	m = main.current
	m.set_process(false)
	main.get_tree().node_added.connect(
		func(n: Node):
			if counting:
				var k := "%s:%s<%s" % [n.get_class(), String(n.name).rstrip("0123456789@"), _owner_name(n)]
				made[k] = int(made.get(k, 0)) + 1
	)
	await _each_kit()
	var fl: Array = await _camp()
	_report()
	return fl


## Who made a node: the nearest ancestor with a name of its own (pooled and made nodes are mostly unnamed).
static func _owner_name(n: Node) -> String:
	var up := n.get_parent()
	while up != null and String(up.name).begins_with("@"):
		up = up.get_parent()
	return String(up.name).rstrip("0123456789@") if up != null else ""


func _step(n: int) -> void:
	for i in n:
		for h in m.hunters:
			h.hp = h.max_hp
		m.step(Match.DT)
		m._process(Match.DT)
		await bench.main.get_tree().process_frame


func _particles() -> Dictionary:
	return ParticleCount.by_owner(bench.main.get_tree().root)


## Every Hunter's E and R alone in front of an idle dummy (it stays, a punching bag in the camp), the rest idle.
func _each_kit() -> void:
	var P: Hunter = m.player
	var ctrl := {}
	for h in m.hunters:
		ctrl[h] = h.ctrl
		if h != P:
			h.ctrl = "idle"
	var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(6, 0, 0), [], 1.0, 0.5, 6.0)
	at.y = m.world.ground_at(at.x, at.z)
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, at, {"arch": "none"})
	T.max_hp = 1e6
	await _step(30)
	for arch in Arch.ids():
		P.set_arch(String(arch))
		_ready_kit(P)
		T.teleport(at)
		P.inp["aim"] = at + Vector3(0, 0.9, 0)
		await _step(60)
		var floor_n: int = ParticleCount.total(_particles())
		made.clear()
		counting = true
		var top := 0
		for f in int(KIT_SECS * 60.0):
			if f == 0:
				P.ak.use_e()
			if f == 60:
				P.ak.use_r()
			await _step(1)
			if f % SAMPLE == 0:
				top = maxi(top, ParticleCount.total(_particles()) - floor_n)
		counting = false
		kits[arch] = {"n": top, "made": made.values().reduce(func(a, b): return a + b, 0), "top": _top(made, 4)}
	for h in ctrl:
		h.ctrl = ctrl[h]


func _ready_kit(h: Hunter) -> void:
	h.unlock_all()
	h.lvl = 6
	h.slot_lv["ult"] = 1
	h.ak.cd["e"] = 0.0
	h.ak.cd["r"] = 0.0


## Three trios round the camp's middle with a monster camp, Boki out, E and R in waves; returns the frames.
func _camp() -> Array:
	var P: Hunter = m.player
	var mid: Vector3 = P.pos
	var i := 0
	for h: Hunter in m.hunters:
		var a := TAU * (h.team + i * 0.11) / 3.0
		h.set_arch(ARCHS[i % ARCHS.size()])
		var at: Vector3 = m.world.free_spot_near(mid + Vector3(cos(a), 0, sin(a)) * RING, [], 1.0, 0.5, 6.0)
		h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		i += 1
	for k in CAMP.size():
		var a := TAU * k / CAMP.size()
		var at: Vector3 = m.world.free_spot_near(mid + Vector3(cos(a), 0, sin(a)) * 3.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(CAMP[k], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	await _step(20)
	for h in m.hunters:
		if h.kin is Kin:
			(h.kin as Kin).throw_to(mid)
	made.clear()
	counting = true
	var fl: Array = []
	var last := Time.get_ticks_usec()
	var f := 0
	while f < int(SECS * 60.0):
		var wave_f := f % int(WAVE * 60.0)
		for h in m.hunters:
			if wave_f == 0:
				_ready_kit(h)
			if wave_f == 0:
				h.ak.use_e()
			if wave_f == int(R_AFTER * 60.0):
				h.ak.use_r()
		var t0 := Time.get_ticks_usec()
		await _step(1)
		var now := Time.get_ticks_usec()
		fl.append(bench._frame("fight", f, (now - last) / 1000.0, (now - t0) / 1000.0))
		last = now
		if f % SAMPLE == 0:
			_sample(f / 60.0)
		f += 1
	counting = false
	return fl


func _sample(t: float) -> void:
	var by := _particles()
	var n: int = ParticleCount.total(by)
	if n > int(peak["n"]):
		peak = {"n": n, "by": by, "t": t, "nodes": _vfx_nodes()}


## The effect nodes drawing now: emitting emitters plus the shown meshes and labels of Fx and HeroVfx.
func _vfx_nodes() -> int:
	var n := 0
	for root in [m.fx, HeroVfx.of(m)]:
		for c in (root as Node).find_children("*", "GeometryInstance3D", true, false):
			n += 1 if (c as Node3D).is_visible_in_tree() and not (c is GPUParticles3D or c is CPUParticles3D) else 0
	for by_cls in ["GPUParticles3D", "CPUParticles3D"]:
		for c in bench.main.get_tree().root.find_children("*", by_cls, true, false):
			n += 1 if c.get("emitting") else 0
	return n


static func _top(by: Dictionary, n: int) -> String:
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	return ", ".join(ks.slice(0, n).map(func(k): return "%s %d" % [k, by[k]]))


func _report() -> void:
	var ks := kits.keys()
	ks.sort_custom(func(a, b): return kits[a]["n"] > kits[b]["n"])
	for k in ks:
		print(
			"FIGHT kit %-11s E+R particles +%d, nodes made %d (%s)" % [k, kits[k]["n"], kits[k]["made"], kits[k]["top"]]
		)
	print(
		(
			"FIGHT peak t=%.1f s: particles %d, vfx nodes %d; by owner: %s"
			% [peak["t"], peak["n"], peak["nodes"], _top(peak["by"], 10)]
		)
	)
	print(
		(
			"FIGHT nodes made in the camp fight %d: %s"
			% [made.values().reduce(func(a, b): return a + b, 0), _top(made, 12)]
		)
	)
