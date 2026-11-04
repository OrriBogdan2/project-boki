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
## - RMB, Grapnel: a braided rope-hook that pierces terrain and stops at the first body (a placed wall still
##   stops it), then reels it in stunned, over rocks and cliffs; you are Grounded while you reel (chain ring at
##   your feet), and only the barge works. Rank 3: a foe hit takes half the cooldown off.
## - E, Anchor Drop: hop a body length forward, then a giant ghost anchor slams the cone in front: a long
##   stun. In the air you smash straight down, the anchor lands with you, a ring at the landing, and the
##   height adds damage. Rank 3: double damage on a foe over the abyss and a longer stun. Just after it the
##   barge turns badly.
## - Dash, Barge: a monster's low lunge toward the cursor, clawing the ground and hauling himself along, that
##   shoves (no damage); a pounce in the air, further. Rank 3: it resets the gun's bloom.
## - X, Brass Broadside (level 6): a 1.1s charge at a slow walk behind a growing fan, then two waves of slugs with
##   Anti-Heal (DredgeBlast).

const ROPE_COL := Color("f0d070")
const BRASS := Color("e0a040")
const BRASS_HOT := Color("fff0b0")
const IRON := Color("3a3f48")
const SLUG_COL := Color("ff4fa8")      # a hot pink streak in flight
const SLUG_CORE := Color("ffd0ec")
const SLUG_REST := Color("7a4aff")     # a slug hanging at its stop line: solid violet, dark core
const ANCHOR_COL := LDFx.ANCHOR_RIM    # seafoam: the anchor's rim, its ring and its stun
const STOP_CARRY := 3.0                # m/s at most kept out of a barge
const HAUL_T := 0.26                   # s per hand-over-hand haul (dr_reel); the rope snaps taut on each
const DIVE_ANCHOR_UP := 3.4            # m from the anchor's base to its ring: the ring rides at his feet
const IDLE_T := 0.7                    # s after the last shot the spread cone folds back to one aim line
const SWING := 6.0                     # 1/s: how fast a reeled body turns onto its new heading (lower swings wider)
# m: a rise past which a reeled body is lifted onto the ground ahead instead of walking up
const CLIFF := 1.2

var pull := {}                  # hold: the reel {t (the foe), left}
var hook_hold: CastHold         # throw to the end of the reel or the miss: height held, a slow walk in flight
var flying := false             # hold: the hook is in the air
var hook_sd := {}               # the hook's shot while it flies
var hauled := 0                 # (tests) times a reeled body was hauled over a rock
var scoop: Array = []           # wisps (downed hunters) the hook scooped up on its way, reeled in with the catch
var wind := 0.0                 # hold: the Anchor's wind-up left
var slam_dir := Vector2.ZERO    # where the slam lands, locked at the press (the telegraph is that exact cone)
var dive := {}                  # hold: the air smash falling {h0, t}
var lock_until := -9.0          # the barge can't turn much until then (just after the Anchor)
var barge_t := 0.0              # the barge's trail is showing
var trail_t := 0.0              # the next barge after-image
var stop_t := 0.0               # the barge under way; when it ends he stops, keeping almost none of its speed
var next_barge := -9.0          # the short gap between barges in a run
var dash_held := false          # Shift pressed in the slam or the Broadside, waiting for its end
var shot_seen := 0              # the last weapon volley the kit dressed
var shot_at := -9.0
var stunned: Array = []         # foes the Anchor stunned: {e, until} (the spiral over them)
var fx: LDFx
var broadside: DredgeBlast      # X, Brass Broadside (its charge and waves are a hold: broadside.blast)
var grapples := 0               # (tests) foes reeled in
var anchors := 0
var abyss_dunks := 0           # (tests) foes the rank-3 Anchor hit over the abyss
var quakes := 0
var backstabs := 0
var snags := 0                  # reels ended by a wall
var arrivals := 0
var stacks_lost := 0
var volleys := 0
var last_quake_k := 0.0         # (tests) the height bonus of the last air smash
var winch_a := 0.0              # the 3D model's winch drum turn (rad)
var pool_k := 0.0               # the 3D model's tar pool at his feet (0 gone, 1 spread)
var claw_k := 0.0               # the 3D model's grab-claw: 1 spread for the throw, -1 clenched on the rope, 0 rest
var _down_seen := false
var _stab_at := -9.0

func _setup() -> void:
	st["base_hp"] = h.max_hp
	fx = LDFx.of(m)
	LDSfx.ensure()
	broadside = DredgeBlast.new(self)

