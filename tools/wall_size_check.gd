extends RefCounted
## --wall-size-check: no wall or obstacle in the practice areas or on The Hollow Crown is a lone post.
## A throw or a shot should go where it looks like it goes, so every connected piece of blocked
## ground (rock, tree, ruin, wall; touching tiles count, corners too) has BlockPrune.MIN_TILES or
## more tiles. That is 3: the shortest run that reads as a wall instead of a stump, and it still
## allows a 1x3 wall or an L. Prints every smaller piece it finds, with its map and tile coordinates.

var fails := 0
var checks := 0

## The pieces smaller than that.
static func small_pieces(world: World) -> Array:
	var smallest := BlockPrune.MIN_TILES
	return BlockPrune.pieces(world).filter(func(group: Array) -> bool: return group.size() < smallest)

func verdict(label: String, world: World) -> void:
	checks += 1
	var small := small_pieces(world)
	for group in small:
		print("WALLSIZE %s: %d-tile piece at %s (%s)" % [label, group.size(), group, _what(world, group)])
	var pass_it := small.is_empty()
	var total := BlockPrune.pieces(world).size()
	print("WALLSIZE %-26s %s  %d pieces, %d too small" % [label, "PASS" if pass_it else "FAIL", total, small.size()])
	if not pass_it:
		fails += 1

func _what(world: World, group: Array) -> String:
	var tile: Vector2i = group[0]
	var prop: String = world.props.get(world.idx(tile.x, tile.y), "")
	if world.walls.has(world.idx(tile.x, tile.y)):
		return "wall"
	return prop if prop != "" else "rock or tree"

func _match(label: String, opts: Dictionary, main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(opts)
	m.set_process(false)
	verdict(label, m.world)
	m.queue_free()
	await main.get_tree().process_frame

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var base := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "no_drop": true}
	await _match("Training Grounds", base.merged({"training": true, "practice": true, "seed": 4242}), main)
	await _match("arena", Match.arena_opts(), main)
	await _match("duel room", Match.duel_opts(), main)
	await _match("tutorial", base.merged({"tutorial": true, "seed": 77}), main)
	for seed_value in [3, 9]:
		await _match("hollow crown seed %d" % seed_value,
			{"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_value, "no_drop": true}, main)
	print("WALLSIZE DONE, %d checks, failures: %d" % [checks, fails])
	main.get_tree().quit()
