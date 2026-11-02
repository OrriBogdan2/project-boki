class_name DredgeKit
extends ArchKit
## Dredge (heavy). Gameplay follows the "initiator who reels you in" brief and the reference sheet
## (docs/heroes/dredge.md); names, art, sounds and text are ours.
##
## - Passive, Salvage: knocks and assists stack (+2.5% health each, 10 at most); being downed costs
##   one. Hits on a hunter's back deal 50% more. A knock heals.
## - LMB: the scattergun (the weapon's own firing): a tight fan of slugs that stop and hang at 6.3m; the
##   two cone-edge lines on the ground while firing, one aim line when idle; the body rocks back on each
##   shot. At dash rank 3 pellet hits trim the barge recharge.
## - RMB, Grapnel: a braided rope-hook that stops at the first foe or wall (on purpose: walls stop it),
##   then reels the foe in stunned; you are Grounded while you reel (chain ring at your feet), and only
##   the barge works. They land Grounded.
## - E, Anchor Drop: hop a body length forward, then a giant ghost anchor slams the cone in front: a long
##   stun. In the air you smash straight down, the anchor lands with you, a ring at the landing, and the
##   height adds damage. Just after it the barge turns badly.
## - Dash, Barge: a shoulder barge toward the cursor that shoves, with a burst where it sets off; further
##   in the air.

const ROPE_COL := Color("f0d070")
const SLUG_COL := Color("ffd9f2")
const SLUG_REST := Color("8a7aff")     # a slug hanging at its stop line
const ANCHOR_COL := Color("ffcf70")
const IDLE_T := 0.7                    # s after the last shot the spread cone folds back to one aim line
const SWING := 6.0                     # 1/s: how fast a reeled body turns onto its new heading (lower swings wider)
const CLIFF := 1.2                     # m: a rise a reeled body can't be dragged up (a cliff face; rocks are hauled over)

var pull := {}                  # hold: the reel {t (the foe), left}
var flying := false             # hold: the hook is in the air
var hook_sd := {}               # the hook's shot while it flies
var hauled := 0                 # (tests) times a reeled body was hauled over a rock
var scoop: Array = []           # wisps (downed hunters) the hook scooped up on its way, reeled in with the catch
var wind := 0.0                 # hold: the Anchor's wind-up left
var hop_dir := Vector2.ZERO     # the wind-up's forward hop
var dive := {}                  # hold: the air smash falling {h0, t}
var lock_until := -9.0          # the barge can't turn much until then (just after the Anchor)
var barge_t := 0.0              # the barge's trail is showing
var shot_seen := 0              # the last weapon volley the kit dressed
var shot_at := -9.0
var stunned: Array = []         # foes the Anchor stunned: {e, until} (the spiral over them)
var fx: LDFx
var grapples := 0               # (tests) foes reeled in
var anchors := 0
var quakes := 0
var backstabs := 0
var snags := 0                  # reels ended by a wall
var arrivals := 0
var stacks_lost := 0
var volleys := 0
var hops := 0
var last_quake_k := 0.0         # (tests) the height bonus of the last air smash
var _down_seen := false
var _stab_at := -9.0

func _setup() -> void:
	st["base_hp"] = h.max_hp
	fx = LDFx.of(m)
	LDSfx.ensure()

func res_text() -> String: return "%d" % int(res)
func res_frac() -> float: return clampf(res / res_max(), 0.0, 1.0)
func ready_label() -> String: return "SALVAGE" if res >= res_max() else ""
func rd() -> Dictionary: return res_def()

## Is this hunter a Dredge reeling someone in? (Hunter.do_dash: Grounded doesn't stop the barge then.)
static func reeling(hn: Hunter) -> bool:
	return hn.ak is DredgeKit and not (hn.ak as DredgeKit).pull.is_empty()

func _hand() -> Vector3:
	var d2 := h.aim_dir()
	var f := Vector3(d2.x, 0, d2.y)
	return h.pos + Vector3(0, 1.15, 0) + f * 0.45 - f.cross(Vector3.UP) * 0.25

# ------------------------------------------------------------------ passive: Salvage
func add_stack(n: int) -> void:
	var before := res
	res = clampf(res + n, 0.0, res_max())
	if res == before:
		return
	_apply_hp()
	if n > 0:
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "SALVAGE %d" % int(res), res_col(), res >= res_max())
		fx.wave(h.pos, 1.6, res_col(), 0.35)
		m.sfx("pay_salvage", h.pos, -4.0, 1.0)
		net_ring(h.pos, 1.5, res_col())
		if pull.is_empty() and wind <= 0.0 and dive.is_empty(): play("dr_flex")