func res_text() -> String: return "%d" % int(res)
func res_frac() -> float: return clampf(res / res_max(), 0.0, 1.0)
func ready_label() -> String: return "SALVAGE" if res >= res_max() else ""
func rd() -> Dictionary: return res_def()

## Is this hunter a Dredge reeling someone in? (Hunter.do_dash: Grounded doesn't stop the barge then.)
static func reeling(hn: Hunter) -> bool:
	return hn.ak is DredgeKit and not (hn.ak as DredgeKit).pull.is_empty()

func _hand() -> Vector3:
	# the 3D model throws from its grab-claw (anchor_claw, between the finger tips)
	var claw := WardenGlb.anchor(h.model, "anchor_claw") if h.model else null
	if claw and claw.is_inside_tree():
		return claw.global_position
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

func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if String(o.get("ab", "")) == "ult":
		return dmg               # the Broadside takes no back bonus (it keeps ult into merge under a one-shot)
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

## A third barge charge: he chains several short, fast shoves in a row.
func extra_dashes() -> float: return 1.0

func can_shoot() -> bool:
	return fire_ok() and fuse.is_empty() and pull.is_empty() and dive.is_empty() and not broadside.running()

func move_k() -> float:
	if broadside.running():
		return broadside.move_k()           # a slow walk through the charge and the waves
	if flying and hook_hold != null:
		return hook_hold.slow_k           # a slow walk while the hook flies out
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
	tell = ""
	if res >= res_max():
		tell = "full"
	elif res >= 5.0:
		tell = "half"
	self_pips(int(res_max()), int(res), res >= res_max(), dt)
	if stop_t > 0.0: _tick_stop(dt)
	if wind > 0.0: _tick_wind(dt)
	if not dive.is_empty(): _tick_dive(dt)
	if flying: _tick_hook()
	if not pull.is_empty(): _tick_pull(dt)
	_tick_hook_hold()
	broadside.tick(dt)
	_tick_held_dash()
	_tick_gun()
	_tick_looks(dt)
	_tick_model(dt)
	KMovesPair.air_moves(self, "dr_jump", "dr_land")
	net_pulse(dt, res >= res_max(), 1.8)

## A Boki merge ends the Anchor's wind-up, the air smash, the reel (the rope goes, no landing effect) and a
## hook in the air (it grabs nothing).
func _drop_holds() -> void:
	wind = 0.0
	dash_held = false
	AimKit.hide(h, "e_tell")
	dive = {}
	flying = false
	hook_sd = {}
	scoop = []
	hook_hold = null
	if not pull.is_empty():
		_end_pull(false)
	broadside.drop()

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
		AimKit.cone(
			h, "spread",
			{
				"len": float(w["range"]), "deg": float(w.get("fan_deg", 30.0)) + h.wbloom, "edges": true, "inner": 0.6,
				"col": Color("fff0f6"), "alpha": 0.8
			}
		)
	else:
		AimKit.line(h, "spread_idle", {"col": Color("fff0f6"), "alpha": 0.7})

func _dress_volley() -> void:
	play("dr_shot")
	var d2 := h.aim_dir()
	var mz := h.pos + Vector3(d2.x, 0, d2.y) * 1.05 + Vector3(0, 1.0, 0)
	fx.orb(mz, BRASS, BRASS_HOT, 0.75, 0.07)          # a brass muzzle flash, one frame
	fx.sunburst(mz, 0.6, Color("ff8a3a"), BRASS_HOT, 0.08, true)
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
		fx.ride(sd, "slug", SLUG_COL, SLUG_CORE, 0.9, 0.2, func(at: Vector3, expired: bool):
			if expired: fx.dot(at, SLUG_REST, 0.26))

func _tick_looks(dt: float) -> void:
	if not tells_visible():
		return
	var id := h.get_instance_id()
	if not pull.is_empty():
		# Grounded while he reels: a chain ring at his feet
		fx.place("chain%d" % id, "chain", h.pos + Vector3(0, 0.08, 0), BRASS, IRON, 0.95, m.time * 0.6)
	if barge_t > 0.0:
		barge_t -= dt
		_barge_trail(dt)
	for s in stunned.duplicate():
		var f = s["e"]
		if not is_instance_valid(f) or (f as Ent).dead or m.time > float(s["until"]):
			stunned.erase(s)
			continue
		fx.place(
			"spiral%d" % (f as Ent).get_instance_id(), "spiral", (f as Ent).pos + Vector3(0, 2.4, 0), ANCHOR_COL,
			Color("1a5a6a"), 0.6
		)

