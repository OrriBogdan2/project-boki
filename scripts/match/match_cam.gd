class_name MatchCam
extends RefCounted
## The match's view for this frame: the ride, the launch, you, or the death camera, each with its zoom, pitch and
## follow. It runs before the frame reads the cursor (Match._process), so the aim ray a shot leaves on is cut by the
## camera the frame is drawn with: while the view moves (a dash, a knock, the skyship) rounds go to the reticle, as
## in the source, not a frame's camera step behind it (--dash-aim-check, steady part). `alpha` is where the last
## frame drew the bodies, so the view follows what is on screen.

static func update(m: Match, delta: float, alpha: float) -> void:
	var cam: CamRig = m.cam
	var player: Hunter = m.player
	cam.follow_mode = String(Settings.get_v("cam_follow"))
	var sty := String(Settings.get_v("cam_style"))
	if sty != m.cam_style:
		m.cam_style = sty
		cam.use_style(sty)
	cam.lead_vel = Vector3.ZERO      # (movefeel) only a live glide leans the view (set below)
	if player and player.riding and player.rocket == null:
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
		if m.intro: m.intro.frame(delta)       # the squad intro takes the view, then hands it over
	elif player and (player.rocket != null or player.dropping):
		cam.skydive(player.render_pos(alpha), m.skydrop.drop_yaw(player), m.player_altitude(), delta)
	elif player and not player.out and not player.downed:
		cam.chase_to = 0.0
		cam.yaw_to = 0.0
		cam.zoom_to = cam.air_zoom(player, m.player_altitude())
		if m.train.has("_sizes"): cam.zoom_to = 0.5     # (--size-demo screenshots)
		if m.has_meta("zoom_hold"): cam.zoom_to = float(m.get_meta("zoom_hold"))     # (--arena-demo screenshots)
		cam.top_to = 0.0
		cam.lead_vel = m.cam_lead_vel()
		var peek := m.mate_look.focus(StepSmooth.view(player, alpha), alpha)
		cam.follow(peek, delta, m.mate_look.looking == null)
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
