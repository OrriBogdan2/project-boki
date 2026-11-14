class_name LastAlive
extends RefCounted
## The last hunter standing in a squad of two or more gets a small lift and a glow everyone can see.
## It is derived from who is up (Hunter.downed / out / extracted), so it needs no Net message and ends
## by itself the moment a teammate is revived or redeployed. A solo squad never gets it (the rule is
## about the loneliness, and solos run 20 players). The source game's exact last-alive numbers are not
## in our refs, so these are small picks.
## Its sounds (tools/gen_sfx_last_alive.py, content/sfx/last_alive.json) are yours alone: nobody else hears
## your last-one-up.

const SPEED := 0.08          # +8% move speed (the Hunter "move_speed" buff)
const MEND_PER_S := 1.0      # hp/s of self-heal while out of combat (InCombat)
const BUFF_HOLD := 0.3       # s each tick's speed buff lasts (renewed every step, gone shortly after the end)
const NODE := "LastAura"
const SHELL_R := 0.75        # m, the body-hugging rim (a capsule around the hunter)
const SHELL_A := 0.95        # peak opacity of the rim at the silhouette
const POOL_R := 1.3          # m, the lit pool and ring on the ground
const AURA: Shader = preload("res://shaders/last_aura.gdshader")
const PULSE_HZ := 0.8
const BED_KEY := "last_alive_bed"
const START_DB := -2.0     # the rising sting as it starts
const BED_DB := -6.0       # the low heartbeat bed, on the Music bus under the score
const END_DB := -2.0       # the release when a teammate is back up

static var heard := {}     # sound -> times it started for you, for --last-alive-check

## Is `h` the last one up on a squad that started with a teammate?
static func active(m: Match, h: Hunter) -> bool:
	if h.downed or h.out or h.extracted:
		return false
	var mates := 0
	for o in m.hunters:
		if o == h or o.team != h.team:
			continue
		if not (o.downed or o.out) or o.extracted:
			return false
		mates += 1
	return mates > 0

## Every step: the buffs on whoever has it, the glow on or off.
static func tick(m: Match, dt: float) -> void:
	for h in m.hunters:
		var on := active(m, h)
		var was := h.get_node_or_null(NODE) != null
		_glow(m, h, on)
		if on:
			_lift(h, dt)
		if h == m.player:
			_sound(m, h, on, was)

## Your own last-one-up: a rising sting and the toast as it starts, a low heartbeat bed on the Music bus
## while it lasts (so the score's combat ducking pulls it under a fight), and a release when it ends
## because a teammate is back up (not when you go down or a teammate leaves by a way out).
static func _sound(m: Match, h: Hunter, on: bool, was: bool) -> void:
	if on and not was:
		_cue(m, "last_alive_start", START_DB)
		if m.hud:
			m.hud.toast_small("LAST ONE UP  ·  quicker, mending", SideColor.YOU)
	if on:
		if not Sfx.loop_on(BED_KEY):
			heard[BED_KEY] = int(heard.get(BED_KEY, 0)) + 1
		Sfx.loop_hold(BED_KEY, BED_KEY, null, BED_DB, 1.0, "Music")
	elif was:
		Sfx.loop_stop(BED_KEY)
		if not (h.downed or h.out or h.extracted) and _mate_up(m, h):
			_cue(m, "last_alive_end", END_DB)

static func _mate_up(m: Match, h: Hunter) -> bool:
	for o in m.hunters:
		if o != h and o.team == h.team and not (o.downed or o.out or o.extracted):
			return true
	return false

static func _cue(m: Match, sname: String, vol: float) -> void:
	heard[sname] = int(heard.get(sname, 0)) + 1
	m.sfx(sname, null, vol)

static func _lift(h: Hunter, dt: float) -> void:
	h.add_buff("move_speed", SPEED, BUFF_HOLD)
	if not InCombat.is_in(h) and h.hp < h.max_hp:
		h.hp = minf(h.max_hp, h.hp + MEND_PER_S * dt)

## Shows or hides the glow.
static func _glow(m: Match, h: Hunter, on: bool) -> void:
	var n := h.get_node_or_null(NODE) as Node3D
	if not on:
		if n:
			n.name = NODE + "Gone"
			n.queue_free()
		return
	var col := SideColor.of(m, h)
	if n == null:
		n = Node3D.new()
		n.name = NODE
		var rim_mat := ShaderMaterial.new()
		rim_mat.shader = AURA
		rim_mat.set_shader_parameter("color", Color(col, SHELL_A))
		var shell := Models.part(n, Models.capsule(SHELL_R, 2.2), rim_mat, Vector3(0, 1.05, 0))
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pool_mat := Models.ring_mat(Color(col, 0.9), 0.08)
		var pool := Models.part(n, Models.flat_quad(POOL_R * 2.0), pool_mat, Vector3(0, 0.06, 0))
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(n)
	n.scale = Vector3.ONE * (1.0 + 0.06 * sin(m.time * TAU * PULSE_HZ))
