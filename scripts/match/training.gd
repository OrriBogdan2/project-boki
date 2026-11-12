class_name Training
extends RefCounted
## The Training Grounds checklist and its practice tools, plus the --balloon-demo and --train-demo test
## hooks (moved out of match.gd). Match keeps the shared state (`train`, `train_t`, `duel_pad`).

## [id, what to do, the action whose key it uses ("" for none)]
const TRAIN := [["move", "Walk around", "up"], ["dash", "Dash", "dash"], ["glide", "Jump, then press Space again in the air (or Mouse 5) and hold to glide", "jump"],
	["shoot", "Shoot a target dummy", "fire"], ["ability", "Use your E ability", "signature"], ["ult", "Fuse with your Boki (%s: open from the start here)", "ultimate"],
	["secondary", "Use your right click", "secondary"], ["glove", "Use your glove (pick one up from the rack first)", "gear1"],
	["crouch", "Sneak: slower, steadier aim, harder to spot", "crouch"],
	["throw", "Sic your Boki at a dummy", "throw"], ["combo", "Land a combo: shoot a foe your Boki just stunned or rooted", "fire"], ["tonic", "Heal with a tonic (belt slot 1)", "util1"],
	["stagger", "Stagger a big dummy: hit it with an ability while it has a purple ring", "signature"],
	["smash", "Break a crate or pot", "fire"], ["weapon", "Take a found weapon off the ground", "interact"],
	["ledge", "Dash off an edge and float back up", ""]]

var m: Match = null

func setup(match_: Match) -> void:
	m = match_

func update(dt: float) -> void:
	if m.player == null:
		return
	if m.duel_pad != Vector3.INF and m.player.flat_dist(m.duel_pad) < 1.3 and not m.player.downed:
		if Input.is_action_just_pressed("interact") and not m.paused:
			Game.start_match(Match.duel_opts())
			return
	m.train_t += dt
	if m.player.downed and m.train_t > 2.0:
		m.revive_hunter(m.player, null)
	if m.opts.get("arena", false):
		return        # the Arena runs its own (scripts/match/arena.gd)
	var was_ult: bool = m.train.get("_ult_full", false)
	# everything recharges quickly here
	m.player.ult = minf(1.0, m.player.ult + dt / 6.0)
	m.player.sig_cd = maxf(0.0, m.player.sig_cd - dt * 2.0)
	for kk in [m.player.kin, m.player.kin2]:
		if kk: (kk as Kin).runner.tick(dt * 2.0)
	if m.player.tonics < 1: m.player.tonics = 3
	if not m.train.has("tonic") and m.player.hp >= m.player.max_hp and m.train_t > 1.0:
		m.player.hp = m.player.max_hp * 0.7     # a scratch, so the tonic has something to heal
	if m.player.inp["move"].length() > 0.1:
		m.train["_moved"] = float(m.train.get("_moved", 0.0)) + Vector2(m.player.pos.x - m.player.prev.x, m.player.pos.z - m.player.prev.z).length()
	var marks := {
		"move": float(m.train.get("_moved", 0.0)) > 4.0,
		"dash": m.player.roll_t > 0.0,
		"glide": m.player.gliding and not m.player.dropping,
		"shoot": m.player.dmg_done > 0.0,
		"ability": (m.player.ak != null and float(m.player.ak.cd["e"]) > 0.0) or (m.player.ak == null and m.player.kin != null and (m.player.kin as Kin).runner.has_slot("k1") and not (m.player.kin as Kin).runner.is_ready("k1")),
		"glove": float(m.player.gear_cd[0]) > 0.0,
		"combo": int(m.player.stats.get("combos", 0)) > 0,
		"crouch": m.player.crouch,
		"secondary": (m.player.ak != null and m.player.ak.last_variant != "") or (m.player.runner != null and m.player.runner.has_slot("utility") and not m.player.runner.is_ready("utility")),
		"ult": (m.player.ak != null and float(m.player.ak.cd["r"]) > 0.0) or (was_ult and m.player.ult < 0.5),
		"throw": m.player.kin != null and m.player.kin.st_throws > 0,
		"tonic": m.player.tonics < int(m.train.get("_tonics", m.player.tonics)),
		"ledge": m.player.grap.size() > 0 or m.player.mantle_k() > 0.0,
		"smash": m.train.get("_smash", false),
		"stagger": m.train.get("_stagger", false),
		"weapon": m.train.get("_weapon", false),
	}
	m.train["_ult_full"] = m.player.ult >= 0.99
	m.train["_tonics"] = m.player.tonics
	for k in marks:
		if marks[k] and not m.train.has(k):
			m.train[k] = true
			Sfx.play("unlock", null, -8.0)
			var left := rows().filter(func(t): return not m.train.has(t[0])).size()
			if m.hud: m.hud.toast(("Done: %s" % _train_label(k)) if left > 0 else "Training complete. Press Esc to head home whenever you like", Color("8ff0a0"))
			if left == 0:
				Save.d["tutorial"]["training"] = true
	# keep a few target dummies around you
	var alive := m.mobs.filter(func(x): return not x.dead)
	if alive.size() < 4 and int(m.train_t * 10.0) % 20 == 0:
		var at := m.world.random_ground(m.world.island_of(m.player.pos.x, m.player.pos.z))
		if Vector2(at.x - m.player.pos.x, at.z - m.player.pos.z).length() > 3.0:
			m.spawn_mob(["skitter", "spitter", "brute", "sentinel"][randi() % 4], at)