## Dredge's 3D model (WardenGlb.EXTRA; nothing on the procedural one): the winch drum pays the rope out while the
## hook flies and winds it in while he reels; the rope and the cargo hook hanging from the drum are gone while the
## kit draws them out on the throw; the grab-claw spreads for the throw and clenches on the rope while he reels.
func _tick_model(dt: float) -> void:
	var sk := WardenGlb.extra_skeleton(h.model)
	if sk == null:
		return
	var out := flying or not pull.is_empty()
	var spin := 0.0
	var want := 0.0
	if flying:
		spin = -16.0
		want = 1.0
	elif not pull.is_empty():
		spin = 10.0
		want = -1.0
	elif anim_id == "dr_throw":
		want = 1.0
	winch_a += dt * spin
	claw_k = move_toward(claw_k, want, dt * 9.0)
	WardenGlb.pose_extra(h.model, "winch", Quaternion(Vector3.RIGHT, wrapf(winch_a, -PI, PI)))
	WardenGlb.pose_extra(h.model, "rope1", Quaternion.IDENTITY, Vector3.ONE * (0.001 if out else 1.0))
	# the tar pool spreads under him while he stands, and is gone the moment he moves or leaves the ground
	var still := h.grounded and Vector2(h.vel.x, h.vel.z).length() < 0.6
	if still:
		pool_k = move_toward(pool_k, 1.0, dt * 0.5)
	else:
		pool_k = move_toward(pool_k, 0.0, dt * 6.0)
	var spread := maxf(pool_k, 0.001)
	WardenGlb.pose_extra(h.model, "pool", Quaternion.IDENTITY, Vector3(spread, 1.0 if pool_k > 0.01 else 0.001, spread))
	# each finger turns out from the claw's middle (spread) or in toward it (clench), about its knuckle
	var mid := Vector3.ZERO
	var heads: Array = []
	for i in [1, 2, 3]:
		var bi := WardenSkeleton.find(sk, "claw%d.L" % i)
		if bi < 0:
			return
		heads.append(sk.get_bone_global_rest(bi))
		mid += (heads[-1] as Transform3D).origin / 3.0
	for i in 3:
		var hx: Transform3D = heads[i]
		var along := hx.basis.y.normalized()
		var away := hx.origin - mid
		away = (away - along * away.dot(along)).normalized()
		var axis := along.cross(away).normalized()
		if axis.length() < 0.5:
			continue
		WardenGlb.pose_extra(h.model, "claw%d.L" % (i + 1), Quaternion(axis, 0.5 * claw_k))
		WardenGlb.pose_extra(h.model, "claw%d_tip.L" % (i + 1), Quaternion(axis, 0.35 * minf(claw_k, 0.0)))

# ------------------------------------------------------------------ RMB: Grapnel
func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	if flying or not pull.is_empty() or wind > 0.0 or not dive.is_empty() or broadside.running():
		h._ab_feedback("sec", "deny")
		return
	if not spend_rmb():
		return
	var rdf := rmb_def()
	flying = true
	scoop = []
	hook_hold = CastHold.hover_slow(h, float(rdf["fly_slow"]))
	play("dr_throw")
	var hook := {"type": "projectile", "speed": float(rdf["speed"]), "range": float(rdf["range"]), "size": 0.24}
	var stg := stage("rmb", {"delivery": hook,
		"effects": [{"type": "damage", "amount": float(rdf["dmg"])}]})
	var n0: int = m.shots.size()
	run(stg, cx("rmb", "grapnel", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if pull.is_empty() and is_instance_valid(f) and not f.dead: _grab(f),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			flying = false
			hook_sd = {}
			if pull.is_empty():
				hook_hold = null          # a miss: gravity is back the moment it ends
			if e == null and pull.is_empty():
				fx.orb(at, ROPE_COL, BRASS_HOT, 0.6, 0.15)
				m.fx.word(at + Vector3(0, 1.2, 0), "SNAGGED" if why == "wall" else "MISS", Color("c0b0a0"), false)}))
	if m.shots.size() > n0:
		hook_sd = m.shots[-1]
		# the hook pierces terrain: rocks, props and cliff faces
		(hook_sd["x"] as Dictionary)["pierce_terrain"] = true
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
	fx.rope("rope%d" % id, _hand(), p, ROPE_COL)
	fx.place("claw%d" % id, "claw", p, BRASS, BRASS_HOT, 1.5, atan2(-v.x, -v.y))

