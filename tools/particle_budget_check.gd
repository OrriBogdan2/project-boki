extends RefCounted
## --particle-budget-check: VFX particles stay under 4,000 on screen (docs/PERF.md, "Particle budget").
## Counts what every Hero move (content/vfx) and every shared Fx call site (scripts/) asks for, then builds a
## 30-Hunter match at each quality preset and adds the worst a fight can pile on top of what the world
## already draws: the Hero VFX cap and the full Fx burst and spark pools. Each preset must stay in budget,
## each one down must draw fewer particles, and Ultra must draw what High draws.

const BUDGET := 4000            # particles on screen at once, the cap
const MOVE_MAX := 160           # particles one Hero move may ask for at once, at full amount
const STEPS := 90               # sim steps before the count, so the lairs, raid fx and pickups are out

var bad := 0
var max_burst := 0       # the largest literal amounts asked of Fx.burst and Fx.spark
var max_spark := 0

func ok(cond: bool, what: String) -> void:
	print("PARTICLES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_moves()
	_sites()
	var worst := {}
	for id in Settings.QUALITY_ORDER:
		worst[id] = await _preset(main, id)
	var order: Array = Settings.QUALITY_ORDER
	for i in range(1, order.size()):
		var a: int = worst[order[i - 1]]
		var b: int = worst[order[i]]
		var same: bool = a == b and order[i] == "ultra"
		ok(a < b or same, "%s draws less than %s (%d, %d)" % [order[i - 1], order[i], a, b])
	ok(worst["high"] == worst["ultra"], "High and Ultra draw the same (%d, %d)" % [worst["high"], worst["ultra"]])
	print("PARTICLES %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## What each Hero move asks for: the particle layers' amounts (a layer never gets more than its pool node holds).
func _moves() -> void:
	var rows: Array = []
	for arch: String in HeroVfx.heroes():
		for mv: String in HeroVfx.data(arch).get("moves", {}):
			var n := 0
			for layer: Dictionary in HeroVfx.data(arch)["moves"][mv].get("fx", []):
				if HeroVfx.AMOUNT.has(layer["p"]):
					n += mini(int(layer.get("n", 12)), int(HeroVfx.AMOUNT[layer["p"]]))
			rows.append([n, "%s/%s" % [arch, mv]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var top := ", ".join(rows.slice(0, 8).map(func(r): return "%s %d" % [r[1], r[0]]))
	print("PARTICLES Hero moves, most first: " + top)
	ok(rows[0][0] <= MOVE_MAX, "no Hero move asks for more than %d (%s %d)" % [MOVE_MAX, rows[0][1], rows[0][0]])

## The shared Fx calls in the scripts: burst(at, col, amount) and spark(at, dir, col, amount), literal amounts only.
func _sites() -> void:
	var by_file := {}
	var re := RegEx.create_from_string("\\.(burst|spark)\\(")
	for path in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for hit in re.search_all(src):
			var args := _args(src, hit.get_end())
			var at := 2 if hit.get_string(1) == "burst" else 3
			if args.size() > at and args[at].is_valid_int():
				var n := int(args[at])
				by_file[path.get_file()] = int(by_file.get(path.get_file(), 0)) + n
				if hit.get_string(1) == "burst":
					max_burst = maxi(max_burst, n)
				else:
					max_spark = maxi(max_spark, n)
	var ks := by_file.keys()
	ks.sort_custom(func(a, b): return by_file[a] > by_file[b])
	print("PARTICLES Fx amounts asked for per file, most first: " + ", ".join(ks.slice(0, 8).map(
		func(k): return "%s %d" % [k, by_file[k]])))
	print("PARTICLES largest literal amounts: burst %d, spark %d" % [max_burst, max_spark])

func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out

## The top-level arguments of the call whose "(" ends at `from`.
func _args(src: String, from: int) -> PackedStringArray:
	var out := PackedStringArray([""])
	var depth := 0
	for i in range(from, mini(src.length(), from + 400)):
		var c := src[i]
		if c in "([{":
			depth += 1
		elif c in ")]}":
			if depth == 0:
				break
			depth -= 1
		if c == "," and depth == 0:
			out.append("")
		else:
			out[-1] += c
	for i in out.size():
		out[i] = out[i].strip_edges()
	return out

## 30 Hunters at one preset: what is drawn now, plus the Hero VFX cap and the full Fx pools.
func _preset(main: Node, id: String) -> int:
	Settings.v["quality"] = id
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "total": 30, "seed": 4101, "no_drop": true, "god": true, "raid": "ash",
		"arch": "juggernaut", "cls": Arch.weight("juggernaut"), "weapon": Arch.signature("juggernaut")})
	m.set_process(false)
	for i in STEPS:
		m.step(1.0 / 60.0)
	var by := ParticleCount.by_owner(m)
	for k in by.keys():
		if k.begins_with("Fx/"):
			by.erase(k)        # the Fx pools are counted in full below, not as they happen to be playing
	var now := ParticleCount.total(by)
	var bursts: int = m.fx.bursts.size() * maxi(3, int(round(max_burst * m.fx.particles)))
	var spark_k := clampf(m.fx.particles / Fx.PARTICLES, 0.4, 1.0)
	var sparks: int = m.fx.sparks.size() * maxi(2, int(round(max_spark * spark_k)))
	var cap := HeroVfx.MAX_LIVE
	var worst := now + bursts + sparks + cap
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	print("PARTICLES %s: drawn %d (%s), + Fx pools %d + sparks %d + Hero VFX cap %d = %d" % [id, now,
		", ".join(ks.slice(0, 4).map(func(k): return "%s %d" % [k, by[k]])), bursts, sparks, cap, worst])
	ok(worst <= BUDGET, "%s: the worst fight moment (%d) is under %d" % [id, worst, BUDGET])
	m.queue_free()
	await main.get_tree().process_frame
	return worst
