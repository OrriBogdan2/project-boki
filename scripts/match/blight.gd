class_name Blight
extends Mob
## The Blight (docs/TONE_AND_THREATS.md §1): the Wyrm's corruption, hunting by noise and light.
## A Mob with its own senses instead of a camp: it hears what BlightDir hears (gunfire, blasts,
## opened chests, dashing, running), sees short (shorter at night, further when you're lit up by a
## muzzle flash or a Warden's lamp), and never forgets where the noise was. It attacks every squad.
##   bl_skitter  fast, fragile, in packs later on. Hunts noise; gives up when it loses you.
##   bl_warden   a slow sentry sweeping a cone of light. Spotted for a moment, it shrieks: every
##               Blight nearby comes to the noise, and from mid-match on new Skitters claw out of the
##               ground round it. Early on the shriek is only a warning.
## Strength comes from BlightDir (lvl): weak in the first minutes and on the outer islands, full
## late, in the core and at night. Early ones are smart, not tanky: they die fast and hit soft.

const SKITTER_SENSE := 6.5        # how far a Skitter notices an unlit hunter (raid condition scales it)
const LIT_SENSE := 5.0            # extra reach on a hunter who just fired, or stands in a Warden's light
const GIVE_UP := 4.0              # seconds without sensing its target before a Skitter gives up
const LEASH := 20.0               # a chase never runs further than this from where it started
const CONE_LEN := 9.0             # a Warden's light
const CONE_HALF := 0.42           # half the cone's angle (about 24 degrees each side)
const SPOT_TIME := 0.75           # seconds in the light before a Warden shrieks (longer early on)
const SHRIEK_CD := 14.0

var dir: BlightDir = null
var lvl := 0.1                    # 0 weakest .. 1 full strength (up to BlightDir.LVL_MAX)
var post := Vector3.ZERO          # where it was placed or clawed out of the ground
var heard := Vector3.INF          # the last noise it's going to look at
var heard_t := 0.0
var lost_t := 0.0
var idle_t := 0.0
var chase_from := Vector3.ZERO
var sense_t := 0.0
# Warden
var cone_a := 0.0                 # which way the light points (radians, on the ground: atan2(x, z))
var sweep0 := 0.0
var sweep_amp := 1.15             # how far the light swings each side of where it faces (radians)
var spot := 0.0                   # 0..1: how close it is to shrieking
var shriek_cd := 0.0
var shriek_t := -9.0              # when it last shrieked (the light flares red for a moment)
var cone: MeshInstance3D = null
var cone_mat: ShaderMaterial = null
var cue_t := 0.0                  # its next sound while out of sight (BlightDir plays it)
var gone := false                 # burrowed away (despawned), not killed
var unseen := false               # out of the local player's sight: not drawn

func init_blight(match_node: Node, id: String, k: String, at: Vector3, level: float, d: BlightDir) -> void:
	init_mob(match_node, id, k, at, 1.0)
	dir = d
	post = at
	chase_from = at
	sweep0 = randf() * TAU
	cone_a = sweep0
	cd = randf_range(0.8, 1.6)
	cue_t = randf_range(0.5, 3.0)
	set_level(level, true)
	if mkind == "bl_warden":
		_build_cone()

func mass() -> float:
	return 4.0 if mkind == "bl_warden" else 0.8

## Health, damage and speed for a strength level. Health keeps its share when it changes.
func set_level(l: float, fresh := false) -> void:
	lvl = clampf(l, 0.0, BlightDir.LVL_MAX)
	var frac := 1.0 if fresh or max_hp <= 0.0 else hp / max_hp
	max_hp = maxf(1.0, round(float(md["hp"]) * BlightDir.hp_k(lvl)))
	hp = max_hp * frac
	dmg_mult = BlightDir.dmg_k(lvl)

func speed_k() -> float:
	return 0.82 + 0.18 * minf(lvl, 1.0) if mkind == "bl_skitter" else 1.0

