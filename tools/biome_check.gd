extends RefCounted
## --biome-check: an expedition on the authored map; what each biome spawned, then a minute of play.

func run(main: Node) -> void:
	# tooling: an expedition on the authored map; what each biome spawned, then a minute of play
	var bm := Match.new()
	main.add_child(bm)
	var args := OS.get_cmdline_user_args()
	var tier: int = _arg(args, "--tier=", 1)
	var seed_n: int = _arg(args, "--seed=", 9)
	bm.start({"teams": 4, "squad": 1, "tier": tier, "seed": seed_n, "no_drop": true, "autoplay": true})
	bm.set_process(false)
	var by := {}
	var rar := [0, 0, 0, 0]
	var nm := 0
	for mb in bm.mobs:
		var b := bm.world.biome_at(mb.pos.x, mb.pos.z)
		if not by.has(b): by[b] = []
		by[b].append(String(mb.md["name"]))
		rar[int(mb.get_meta("rarity", 0))] += 1
		if not (mb.get_meta("muts", []) as Array).is_empty(): nm += 1
	for b in by:
		print("BIOME %s: %d mobs, e.g. %s" % [b, by[b].size(), ", ".join((by[b] as Array).slice(0, 6))])
	var hk := {}
	for hz in bm.biomes.hazards: hk[hz["kind"]] = int(hk.get(hz["kind"], 0)) + 1
	var line := "BIOME rarity common/uncommon/rare/elite %s, mutated %d of %d; hazards %s"
	print(line % [str(rar), nm, bm.mobs.size(), str(hk)])
	for i in int(60.0 / Match.DT):
		bm.step(Match.DT)
	var alive := bm.mobs.filter(func(x): return not x.dead).size()
	print("BIOME sim ok, time %.0f, mobs left %d, fields %d" % [bm.time, alive, bm.fields.list.size()])
	main.get_tree().quit()

func _arg(args: PackedStringArray, prefix: String, dflt: int) -> int:
	for a in args:
		if a.begins_with(prefix): return int(a.substr(prefix.length()))
	return dflt