func _grab(f: Ent, ally := false) -> void:
	flying = false
	hook_sd = {}
	if KinMerge.transforming(h) or KinMerge.active(h):
		hook_hold = null
		return
	var rdf := rmb_def()
	if f.mass() >= 6.0:
		hook_hold = null
		m.fx.word(f.pos + Vector3(0, 2.4, 0), "TOO HEAVY", Color("c0b0a0"), false)
		return
	grapples += 1
	if rank("sec") >= 3 and not ally:
		cd["rmb"] = float(cd["rmb"]) * (1.0 - float(rdf["refund"]))
	var wisp: bool = f is Hunter and (f as Hunter).downed
	ally = ally or wisp           # a wisp caught head-on is reeled in like an ally: no stun, no Grounded
	pull = {"t": f, "left": float(rdf["pull_max"]), "v": Vector2.ZERO, "ally": ally, "wisp": wisp, "from": f.pos}
	# the caster is Grounded while he reels (sheet gap 5); the chain ring at his feet is the tell, and the barge
	# still works
	KitStatus.apply(h, "gnd", float(rdf["pull_max"]), 0.0, true, "reeling: no jump or glide (the barge still works)")
	st["self_gnd"] = true
	if not ally: f.stun_t = maxf(f.stun_t, 0.3)
	m.fx.word(
		f.pos + Vector3(0, 2.4, 0), _grab_word(wisp, ally), col_of(rdf), true
	)
	fx.orb(f.pos + Vector3(0, 1.0, 0), ROPE_COL, BRASS_HOT, 1.1, 0.15)
	m.sfx("dr_grab", f.pos, -1.0, 1.0)
	m.sfx("dr_reel", h.pos, -5.0, 1.0)
	play("dr_reel")
	if f.remote:
		_end_pull(not ally)           # their body belongs to another game: the hit and Grounded still land

func _grab_word(wisp: bool, ally: bool) -> String:
	if wisp:
		return "SCOOPED"
	return "HOLD ON" if ally else "HOOKED"

## The reel: the body is hauled toward wherever Dredge is now, with weight (it carries its sideways speed and
## eases into the new heading), so walking sideways while reeling swings it round you (the source's physics
## pull). It is dragged over rocks, props and cliff faces; only a placed wall stops it; the abyss takes it.
func _tick_pull(dt: float) -> void:
	var f = pull["t"]
	var gone: bool = not is_instance_valid(f) or (f as Ent).dead
	var state_changed: bool = not gone and f is Hunter and (f as Hunter).downed != bool(pull.get("wisp", false))
	if gone or state_changed or h.stun_t > 0.0 or h.downed:
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
		fx.rope("rope%d" % id, _hand(), b, ROPE_COL, _rope_thick())
		fx.place("claw%d" % id, "claw", b, BRASS, BRASS_HOT, 1.5, atan2(to.x, to.y))
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
			scoop.erase(w)
			continue
		var tw := Vector2(h.pos.x - w.pos.x, h.pos.z - w.pos.z)
		if tw.length() > gap: _drag(w, tw.normalized(), minf(float(rdf["pull_speed"]) * dt, tw.length() - gap))

## Off the ground, from the throw until the miss or the end of the reel, he keeps his height (no fall, even
## over the abyss); on the ground there is nothing to hold.
func _tick_hook_hold() -> void:
	if hook_hold != null and not h.grounded:
		hook_hold.tick(m.world)

## The rope's thickness while reeling: it swells taut on each hand-over-hand haul.
func _rope_thick() -> float:
	var since := fposmod(m.time - anim_at - 0.18, HAUL_T)
	return 0.32 * (1.0 + 0.8 * (1.0 - smoothstep(0.0, 0.12, since)))