# ------------------------------------------------------------------ senses
## Whether this body notices a hunter right now (not through walls; grass hides you unless you're lit).
func notices(h: Hunter, reach: float) -> bool:
	if not h.targetable() or absf(h.pos.y - pos.y) > 2.5:
		return false
	if m.lairs and not m.lairs.lair_of(h.pos).is_empty():
		return false        # sealed in a boss lair: the Blight stays out of it
	var d := flat_dist(h)
	var lit := h.reveal_t > 0.0 or h.muzzle_t > 0.0
	var r := reach * (0.55 if h.crouch and not lit else 1.0) + (LIT_SENSE if lit else 0.0)
	if d > r:
		return false
	if d > 2.2 and not lit and (m.world.in_bush(h.pos.x, h.pos.z) or m.in_smoke(h.pos)):
		return false
	return m.world.los(pos, h.pos, pos.y + 0.7) or d < 1.8

func _sense() -> Ent:
	var reach: float = SKITTER_SENSE * (0.85 + 0.15 * m.sight_k) * (1.0 + 0.25 * minf(lvl, 1.0))
	var best: Ent = null; var bd := 1e9
	for h in m.hunters:
		if notices(h, reach):
			var d := flat_dist(h)
			if d < bd: bd = d; best = h
	for k in m.kins:
		if k.is_wild() or k.state != "active" or k.dead:
			continue
		var d := flat_dist(k)
		if d < reach * 0.7 and d < bd:
			bd = d; best = k
	return best

func _still_has(t: Ent) -> bool:
	if t == null or not is_instance_valid(t) or t.dead or not t.hittable():
		return false
	if t is Hunter:
		var h: Hunter = t
		if not h.targetable() or h.extracted or h.out:
			return false
		if m.lairs and not m.lairs.lair_of(h.pos).is_empty():
			return false
	return true

func hurt(d: float, by: Ent, opts := {}) -> float:
	var was := st
	var dealt := super.hurt(d, by, opts)
	if dealt > 0.0 and not remote and not dead:
		if was == "idle" and st == "chase":
			chase_from = pos; lost_t = 0.0; heard = Vector3.INF
		# shot at: a Warden has found you whether or not you were in its light
		if mkind == "bl_warden" and tgt and shriek_cd <= 0.0 and (tgt is Hunter or tgt is Kin):
			shriek(tgt)
	return dealt

## A noise reaches it (BlightDir.noise): go and look, if nothing better to do.
func hear(at: Vector3, loud: float) -> void:
	if dead or remote:
		return
	if st == "idle" or (st == "chase" and tgt == null):
		heard = at + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		heard_t = 0.0
		idle_t = 0.0
		if mkind == "bl_warden":
			cone_a = atan2(at.x - pos.x, at.z - pos.z)

