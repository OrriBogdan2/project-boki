extends RefCounted
## --dmg-number-shots --shots-dir=<dir>: the match camera in a crowded fight, to compare damage numbers
## before and after the roll-up. Five rivals stand in front of the player; each takes a zone tick every
## quarter second for two seconds, one a crit and one a heavy hit, the reticle on the nearest.
##   dmgnum_0_ticks   mid-fight, ticks landing
##   dmgnum_1_end     the last tick, numbers at their totals
##   dmgnum_3_kinds_a / _b  one hit of every kind (HudStyle.NUM_STYLE) on a ring of rivals: a plain hit, armour,
##     a crit, an empowered hit, a shield (a); a Fusion shell, a heal, damage you take, plain and shield again
##     as the reference (b)
##   dmgnum_2_trio    you and two teammates focus one dummy (tools/dmg_number_trio.gd), 2.3 s in, and
##   dmgnum_2_trio_crop  the 480x360 around the dummy; prints the most numbers over one spot per frame
##   dmgnum_3_sizes   (taken before the trio) three rivals, 4 frames after a rifle round (8), an ability hit (18)
##                    and an ult (45) from you: the size each prints at and its impact flash
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const Trio := preload("res://tools/dmg_number_trio.gd")
const TICK_EVERY := 15  # frames: a quarter second

var main: Node
var m: Match
var P: Hunter
var fx: Fx
var dir := ""
var foes: Array = []


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var lines: Array = []
	for f in 120:
		if f % TICK_EVERY == 0:
			_tick(f)
		await _frame()
		if f == 70:
			_take("dmgnum_0_ticks", lines, "Mid-fight: five rivals taking ticks, reticle on the nearest")
	_take("dmgnum_1_end", lines, "After two seconds of ticks, a crit and a heavy hit")
	await _sizes(lines)
	await _kinds(lines)
	await _trio(lines)
	var cap := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		cap.store_line(l)
	cap.close()
	print("DMGNUMSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)


func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 5, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	fx = m.fx
	fx.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.teleport(m.world.random_ground())
	var i := 0
	for h in m.hunters.filter(func(x): return x.team != P.team):
		h.max_hp = 1e6
		h.hp = 1e6
		var ring := Vector3(1, 0, 0).rotated(Vector3.UP, i * TAU / 5.0) * 3.5
		h.teleport(m.world.free_spot_near(P.pos + ring, [], 1.0, 0.4, 6.0))
		foes.append(h)
		i += 1
	await _frame()
	print("DMGNUMSHOTS foes at ", foes.map(func(h): return h.pos.snapped(Vector3(0.1, 0.1, 0.1))))
	var cam := main.get_viewport().get_camera_3d()
	main.get_viewport().warp_mouse(cam.unproject_position(foes[0].pos + Vector3(0, 1.5, 0)))


func _tick(f: int) -> void:
	for h in foes:
		h.hurt(6.0, P, {"src": "abil", "tags": ["ult", "cinder_zone"]})
	if f == 60:
		foes[1].hurt(40.0, P, {"src": "shot", "crit": true})
		foes[2].hurt(240.0, P, {"src": "shot"})


## One hit of each size from you on three rivals, the frame 4 frames later (numbers popped, flashes up).
func _sizes(lines: Array) -> void:
	fx.nums.clear()
	for l in fx.num_pool:
		l.visible = false
	for k in 40:
		await _frame()
	foes[0].hurt(8.0, P, {"src": "shot"})
	foes[1].hurt(18.0, P, {"src": "abil", "ab": "utility"})
	foes[2].hurt(45.0, P, {"src": "abil", "ab": "ult"})
	for k in 4:
		await _frame()
	_take("dmgnum_3_sizes", lines, "A rifle round (8), an ability hit (18) and an ult (45) from you, 4 frames on")


func _frame() -> void:
	m.step(DT)
	fx._process(DT)
	m.cam.snap(P.pos)
	for h in m.hunters:
		h.render(DT, 1.0)
	await main.get_tree().process_frame


func _take(file: String, lines: Array, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])


## One hit of every kind, two stills (a: plain, armour, crit, empowered, shield; b: shell, heal, hurt, plain, shield).
func _kinds(lines: Array) -> void:
	var sets := [
		["a", ["hit", "armour", "crit", "empowered", "shield"]],
		["b", ["shell", "heal", "hurt", "hit", "shield"]],
	]
	for sv in sets:
		fx.nums.clear()
		for h in foes:
			h.armor = 0.0
			h.shield = 0.0
			h.merge_st = {}
			h.inv_t = 0.0
			h.hp = 1e6
		P.inv_t = 0.0
		P.hp = P.max_hp
		for i in 5:
			var k: String = sv[1][i]
			var h: Hunter = foes[i]
			match k:
				"hit":
					h.hurt(30.0, P, {"src": "shot"})
				"armour":
					h.armor = 200.0
					h.hurt(30.0, P, {"src": "shot"})
				"crit":
					h.hurt(30.0, P, {"src": "shot", "crit": true})
				"empowered":
					h.hurt(30.0, P, {"src": "shot", "heavy": true})
				"shield":
					h.shield = 200.0
					h.shield_t = 30.0
					h.hurt(30.0, P, {"src": "shot"})
				"shell":
					h.merge_st = {"shell": 200.0, "shell_max": 200.0, "form": {"glow": Color.RED}}
					h.hurt(30.0, P, {"src": "shot"})
					h.merge_st = {}  # (only the hit needs the shell: a bare dict would trip the merge's step)
				"heal":
					h.hp = 900000.0
					fx.healed(h, 30.0)
				"hurt":
					P.hurt(30.0, h, {"src": "shot"})
		for f in 24:
			await _frame()
		_take("dmgnum_3_kinds_" + String(sv[0]), lines, "One hit of every kind: " + ", ".join(sv[1]))
		for f in 60:
			await _frame()


## The trio-focus case: three attackers on one dummy for Trio.SECS s, the frame after your ability hit
## shot whole and cropped round the dummy.
func _trio(lines: Array) -> void:
	m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	fx = m.fx
	fx.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var s := Trio.setup(m)
	var dummy: Hunter = s["dummy"]
	fx.nums.clear()
	var most := 0
	var per: Array = []
	for f in int(Trio.SECS / DT):
		Trio.hit(s, f)
		await _frame()
		var c := Trio.overlap(fx, m.cam)
		per.append(c)
		most = maxi(most, c)
		if f == 138:
			_take("dmgnum_2_trio", lines, "Trio focus: you and two teammates on one dummy, 2.3 s in")
			var img := main.get_viewport().get_texture().get_image()
			var c2 := Vector2i(m.cam.unproject_position(dummy.pos + Vector3(0, 1.5, 0)))
			var r := Rect2i(c2 - Vector2i(240, 200), Vector2i(480, 360))
			r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img.get_region(r).save_png(dir.path_join("dmgnum_2_trio_crop.png"))
			lines.append("dmgnum_2_trio_crop.png: The dummy's numbers, cropped")
	print(
		(
			"DMGNUMSHOTS trio max overlap %d (limit %d), per-second max %s"
			% [most, Trio.MAX_OVERLAP, [per.slice(0, 60).max(), per.slice(60, 120).max(), per.slice(120, 180).max()]]
		)
	)
