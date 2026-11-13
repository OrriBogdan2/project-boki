class_name LastAlive
extends RefCounted
## The last hunter standing in a squad of two or more gets a small lift and a glow everyone can see.
## It is derived from who is up (Hunter.downed / out / extracted), so it needs no Net message and ends
## by itself the moment a teammate is revived or redeployed. A solo squad never gets it (the rule is
## about the loneliness, and solos run 20 players). The source game's exact last-alive numbers are not
## in our refs, so these are small picks.

const SPEED := 0.08          # +8% move speed (the Hunter "move_speed" buff)
const MEND_PER_S := 1.0      # hp/s of self-heal once REGEN_WAIT has passed without a hit
const BUFF_HOLD := 0.3       # s each tick's speed buff lasts (renewed every step, gone shortly after the end)
const NODE := "LastAura"
const SHELL_R := 0.95        # m, the soft body glow
const SHELL_A := 0.2         # peak opacity of that glow
const PULSE_HZ := 0.8

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
		var fresh := _glow(m, h, on)
		if on:
			_lift(h, dt)
			if fresh and h == m.player and m.hud:
				m.hud.toast_small("LAST ONE UP  ·  quicker, mending", SideColor.you())

static func _lift(h: Hunter, dt: float) -> void:
	h.add_buff("move_speed", SPEED, BUFF_HOLD)
	if h.regen_wait <= 0.0 and h.hp < h.max_hp:
		h.hp = minf(h.max_hp, h.hp + MEND_PER_S * dt)

## Shows or hides the glow; true when it was just raised.
static func _glow(m: Match, h: Hunter, on: bool) -> bool:
	var n := h.get_node_or_null(NODE) as Node3D
	if not on:
		if n:
			n.name = NODE + "Gone"
			n.queue_free()
		return false
	var fresh := n == null
	var col := SideColor.of(m, h)
	if fresh:
		n = Node3D.new()
		n.name = NODE
		var glow := Models.glow_mat(Color(col, SHELL_A))
		var shell := Models.part(n, Models.sphere(SHELL_R, 12), glow, Vector3(0, 0.95, 0), Vector3(0.8, 1.2, 0.8))
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring := Models.part(n, Models.flat_quad(2.2), Models.ring_mat(Color(col, 0.9), 0.07), Vector3(0, 0.06, 0))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(n)
	n.scale = Vector3.ONE * (1.0 + 0.06 * sin(m.time * TAU * PULSE_HZ))
	return fresh
