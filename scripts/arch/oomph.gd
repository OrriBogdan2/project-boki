class_name Oomph
extends RefCounted
## Combat weight (the gameplay side of "oomph"): what a shot does to the shooter (a push
## back on heavy weapons; never a camera kick), what a hit does to the body it lands on (a flinch scaled by the hit, a
## short stagger on big hits, a hit-shake while it's frozen), and how visible a shot is (a glowing
## bolt with a halo and a tracer that stretches with speed). How hits look and sound beyond that
## (impact sparks, sound design) belongs to Juice; the numbers and these reactions live here, in
## separate functions, so the two never step on each other.
##
## Weapon data can tune it: "push" (the shooter
## is shoved back this many m/s), "tracer" (how long the streak reads, 1 = default).

const STAGGER_FRAC := 0.12     # a hit of at least this share of max health staggers
const STAGGER_T := 0.28        # ... for this long
const STAGGER_SLOW := 0.45     # ... slowed this much
const HEAVY_FLINCH := 2.6      # the flinch of a stagger, relative to a chip hit
static var legacy := false     # tooling (--legacy-shots): the old look, for before/after shots

# ------------------------------------------------------------------ shooting
## A shot (or swing) leaving: heavy weapons shove the shooter back a little (shotgun, sniper, bow).
static func on_fire(h: Hunter, _melee := false) -> void:
	if h == null or h.m == null:
		return
	if legacy:
		return
	var w: Dictionary = h.wpn
	var d := h.aim_dir()
	var push := float(w.get("push", 0.0))
	# the self push is feel for your own hands only: a bot (or a teammate reviving someone) never
	# drifts off its spot from its own shots
	if push > 0.0 and h.grounded and h.is_local() and h.ctrl == "local" and h.base_t <= 0.0:
		h.vel.x -= d.x * push
		h.vel.z -= d.y * push

# ------------------------------------------------------------------ being hit
## What a landed hit does to the body (called from Match.on_damage for every hit). Only the game that
## owns the body changes its state (stagger); the flinch and freeze are visual, everyone shows them.
static func react(m: Node, target: Ent, by: Ent, d: float, o: Dictionary) -> void:
	if target == null or d <= 0.0 or String(o.get("src", "")) in ["burn", "fall", "heat"] or o.get("tick", false):
		return
	var mh := maxf(1.0, target.max_hp)
	var frac := d / mh
	var big: bool = frac >= STAGGER_FRAC or o.get("payoff", false) or o.get("heavy", false) or float(o.get("stun", 0.0)) > 0.0
	# a visual hold scaled by the hit (the Feel tier sets it too; take the larger)
	target.freeze_t = maxf(target.freeze_t, clampf(0.03 + frac * 0.35, 0.03, 0.09))
	if target is Hunter:
		var h := target as Hunter
		h.hit_k = clampf(0.8 + frac * 9.0, 0.8, HEAVY_FLINCH) if not big else HEAVY_FLINCH
		h.hit_shake = maxf(h.hit_shake, clampf(frac * 1.6, 0.06, 0.22))
		if by and is_instance_valid(by):
			h.hit_from = Vector2(h.pos.x - by.pos.x, h.pos.z - by.pos.z).normalized()
		# (hunters and their Boki stagger you; monsters' hits never do, so PvE lethality is unchanged)
		var pvp: bool = by != null and is_instance_valid(by) and not (by is Mob) and String(o.get("src", "")) != "mob"
		if big and pvp and not h.remote and not h.downed and h.fortify_t <= 0.0:
			# a stagger: a short slow, so a big hit actually interrupts the dance (unstoppable
			# states, fortify_t, shrug it off)
			h.slow_k = maxf(h.slow_k, STAGGER_SLOW) if h.slow_t > 0.0 else STAGGER_SLOW
			h.slow_t = maxf(h.slow_t, STAGGER_T)
			h.stagger_t = STAGGER_T
	elif target is Mob:
		target.squash = maxf(target.squash, clampf(0.12 + frac * 0.6, 0.12, 0.35))
	elif target is Kin and target.model:
		var away := target.pos - by.pos if by and is_instance_valid(by) else Vector3.ZERO
		KinFlinch.hit(target.model, away, frac, (target as Kin).mass())

## Called at the end of Hunter.render. The hit shove and the shiver during a freeze are Juice's
## (Ent.flinch, the pop branch); this only runs the stagger clock and the anim flinch scale.
static func render_hit(h: Hunter, delta: float) -> void:
	h.hit_shake = maxf(0.0, h.hit_shake - delta * 1.4)
	h.stagger_t = maxf(0.0, h.stagger_t - delta)

# ------------------------------------------------------------------ how a shot looks
## The colour, size and halo of a shot as the local player sees it. What can hurt you stays the
## hottest thing on screen; your own shots are bright, solid bolts too (they used to be dim specks).
static func shot_look(m: Node, by: Ent, col: Color, size: float) -> Array:
	if legacy:
		var p0 = m.get("player")
		if p0 and by.team != p0.team: return [Color(col.lerp(Color("ff5a3a"), 0.35), 1.0), size * 2.6, 0.0]
		return [Color(col, 0.5), size * 1.7, 0.0]
	var vis_col := col
	var vis_size := size * 2.0
	var halo := 0.28
	var p = m.get("player")
	if p and by.team != p.team:
		vis_col = Color(col.lightened(0.1), 1.0)     # (the shooter's own colour: enemy reads by size and halo)
		vis_size *= 1.3
		halo = 0.4
	elif p:
		vis_col = Color(col.lightened(0.15), 0.95)
		vis_size *= 1.45
		if by != p:
			vis_col.a = 0.7          # teammates' shots: a touch softer than yours
			halo = 0.18
	return [vis_col, vis_size, halo]

## How long the streak behind a shot reads, from its speed (and the weapon's "tracer" scale).
static func tracer_len(r: float, speed: float, k := 1.0) -> float:
	if legacy:
		return r * 2.0 + speed * 0.025
	return r * 2.0 + minf(3.2, speed * 0.04 * k)