## Moves a body `dist` along `dir` in small steps: over rocks and props and up cliff faces (lifted onto them),
## never through a placed wall. Returns how far it went. Over the void it just goes on.
func _drag(fe: Ent, dir: Vector2, dist: float) -> float:
	var moved := 0.0
	var W = m.world
	while moved < dist - 0.001:
		var s := minf(0.2, dist - moved)
		var nx := fe.pos.x + dir.x * s
		var nz := fe.pos.z + dir.y * s
		var gy: float = W.ground_at(nx, nz)
		var wall: bool = not W.dyn_walls.is_empty() and Verbs.wall_blocks(W.dyn_walls, nx, nz, fe.r, fe.pos.y) > 0.0
		if wall:
			break
		var face: float = W.ground_at(nx + dir.x * fe.r, nz + dir.y * fe.r)
		# a body already falling into the abyss isn't saved
		var standing: bool = gy > World.VOID + 1.0 and fe.pos.y > gy - 0.5
		if standing and face > World.VOID + 1.0 and face - fe.pos.y > CLIFF:
			fe.pos.y = face + 0.5          # hauled up a cliff face
			fe.vel.y = maxf(fe.vel.y, 5.0)
		if W.occupy(nx, nz, fe.r, fe.pos.y, false) != 0.0 and gy > World.VOID + 1.0:
			# a rock or a prop in the way: haul the body up and over it to the first clear spot beyond
			var k := s
			var clear := false
			while k < 5.0:
				k += 0.2
				var qx := fe.pos.x + dir.x * k
				var qz := fe.pos.z + dir.y * k
				var qy: float = W.ground_at(qx, qz)
				if qy - fe.pos.y > CLIFF: break
				if W.occupy(qx, qz, fe.r, maxf(fe.pos.y, qy), false) == 0.0:
					fe.pos.x = qx
					fe.pos.z = qz
					fe.pos.y = maxf(fe.pos.y, qy) + 0.5
					fe.vel.y = maxf(fe.vel.y, 5.0)      # a little toss as it clears the top
					clear = true
					break
			if not clear:
				break
			hauled += 1
			moved += k
			continue
		fe.pos.x = nx
		fe.pos.z = nz
		moved += s
	return moved

func _end_pull(arrived: bool) -> void:
	var f = pull.get("t")
	var ally: bool = pull.get("ally", false)
	var wisp: bool = pull.get("wisp", false)
	pull = {}
	scoop = []
	hook_hold = null
	if st.get("self_gnd", false):
		st["self_gnd"] = false
		h.set_meta("gnd_until", minf(float(h.get_meta("gnd_until", 0.0)), m.time))
	play("dr_pullend")
	if arrived and is_instance_valid(f) and not (f as Ent).dead:
		arrivals += 1
		var rdf := rmb_def()
		(f as Ent).vel.x = 0.0
		(f as Ent).vel.z = 0.0
		if ally:
			if not wisp: m.fx.word((f as Ent).pos + Vector3(0, 2.4, 0), "SAVED", col_of(rdf), true)
			return
		payoff_fx((f as Ent).pos, "HAULED", col_of(rdf), "pay_salvage", h.aim_dir(), f)

# ------------------------------------------------------------------ E: Anchor Drop
func cast_e() -> bool:
	if wind > 0.0 or not pull.is_empty() or not dive.is_empty() or broadside.running():
		return false
	var ed := e_def()
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var height := h.pos.y - gy
	if not h.grounded and gy > World.VOID + 1.0 and height >= float(ed["air_min"]):
		_start_dive(height)
		return true
	wind = float(ed["windup"])
	slam_dir = h.aim_dir()
	play("dr_anchor")
	m.sfx("dr_anchor_wind", h.pos, -3.0, 1.0)
	return true

func use_e() -> void:
	if not pull.is_empty():
		h._ab_feedback("k1", "deny")          # only the barge works while reeling
		return
	super.use_e()

## The wind-up: the fist raised high while the slam's exact area fills on the ground in front of him (everyone
## sees it), then the slam on the last frame.
func _tick_wind(dt: float) -> void:
	var ed := e_def()
	wind -= dt
	if h.stun_t > 0.0 or h.downed:
		wind = 0.0
		AimKit.hide(h, "e_tell")
		return
	h.face = atan2(-slam_dir.x, -slam_dir.y)
	var k := 1.0 - wind / float(ed["windup"])
	AimKit.cone(h, "e_tell", slam_tell(k))
	if tells_visible():
		fx.orb(CareUtil.hand_at(h, false), BRASS, BRASS_HOT, 0.6 + 0.6 * k, 0.05)     # the raised fist, glowing hotter
	if wind <= 0.0:
		wind = 0.0
		AimKit.hide(h, "e_tell")
		_anchor()

## The slam's telegraph at fill `k`: the same cone (radius, angle, locked direction) the slam hits.
func slam_tell(k: float) -> Dictionary:
	var ed := e_def()
	return {
		"dir": slam_dir, "len": float(ed["radius"]), "deg": float(ed["angle"]), "fill": clampf(k, 0.0, 1.0),
		"all": true, "col": ANCHOR_COL, "alpha": 1.8, "hot": 0.5 * k
	}