func _apply_hp() -> void:
	var want := float(st.get("base_hp", h.max_hp)) * (1.0 + float(rd()["per_stack"]) * res)
	var delta := want - h.max_hp
	h.max_hp = want
	if delta > 0.0: h.hp += delta
	else: h.hp = minf(h.hp, h.max_hp)

func on_knock(t: Hunter, mine: bool) -> void:
	add_stack(1)
	if mine and is_instance_valid(t):
		h.heal(h.max_hp * float(rd()["heal_knock"]))
		m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)

func outgoing(t: Ent, dmg: float, _o: Dictionary) -> float:
	if t is Hunter and ArchKit.behind(t, h):
		if m.time - _stab_at > 1.2:
			_stab_at = m.time
			backstabs += 1
			m.fx.word(t.pos + Vector3(0, 2.2, 0), "BEHIND", res_col(), false)
		return dmg * (1.0 + float(rd()["back_k"]))
	return dmg

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) != "shot":
		return
	if rank("dash") >= 3 and h.dashes < h.max_dashes():
		h.dashes = minf(h.max_dashes(), h.dashes + float(dash_def()["cut"]) / maxf(0.5, h.dash_regen()))

func can_shoot() -> bool:
	return fire_ok() and fuse.is_empty() and pull.is_empty() and dive.is_empty()

func move_k() -> float:
	return 0.7 if wind > 0.0 else 1.0

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	fx.track()
	if h.downed and not _down_seen:
		_down_seen = true
		if res > 0.0:
			stacks_lost += 1
			add_stack(-1)
	elif not h.downed:
		_down_seen = false
	tell = "full" if res >= res_max() else ("half" if res >= 5.0 else "")
	self_pips(int(res_max()), int(res), res >= res_max(), dt)
	if wind > 0.0: _tick_wind(dt)
	if not dive.is_empty(): _tick_dive(dt)
	if flying: _tick_hook()
	if not pull.is_empty(): _tick_pull(dt)
	_tick_gun()
	_tick_looks(dt)
	net_pulse(dt, res >= res_max(), 1.8)

## A Boki merge ends the Anchor's wind-up, the air smash, the reel (the rope goes, no landing effect) and a
## hook in the air (it grabs nothing).
func _drop_holds() -> void:
	wind = 0.0
	dive = {}
	flying = false
	hook_sd = {}
	scoop = []
	if not pull.is_empty():
		_end_pull(false)

## The scattergun: each new volley rocks the body back, flashes the muzzle and dresses its slugs (pink
## streaks that hang as violet dots where they stop). While firing, the spread's two edge lines lie on the
## ground out to the slug range; idle, they fold into one aim line to the cursor (sheet gap 4).
func _tick_gun() -> void:
	if h.wid != "shotgun" or KinMerge.active(h):
		return
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		shot_at = m.time
		volleys += 1
		_dress_volley()
	if not pull.is_empty() or h.downed:
		return
	var w: Dictionary = h.wpn
	if m.time - shot_at < IDLE_T or bool(h.inp.get("fire", false)):
		AimKit.cone(h, "spread", {"len": float(w["range"]), "deg": float(w.get("fan_deg", 30.0)) + h.wbloom, "edges": true, "inner": 0.6, "col": Color("fff0f6"), "alpha": 0.8})
	else:
		AimKit.line(h, "spread_idle", {"col": Color("fff0f6"), "alpha": 0.7})

func _dress_volley() -> void:
	play("dr_shot")
	var d2 := h.aim_dir()
	var mz := h.pos + Vector3(d2.x, 0, d2.y) * 1.05 + Vector3(0, 1.0, 0)
	fx.orb(mz, Color("fff4e0"), Color.WHITE, 0.75, 0.07)          # a white-hot muzzle flash, one frame
	fx.sunburst(mz, 0.6, Color("ffd0a0"), Color.WHITE, 0.08, true)
	m.sfx("dr_shot", h.pos, -5.0 if h.is_local() else -8.0, 1.0)
	if not tells_visible():
		return
	var key := "%s_%d" % [h.nid, h.shot_n]
	var i: int = m.shots.size() - 1
	var seen := 0
	while i >= 0 and seen < 14:
		var sd: Dictionary = m.shots[i]
		i -= 1
		seen += 1
		if sd.get("by") != h or String((sd["x"] as Dictionary).get("pg", "")) != key:
			continue
		fx.ride(sd, "slug", SLUG_COL, Color.WHITE, 0.6, 0.12, func(at: Vector3, expired: bool):
			if expired: fx.dot(at, SLUG_REST, 0.18))

