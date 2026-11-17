extends "res://tools/hitbox_size_check.gd"
## --hurtbox-check: every Hunter's hurtbox (docs/HITBOX_SIZE.md) is its own data and follows the owner's
## height chart. Per Hunter: hit_r is the compressed size multiple of the standard, hit_h the chart height
## in metres, the body's collision radius is its own value, a point shot 5 cm inside the circle hits and
## 5 cm outside misses, and a shot hits up to the top of the body's band and misses above it. Never
## touches the save.

const WARDENS := preload("res://tools/warden_model_check.gd").WARDENS
const MEDIUM_HEIGHT := 1.732      # m, a medium hunter drawn (head top 1.546 x Hunter.VIS_SCALE 1.12)
const SIZE_PULL := 0.3            # how much of a height's distance from the medium counts toward the radius
const EDGE := 0.05                # m, the shot's miss or hit distance from the circle
const TOP_PAD := 0.9              # m over the head a shot still hits (Match.shot_band)

var home := Vector3.ZERO

## A hit shoves and stuns the hunter, so each shot starts from the same spot and a calm body.
func _fire(m: Match, shooter: Hunter, h: Hunter, side: float, rad := 0.1, up := 0.95) -> bool:
	h.teleport(home)
	h.vel = Vector3.ZERO
	h.stun_t = 0.0
	return super(m, shooter, h, side, rad, up)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for k in m.kins:      # a wild Boki's bites would count as hits
		k.queue_free()
	m.kins.clear()
	for b in m.breaks: b["dead"] = true
	var h: Hunter = m.hunters[0]
	var shooter: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o.team != h.team and shooter == null: shooter = o
	for o in m.hunters:
		if o != h and o != shooter: o.teleport(m.world.random_ground())
	_flatten(m, h)
	home = h.pos
	var std := float(Data.CLASSES["medium"]["hit_r"])
	for a in Arch.ids():
		var chart := float(WARDENS[a]["height"])
		h.reclass(Arch.weight(a), a)
		h.teleport(h.pos)
		h.vel = Vector3.ZERO
		shooter.teleport(h.pos + Vector3(0, 0, 5.0))
		var want_r := std * clampf(1.0 + SIZE_PULL * (chart - 1.0), BAND.x, BAND.y)
		ok(absf(h.r - want_r) < 0.0015, "%s: hit_r %.3f follows chart %.2f (wants %.3f)" % [a, h.r, chart, want_r])
		var hh := Arch.hit_h(a)
		ok(absf(hh - MEDIUM_HEIGHT * chart) < 0.01, "%s: hit_h %.2f = chart %.2f x medium" % [a, hh, chart])
		ok(h.body_r > 0.0 and absf(h.hull_r() - h.body_r) < 0.0001, "%s: body radius %.3f is its own" % [a, h.hull_r()])
		var edge := h.hit_radius()
		ok(_fire(m, shooter, h, edge - EDGE, 0.0), "%s: shot at radius %.3f - 5 cm hits" % [a, edge])
		ok(not _fire(m, shooter, h, edge + EDGE, 0.0), "%s: shot at radius %.3f + 5 cm misses" % [a, edge])
		var top := Arch.hit_h(a) + TOP_PAD
		ok(_fire(m, shooter, h, 0.0, 0.0, top - EDGE), "%s: shot %.2f m up hits" % [a, top - EDGE])
		ok(not _fire(m, shooter, h, 0.0, 0.0, top + EDGE), "%s: shot %.2f m up passes over" % [a, top + EDGE])
	print("HURTBOX CHECK DONE, failures: ", bad)
	main.get_tree().quit()