# ------------------------------------------------------------------ simulation
func sim(dt: float) -> void:
	prev = pos
	if dead:
		return
	tick_status(dt)
	if remote:
		st_t -= dt
		net_follow(dt)
		_net_telegraph()
		return
	cd -= dt
	st_t -= dt
	shriek_cd -= dt
	var spd: float = float(md["speed"]) * speed_k() * slow_mult(0.55)
	if root_t > 0.0 or stun_t > 0.0:
		spd = 0.0
		if stun_t > 0.0 and st == "windup":
			_cancel_tele(); st = "recover"; st_t = 0.4
	var wish := Vector2.ZERO
	match st:
		"idle", "chase":
			wish = _warden_think(dt, spd) if mkind == "bl_warden" else _skitter_think(dt, spd)
		"windup":
			if tgt and is_instance_valid(tgt) and md["attack"] in ["lunge", "spit"]:
				if st_t > float(md["windup"]) * 0.4:
					atk_dir = atk_dir.slerp(dir_to(tgt), dt * 4.0)
					if tele:
						m.fx.aim_telegraph(tele, pos, atk_dir)
			if tele:
				m.fx.telegraph_progress(tele, 1.0 - st_t / float(md["windup"]))
			if mkind == "bl_warden":
				cone_a = atan2(atk_dir.x, atk_dir.y)
			if st_t <= 0.0:
				_strike()
		"lunge":
			vel.x = atk_dir.x * 11.0; vel.z = atk_dir.y * 11.0
			for e in m.foes_of(team):
				if lunge_hit.has(e.nid): continue
				if flat_dist(e) < e.r + r + 0.3 and absf(e.pos.y - pos.y) < 1.2:
					lunge_hit[e.nid] = true
					e.hurt(float(md["dmg"]) * dmg_mult, self, {"kb": atk_dir * 3.0, "src": "mob", "tags": ["blight"]})
			if st_t <= 0.0:
				st = "recover"; st_t = 0.5
				vel.x *= 0.2; vel.z *= 0.2
		"recover":
			if st_t <= 0.0:
				st = "chase"
	if st != "lunge":
		var hv := Vector2(vel.x, vel.z)
		var k := 10.0 if hv.length() <= spd * 1.3 else 2.5
		hv += (wish - hv) * (1.0 - exp(-k * dt))
		var ahead := Vector2(pos.x, pos.z) + hv.normalized() * (r + 0.3)
		if grounded and hv.length() <= spd * 1.3 and (m.world.is_void(ahead.x, ahead.y) or (m.lairs and not m.lairs.lair_of(Vector3(ahead.x, pos.y, ahead.y)).is_empty())):
			hv = Vector2.ZERO
		vel.x = hv.x; vel.z = hv.y
	var pre_v := Vector2(vel.x, vel.z).length()
	if slide(dt) and m.time - kb_time < 0.6 and pre_v > 7.5 and mass() < 10.0:
		kb_time = -9.0
		stun_t = maxf(stun_t, 1.0)
		if st == "windup": _cancel_tele(); st = "recover"; st_t = 1.0
		m.on_wall_slam(self)
		hurt(8.0, last_hit_by, {"src": "wall"})
	body_vertical(dt)
	var look := atk_dir if st in ["windup", "lunge"] else Vector2(vel.x, vel.z)
	if mkind == "bl_warden" and st != "windup":
		look = Vector2(sin(cone_a), cos(cone_a))
	if look.length() > 0.2:
		face = lerp_angle(face, atan2(-look.x, -look.y), minf(1.0, dt * (10.0 if mkind == "bl_skitter" else 3.0)))

func _skitter_think(dt: float, spd: float) -> Vector2:
	var wish := Vector2.ZERO
	sense_t -= dt
	if st == "idle":
		if sense_t <= 0.0:
			sense_t = 0.2
			var t := _sense()
			if t:
				tgt = t; st = "chase"; lost_t = 0.0; chase_from = pos; heard = Vector3.INF
				m.sfx("v_skitter", pos, -10.0, randf_range(0.55, 0.7))
				return wish
		if heard != Vector3.INF:
			heard_t += dt
			if flat_dist(heard) < 1.0 or heard_t > 12.0:
				post = heard; heard = Vector3.INF
			else:
				wish = dir_to(heard) * spd
		else:
			idle_t += dt
			if wander == Vector3.INF or flat_dist(wander) < 0.4 or randf() < dt * 0.3:
				var a := randf() * TAU
				var q := post + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 2.5)
				if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
					wander = q
			if wander != Vector3.INF:
				wish = dir_to(wander) * spd * 0.35
		return wish
	# chase
	if not _still_has(tgt):
		tgt = null
	if tgt == null:
		st = "idle"; engaged = false
		return wish
	if sense_t <= 0.0:
		sense_t = 0.25
		var sensed := (tgt is Hunter and notices(tgt as Hunter, SKITTER_SENSE * 1.6)) or (not (tgt is Hunter) and flat_dist(tgt) < 9.0)
		lost_t = 0.0 if sensed else lost_t + 0.25
	if lost_t > GIVE_UP or flat_dist(tgt) > 16.0 or flat_dist(chase_from) > LEASH:
		# lost you: go and sniff round where you were last
		heard = tgt.pos; heard_t = 0.0
		tgt = null; st = "idle"; engaged = false
		return wish
	var d := flat_dist(tgt)
	if not engaged:
		engaged = _engaged_on(tgt) < MAX_ENGAGED + (1 if lvl > 0.7 else 0)
	var want: float = float(md["range"]) * 0.85
	if not engaged:
		var hold := 4.0
		var to_t := dir_to(tgt)
		var side := Vector2(-to_t.y, to_t.x) * (1.0 if int(nid.hash()) % 2 == 0 else -1.0)
		wish = (to_t * clampf(d - hold, -1.0, 1.0) + side * 0.6) * spd * 0.7
	elif d > want:
		wish = dir_to(tgt) * spd
	if engaged and d <= float(md["range"]) + tgt.r and cd <= 0.0 and m.world.los(pos, tgt.pos, pos.y + 0.6):
		_begin_attack()
	return wish