func _tick_looks(dt: float) -> void:
	if not tells_visible():
		return
	var id := h.get_instance_id()
	if not pull.is_empty():
		# Grounded while he reels: a chain ring at his feet
		fx.place("chain%d" % id, "chain", h.pos + Vector3(0, 0.08, 0), Color("f4f0e0"), Color("8a8070"), 0.95, m.time * 0.6)
	if barge_t > 0.0:
		barge_t -= dt
		var d2 := h.aim_dir()
		fx.orb(h.pos + Vector3(0, 0.9, 0) - Vector3(d2.x, 0, d2.y) * 0.5, Color("ffc860"), Color("fff0c0"), 0.7, 0.22)
	for s in stunned.duplicate():
		var f = s["e"]
		if not is_instance_valid(f) or (f as Ent).dead or m.time > float(s["until"]):
			stunned.erase(s); continue
		fx.place("spiral%d" % (f as Ent).get_instance_id(), "spiral", (f as Ent).pos + Vector3(0, 2.4, 0), Color("ffe0a0"), Color("8a6aff"), 0.45)

# ------------------------------------------------------------------ RMB: Grapnel
func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	if flying or not pull.is_empty() or wind > 0.0 or not dive.is_empty():
		h._ab_feedback("sec", "deny")
		return
	if not spend_rmb():
		return
	var rdf := rmb_def()
	flying = true
	scoop = []
	play("dr_throw")
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(rdf["speed"]), "range": float(rdf["range"]), "size": 0.24},
		"effects": [{"type": "damage", "amount": float(rdf["dmg"])}]})
	var n0: int = m.shots.size()
	run(stg, cx("rmb", "grapnel", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if pull.is_empty() and is_instance_valid(f) and not f.dead: _grab(f),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			flying = false
			hook_sd = {}
			if e == null and pull.is_empty():
				fx.orb(at, ROPE_COL, Color.WHITE, 0.6, 0.15)
				m.fx.word(at + Vector3(0, 1.2, 0), "SNAGGED" if why == "wall" else "MISS", Color("c0b0a0"), false)}))
	if m.shots.size() > n0:
		hook_sd = m.shots[-1]
		(hook_sd["x"] as Dictionary)["rocks"] = true      # the hook flies over rocks and props (cliff faces still stop it)
		var sn = hook_sd.get("node")
		if sn is Node3D and is_instance_valid(sn):
			(sn as Node3D).visible = false          # the claw and the rope are drawn by the kit
			hook_sd["node"] = null
	m.sfx("dr_throw", h.pos, -2.0, 1.0)

## The hook in flight: the braided rope from the throwing hand to the claw, drawn through rocks. It also
## catches an ally in its path (reeled in to safety) and scoops up any wisp (downed hunter) it passes.
func _tick_hook() -> void:
	if hook_sd.is_empty():
		return
	var p: Vector3 = hook_sd["pos"]
	var v: Vector2 = hook_sd["vel"]
	for o in m.hunters:
		if o == h or not is_instance_valid(o) or o.dead or o.out or absf(o.pos.y + 0.9 - p.y) > 1.6:
			continue
		if Vector2(o.pos.x - p.x, o.pos.z - p.z).length() > o.r + 0.55:
			continue
		if o.downed:
			if not scoop.has(o):
				scoop.append(o)
				m.fx.word(o.pos + Vector3(0, 1.6, 0), "SCOOPED", ROPE_COL, false)
		elif o.team == h.team and pull.is_empty():
			hook_sd["life"] = 0.0
			_grab(o, true)
			return
	if not tells_visible():
		return
	var id := h.get_instance_id()
	fx.rope("rope%d" % id, _hand(), p, ROPE_COL, 0.22)
	fx.place("claw%d" % id, "claw", p, Color("e0b040"), Color.WHITE, 1.0, atan2(-v.x, -v.y))

