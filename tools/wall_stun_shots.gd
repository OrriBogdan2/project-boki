extends RefCounted
## Screenshots for --wall-stun-shots --shots-dir=<dir>: a foe driven into a Tenzo rock by Lace and into a
## Rink Wall by Albert, the crack and dust at 0.05 s and 0.4 s. Writes <dir>/MANIFEST.txt
## (wallstun|<file>|<caption>). Run under xvfb with a renderer.

## [file stem, attacker archetype, surface, caption]
const SHOTS := [
	["rock_archer", "archer", "rock", "A body driven into a Tenzo rock: crack and dust, Lace's rim"],
	["rimewall_bulwark", "bulwark", "rimewall", "A body driven into a Rink Wall: crack and dust, Albert's rim"],
]

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var out := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	var lines: Array = []
	var m := Match.new()
	main.add_child(m)
	var opts := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	await m.start(Match.arena_opts("gunslinger").merged(opts))
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud: m.hud.visible = false
	var P: Hunter = m.player
	var home := _spot(m, P.pos)
	var T := m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(3.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T: x.teleport(home + Vector3(-30, 0, 30))
	for s in SHOTS:
		P.set_arch(String(s[1]))
		P.teleport(home)
		P.vel = Vector3.ZERO
		T.teleport(home + Vector3(3.0, 0, 0))
		T.vel = Vector3.ZERO
		T.stun_t = 0.0
		T.wslam_t = 0.0
		var wall := _wall(m, T, home + Vector3(7.5, 0, 0), String(s[2]))
		var wi: WallImpact = m.fx.wall_impact
		for i in 40:      # (a second stun of the same body within 0.5 s is the same stun)
			m.step(1.0 / 60.0)
		var n0 := wi.placed
		T.hurt(5.0, P, {"src": "abil", "ab": "lmb", "kb": Vector2(14.0, 0.0), "lift": 0.5})
		for i in 90:
			m.step(1.0 / 60.0)
			if wi.placed > n0: break
		wi.set_process(false)      # the fade is stepped by hand below, so the two frames are the same on any machine
		for k in [["a", 0.05], ["b", 0.4]]:
			wi._process(float(k[1]))
			m.cam.snap(wi.last_at)
			for h in m.hunters: h.render(1.0 / 60.0, 1.0)
			await main.get_tree().process_frame
			var file := "wallstun_%s_%s.png" % [s[0], k[0]]
			main.get_viewport().get_texture().get_image().save_png(out.path_join(file))
			lines.append("wallstun|%s|%s (%.2f s)" % [file, s[3], k[1]])
		m.verbs.walls.erase(wall)
	var f := FileAccess.open(out.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	print("WALLSTUN shots: %d in %s" % [lines.size(), out])
	main.get_tree().quit(0)

func _wall(m: Match, T: Hunter, at: Vector3, kind: String) -> Dictionary:
	if kind == "rock":
		return HeroZones.rock(m, T, at, Vector2(1, 0), "wss", 4.0, 30.0, 999.0, false)
	var e := {"length": 4.0, "hp": 999.0, "time": 30.0, "move": true, "block": "enemy"}
	return m.verbs.add_wall(T, at, Vector2(1, 0), e, 1.0)

## A flat stretch of open ground away from the start (see aimkit_shots).
func _spot(m: Match, start: Vector3) -> Vector3:
	var W = m.world
	for z in range(6, W.h - 6, 3):
		for x in range(6, W.w - 18, 3):
			if Vector2(x - start.x, z - start.z).length() < 24.0:
				continue
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-3, 4):
				for dx in range(-3, 13):
					var i: int = W.idx(x + dx, z + dz)
					var plain: bool = W.kind[i] == World.T_GROUND and int(W.level[i]) == lv
					if not plain or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false
						break
				if not good:
					break
			if good:
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	return start
