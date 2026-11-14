class_name HunterCooldowns
extends RefCounted
## The hunter's timers that count down to zero every sim step. Spelled out rather than looped over
## by name: a reflective set()/get() per timer cost each hunter's step more than its physics.

## Counts every timer down by dt, stopping at zero.
static func tick(h: Hunter, dt: float) -> void:
	h.base_cd = maxf(0.0, h.base_cd - dt)
	h.weak_t = maxf(0.0, h.weak_t - dt)
	h.dash_buf = maxf(0.0, h.dash_buf - dt)
	h.hit_heat_t = maxf(0.0, h.hit_heat_t - dt)
	h.ex_cd = maxf(0.0, h.ex_cd - dt)
	h.reveal_t = maxf(0.0, h.reveal_t - dt)
	h.inv_t = maxf(0.0, h.inv_t - dt)
	h.fire_cd = maxf(0.0, h.fire_cd - dt)
	h.coyote = maxf(0.0, h.coyote - dt)
	h.jump_buf = maxf(0.0, h.jump_buf - dt)
	h.mantle_cd = maxf(0.0, h.mantle_cd - dt)
	h.grap_cd = maxf(0.0, h.grap_cd - dt)
	h.sig_cd = maxf(0.0, h.sig_cd - dt)
	h.cloak_t = maxf(0.0, h.cloak_t - dt)
	h.haste_t = maxf(0.0, h.haste_t - dt)
	h.fortify_t = maxf(0.0, h.fortify_t - dt)
	h.recoil = maxf(0.0, h.recoil - dt)
	h.muzzle_t = maxf(0.0, h.muzzle_t - dt)
	h.regen_wait = maxf(0.0, h.regen_wait - dt)
	h.land_t = maxf(0.0, h.land_t - dt)
	h.glide_cd = maxf(0.0, h.glide_cd - dt)
	h.bless_t = maxf(0.0, h.bless_t - dt)
	h.crit_t = maxf(0.0, h.crit_t - dt)
	h.sick_t = maxf(0.0, h.sick_t - dt)
	h.phase_t = maxf(0.0, h.phase_t - dt)