func _grab(f: Ent, ally := false) -> void:
	flying = false
	hook_sd = {}
	if KinMerge.transforming(h) or KinMerge.active(h):
		return
	var rdf := rmb_def()
	if f.mass() >= 6.0:
		m.fx.word(f.pos + Vector3(0, 2.4, 0), "TOO HEAVY", Color("c0b0a0"), false)
		return
	grapples += 1
	if rank("sec") >= 3 and not ally:
		cd["rmb"] = float(cd["rmb"]) * (1.0 - float(rdf["refund"]))
	var wisp: bool = f is Hunter and (f as Hunter).downed
	ally = ally or wisp           # a wisp caught head-on is reeled in like an ally: no stun, no Grounded
	pull = {"t": f, "left": float(rdf["pull_max"]), "v": Vector2.ZERO, "ally": ally, "wisp": wisp, "from": f.pos}
	KitStatus.apply(h, "gnd", float(rdf["pull_max"]))      # the caster is Grounded while he reels (sheet gap 5)
	st["self_gnd"] = true
	if not ally: f.stun_t = maxf(f.stun_t, 0.3)
	m.fx.word(f.pos + Vector3(0, 2.4, 0), "SCOOPED" if wisp else ("HOOKED" if not ally else "HOLD ON"), col_of(rdf), true)
	fx.orb(f.pos + Vector3(0, 1.0, 0), ROPE_COL, Color.WHITE, 1.1, 0.15)
	m.sfx("dr_grab", f.pos, -1.0, 1.0)
	m.sfx("dr_reel", h.pos, -5.0, 1.0)
	play("dr_reel")
	if f.remote:
		_end_pull(not ally)           # their body belongs to another game: the hit and Grounded still land

## The reel: the body is hauled toward wherever Dredge is now, with weight (it carries its sideways speed and
## eases into the new heading), so walking sideways while reeling swings it round you (the source's physics
## pull). It is dragged over rocks and props; a cliff face or a placed wall stops it; the abyss takes it.
func _tick_pull(dt: float) -> void:
	var f = pull["t"]
	if not is_instance_valid(f) or (f as Ent).dead or ((f is Hunter) and (f as Hunter).downed != bool(pull.get("wisp", false))) or h.stun_t > 0.0 or h.downed:
		_end_pull(false)
		return
	var fe := f as Ent
	pull["left"] = float(pull["left"]) - dt
	var rdf := rmb_def()
	var to := Vector2(h.pos.x - fe.pos.x, h.pos.z - fe.pos.z)
	var dist := to.length()
	var gap := float(rdf["gap"])
	if tells_visible():
		var id := h.get_instance_id()
		var b := fe.pos + Vector3(0, 0.95, 0)
		fx.rope("rope%d" % id, _hand(), b, ROPE_COL, 0.22)
		fx.place("claw%d" % id, "claw", b, Color("e0b040"), Color.WHITE, 1.0, atan2(to.x, to.y))
	if dist <= gap + 0.05:
		_end_pull(true)
		return
	if float(pull["left"]) <= 0.0:
		_end_pull(false)
		return
	if not pull.get("ally", false):
		fe.stun_t = maxf(fe.stun_t, 0.2)        # carried, stunned: they can't act or walk off the rope
	var want := to / dist * float(rdf["pull_speed"])
	var v: Vector2 = (pull["v"] as Vector2).lerp(want, 1.0 - exp(-SWING * dt))
	pull["v"] = v
	var left := minf(v.length() * dt, dist - gap)
	var dir := v.normalized() if v.length() > 0.01 else to / dist
	var moved := _drag(fe, dir, left)
	if moved < left - 0.001 and moved < 0.001 and v.length() > 1.0:
		snags += 1
		m.fx.word(fe.pos + Vector3(0, 2.2, 0), "WALLED", Color("c0b0a0"), false)
		_end_pull(false)
	for w in scoop.duplicate():
		if not is_instance_valid(w) or not (w as Hunter).downed or (w as Hunter).out:
			scoop.erase(w); continue
		var tw := Vector2(h.pos.x - w.pos.x, h.pos.z - w.pos.z)
		if tw.length() > gap: _drag(w, tw.normalized(), minf(float(rdf["pull_speed"]) * dt, tw.length() - gap))

