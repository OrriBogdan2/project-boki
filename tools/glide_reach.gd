extends RefCounted
## --glide-reach: how far a glide carries over open void (no ground anywhere near), at the same height
## as the ground you left: a plain held glide, a feathered glide (tap off/on) and a dash into a glide.
## Used to size the glide gaps on authored maps (docs/MAPS.md). Prints "GREACH <kind> = <metres>".
const DT := Match.DT
var m: Match
var h: Hunter

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	h = m.hunters[0]
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(Vector3(-500, 50, -500)); o.out = true
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk: m.kins.erase(kk); kk.queue_free()
	h.kin = null; h.kin2 = null
	var w := m.world
	for i in w.w * w.h: w.kind[i] = World.T_VOID
	w._aref = PackedFloat32Array()
	for kind in ["hold", "feather", "dash"]:
		print("GREACH %s = %.1f m" % [kind, _try(kind)])
	main.get_tree().quit()

func _try(kind: String) -> float:
	var start := Vector3(20, 0.0, 108)
	h.out = false; h.downed = false; h.hp = h.max_hp
	h.teleport(start)
	h.grounded = false; h.last_gy = 0.0; h.glide_fuel = 1.0; h.gliding = true; h.air_t = 0.5
	h.dropping = false; h.lfloat = {}; h.pad = {}
	h.vel = Vector3(13.8 if kind == "dash" else 6.5, 1.0, 0)
	var t := 0.0
	while t < 40.0:
		h.inp["move"] = Vector2(1, 0)
		h.inp["glide"] = true
		if kind == "feather":
			h.inp["glide"] = fmod(t, 0.9) < 0.6
		if h._in_abyss() or h.out:
			break
		m.step(DT); t += DT
		if h.pos.y < h.abyss_kill_y() or h.out:
			break
	return h.pos.x - start.x