func _warden_think(dt: float, spd: float) -> Vector2:
	var wish := Vector2.ZERO
	sense_t -= dt
	if st == "idle":
		# patrol a little round its post, the light sweeping side to side
		if heard != Vector3.INF:
			heard_t += dt
			cone_a = lerp_angle(cone_a, atan2(heard.x - pos.x, heard.z - pos.z), minf(1.0, dt * 2.0))
			if heard_t > 6.0:
				sweep0 = cone_a; heard = Vector3.INF
		else:
			sweep0 += dt * 0.12
			cone_a = sweep0 + sin(m.time * 0.55 + float(nid.hash() % 13)) * sweep_amp
			if wander == Vector3.INF or flat_dist(wander) < 0.4 or randf() < dt * 0.08:
				var a := randf() * TAU
				var q := post + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 3.0)
				if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
					wander = q
			if wander != Vector3.INF:
				wish = dir_to(wander) * spd * 0.5
		if sense_t <= 0.0:
			sense_t = 0.1
			var seen := _in_light()
			if seen:
				spot += 0.1 / spot_time()
				if spot >= 1.0:
					shriek(seen)
					tgt = seen; st = "chase"; lost_t = 0.0
			else:
				spot = maxf(0.0, spot - 0.1 / 1.6)
		return wish
	# alerted: the light follows its target, bolts at range
	if not _still_has(tgt):
		tgt = null
	if tgt == null:
		st = "idle"; spot = 0.0
		return wish
	cone_a = lerp_angle(cone_a, atan2(tgt.pos.x - pos.x, tgt.pos.z - pos.z), minf(1.0, dt * 3.0))
	if sense_t <= 0.0:
		sense_t = 0.2
		var vis: bool = flat_dist(tgt) < CONE_LEN + 4.0 and m.world.los(pos, tgt.pos, pos.y + 1.6)
		lost_t = 0.0 if vis else lost_t + 0.2
		_light_up()
	if lost_t > 5.0 or flat_dist(tgt) > 15.0 or flat_dist(post) > 8.0:
		heard = tgt.pos; heard_t = 0.0
		tgt = null; st = "idle"; spot = 0.0
		return dir_to(post) * spd if flat_dist(post) > 2.0 else wish
	var d := flat_dist(tgt)
	if d < 4.0:
		wish = -dir_to(tgt) * spd       # it keeps its distance
	elif d > float(md["range"]) and flat_dist(post) < 6.0:
		wish = dir_to(tgt) * spd * 0.6
	if d <= float(md["range"]) + tgt.r and cd <= 0.0 and m.world.los(pos, tgt.pos, pos.y + 1.4):
		_begin_attack()
	return wish

func spot_time() -> float:
	# early on there's more time to get out of the light
	return SPOT_TIME * (1.6 - 0.6 * minf(lvl, 1.0))

func cone_len() -> float:
	return CONE_LEN * (1.0 + 0.15 * minf(lvl, 1.0))