## Moves a body `dist` along `dir` in small steps: over rocks and props (lifted onto them), never up a cliff
## face (a rise past CLIFF) or through a placed wall. Returns how far it went. Over the void it just goes on.
func _drag(fe: Ent, dir: Vector2, dist: float) -> float:
	var moved := 0.0
	var W = m.world
	while moved < dist - 0.001:
		var s := minf(0.2, dist - moved)
		var nx := fe.pos.x + dir.x * s; var nz := fe.pos.z + dir.y * s
		var gy: float = W.ground_at(nx, nz)
		var wall: bool = not W.dyn_walls.is_empty() and Verbs.wall_blocks(W.dyn_walls, nx, nz, fe.r, fe.pos.y) > 0.0
		if wall or (gy > World.VOID + 1.0 and gy - fe.pos.y > CLIFF):
			break
		if W.occupy(nx, nz, fe.r, fe.pos.y, false) != 0.0 and gy > World.VOID + 1.0:
			# a rock or a prop in the way: haul the body up and over it to the first clear spot beyond
			var k := s
			var clear := false
			while k < 5.0:
				k += 0.2
				var qx := fe.pos.x + dir.x * k; var qz := fe.pos.z + dir.y * k
				var qy: float = W.ground_at(qx, qz)
				if qy - fe.pos.y > CLIFF: break
				if W.occupy(qx, qz, fe.r, maxf(fe.pos.y, qy), false) == 0.0:
					fe.pos.x = qx; fe.pos.z = qz
					fe.pos.y = maxf(fe.pos.y, qy) + 0.5
					fe.vel.y = maxf(fe.vel.y, 5.0)      # a little toss as it clears the top
					clear = true
					break
			if not clear:
				break
			hauled += 1
			moved += k
			continue
		fe.pos.x = nx; fe.pos.z = nz
		moved += s
	return moved

func _end_pull(arrived: bool) -> void:
	var f = pull.get("t")
	var ally: bool = pull.get("ally", false)
	var wisp: bool = pull.get("wisp", false)
	pull = {}
	scoop = []
	if st.get("self_gnd", false):
		st["self_gnd"] = false
		h.set_meta("gnd_until", minf(float(h.get_meta("gnd_until", 0.0)), m.time))
	play("dr_pullend")
	if arrived and is_instance_valid(f) and not (f as Ent).dead:
		arrivals += 1
		var rdf := rmb_def()
		(f as Ent).vel.x = 0.0; (f as Ent).vel.z = 0.0
		if ally:
			if not wisp: m.fx.word((f as Ent).pos + Vector3(0, 2.4, 0), "SAVED", col_of(rdf), true)
			return
		KitStatus.apply(f, "gnd", float(rdf["ground_t"]))
		payoff_fx((f as Ent).pos, "HAULED", col_of(rdf), "pay_salvage", h.aim_dir(), f)

# ------------------------------------------------------------------ E: Anchor Drop
func cast_e() -> bool:
	if wind > 0.0 or not pull.is_empty() or not dive.is_empty():
		return false
	var ed := e_def()
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var height := h.pos.y - gy
	if not h.grounded and gy > World.VOID + 1.0 and height >= float(ed["air_min"]):
		_start_dive(height)
		return true
	wind = float(ed["windup"])
	hop_dir = h.aim_dir()
	hops += 1
	play("dr_anchor")
	m.sfx("dr_anchor_wind", h.pos, -3.0, 1.0)
	return true

func use_e() -> void:
	if not pull.is_empty():
		h._ab_feedback("k1", "deny")          # only the barge works while reeling
		return
	super.use_e()

## The wind-up: the fist hauled back, then a hop up and about a body height forward (0.14-0.32s), then the slam.
func _tick_wind(dt: float) -> void:
	var ed := e_def()
	var t0 := float(ed["windup"]) - wind
	wind -= dt
	if h.stun_t > 0.0 or h.downed:
		wind = 0.0
		return
	if t0 >= 0.14 and t0 < 0.32:
		var step := float(ed["hop"]) / 0.18 * dt
		var nx := h.pos.x + hop_dir.x * step; var nz := h.pos.z + hop_dir.y * step
		var gy: float = m.world.ground_at(nx, nz)
		if gy > World.VOID + 1.0 and m.world.occupy(nx, nz, h.r, h.pos.y, false) == 0.0:
			h.pos.x = nx; h.pos.z = nz           # never hops off into the abyss or into a wall
	if wind <= 0.0:
		wind = 0.0
		_anchor()

