extends RefCounted
func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle",
			"cls": Arch.weight("gunslinger"), "arch": "gunslinger", "weapon": Arch.signature("gunslinger"), "tut_test": true})
	m.set_process(false)
	var w := m.world
	var c := Vector2(58, 47)
	for z in range(36, 58):
		var row := ""
		for x in range(44, 68):
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if Vector2(dx, dz).length() <= 2.2:
						var q := Vector2(x + 0.5 + dx, z + 0.5 + dz)
						if w.is_void(q.x, q.y) or w.is_block(q.x, q.y) or absf(w.ground_at(q.x, q.y)) > 0.01 or w.island_of(q.x, q.y) != 3:
							ok = false
			row += ("o" if ok else ".")
		print("MAPO %d %s" % [z, row])
	main.get_tree().quit()