## The hunter standing in the light, if any (crouching shortens the reach; grass hides you unless
## you're right under it). Everyone in the light is lit up for everyone to see.
func _in_light() -> Hunter:
	var best: Hunter = null; var bd := 1e9
	var cdir := Vector2(sin(cone_a), cos(cone_a))
	for h in m.hunters:
		if not h.targetable() or absf(h.pos.y - pos.y) > 3.0:
			continue
		var rel := Vector2(h.pos.x - pos.x, h.pos.z - pos.z)
		var d := rel.length()
		var reach := cone_len() * (0.65 if h.crouch else 1.0)
		if d > reach or d < 0.01:
			continue
		if rel.normalized().dot(cdir) < cos(CONE_HALF) and d > 1.6:
			continue
		if d > 2.5 and (m.world.in_bush(h.pos.x, h.pos.z) or m.in_smoke(h.pos)) and h.reveal_t <= 0.0:
			continue
		if m.lairs and not m.lairs.lair_of(h.pos).is_empty():
			continue
		if not m.world.los(pos, h.pos, pos.y + 1.6):
			continue
		h.reveal_t = maxf(h.reveal_t, 0.35)
		if d < bd: bd = d; best = h
	return best

func _light_up() -> void:
	_in_light()

## Spotted: a shriek that wakes the Blight nearby. Early it's only a warning; later new Skitters
## claw out of the ground round it (BlightDir.on_shriek).
func shriek(at_h: Ent) -> void:
	if shriek_cd > 0.0:
		return
	shriek_cd = SHRIEK_CD
	shriek_t = m.time
	spot = 1.0
	shriek_fx()
	if m.net_on:
		m.net_event(["blsh", nid])
	if dir:
		dir.on_shriek(self, at_h)

func shriek_fx() -> void:
	shriek_t = m.time
	m.sfx("v_warden", pos, 2.0, 1.75)
	m.sfx("blight_rumble", pos, -2.0)
	m.fx.ring(pos, 6.0, Color("ff5a2a"), 0.6)
	m.fx.ring(pos, 10.0, Color("ff8a4a"), 0.9)
	m.fx.burst(pos + Vector3(0, 2.0, 0), BlightModels.EMBER, 26, 5.0, 0.7, -2.0)
	m.on_blight_shriek(self)

func _begin_attack() -> void:
	if dir and tgt:
		var tm: int = tgt.team if tgt is Hunter else (tgt.owner_h.team if tgt is Kin and tgt.owner_h else -1)
		dmg_mult = BlightDir.dmg_k(dir.level_vs(self, tm))
	super._begin_attack()

func _strike() -> void:
	if mkind != "bl_warden":
		super._strike()
		return
	_cancel_tele()
	cd = float(md["cd"]) * randf_range(0.85, 1.15)
	st = "recover"; st_t = 0.6
	# an ember bolt from the lamp
	var o := pos + Vector3(atk_dir.x * 0.7, 2.0, atk_dir.y * 0.7)
	m.spawn_shot(self, o, atk_dir * 9.0, float(md["dmg"]) * dmg_mult, 10.0 / 9.0, 0.34, BlightModels.EMBER_HOT, {"mob": true, "kb": 2.0, "burn": 1.0 if lvl > 0.6 else 0.0})
	m.sfx("k_venom", pos, -6.0, 0.7)

## Burrows away quietly (BlightDir despawns idle Blight far from everyone).
func burrow() -> void:
	if dead:
		return
	gone = true
	dead = true
	hp = 0.0
	death_t = 1.0
	_cancel_tele()
	visible = false
	if m.net_on:
		m.net_event(["blgone", nid])