func _anchor() -> void:
	var ed := e_def()
	var dd := h.aim_dir()
	anchors += 1
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var over_void := gy <= World.VOID + 1.0
	var amt := float(ed["dmg"])
	var stun := float(ed["stun"]) + 0.1 * float(maxi(0, rank("kin") - 1))
	var stg := stage("e", {"delivery": {"type": "cone", "radius": float(ed["radius"]), "angle": float(ed["angle"])},
		"effects": [{"type": "damage", "amount": amt}, {"type": "stun", "duration": stun}]})
	run(stg, cx("e", "anchor_drop", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary): _slammed(f, stun)}))
	var at := h.pos + Vector3(dd.x, 0, dd.y) * 1.7
	fx.anchor_drop(ground(at), dd, ANCHOR_COL, 0.55, 0.62)
	fx.crescent(h.pos + Vector3(0, 0.25, 0), dd, float(ed["angle"]), float(ed["radius"]), Color("ffe0a0"), Color("d89040"), 0.25)
	AimKit.cone(h, "e_hit", {"len": float(ed["radius"]), "deg": float(ed["angle"]), "edges": true, "all": true, "dur": 0.2, "col": Color("ffffff"), "alpha": 0.7})
	m.later(0.08, func(): if is_instance_valid(h): m.fx.dust(at, 26); fx.wave(ground(at), 1.8, Color("fff4e0"), 0.35))
	m.sfx("dr_anchor", h.pos, -1.0, 1.0)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dd, 0.25)
	if not h.grounded and not over_void:
		h.gliding = false
		h.vel.y = -float(ed["dive"])          # a low air cast still drives you down (never over the abyss)
	st["dive_vy"] = h.vel.y               # (tests) what the Anchor left your fall speed at
	lock_until = m.time + float(dash_def()["lock_t"])
	net_ring(h.pos, float(ed["radius"]), col_of(ed))

func _slammed(f: Ent, stun: float) -> void:
	var ed := e_def()
	if not is_instance_valid(f) or f.dead: return
	f.vel.y = minf(f.vel.y, -16.0)
	KitStatus.apply(f, "gnd", float(ed["gnd_t"]))
	Feel.hitstop(m, h, f, 30.0, {"melee": true, "heavy": true})
	stunned.append({"e": f, "until": m.time + stun})
	m.fx.word(f.pos + Vector3(0, 2.3, 0), "ANCHORED", col_of(ed), false)

## In the air: smash straight down, the anchor falling with you; the landing ring shows where you'll hit.
func _start_dive(height: float) -> void:
	var ed := e_def()
	dive = {"h0": height, "y0": h.pos.y, "t": 0.0}
	h.gliding = false
	h.vel = Vector3(0, -float(ed["dive"]), 0)
	st["dive_vy"] = h.vel.y
	play("dr_dive")
	m.sfx("dr_dive", h.pos, -3.0, 1.0)

func _tick_dive(dt: float) -> void:
	var ed := e_def()
	dive["t"] = float(dive["t"]) + dt
	if h.stun_t > 0.0 or h.downed:
		dive = {}
		return
	h.vel.x = 0.0; h.vel.z = 0.0
	h.vel.y = minf(h.vel.y, -float(ed["dive"]))
	h.gliding = false
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	if gy <= World.VOID + 1.0:
		dive = {}                 # drifted over the abyss: no smash, no push
		return
	var land := Vector3(h.pos.x, gy, h.pos.z)
	AimKit.circle(h, "e_land", {"at": land, "r": float(ed["quake_r"]), "all": true, "fill": clampf(float(dive["t"]) / 0.4, 0.0, 1.0), "ticks": true, "col": ANCHOR_COL})
	if tells_visible():
		var d2 := h.aim_dir()
		fx.place("dive_anchor%d" % h.get_instance_id(), "anchor", h.pos + Vector3(d2.x, 0, d2.y) * 0.9 + Vector3(0, -0.4, 0), ANCHOR_COL, Color.WHITE, 0.55, atan2(-d2.x, -d2.y) + PI / 2.0)
	if h.grounded or h.pos.y - gy < 0.12 or float(dive["t"]) > 2.0:
		var fell := maxf(float(dive["h0"]), float(dive["y0"]) - gy)
		dive = {}
		_quake(land, fell)