## The checklist for this hero: the secondary step only shows for heroes that have one.
func rows() -> Array:
	var rows := TRAIN.filter(func(t): return t[0] != "secondary" or (m.player != null and (m.player.ak != null or (m.player.runner != null and m.player.runner.has_slot("utility")))))
	return rows.map(func(t): return [t[0], _train_text(t), t[2]])

func _train_text(t: Array) -> String:
	return String(t[1]) % Settings.key_cap(String(t[2])) if String(t[1]).contains("%s") else String(t[1])

func _train_label(k: String) -> String:
	for t in TRAIN:
		if t[0] == k: return _train_text(t)
	return k

## Test hook (--balloon-demo=lip|glide|hop|self): hit markers. "lip" hangs a foe and a squadmate
## below an island's lip (balloons) and you shoot the foe's; "glide" holds them high over land
## (rings) and you shoot the low one through its ring; "hop" holds them mid-hop (no marker: the
## body is the target); "self" hangs you below the lip (your own faint balloon).
var _bdemo := {}
func balloon_demo() -> void:
	var mode := String(m.opts["balloon_demo"])
	var foe: Hunter = null; var mate: Hunter = null
	for h in m.hunters:
		if h == m.player: continue
		if h.team != m.player.team and foe == null: foe = h
		elif h.team == m.player.team and mate == null: mate = h
	if _bdemo.is_empty():
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		for h in m.hunters:
			if h != m.player: h.ctrl = "idle"
		m.cam.zoom_to = 0.8
		# an island edge with open air beyond it, and a flat stretch of ground behind it
		for k in 4000:
			var g := m.world.random_ground()
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var ok := not m.world.is_void(g.x, g.z)
				for dd in [1.6, 2.4, 3.2, 4.0]:
					for sd in [-2.0, 0.0, 2.0]:
						if not m.world.is_void(g.x + d.x * dd + d.y * sd, g.z + d.y * dd + d.x * sd): ok = false
				for dd in [0.0, -1.5, -3.0, -4.5]:
					for sd in [-3.0, 0.0, 3.0]:
						var x: float = g.x + d.x * dd + d.y * sd; var z: float = g.z + d.y * dd + d.x * sd
						if m.world.is_void(x, z) or m.world.is_block(x, z) or absf(m.world.ground_at(x, z) - g.y) > 0.05: ok = false
				if ok:
					var ex := g.x; var ez := g.z
					while not m.world.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
						ex += d.x * 0.25; ez += d.y * 0.25
					_bdemo = {"edge": Vector3(ex, g.y, ez), "dir": d}
					break
			if not _bdemo.is_empty(): break
		if _bdemo.is_empty():
			push_warning("balloon demo: no edge found"); _bdemo = {"edge": m.player.pos, "dir": Vector2(1, 0)}
		for h in m.hunters:
			if h != m.player and h != foe and h != mate: h.teleport(m.world.random_ground())
	var e: Vector3 = _bdemo["edge"]; var d: Vector2 = _bdemo["dir"]
	var side := Vector2(-d.y, d.x)
	var hold := func(h: Hunter, p: Vector3, glide: bool) -> void:
		if h == null: return
		h.teleport(p); h.vel = Vector3.ZERO; h.grounded = false; h.pad = {}
		h.gliding = glide; h.inp["glide"] = glide; h.glide_fuel = 1.0; h.glide_cd = 0.0
		h.hp = h.max_hp; h.stun_t = 0.0; h.knock_t = 0.0; h.shot_down = false
	var stand := func(h: Hunter, p: Vector3) -> void:
		if h == null: return
		h.teleport(p); h.vel = Vector3.ZERO; h.grounded = true
		h.hp = h.max_hp
	var on := func(back: float, sd: float) -> Vector3:
		var x := e.x - d.x * back + side.x * sd; var z := e.z - d.y * back + side.y * sd
		return Vector3(x, m.world.ground_at(x, z), z)
	var shoot := false
	match mode:
		"lip":
			stand.call(m.player, on.call(2.2, 0.0))
			hold.call(foe, Vector3(e.x + d.x * 1.3 + side.x * 1.4, e.y - 2.6, e.z + d.y * 1.3 + side.y * 1.4), true)
			hold.call(mate, Vector3(e.x + d.x * 1.5 - side.x * 2.0, e.y - 2.0, e.z + d.y * 1.5 - side.y * 2.0), true)
			shoot = true
		"glide":
			stand.call(m.player, on.call(4.0, 0.0))
			hold.call(foe, on.call(1.6, 1.6) + Vector3(0, 2.3, 0), true)
			hold.call(mate, on.call(2.6, -2.4) + Vector3(0, 4.0, 0), true)
			shoot = true
		"hop":
			stand.call(m.player, on.call(4.0, 0.0))
			hold.call(foe, on.call(1.6, 1.6) + Vector3(0, 0.9, 0), false)
			hold.call(mate, on.call(2.6, -2.4) + Vector3(0, 1.1, 0), false)
			shoot = true
		"self":
			hold.call(m.player, Vector3(e.x + d.x * 1.3, e.y - 2.4, e.z + d.y * 1.3), true)
			stand.call(mate, on.call(1.5, 1.5))
			stand.call(foe, on.call(3.5, -2.0))
	if shoot and foe:
		# fire level along the island at the foe's marker (or body, mid-hop)
		var fy: float = m.shot_stance_y(foe)
		m.player.inp["aim"] = Vector3(foe.pos.x, fy + 0.95, foe.pos.z)
		m.player.inp["aim_y"] = m.player.pos.y
		m.player.inp["fire"] = fmod(m.time, 0.9) < 0.12
		m.player.inp["move"] = Vector2.ZERO
		m.player.ammo = maxi(m.player.ammo, 3)

