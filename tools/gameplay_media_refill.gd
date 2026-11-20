extends RefCounted
## Clip 17 of --gameplay-media (tools/gameplay_media.gd): the dash refill cue. Thief (one charge, 4.5 s back) on a
## cleared lane dashes, presses again on empty (DashSlot's no-charge tick), walks slowly while the charge comes back
## (the flash and one quiet ab_ready, heard on its own over footsteps), dashes again and waits for the second return:
## two returns inside ~10 s at the live recharge. MEDIA_REFILL lines give the scene second and frame of each return.

const MoveSpeedCheck := preload("res://tools/move_speed_check.gd")
const DASH_AT := [0.5, 1.1, 5.6]    # s: a dash, an empty press (the no-charge tick), a dash after the first return
const LANE := 14.0                  # m of flat lane to walk on
const FRAME := 2.0 / 60.0           # s per rendered frame (gameplay_media.gd FRAME)

static func run(g, secs: float) -> void:
	await g._start("thief", "zapple")
	var P: Hunter = g.m.player
	P.teleport(MoveSpeedCheck.flat_lane(g.m.world, P.pos, int(LANE) + 2))
	g._zoom(0.8)
	g.still_at = 1.0
	g._mark("dashes")
	var x0 := P.pos.x
	var was := [int(P.dashes)]
	await g._go(secs, func(t: float):
		var dash := false
		for at in DASH_AT:
			dash = dash or absf(t - float(at)) < FRAME * 0.5
		var mv := Vector2(1, 0)
		if t >= 1.6:
			mv.x = 0.35 if fmod(t, 6.0) < 3.0 else -0.35
		if P.pos.x > x0 + LANE:
			mv.x = minf(mv.x, 0.0)
		g._keys(P, mv, false, false, dash)
		if int(P.dashes) > int(was[0]):
			print("MEDIA_REFILL t=%.2f frame=%d charges=%d" % [t, g.frame, int(P.dashes)])
		was[0] = int(P.dashes),
		func(_t: float): return P.pos)