# ------------------------------------------------------------------ looks
func _build_cone() -> void:
	cone = MeshInstance3D.new()
	cone.name = "Cone"
	var am := ArrayMesh.new()
	var verts := PackedVector3Array(); var cols := PackedColorArray()
	var n := 14
	for i in n:
		var a0 := -CONE_HALF + 2.0 * CONE_HALF * float(i) / float(n)
		var a1 := -CONE_HALF + 2.0 * CONE_HALF * float(i + 1) / float(n)
		verts.append(Vector3(0, 0, 0)); cols.append(Color(1, 1, 1, 0.75))
		verts.append(Vector3(sin(a1), 0, cos(a1))); cols.append(Color(1, 1, 1, 0.0))
		verts.append(Vector3(sin(a0), 0, cos(a0))); cols.append(Color(1, 1, 1, 0.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cone.mesh = am
	var sh := Shader.new()
	sh.code = CONE_SHADER
	cone_mat = ShaderMaterial.new()
	cone_mat.shader = sh
	cone.material_override = cone_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position.y = 0.12
	add_child(cone)

const CONE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float strength = 0.5;
void fragment() {
	ALBEDO = col.rgb;
	ALPHA = COLOR.a * strength;
}
"""

func render(delta: float, alpha: float) -> void:
	super.render(delta, alpha)
	if gone:
		visible = false
		return
	if not dead and unseen:
		visible = false
	if dead or model == null:
		if cone: cone.visible = false
		return
	var body: Node3D = model.get_node("Body")
	var spd := Vector2(vel.x, vel.z).length()
	var moving := spd > 0.3
	var wind := 0.0
	if st == "windup":
		wind = 1.0 - st_t / float(md["windup"])
	if mkind == "bl_skitter":
		body.position.y = absf(sin(anim * 1.4)) * 0.04 * float(moving) - wind * 0.1
		for i in 4:
			for sx in [-1, 1]:
				var lg := body.get_node_or_null("Leg%d%d" % [i, sx]) as Node3D
				if lg == null: continue
				var ph := anim * 2.2 + (PI if (i % 2 == 0) == (sx > 0) else 0.0) + i * 0.3
				var mv := 1.0 if moving else 0.12
				lg.rotation.z = maxf(0.0, cos(ph)) * 0.4 * sx * mv - wind * 0.35 * sx
				lg.rotation.x = sin(ph) * 0.3 * mv
	else:
		for i in 6:
			var lg := body.get_node_or_null("Leg%d" % i) as Node3D
			if lg == null: continue
			var ph := anim * 0.8 + float(i) * PI / 3.0
			lg.rotation.z = sin(ph) * 0.12 * (1.0 if moving else 0.25)
		var hood := body.get_node_or_null("Hood") as Node3D
		if hood:
			hood.rotation.x = -wind * 0.35 + sin(m.time * 1.3) * 0.04 + (0.25 if m.time - shriek_t < 0.8 else 0.0)
			hood.rotation.y = lerp_angle(hood.rotation.y, 0.0, delta * 4.0)
	# the embers breathe; brighter as it winds up, flaring on a shriek
	if model.has_meta("ember"):
		var flare: float = 1.0 + wind * 1.4 + (1.6 if m.time - shriek_t < 0.6 else 0.0) + spot * 0.8
		for em in model.get_meta("ember"):
			(em as ShaderMaterial).set_shader_parameter("glow", float((em as ShaderMaterial).get_meta("glow0", 2.0)) * flare * (0.85 + 0.15 * sin(m.time * 3.0 + float(nid.hash() % 7))))
	if cone:
		cone.visible = true
		cone.rotation.y = cone_a
		var L := cone_len()
		cone.scale = Vector3(L, 1.0, L)
		var alert := st in ["chase", "windup", "recover"] and tgt != null
		var c := Color(1.0, 0.62, 0.25).lerp(Color(1.0, 0.18, 0.1), clampf(spot, 0.0, 1.0) if not alert else 1.0)
		cone_mat.set_shader_parameter("col", c)
		var night_k: float = 1.0 + (1.0 - m.sight_k) * 0.7
		cone_mat.set_shader_parameter("strength", (0.32 + spot * 0.25 + (0.25 if alert else 0.0)) * night_k * (0.9 + 0.1 * sin(m.time * 5.0)))