## The slam: his fist into the ground in front, on this frame: the cone's damage and stun, cracks, dust and a
## shake right where the telegraph was.
func _anchor() -> void:
	var ed := e_def()
	var dd := slam_dir
	anchors += 1
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var over_void := gy <= World.VOID + 1.0
	var amt := float(ed["dmg"])
	var stun := _stun_t()
	var stg := stage("e", {"delivery": {"type": "cone", "radius": float(ed["radius"]), "angle": float(ed["angle"])},
		"effects": [{"type": "damage", "amount": amt}, {"type": "stun", "duration": stun}]})
	var on_foe := func(f: Ent, _c: Dictionary): _slammed(f, stun, amt)
	var aim_pt := h.pos + Vector3(dd.x, 0, dd.y) * float(ed["radius"])
	run(stg, cx("e", "anchor_drop", aim_pt, {"no_floor": true, "on_foe": on_foe}))
	var at := ground(h.pos + Vector3(dd.x, 0, dd.y) * float(ed["radius"]) * 0.5)
	var fist := ground(h.pos + Vector3(dd.x, 0, dd.y) * 1.1)
	fx.crescent(h.pos + Vector3(0, 0.25, 0), dd, float(ed["angle"]), float(ed["radius"]), ANCHOR_COL, IRON, 0.25)
	fx.scorch(fist, 1.6, 1.4, Color("8a7a66"), Color("2a241e"))          # cracked ground under the fist
	fx.scorch(at, float(ed["radius"]) * 0.7, 1.2, Color("6a5e50"), Color("2a241e"))
	fx.orb(fist + Vector3(0, 0.3, 0), BRASS, BRASS_HOT, 1.2, 0.08)
	m.fx.burst(fist + Vector3(0, 0.2, 0), Color("c8b8a0"), 18, 5.0, 0.45, 10.0, 1.3, Vector3(dd.x, 0.8, dd.y), 70.0)
	AimKit.cone(h, "e_hit", slam_tell(1.0).merged({"dur": 0.2, "alpha": 0.7}, true))
	m.later(0.06, _anchor_dust.bind(at))
	m.sfx("dr_anchor", h.pos, -1.0, 1.0)
	Feel.shake(m, "t3", h, at)
	if h.is_local(): Oomph.punch_dir(m, dd, 0.25)
	if not h.grounded and not over_void and not h.gliding:
		h.vel.y = -float(ed["dive"])          # a low air cast still drives you down (never over the abyss or a glider)
	st["dive_vy"] = h.vel.y               # (tests) what the Anchor left your fall speed at
	lock_until = m.time + float(dash_def()["lock_t"])
	net_ring(at, float(ed["radius"]) * 0.6, col_of(ed))

## The dust cloud a beat after the slam, over the area it hit.
func _anchor_dust(at: Vector3) -> void:
	if not is_instance_valid(h):
		return
	m.fx.dust(at, 26)
	fx.wave(ground(at), 1.8, ANCHOR_COL, 0.35, Color(IRON, 0.5))

## The Anchor's stun: +0.1s a rank, and rank 3 adds its own 0.2s.
func _stun_t() -> float:
	var ed := e_def()
	var bonus := float(ed["rank3_stun"]) if rank("kin") >= 3 else 0.0
	return float(ed["stun"]) + 0.1 * float(maxi(0, rank("kin") - 1)) + bonus

## True when the foe stands over the abyss.
func over_abyss(f: Ent) -> bool:
	return m.world.ground_at(f.pos.x, f.pos.z) <= World.VOID + 1.0

func _slammed(f: Ent, stun: float, amt: float) -> void:
	var ed := e_def()
	if not is_instance_valid(f) or f.dead: return
	if rank("kin") >= 3 and over_abyss(f):
		abyss_dunks += 1
		f.hurt(amt * power("kin") * float(ed["abyss_k"]), h, {"src": "abil", "ab": "k1", "tags": ["anchor"]})
	f.vel.y = minf(f.vel.y, -16.0)
	# ANCHORED says it all: no separate GROUNDED word over the stun
	KitStatus.apply(f, "gnd", float(ed["gnd_t"]), 0.0, true, "anchored: no dash, jump or glide")
	Feel.hitstop(m, h, f, 30.0, {"melee": true, "heavy": true})
	stunned.append({"e": f, "until": m.time + stun})
	m.fx.word(f.pos + Vector3(0, 2.3, 0), "ANCHORED", col_of(ed), false)

