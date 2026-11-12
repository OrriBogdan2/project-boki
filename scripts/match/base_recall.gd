class_name BaseRecall
extends RefCounted
## B: base to a teammate (a recall to an ally, in our own look). A CHANNEL_S channel where you stand
## still and can't attack; moving, attacking, any damage, or the teammate going down or out cancels it, and
## no progress is kept. Everyone sees it coming: a ring filling round you and a circle filling under the
## teammate (Fx telegraph). A hit breaks it loudly (a red burst, "INTERRUPTED", its own sound). You arrive
## beside them weakened for WEAK_S: half damage, and the crowd control, healing and shields you apply are
## halved. Bots use the same start/cancel/tick, so the same rules. State lives on Hunter (base_t, base_to,
## base_cd, base_tele, weak_t) because the HUD, bots and anims read it. The player picks with BaseWheel.

const CHANNEL_S := 5.5        # s: the channel (5-6 s reads as a commitment)
const CD_S := 40.0            # s: the cooldown after a base lands
const LOCKOUT_S := 4.0        # s: the short cooldown after an interrupted channel
const WEAK_S := 3.0           # s: weakened after arriving
const TELE_R := 1.3           # m: the circle under the teammate (and how far beside them you land)
const MINT := Color("8fe3c8")
const HURT := Color("ff6a5a")


## Can `o` take `h` right now (a living teammate on the ground)? The wheel greys the ones that can't.
static func can_take(h: Hunter, o: Hunter) -> bool:
	return o != h and is_instance_valid(o) and o.team == h.team and not o.out and not o.downed \
			and not o.extracted and not o.dropping and not o.riding


## Every teammate still in the match (downed ones too: the wheel shows them greyed).
static func mates(m: Match, h: Hunter) -> Array:
	return m.hunters.filter(func(o: Hunter): return o != h and o.team == h.team and not o.out and not o.extracted)


## The first teammate who can take you (bots and checks; the player picks on the wheel).
static func target(m: Match, h: Hunter) -> Hunter:
	for o: Hunter in mates(m, h):
		if can_take(h, o):
			return o
	return null


## 0..1 through the channel, -1 when not basing (the anim state and the HUD rings).
static func progress(h: Hunter) -> float:
	return 1.0 - h.base_t / CHANNEL_S if h.base_t > 0.0 else -1.0


static func start(h: Hunter, to: Hunter) -> void:
	var m := h.m
	if to == null:
		if h.is_local() and m.hud: m.hud.toast_small("No teammate to base to", Color("a2a8bb"))
		h._ab_feedback("base", "deny")
		return
	if h.base_cd > 0.0 or h.downed or h.out or h.dropping or h.riding or not h.grounded or h.base_t > 0.0 \
			or not can_take(h, to):
		h._ab_feedback("base", "deny")
		return
	h.base_t = CHANNEL_S
	h.base_to = to
	h.base_tele = m.fx.telegraph_circle(to.pos, TELE_R, Color(MINT, 0.9))
	h._ab_feedback("base", "cast")
	m.sfx("portal", h.pos, -6.0, 1.2)
	if h.is_local() and m.hud: m.hud.toast_small("Basing  ·  hold still", MINT)


## Ends a channel early. `hurt`: a hit broke it (the loud cue); otherwise a quiet warn.
static func cancel(h: Hunter, why := "", hurt := false) -> void:
	if h.base_t <= 0.0:
		return
	var m := h.m
	_end(h)
	h.base_cd = LOCKOUT_S
	if hurt:
		m.fx.ring(h.pos, 1.8, HURT, 0.45)
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "INTERRUPTED", HURT, true)
		if h.base_to != null and is_instance_valid(h.base_to):
			m.fx.ring(h.base_to.pos, TELE_R, HURT, 0.45)
		m.sfx("scan_fail", h.pos, 0.0, 0.8)
	else:
		m.sfx("warn", h.pos, -10.0, 0.8)
	h.base_to = null
	if h.is_local() and m.hud and why != "": m.hud.toast_small("Base interrupted: " + why, Color("ff9a8a"))


static func tick(h: Hunter, dt: float) -> void:
	if h.base_t <= 0.0:
		return
	var o := h.base_to
	if o == null or not is_instance_valid(o) or not can_take(h, o) or h.downed or h.out or h.extracted:
		cancel(h, "your teammate can't take you")
		return
	var i := h.inp
	var mv: Vector2 = i.get("move", Vector2.ZERO)
	if mv.length() > 0.2 or i.get("fire", false) or i["dash"] or i["jump"] or i["sig"] or i["sec"] or i["ult"] \
			or i.get("gear1", false) or i.get("gear2", false) or i.get("throw", false):
		cancel(h, "you moved")
		return
	h.base_t -= dt
	if h.base_tele:
		h.base_tele.global_position = o.pos + Vector3(0, 0.07, 0)
		h.m.fx.telegraph_progress(h.base_tele, progress(h))
	if h.base_t <= 0.0:
		_arrive(h, o)


static func _arrive(h: Hunter, o: Hunter) -> void:
	var m := h.m
	_end(h)
	h.base_to = null
	var at := o.pos
	for k in 12:
		var a := TAU * k / 12.0
		var q := o.pos + Vector3(cos(a) * TELE_R, 0, sin(a) * TELE_R)
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z) \
				and absf(m.world.ground_at(q.x, q.z) - o.pos.y) < 0.6:
			at = Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
			break
	m.fx.ring(h.pos, 1.6, MINT, 0.4)
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.weak_t = WEAK_S
	h.base_cd = CD_S
	m.fx.ring(at, 1.8, MINT, 0.45)
	m.sfx("portal", at, -2.0, 1.5)
	if h.is_local() and m.hud: m.hud.toast_small("Weakened %ds" % int(WEAK_S), Color("ffb36a"))


## Clears the channel and its telegraph (the caller sets the cooldown).
static func _end(h: Hunter) -> void:
	h.base_t = 0.0
	if h.base_tele and is_instance_valid(h.base_tele):
		h.m.fx.end_telegraph(h.base_tele)
	h.base_tele = null