## Test hook (--m.train-demo): ride the sky m.train from a stop; "--m.train-demo=track" stands you on the
## track ahead of the engine instead, "--m.train-demo=view" watches it from a pier. "walk" and "hit"
## start with the m.train already under way: "walk" stands you on a car and walks, strafes, jumps and
## shoots on it; "hit" stands you on the rails a couple of seconds ahead of the engine.
func train_demo() -> void:
	var mode := String(m.opts["train_demo"]) if m.opts["train_demo"] is String else "ride"
	var st := m.skytrain
	if m.time < Match.DT * 1.5 and mode in ["walk", "hit"]:
		var lg: Dictionary = st.legs[0]
		m.time = st.dwell + float(lg["t"]) * 0.3
		m.opts["train_t0"] = m.time
		st.tick(0.0)
		st.old = st.cur.duplicate()
	var since: float = m.time - float(m.opts.get("train_t0", 0.0))
	if not m.opts.has("train_init") and mode != "watch":
		m.opts["train_init"] = true
		m.cam.zoom_to = 0.8
		if mode == "track" or mode == "hit":
			# a stretch of open track ahead, level with the islands (not down under a bridge)
			var ps := st.head_s + 20.0
			if mode == "hit":
				# just a couple of seconds down the line, wherever the rails are level with the islands
				# open air round the rails somewhere ahead, then the clock moved on until the engine is
				# a couple of seconds away from it
				ps = st.head_s + 14.0
				while ps < st.head_s + st.loop_len and not (m.world.train_at(ps).y > -0.01 and _open_air(m.world.train_at(ps), 4.0)):
					ps += 1.0
				var t1 := m.time
				while m.time < t1 + 120.0 and not (st.head_v > st.speed * 0.8 and fposmod(ps - st.head_s, st.loop_len) < 11.0):
					m.time += 0.05
					st._place(m.time)
				st.old = st.cur.duplicate()
			while mode == "track" and ps < st.head_s + 120.0 and not (m.world.train_at(ps).y > -0.01 and m.world.train_at(ps - 6.0).y > -0.01 and m.world.is_void(m.world.train_at(ps).x, m.world.train_at(ps).z)):
				ps += 1.0
			m.opts["train_pin"] = m.world.train_at(ps)
			m.player.teleport(m.opts["train_pin"])
		elif mode == "view":
			var t: Transform3D = st.cur[2]
			m.player.teleport(m.world.free_spot_near(t.origin - t.basis.x * 4.0, [], 1.0, 0.4, 6.0))
		else:
			var t2: Transform3D = st.cur[2]
			m.player.teleport(t2.origin + Vector3(0, 0.05, 0))
		m.player.grounded = true
	if (mode == "track" or mode == "hit") and not m.player.downed and not m.player.out:
		# stand on the rails (pinned there: the track has no floor of its own) and wait for the engine
		m.player.pos = m.opts["train_pin"]; m.player.vel = Vector3.ZERO; m.player.grounded = true
		m.player.inp["move"] = Vector2.ZERO
		m.player.lives = 1
	if mode == "walk" and not m.player.out:
		# forward along the car, across it, a hop, then shooting from the deck
		var k := 2
		var tk: Transform3D = st.cur[k]
		var f2 := Vector2(-tk.basis.z.x, -tk.basis.z.z).normalized()
		var r2 := Vector2(tk.basis.x.x, tk.basis.x.z).normalized()
		m.player.inp["move"] = Vector2.ZERO
		if since > 0.4 and since < 1.0: m.player.inp["move"] = f2
		elif since > 1.0 and since < 1.5: m.player.inp["move"] = r2
		elif since > 1.5 and since < 2.3: m.player.inp["move"] = -f2
		if absf(since - 2.4) < Match.DT * 0.5: m.player.inp["jump"] = true
		if since > 2.9:
			m.player.inp["aim"] = m.player.pos + Vector3(r2.x * 6.0, 0.9, r2.y * 6.0)
			m.player.inp["fire"] = fmod(since, 0.5) < 0.1
			m.player.ammo = maxi(m.player.ammo, 3)
	if int(m.time * 60.0) % 60 == 0:
		var t3: Transform3D = st.cur[2]
		print("TRAIN t=%.1f head=%.1f v=%.1f m.player=(%.1f,%.2f,%.1f) car2=(%.1f,%.2f,%.1f) grounded=%d hp=%.0f downed=%d out=%d" % [m.time, st.head_s, st.head_v, m.player.pos.x, m.player.pos.y, m.player.pos.z, t3.origin.x, t3.origin.y, t3.origin.z, int(m.player.grounded), m.player.hp, int(m.player.downed), int(m.player.out)])

## Nothing but air within `rad` of p (for the demos).
func _open_air(p: Vector3, rad: float) -> bool:
	for i in 12:
		var a := TAU * i / 12.0
		for d in [rad * 0.5, rad]:
			if not m.world.is_void(p.x + cos(a) * d, p.z + sin(a) * d):
				return false
	return true