## The air smash lands: a ring of anchor and dust round the landing, damage scaled by the height fallen.
func _quake(at: Vector3, fell: float) -> void:
	var ed := e_def()
	anchors += 1
	quakes += 1
	var mx := float(ed["air_max3"] if rank("kin") >= 3 else ed["air_max"])
	last_quake_k = 1.0 + mx * clampf(fell / float(ed["air_h"]), 0.0, 1.0)
	var stun := float(ed["stun"]) + 0.1 * float(maxi(0, rank("kin") - 1))
	var r := float(ed["quake_r"])
	var stg := stage("e", {"delivery": {"type": "burst", "radius": r},
		"effects": [{"type": "damage", "amount": float(ed["dmg"]) * last_quake_k}, {"type": "stun", "duration": stun}]})
	run(stg, cx("e", "anchor_drop", at, {"at_fixed": at, "no_floor": true, "on_foe": func(f: Ent, _c: Dictionary): _slammed(f, stun)}))
	var d2 := h.aim_dir()
	fx.anchor_drop(at + Vector3(d2.x, 0, d2.y) * 0.9, d2, ANCHOR_COL, 0.45, 0.62)
	fx.wave(at, r, ANCHOR_COL, 0.45, Color("fff0c0"))
	fx.wave(at, r * 0.6, Color.WHITE, 0.3)
	fx.sunburst(at, r * 0.9, Color("ffd890"), Color.WHITE, 0.35)
	fx.scorch(at, r * 0.6, 1.2, Color("ffb040"), Color("3a3020"))
	m.fx.dust(at, 34)
	play("dr_quake")
	m.sfx("dr_quake", at, 0.0, 1.0)
	Feel.shake(m, "t4", h, at)
	if h.is_local():
		if m.cam: m.cam.punch(0.05)
	lock_until = m.time + float(dash_def()["lock_t"])
	net_ring(at, r, col_of(ed))

# ------------------------------------------------------------------ dash: Barge
func on_dash(use_ex: bool) -> bool:
	if wind > 0.0 or not dive.is_empty():
		return true
	var dd := dash_def()
	var dir := h.aim_dir()
	if m.time < lock_until:
		# just after the Anchor the barge can't turn far from where you face
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		var lim := deg_to_rad(float(dd["lock_deg"]))
		var ang := fwd.angle_to(dir)
		if absf(ang) > lim:
			dir = fwd.rotated(clampf(ang, -lim, lim))
	_barge_burst(dir)
	if use_ex and not h.grounded:
		# the class air dash, further when airborne (sheet: Barge)
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)) * float(dd["air_k"]), float(h.cdat.get("ex_time", 0.21)) * 1.15, {"invuln": 0.08, "trail": "", "dir": dir}, true)
		play("dr_hop")
		m.sfx("dr_hop", h.pos, -3.0, 1.0)
		barge_t = 0.25
		return true
	if not spend_dash(false):
		return true
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	travel(float(dd["dist"]), float(dd["time"]), {"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "shove_dmg": float(dd["hit_dmg"]) * pk, "trail": "", "dir": dir})
	st["last_dash"] = "barge"
	play("dr_barge")
	barge_t = float(dd["time"])
	h.glide_cd = maxf(h.glide_cd, float(dd["time"]) + 0.35)
	m.sfx("dr_barge", h.pos, -2.0, 1.0)
	return true

## A red spiky burst where the barge sets off, and an ember scorch left there for a second (sheet 0188).
func _barge_burst(dir: Vector2) -> void:
	var at := h.pos
	fx.sunburst(at + Vector3(0, 0.9, 0), 1.9, Color("ff4a3a"), Color("ffd0a0"), 0.25, true)
	fx.scorch(ground(at), 0.9, 1.0, Color("ff8a3a"), Color("3a2018"))
	m.fx.burst(at + Vector3(0, 0.6, 0), Color("ff6a3a"), 12, 4.0, 0.3, 4.0, 1.0, Vector3(-dir.x, 0.3, -dir.y), 50.0)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null or not pull.is_empty() or wind > 0.0 or not dive.is_empty():
		return
	var tf := tgt as Ent
	# the Anchor on a foe that has just landed Grounded, or any foe up close
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["radius"]) + 1.0 and los:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and not flying and los and dist > 4.5 and dist < float(rmb_def()["range"]) - 1.0 and (tf.mass() < 6.0):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sec"] = true; return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 3.0 and dist < 6.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
