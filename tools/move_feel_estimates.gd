extends RefCounted
## --move-feel-check's last three estimates (sv/FEEL_NOTES.md "Still estimates"): the overheated glider's
## burn, the heat spike's plunge and the Spring pad's launch, each through the game's own path. None has a
## source number (sv/DATA.md 4, 5 and 9 name them with no value; sv/briefs/physics.md lists SpikeSlamForceZ and
## the overheat penalty effects undecoded; the only pad use on camera, venator.md Mini Nuke f103, is not on disk
## to measure). So every row is [?] and pins ours: content/rules/hunter_move.json, where each is tagged.

const BURN_S := 4.0  # s of overheated glide to count the burn over (20-damage ticks)
const SHOT := 10.0  # a player's hit on the overheated glider

## key -> [op, target, unit, note], as move_feel_check's T.
const T := {
	"overheat_burn_s": ["~", [0.030, 0.036], "hp/s", "[?] health share burnt a second (hunter_move overheat_burn)"],
	"spike_fall_vy": ["~", [5.95, 6.05], "m/s", "[?] heat spike's plunge (hunter_move glide_spike.fall_vy)"],
	"pad_vy": ["~", [16.95, 17.05], "m/s", "[?] Spring pad launch up (hunter_move jump_pad.vy)"],
	"pad_apex_m": ["~", [9.0, 10.5], "m", "[?] pad apex at [game data] gravity 14.7"],
}


static func run(c) -> void:
	var h: Hunter = c.p_v
	# Overheated glide, height pinned so it never lands: the burn per second as a share of max health.
	c._glide_at(25.0)
	var y: float = h.pos.y
	h.hp = h.max_hp
	h.heat_burn = 0.0
	h.inp["jump"] = true
	for i in int(BURN_S / c.DT):
		h.inp["glide"] = true
		h.inp["move"] = Vector2.ZERO
		h.glide_fuel = 0.0
		c.m.step(c.DT)
		h.pos.y = y
	c.rec("overheat_burn_s", (h.max_hp - h.hp) / h.max_hp / BURN_S, T)
	# A player's shot on that overheated glider spikes it: the plunge it leaves at.
	c.ok(h.gliding, "the overheated glider is still open before the spike shot")
	h.hurt(SHOT, c.m.hunters[1])
	c.ok(h.shot_down and not h.gliding, "a shot on the overheated glider spikes it")
	c.rec("spike_fall_vy", -h.vel.y, T)
	c._clear_inp()
	# Spring pad from a standstill on flat ground: the launch speed and the apex above the pad.
	c._reset(c.flat)
	h.stun_t = 0.0
	h.shot_down = false
	var y0: float = h.pos.y
	UtilityUse.pad_launch(h)
	c.rec("pad_vy", h.vel.y, T)
	var top := y0
	for i in 240:
		c.m.step(c.DT)
		top = maxf(top, h.pos.y)
		if h.vel.y < 0.0:
			break
	c.rec("pad_apex_m", top - y0, T)
	h.hp = h.max_hp
