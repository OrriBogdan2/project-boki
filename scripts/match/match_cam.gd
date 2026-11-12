class_name MatchCam
extends RefCounted
## The match's view for this frame: the ride, the launch, you, or the death camera, each with its zoom, pitch and
## follow. It runs once, after the fixed steps (Match._process), at the frame's own `alpha`: the view follows the
## body as this frame draws it and never leads its own frame (--camera-fast-check: a blink or a reel no longer
## shows one frame off centre). Steady aim (--dash-aim-check, steady part) is kept by steady_aim, which reads the
## cursor before each step against the camera moved to where the frame will draw you, so while the view moves
## (a dash, a knock) rounds go to the reticle as drawn, not a frame's camera step behind it.

## Before each fixed step: re-read the local cursor against the camera shifted by what follow() will do once the
## steps are done. `ahead` is the frame time not yet stepped (Match.acc): the body is predicted that far along its
## velocity, which is where render_pos puts it at the end of the frame. Only the play follow (not the ride, the
## launch or the death camera), and only when _gather_input read the cursor this frame.
static func steady_aim(m: Match, delta: float, ahead: float) -> void:
	var p: Hunter = m.player
	if p == null or p.out or p.downed or p.riding or m.opts.get("tut_test", false) or DropLaunch.locked(p):
		return
	var cam: CamRig = m.cam
	var stp := p.pos - p.prev
	var at := p.pos if stp.length() > 1.5 else p.pos + p.vel * ahead
	var shift := cam.follow_shift(at, delta)
	if shift.length_squared() < 1e-6:
		return
	cam.global_position += shift
	var mp := m.get_viewport().get_mouse_position()
	p.inp["aim"] = m._mouse_aim(mp)
	p.inp["aim_ray"] = cam.mouse_ray()
	p.inp["aim_y"] = m.aim_y
	cam.global_position -= shift

static func update(m: Match, delta: float, alpha: float) -> void:
	var cam: CamRig = m.cam
	var player: Hunter = m.player
	cam.follow_mode = String(Settings.get_v("cam_follow"))
	var sty := String(Settings.get_v("cam_style"))
	if sty != m.cam_style:
		m.cam_style = sty
		cam.use_style(sty)
	cam.lead_vel = Vector3.ZERO      # only a live glide leans the view (set below)
	if player and player.riding:
		# aboard the skyship: a low view from just behind and above it, looking ahead along its
		# course over the islands, like riding the bus in a battle royale
		var ps := m.ship_of(player)
		var sd: Vector3 = ps.get("dir", Vector3.FORWARD)
		cam.yaw_to = atan2(-sd.x, -sd.z)
		cam.chase_to = 1.0
		cam.top_to = 0.0
		cam.zoom_to = Match.RIDE_CAM_DIST / cam.dist
		if m.time < 0.5:
			# boarding: start already behind the ship rather than swinging through it
			cam.chase = 1.0
			cam.yaw = cam.yaw_to
			cam.zoom = cam.zoom_to
		# item 163: the whole ship in frame (hull, balloon, props) with the squad aboard (follow aims ~4 m under)
		var fp := m.ship_pos_of(ps) + sd * 3.0
		cam.follow(Vector3(fp.x, m.ship_pos_of(ps).y + 7.0, fp.z), delta, false)
	elif player and DropLaunch.locked(player):
		# the launch: chasing the squad down its heading, the ship receding overhead (item 163)
		var hd := Vector2(player.vel.x, player.vel.z)
		if hd.length() > 0.5:
			cam.yaw_to = atan2(-hd.x, -hd.y)
		cam.chase_to = 1.0
		cam.top_to = 0.0
		cam.zoom_to = Match.LAUNCH_CAM_DIST / cam.dist
		cam.follow(player.pos + Vector3(0, 4.0, 0), delta, false)
	elif player and not player.out and not player.downed:
		cam.chase_to = 0.0
		cam.yaw_to = 0.0
		if player.dropping:
			# the drop: looking down over your shoulder, pulled back while you're high up
			var gy := 0.0
			if not m.world.is_void(player.pos.x, player.pos.z):
				gy = m.world.ground_at(player.pos.x, player.pos.z)
			var hk := clampf((player.pos.y - gy) / Match.SHIP_Y, 0.0, 1.0)
			cam.zoom_to = lerpf(1.05, 1.7, hk)
			cam.top_to = clampf(hk * 0.7, 0.0, 0.6)
		else:
			cam.zoom_to = cam.air_zoom(player, m.player_altitude())
			if m.train.has("_sizes"): cam.zoom_to = 0.5     # (--size-demo screenshots)
			if m.has_meta("zoom_hold"): cam.zoom_to = float(m.get_meta("zoom_hold"))     # (--arena-demo screenshots)
			cam.top_to = 0.0
		cam.lead_vel = m.cam_lead_vel()
		cam.follow(player.render_pos(alpha), delta, not player.dropping)
	elif player and (player.downed or player.out):
		# death camera: frame you and whoever got you
		var foc := player.prev.lerp(player.pos, alpha)
		if player.pos.y < -2.0:
			foc = cam.focus
		var killer: Ent = player.last_hit_by
		if killer is Kin and killer.owner_h: killer = killer.owner_h
		if killer is Hunter and killer != player and not killer.out and killer.flat_dist(player) < 16.0:
			foc = foc.lerp(killer.pos, 0.5 if player.downed else 0.85)
		cam.zoom_to = 0.8
		# dead and waiting on your team: after a moment, watch a teammate who's still in it
		var mate := m.spectating()
		if mate:
			foc = mate.prev.lerp(mate.pos, alpha)
			cam.zoom_to = 1.0
		cam.follow(foc, delta, false)
	elif player:
		cam.follow(cam.focus, delta, false)