## In the air: smash straight down, the anchor falling with you; the landing ring shows where you'll hit.
func _start_dive(height: float) -> void:
	var ed := e_def()
	# a glide key already held when he smashes doesn't reopen the glider; a fresh press does (and wins)
	dive = {"h0": height, "y0": h.pos.y, "t": 0.0, "held": bool(h.inp.get("glide", false))}
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
	if bool(dive["held"]):
		dive["held"] = bool(h.inp.get("glide", false))
		h.glide_cd = maxf(h.glide_cd, 0.05)
	if h.gliding:
		# the glider wins: opening it ends the smash (no landing hit) and he glides on, never dragged down
		dive = {}
		h.vel.y = maxf(h.vel.y, -Hunter.GLIDE_SINK)       # a normal glide from here, none of the smash's speed
		AimKit.hide(h, "e_land")
		play("")
		return
	h.vel.x = 0.0
	h.vel.z = 0.0
	h.vel.y = minf(h.vel.y, -float(ed["dive"]))
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	if gy <= World.VOID + 1.0:
		dive = {}                 # drifted over the abyss: no smash, no push
		return
	var land := Vector3(h.pos.x, gy, h.pos.z)
	AimKit.circle(
		h, "e_land",
		{
			"at": land, "r": float(ed["quake_r"]), "all": true, "fill": clampf(float(dive["t"]) / 0.4, 0.0, 1.0),
			"ticks": true, "col": ANCHOR_COL
		}
	)
	if tells_visible(): _dive_looks(land, float(ed["quake_r"]))
	if h.grounded or h.pos.y - gy < 0.12 or float(dive["t"]) > 2.0:
		var fell := maxf(float(dive["h0"]), float(dive["y0"]) - gy)
		dive = {}
		_quake(land, fell)

## The air dive: he rides the anchor down (full size under his feet, ahead of the fall), and the landing
## ring is a chain of brass links on the ground, solid enough to read on grass.
func _dive_looks(land: Vector3, r: float) -> void:
	var id := h.get_instance_id()
	var under := h.pos - Basis(Vector3.RIGHT, LDFx.ANCHOR_LEAN) * Vector3(0, DIVE_ANCHOR_UP, 0)
	under.y = maxf(land.y, under.y)
	fx.place("dive_anchor%d" % id, "anchor", under, ANCHOR_COL, IRON, 1.0)
	fx.place("dive_ring%d" % id, "chain", land + Vector3(0, 0.08, 0), BRASS, IRON, r / 0.82, m.time * 0.4)

## The air smash lands: a ring of anchor and dust round the landing, damage scaled by the height fallen.
func _quake(at: Vector3, fell: float) -> void:
	var ed := e_def()
	anchors += 1
	quakes += 1
	last_quake_k = 1.0 + float(ed["air_max"]) * clampf(fell / float(ed["air_h"]), 0.0, 1.0)
	var stun := _stun_t()
	var amt := float(ed["dmg"]) * last_quake_k
	var r := float(ed["quake_r"])
	var stg := stage("e", {"delivery": {"type": "burst", "radius": r},
		"effects": [{"type": "damage", "amount": amt}, {"type": "stun", "duration": stun}]})
	var on_foe := func(f: Ent, _c: Dictionary): _slammed(f, stun, amt)
	run(stg, cx("e", "anchor_drop", at, {"at_fixed": at, "no_floor": true, "on_foe": on_foe}))
	var d2 := h.aim_dir()
	fx.anchor_drop(at + Vector3(d2.x, 0, d2.y) * 0.6, 0.0, 1.0)
	fx.wave(at, r, ANCHOR_COL, 0.45, Color(IRON, 0.5))
	fx.wave(at, r * 0.6, BRASS, 0.3)
	fx.sunburst(at, r * 0.9, BRASS, BRASS_HOT, 0.35)
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
	var busy_slot := _committed_slot()
	if busy_slot != "":
		# Shift in the slam or the Broadside: held for its end when its into_dash row says buffer
		dash_held = String(DashFlow.into_dash_of(id, busy_slot).get("mode", "")) == "buffer"
		return true
	if m.time < next_barge:
		return true
	var dd := dash_def()
	var dir := dash_dir()
	if m.time < lock_until:
		# just after the Anchor the barge can't turn far from where you face
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		var lim := deg_to_rad(float(dd["lock_deg"]))
		var ang := fwd.angle_to(dir)
		if absf(ang) > lim:
			dir = fwd.rotated(clampf(ang, -lim, lim))
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		_air_barge(dd, dir)
	else:
		if not spend_dash(false):
			return true
		var shove := {"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "trail": "", "dir": dir}
		travel(float(dd["dist"]), float(dd["time"]), shove)
		st["last_dash"] = "barge"
		play("dr_lunge")
		h.glide_cd = maxf(h.glide_cd, h.roll_t + 0.35)
		m.sfx("dr_barge", h.pos, -2.0, 1.0)
	if rank("dash") >= 3:
		h.wbloom = 0.0                # rank 3: a dash resets the gun's bloom
	_clawed_turf(dir)
	barge_t = h.roll_t
	stop_t = h.roll_t + 0.02
	next_barge = m.time + h.roll_t + float(dd["gap"])
	return true

## The ability he is committed to now ("e": the slam's wind-up or the air smash, "x": the Broadside), else "".
func _committed_slot() -> String:
	if wind > 0.0 or not dive.is_empty():
		return "e"
	return "x" if broadside.running() else ""

## A Shift held through the slam or the Broadside barges the step it ends (its into_dash row: buffer).
func _tick_held_dash() -> void:
	if dash_held and _committed_slot() == "":
		dash_held = false
		h.do_dash()

## In the air (the class air dash slot): the same quick shove 35% further, so it is faster, not longer (the
## class long dash would otherwise take over its distance and time).
func _air_barge(dd: Dictionary, dir: Vector2) -> void:
	var feel := dash_feel()
	var air_t := float(dd["time"]) * float(feel["time"])
	var air_dist := float(dd["dist"]) * float(dd["air_k"]) * float(feel["dist"])
	travel(air_dist, air_t, {"invuln": 0.08, "trail": "", "dir": dir}, true)
	h.roll_t = air_t
	h.roll_speed = air_dist / air_t
	play("dr_pounce")
	m.sfx("dr_hop", h.pos, -3.0, 1.0)

## The barge's end: he arrives planted (the class carry would slide a heavy on after each quick shove).
func _tick_stop(dt: float) -> void:
	stop_t -= dt
	if stop_t > 0.0 or h.roll_t > 0.0:
		return
	stop_t = 0.0
	var flat := Vector2(h.vel.x, h.vel.z).limit_length(STOP_CARRY)
	h.vel.x = flat.x
	h.vel.z = flat.y

## Dredge's own barge after-images: dark iron shoves with a brass rim, dropped behind him as he lumbers.
func _barge_trail(dt: float) -> void:
	trail_t -= dt
	if trail_t > 0.0:
		return
	trail_t = 0.045
	var d2 := h.aim_dir()
	fx.puff(h.pos + Vector3(0, 0.9, 0) - Vector3(d2.x, 0, d2.y) * 0.5, LDFx.M_ORB, BRASS, IRON, 0.9, 0.3)

func own_dash_trail() -> bool: return true

## Clods of turf his hands tear up as he hauls himself off, thrown back behind him (no burst: a dash never
## explodes).
func _clawed_turf(dir: Vector2) -> void:
	if not h.grounded:
		return
	var at := h.pos + Vector3(dir.x * 0.6, 0.15, dir.y * 0.6)
	m.fx.burst(at, Color("6a5236"), 10, 4.0, 0.35, 12.0, 1.0, Vector3(-dir.x, 0.5, -dir.y), 35.0)

# ------------------------------------------------------------------ X: Brass Broadside
## Only from a free stance: not mid-reel, mid-Anchor or mid-dive.
func cast_ult() -> bool:
	if flying or not pull.is_empty() or wind > 0.0 or not dive.is_empty():
		return false
	return HeroUlt.press(self, broadside.start)

func has_ult() -> bool: return true

func ult_running() -> bool: return broadside.running()

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null or not pull.is_empty() or wind > 0.0 or not dive.is_empty() or broadside.running():
		return
	var tf := tgt as Ent
	if HeroUlt.ready(self) and los and dist < 3.5:
		h.inp["aim"] = tgt.pos
		HunterKeys.ult_pressed(h)
		return
	# the Anchor on a foe that has just landed Grounded, or any foe up close
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["radius"]) + 1.0 and los:
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
		return
	var in_reach := dist > 4.5 and dist < float(rmb_def()["range"]) - 1.0
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and not flying and los and in_reach and tf.mass() < 6.0:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 3.0 and dist < 6.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
