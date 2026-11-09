class_name RimewrightKit
extends ArchKit
## Claire, the Rimewright (light ice controller). docs/heroes/rimewright.md. Copies her source as it
## plays: ice damage, control and a wall, no healing or shields for the squad.
## Passive Hoarfrost: damage Chills; a knock on a Chilled foe, or 8 darts on one foe, Shatters them.
## LMB Ice Dart: hold for a steady stream of slow homing shards that bow out and curve onto the foe
## nearest the cursor; while skating they fly straight and thick. RMB Ice Spear: hold to
## see the landing ring, let go: it lands at the cursor, leaves a slow zone and detonates 1.8s later.
## Shift Skate (hold). E Rink Wall: a 0.2s tell, then a narrow block of ice that slides toward the
## cursor, widening, shoving foes; E again freezes it. X Rimelock (level 6): sealed in ice, invulnerable,
## inside a slowing rink that cracks open into a stun. R is the Boki Merge. Looks: content/vfx/rimewright.json
## (HeroVfx) for the moments, CareLook and UltLook for the bodies (darts, spear, wall, zone, rink, shells);
## moves: KMovesCare "tm_".

var chill := {}                # target instance id -> {t: Ent, left: float}
var fan_hits := {}             # target instance id -> {n: int, left: float, t: Ent}
var darts: Array = []          # homing shards in flight: {s: Dictionary, side: float, passed}
var dart_n := 0                # darts thrown (alternates the bow side and the hand)
var seq_next := 0.0            # when the next dart may leave
var burst_i := 0               # darts so far in this hold: after wpn.burst plain ones come wpn.heavy.n large ones
var rinkrun := {}              # the running Skate: {t, dir, loop, slab}
var ice_t := 0.0               # s until the rank-3 Skate may lay its next span of ice
var wall := {}                 # the Rink Wall: {w, dir, sliding, t, slide_t, hp0, hit}
var carried := {}              # foe id -> its Displace tow: bodies the sliding Rink Wall carries
var wall_cast := {}            # the wall's 0.2 s tell before it erupts: {t, dir, travel}
var spear_aim := false         # RMB held: the landing ring and the raised spear are up
var throw_t := -1.0            # s left of the push before the spear leaves her palms (-1: none)
var zones: Array = []          # landed spears: {at, left, total, id}
var zone_n := 0
var splinter_log := 0          # Shatters fired (tests)
var look: CareLook
var stats := {      # counters for the checks
	"darts": 0, "heavies": 0, "beams": 0, "spears": 0, "detonations": 0, "rimes": 0, "crashes": 0, "cancels": 0,
}
var rime := {}                 # Rimelock running: {t, at, slow: {instance id: seconds in the rink}, creak}
var last_stunned := 0          # foes the last Rimelock crash stunned (tests)
var glide_held := false        # the glide key was down last step (Rimelock refuses each new press once)
var ult_look: UltLook
const SHELL_T := 0.15          # s the icy shell shows on a foe before the 8-dart Shatter bursts
const SLAB_GAP := 0.06         # s between ice plates under the skate
const FROST_EVERY := 3         # ice plates between two frost patches left on the ground behind her
const SLAB_LEAD := 0.5         # m ahead of her middle a plate forms (under the leading blade)
const SLAB_LIFE := 3.0         # s a plate stays before it fades (the owner's "a few seconds")
const SHATTER_R := 2.7         # m, the Shatter's spike starburst (about 1.5 body heights)
const PUSH_T := 0.1           # s from letting go of RMB to the release: both palms drive forward (tm_spear)
const SPEAR_ARC := 0.25        # m the driven spear's low flight bows above the line from her palms to the ground
const SPEAR_AHEAD := 0.9       # m in front of her chest of the spear's head end; its shaft runs back to her palms
const SPEAR_Y := 1.05          # m: the height of her palms at the chest
const SPEAR_FORM_T := 0.3      # s of holding RMB for the spear to grow to full size between her palms
const BUD_CLOSE_T := 0.15     # s the frost bud takes to close over her when cast standing
const CARRY_T := 0.5           # s a skate out of Rimelock holds its push-off speed before easing to the skate's

func _setup() -> void:
	res = 0.0

func lk() -> CareLook:
	if look == null:
		look = CareLook.new(m, h)
	return look

func play_soft(move: String) -> void:
	if anim_id == "" or m.time - anim_at >= KMovesCare.length(anim_id):
		play(move)

# ------------------------------------------------------------------ Chill and Shatter
func chilled(t: Ent) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var e: Dictionary = chill.get(t.get_instance_id(), {})
	return float(e.get("left", 0.0)) > 0.0

func add_chill(t: Ent) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team:
		return
	var key := t.get_instance_id()
	var fresh := not chilled(t)
	chill[key] = {"t": t, "left": float(d["passive"].get("chill_t", 4.0))}
	if fresh:
		vfx("chill", t.pos)

func fan_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t): return 0
	return int((fan_hits.get(t.get_instance_id(), {}) as Dictionary).get("n", 0))

func best_fan() -> int:
	var b := 0
	for k in fan_hits:
		b = maxi(b, int((fan_hits[k] as Dictionary)["n"]))
	return b

func res_frac() -> float: return float(best_fan()) / float(d["passive"].get("fan_hits", 8))
func res_text() -> String: return "%d/%d" % [best_fan(), int(d["passive"].get("fan_hits", 8))]
func full_ready() -> bool: return false

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) in ["burn", "splinter"]:
		return
	var pd: Dictionary = d["passive"]
	# the knock or the kill on a Chilled foe: they Shatter a beat later
	if t.hp <= 0.0 and chilled(t) and (t is Hunter or t is Mob):
		var at := t.pos
		m.later(
				float(pd.get("splinter_delay", 0.4)),
				func(): splinter(at, float(pd["splinter_dmg"]), float(pd["splinter_r"]), t))
		chill.erase(t.get_instance_id())
		return
	add_chill(t)
	if String(o.get("ab", "")) == "fan":
		m.sfx("rimewright_dart_hit", t.pos, -5.0, 1.0)
		var key := t.get_instance_id()
		var e: Dictionary = fan_hits.get(key, {"n": 0, "left": 3.0, "t": t})
		e["n"] = int(e["n"]) + 1
		e["left"] = 3.0
		e["t"] = t
		fan_hits[key] = e
		if int(e["n"]) >= int(pd.get("fan_hits", 8)):
			fan_hits.erase(key)
			# an icy shell closes over them for a beat, then it bursts
			lk().burst("shell", t.pos, {"dur": SHELL_T + 0.05, "ent": t})
			m.sfx("rimewright_chime", t.pos, -3.0, 1.0)
			var at := t.pos
			m.later(SHELL_T, func(): splinter(at, float(pd["fan_splinter"]), float(pd["splinter_r"]) * 0.8, t))

## Shatter: a starburst of ice spikes round the foe, damage and more Chill to everyone near.
func splinter(at: Vector3, dmg: float, r: float, skip: Ent = null) -> void:
	splinter_log += 1
	m.fx.word(at + Vector3(0, 2.7, 0), "SHATTER", res_col(), true)
	m.sfx("rime_splinter", at, 0.0, 1.0)
	lk().burst("spikes", at, {"r": SHATTER_R, "dur": 0.7})
	vfx("shatter", at)
	play_soft("tm_shatter")
	for f in foes_in(at, r):
		if f == skip and f.hp <= 0.0:
			continue
		f.hurt(
				dmg * power("passive"), h,
				{
					"src": "splinter", "ab": "passive", "slow": 1.2, "slow_k": 0.3, "tags": ["passive", "splinter"],
					"payoff": true})
		add_chill(f)

func _tick(dt: float) -> void:
	for key in chill.keys():
		var e: Dictionary = chill[key]
		e["left"] = float(e["left"]) - dt
		var tv = e["t"]     # untyped first: a freed foe can't be assigned to a typed var
		var t: Ent = tv if is_instance_valid(tv) else null
		if float(e["left"]) <= 0.0 or t == null or t.dead:
			chill.erase(key)
			continue
	for key in fan_hits.keys():
		var e2: Dictionary = fan_hits[key]
		e2["left"] = float(e2["left"]) - dt
		var tv2 = e2["t"]
		if float(e2["left"]) <= 0.0 or not is_instance_valid(tv2):
			fan_hits.erase(key)
			continue
		# the frost glow on the foe grows with each dart toward the Shatter
		var n := int(e2["n"])
		lk().keep(
				"frost%d" % key, "frost", (tv2 as Node3D).global_position,
				{"r": 0.7 + 0.08 * n, "a": 0.15 + 0.75 * float(n) / 8.0})
	_tick_darts(dt)
	_tick_throw(dt)
	_tick_rinkrun(dt)
	_tick_wall_cast(dt)
	_tick_wall(dt)
	_tick_zones(dt)
	_tick_rime(dt)
	_tick_trails(dt)
	if h.is_local() and not busy():
		AimKit.line(h, "aim", {"alpha": 0.7, "col": Color("e8ffff")})     # the thin aim line to the cursor, always up
	lk().tick(dt)
	if ult_look != null:
		ult_look.tick(dt)

# ------------------------------------------------------------------ LMB: Ice Dart
func lmb_override(held: bool, _dt: float) -> bool:
	if not held:
		burst_i = 0
	if not h.can_fire() or not rime.is_empty():
		return true
	if not held or h.fire_cd > 0.0 or m.time < seq_next:
		return true
	_throw_dart()
	return true

## The barrage's rhythm (the source's data): wpn.burst plain darts, then wpn.heavy.n larger ones (double damage,
## faster, longer reach), then round again while the button stays down.
func _heavy_now() -> bool:
	var wd: Dictionary = h.wpn
	var plain := int(wd.get("burst", 4))
	var cycle := plain + int((wd.get("heavy", {}) as Dictionary).get("n", 0))
	return cycle > plain and burst_i % cycle >= plain

func _throw_dart() -> void:
	var wd: Dictionary = h.wpn
	var skating := in_dash() and String(flow.row("lmb")["variant"]) == "beam"
	var heavy := _heavy_now()
	var dir := h.aim_dir()
	burst_i += 1
	dart_n += 1
	var side := 1.0 if dart_n % 2 == 0 else -1.0
	# a dart leaves a little to one side of the aim and curves in late; a skating beam leaves straight on the aim
	var bow := 0.0 if skating else deg_to_rad(float(wd.get("bow_deg", 18.0))) * side
	var v := dir.rotated(bow)
	var start := Vector3(h.pos.x + v.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + v.y * 0.6)
	var dmg: float = float(wd["dmg"]) * float(m.dmg_mult(h)) * _heavy_k("dmg_k", heavy)
	var spd := (float(wd.get("skate_speed", 30.0)) if skating else float(wd["speed"])) * _heavy_k("speed_k", heavy)
	var rng := float(wd["range"]) * h.shot_range_k * _heavy_k("range_k", heavy)
	h.shot_range_k = 1.0
	var extra := {"src": "shot", "ab": "fan", "kb": float(wd["kb"]), "tracer": 1.0, "heavy": heavy}
	m.spawn_shot(
			h, start, v * spd, dmg, rng / spd * (1.0 if skating else 1.15),
			float(wd["size"]) * (1.6 if skating else 1.0) * _heavy_k("size_k", heavy), wd["color"], extra)
	var s := lk().last_shot()
	if not s.is_empty():
		lk().skin(s, "beam" if skating else "shard", {}, _heavy_k("size_k", heavy))
		darts.append({"s": s, "side": side, "passed": false})
		if skating:
			HeroVfx.of(m).trail(h, "beam_trail", s["node"])
		else:
			HeroVfx.of(m).trail(h, "dart_trail", s["node"])
	vfx("dart")
	var pitch := (1.0 + 0.06 * side) * (0.8 if heavy else 1.0)
	var loud := 0.0 if heavy else -2.0
	m.sfx("rime_beam" if skating else String(wd["sfx"]), h.pos, loud, pitch)
	if heavy:
		stats["heavies"] += 1
	if skating:
		stats["beams"] += 1
		play("tm_beam")
	else:
		stats["darts"] += 1
		_play_dart(heavy, side)
	h.recoil = 0.4
	h.muzzle_t = 0.05
	h.reveal_t = maxf(h.reveal_t, 1.2)
	h.idle_fire = 0.0
	seq_next = m.time + float(wd.get("rate", 0.18))

## A large dart's multiplier `key` (wpn.heavy), 1 for a plain one.
func _heavy_k(key: String, heavy: bool) -> float:
	return float((h.wpn.get("heavy", {}) as Dictionary).get(key, 1.0)) if heavy else 1.0

## A dart's own flick (a large one flings both hands); none while the spear is held between her palms.
func _play_dart(heavy: bool, side: float) -> void:
	if spear_aim:
		return
	if heavy:
		play("tm_dart_heavy")
	else:
		play("tm_dart_r" if side > 0.0 else "tm_dart_l")

## Homing: late in its flight each dart (and each skating beam) turns toward the foe nearest the cursor (or,
## with none there, the nearest one ahead of it, or else the cursor point itself).
func _tick_darts(dt: float) -> void:
	var wd: Dictionary = h.wpn
	var turn := float(wd.get("turn", 7.0))
	var aimp: Vector3 = h.inp.get("aim", h.pos)
	var near_cur: Ent = null
	var nd := float(wd.get("cursor_r", 3.5))
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var dc := Vector2(f.pos.x - aimp.x, f.pos.z - aimp.z).length()
		if dc < nd:
			nd = dc
			near_cur = f
	for dd in darts.duplicate():
		var s: Dictionary = dd["s"]
		if not m.shots.has(s):
			darts.erase(dd)
			continue
		var v: Vector2 = s["vel"]
		var p: Vector3 = s["pos"]
		var want := Vector2.ZERO
		if near_cur != null:
			want = Vector2(near_cur.pos.x - p.x, near_cur.pos.z - p.z)
		else:
			var best: Ent = null
			var bd := float(wd.get("acquire", 9.0))
			for f in m.foes_of(h.team):
				var to := Vector2(f.pos.x - p.x, f.pos.z - p.z)
				if (to.length() < bd
						and to.length() > 0.3
						and absf(v.angle_to(to)) < deg_to_rad(float(wd.get("cone_deg", 75.0)))
						and f.hittable()):
					bd = to.length()
					best = f
			if best != null:
				want = Vector2(best.pos.x - p.x, best.pos.z - p.z)
			elif not bool(dd["passed"]):
				want = Vector2(aimp.x - p.x, aimp.z - p.z)
				if want.length() < 0.8 or v.dot(want) < 0.0:
					dd["passed"] = true          # past the cursor: it flies on straight
					want = Vector2.ZERO
		if want.length() < 0.05 or absf(v.angle_to(want)) > PI * 0.6:
			continue             # nothing to chase, or it is already past it: it flies on
		var rate := turn * _homing_k(s, want.length())
		var ang := clampf(v.angle_to(want), -rate * dt, rate * dt)
		s["vel"] = v.rotated(ang)

## How hard a dart (or a skating beam) homes now, 0..1: it flies out along the aim, then curves in toward the end
## of its flight to what it chases, as Celeste's do (from wpn.home_from to wpn.home_full of the way there).
func _homing_k(s: Dictionary, left: float) -> float:
	var wd: Dictionary = h.wpn
	var from: Vector3 = s["start"]
	var p: Vector3 = s["pos"]
	var flown := Vector2(p.x - from.x, p.z - from.z).length()
	var way := flown / maxf(0.01, flown + left)
	return smoothstep(float(wd.get("home_from", 0.35)), float(wd.get("home_full", 0.7)), way)

# ------------------------------------------------------------------ Shift: Skate
## The skate is her dash (DashFlow sees it); its rows (content/dash_flow/rimewright.json) say what fires from it.
## Skating into Rimelock the dash goes on as the statue's slide (item 64), so the X press reads as a "fire".
func in_dash() -> bool:
	return not rinkrun.is_empty() or _rime_carrying()

## Mid-air she sinks gently along the skate (dash.air_fall m/s, item 62) instead of holding her height; the
## statue sliding on in the air does the same. An air press starts at that sink (_begin_skate); a jump pressed in
## the skate rises and falls as any jump down to it (item 51's combo: the skate goes on under it).
func dash_vy(dt: float) -> float:
	if rinkrun.is_empty() and not _rime_carrying():
		return 0.0
	return maxf(h.vel.y - Hunter.H_GRAV * dt, -float(dash_def().get("air_fall", 1.5)))

## Sealed in Rimelock she is a statue: her facing stays as it was on the cast frame (item 65).
func face_locked() -> bool:
	return not rime.is_empty()

## The statue takes no jump, glove or Boki ability either; only the recast and Shift out (item 65).
func cast_locked() -> bool:
	return not rime.is_empty()

## Seconds left in the skate (the timer in_dash reads): to its full length while Shift is held, else to its
## shortest run.
func dash_left() -> float:
	if rinkrun.is_empty():
		if _rime_carrying():
			return maxf(0.0, float(x_def()["carry_t"]) - float(rime["t"]))
		return super.dash_left()
	var dd := dash_def()
	var end := float(dd.get("max_t", 1.6)) if held("dash") else float(dd.get("min_t", 0.2))
	return maxf(0.0, end - float(rinkrun["t"]))

## LMB from the skate: her row says fire, with the "beam" variant (straight thick darts).
func fires_in_dash() -> bool:
	return not rinkrun.is_empty() and String(flow.row("lmb")["mode"]) == "fire"

## She skates along her line and turns to the cursor only while the darts fly.
func aims_in_dash() -> bool:
	return fires_in_dash() and bool(h.inp.get("fire", false))

## No class long dash: Shift is only ever the skate (the HUD shows no long-dash segment for her).
func has_long_dash() -> bool: return false

## Shift is the skate and nothing else, on the ground or in the air (item 62: pressed in the air, jumping,
## falling or gliding, it starts at once); with no charge it is refused.
func on_dash(_use_ex: bool) -> bool:
	if not rinkrun.is_empty() or not rime.is_empty():
		return true
	if h.dashes < 1.0:
		h._ab_feedback("dash", "deny")
		return true
	_begin_skate()
	return true

## The push-off: spends the charge and starts the skate along the move keys.
func _begin_skate() -> void:
	h.dashes -= 1.0
	var dir := dash_dir()
	rinkrun = {"t": 0.0, "dir": dir.normalized(), "loop": 0.16, "slab": 0.0, "air": not h.grounded}
	h.gliding = false          # a press while gliding folds the glider: the skate takes over
	if not h.grounded:
		h.vel.y = -float(dash_def().get("air_fall", 1.5))
	play("tm_skate_go" if h.grounded else "tm_skate_air")
	m.sfx("rimewright_dash", h.pos, -3.0, 1.0)
	vfx("skate_go", null, dir)          # ice kicked back off the pushing blade (no ring: a dash never bursts)

func _tick_rinkrun(dt: float) -> void:
	if rinkrun.is_empty():
		return
	var dd := dash_def()
	rinkrun["t"] = float(rinkrun["t"]) + dt
	var t := float(rinkrun["t"])
	if _glide_pressed():
		_rinkrun_end()
		h.do_jump()
		return
	# she skates on over a ledge (only a glide, a stun or letting go ends it)
	var stop := h.downed or h.stun_t > 0.0 or h.out or t >= float(dd.get("max_t", 1.6)) or h.gliding
	if t > float(dd.get("min_t", 0.2)) and not held("dash"):
		stop = true
	if stop:
		_rinkrun_end()
		return
	# steer toward the move keys: she carves a curve (a set turn rate, so the skate keeps its flow), and
	# a hard carve throws ice off the outside edge
	var mv: Vector2 = h.inp["move"]
	var cur: Vector2 = rinkrun["dir"]
	var steer := float(dd.get("steer", 3.6))
	var turn := 0.0
	if mv.length() > 0.1:
		turn = clampf(cur.angle_to(mv.normalized()), -steer * dt, steer * dt)
		cur = cur.rotated(turn)
	rinkrun["dir"] = cur
	_edge_spray(cur, turn / maxf(dt, 0.001), dt)
	h.roll_dir = cur
	# full speed within `ramp` s of the push-off; out of Rimelock it starts at full speed (or the speed she
	# had) and holds it CARRY_T before easing to the skate's own
	var spd := float(dd.get("speed", 11.5)) * lerpf(0.45, 1.0, clampf(t / float(dd.get("ramp", 0.2)), 0.0, 1.0))
	if bool(rinkrun.get("air", false)):
		spd = float(dd.get("speed", 11.5))        # pressed in the air: at skate speed from the first frame (item 62)
	var carry := float(rinkrun.get("carry", 0.0))
	if carry > 0.0 and t < CARRY_T * 2.0:
		spd = maxf(spd, lerpf(carry, float(dd.get("speed", 11.5)), smoothstep(CARRY_T, CARRY_T * 2.0, t)))
	h.roll_speed = spd
	h.roll_t = 0.1
	h.move_kind = "rinkrun"
	# the stride move, replayed every 0.56 s; off the ground she glides on her ribbon (its own move id, item 62)
	var stride := "tm_skate" if h.grounded or h.coyote > 0.0 else "tm_skate_air"
	var striding: bool = anim_id in ["tm_skate", "tm_skate_air"]
	rinkrun["loop"] = float(rinkrun["loop"]) - dt
	var stride_free: bool = striding or anim_id == "tm_skate_go" or m.time - anim_at >= KMovesCare.length(anim_id)
	if stride_free and (float(rinkrun["loop"]) <= 0.0 or (striding and anim_id != stride)):
		rinkrun["loop"] = KMovesCare.length(stride)
		play(stride)
		m.sfx("rimewright_skate_scrape", h.pos, -5.0, 1.0)     # each stride's blade on the ice
	_lay_ice(cur, dt)

## A jump press in the air skate with no jump left in it, clear of the ground: ending in the air takes the normal
## glide rules (item 62), and the shared press can't open a glider while the skate runs. Near the ground the press
## stays the shared buffered jump.
func _glide_pressed() -> bool:
	if not bool(h.inp.get("jump", false)) or h.grounded or h.vel.y >= Hunter.JUMP_V - 0.01:
		return false
	return h.over_void() or h.pos.y - h.ground() > 0.9

## Rank 3: skating over the Abyss lays ice underfoot, a short span just ahead of her every `ice_gap`
## seconds, which stays a few seconds so she (and anyone after her) can land on it.
func _lay_ice(dir: Vector2, dt: float) -> void:
	if rank("dash") < 3:
		return
	ice_t -= dt
	if ice_t > 0.0:
		return
	var dd := dash_def()
	var ahead := Vector2(h.pos.x, h.pos.z) + dir * float(dd.get("ice_look", 2.0))
	if not h.over_void() and not m.world.is_void(ahead.x, ahead.y):
		return
	ice_t = float(dd.get("ice_gap", 0.2))
	var laid := HeroZones.bridge(
			m, h, h.pos, dir, float(dd.get("ice_len", 3.6)), float(dd.get("ice_width", 1.6)),
			float(dd.get("ice_time", 5.0)), true, String(dd.get("ice_col", "#bff0ff")))
	if laid > 0:
		vfx("ice_bridge")

## A Boki merge ends the Skate (its refund is the same as letting go), drops the spear aim and a wall
## still in its tell (no wall comes up).
func _drop_holds() -> void:
	if not rime.is_empty():
		_rime_clear()
	if not rinkrun.is_empty():
		_rinkrun_end()
	if spear_aim or rmb_down:
		spear_aim = false
		rmb_down = false
		if anim_id == "tm_spear_aim": anim_id = ""
		lk().drop("spear_prop")
	if throw_t >= 0.0:
		_drop_throw()
	wall_cast = {}

## Ends the skate; `into_rime` hands it straight to the Rimelock statue's slide (no stop, no spray).
func _rinkrun_end(into_rime := false) -> void:
	var dd := dash_def()
	var t := float(rinkrun.get("t", 0.0))
	var early := 1.0 - clampf(t / float(dd.get("max_t", 1.6)), 0.0, 1.0)
	h.dashes = minf(h.max_dashes(), h.dashes + early * float(dd.get("refund", 0.6)))
	rinkrun = {}
	if into_rime:
		return
	h.roll_t = 0.0
	if h.grounded:
		h.vel.x *= 0.3
		h.vel.z *= 0.3
	else:
		# ended in the air: she keeps the skate's speed the way any air dash does, then the normal fall / glide
		var keep := HunterMove.dash_exit(h.roll_dir * h.roll_speed, h.base_speed)
		h.vel.x = keep.x
		h.vel.z = keep.y
	play("tm_skate_stop")
	dash_press_at = m.time           # the stop is the skate's own move: it never holds the glider shut (AirLimits)
	m.sfx("rime_stop", h.pos, -4.0, 1.0)
	vfx("skate_stop", null, h.roll_dir)          # a spray of ice off the braced blades, thrown on ahead

func rinkrunning() -> bool: return not rinkrun.is_empty()

## Carving: a spray of ice and chips off the outside blade, more the harder she turns.
func _edge_spray(dir: Vector2, turn_rate: float, dt: float) -> void:
	var hard := clampf(absf(turn_rate) / 3.0, 0.0, 1.0)
	if hard < 0.25:
		return
	rinkrun["spray"] = float(rinkrun.get("spray", 0.0)) - dt
	if float(rinkrun["spray"]) > 0.0:
		return
	rinkrun["spray"] = 0.08
	var outside := Vector2(dir.y, -dir.x) * signf(turn_rate)
	vfx("skate_carve", h.pos + Vector3(outside.x * 0.3, 0.0, outside.y * 0.3), outside)

## The skate's frost trail: ice chips and snow drifting off her blades (content/vfx "skate", held while she
## skates) and the ice plates under them; her own trail replaces the shared after-image pill.
func _tick_trails(dt: float) -> void:
	if h.roll_t > 0.0:
		h.ghost_t = 0.3
	if not rinkrun.is_empty():
		HeroVfx.of(m).hold(h, "skate")
		_lay_slabs(dt)

## Plates of ice that form under her blades as she skates and fade behind her, each with a frost sheen
## where the blade bites.
func _lay_slabs(dt: float) -> void:
	rinkrun["slab"] = float(rinkrun.get("slab", 0.0)) - dt
	if float(rinkrun["slab"]) > 0.0:
		return
	rinkrun["slab"] = SLAB_GAP
	var span := randf_range(0.9, 1.3)
	# laid just under the leading blade, so the newest plate is always under her feet
	var under := h.position + Vector3(h.roll_dir.x, 0.0, h.roll_dir.y) * SLAB_LEAD
	lk().burst("slab", under, {"r": span, "dur": SLAB_LIFE, "dir": h.roll_dir.rotated(randf_range(-0.25, 0.25))})
	rinkrun["frost"] = int(rinkrun.get("frost", 0)) + 1
	if int(rinkrun["frost"]) % FROST_EVERY == 0:
		vfx("skate_frost", h.position, h.roll_dir)       # a frost patch that lingers, then melts

# ------------------------------------------------------------------ RMB: Ice Spear
func rmb_charge_full() -> float: return 0.0

## Held: the landing ring at the cursor (clamped to range); she draws both palms in to her chest and the
## spear forms between them, pointing at the cursor.
func rmb_hold_tick(t: float) -> void:
	if not rmb_ready() or busy():
		return
	var ld: Dictionary = rmb_def()["lance"]
	AimKit.circle(
			h, "rmb",
			{
				"range": float(ld["range"]), "r": float(ld["zone_r"]), "ticks": true, "star": true,
				"col": Color("dffcff")})
	if not spear_aim:
		spear_aim = true
		play("tm_spear_aim")
		m.sfx("rime_spear_aim", h.pos, -6.0, 1.0)
	HeroVfx.of(m).hold(h, "spear_aim")
	_hold_spear(lerpf(0.45, 1.0, clampf(t / SPEAR_FORM_T, 0.0, 1.0)), -0.25)

## The ice spear between her palms at `grown` of its size, `ahead` m further out than her chest (the push
## drives it out), along the aim.
func _hold_spear(grown: float, ahead: float) -> void:
	var dir := h.aim_dir()
	var at := _spear_at(ahead)
	var facing := Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP)
	var xf := Transform3D(facing.scaled(Vector3.ONE * grown), at)
	lk().keep("spear_prop", "spear", at, {"xf": xf})

## Where the spear sits in front of her chest, `ahead` m further along the aim.
func _spear_at(ahead: float) -> Vector3:
	var dir := h.aim_dir() * (SPEAR_AHEAD + ahead)
	return h.position + Vector3(dir.x, SPEAR_Y, dir.y)

## RMB let go: both palms drive forward (PUSH_T later the spear leaves them). A push, not a throw: no arm
## drawn back, no release flick.
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	spear_aim = false
	AimKit.hide(h, "rmb")
	if not spend_rmb():
		lk().drop("spear_prop")
		if anim_id == "tm_spear_aim": anim_id = ""
		return
	throw_t = PUSH_T
	play("tm_spear")
	m.sfx("rime_spear_aim", h.pos, -4.0, 0.8)

## The push: the spear rides out on her palms until they are fully extended. A stun or the seal drops it.
func _tick_throw(dt: float) -> void:
	if throw_t < 0.0:
		return
	if busy() or not rime.is_empty():
		_drop_throw()
		return
	throw_t -= dt
	_hold_spear(1.0, -0.25 * throw_t / PUSH_T)
	if throw_t <= 0.0:
		throw_t = -1.0
		_release_spear()

func _drop_throw() -> void:
	throw_t = -1.0
	lk().drop("spear_prop")

## The spear leaves her palms and drives out low and fast to the cursor (clamped to its range): the further
## the target, the longer it travels (distance / speed). It lands only when it gets there; a foe in the way
## takes the small hit and it lands there.
func _release_spear() -> void:
	lk().drop("spear_prop")
	var ld: Dictionary = rmb_def()["lance"]
	var dir := h.aim_dir()
	var start := _spear_at(0.0)
	var spd := float(ld["speed"])
	var dist := AimMode.dist(h, float(ld["range"]))
	var on_land := func(_s: Dictionary, at: Vector3, _e: Ent, _why: String): _spear_land(at)
	var extra := {"src": "abil", "ab": "utility", "tracer": 1.4, "kb": 0.0, "kx": on_land}
	# the spear itself does no damage on the way: its hit is the landing's small area (_spear_land)
	m.spawn_shot(
			h, start, dir * spd, 0.0, dist / spd, float(ld["hit_r"]) * 0.5,
			col_of(rmb_def()), extra)
	var s := lk().last_shot()
	var land_y: float = ground(start + Vector3(dir.x, 0, dir.y) * dist).y + 0.1
	lk().skin(s, "spear", {"dist": dist, "y": land_y, "h": SPEAR_ARC})
	if not s.is_empty():
		HeroVfx.of(m).trail(h, "spear_trail", s["node"])
	stats["spears"] += 1
	m.sfx("rime_lance", h.pos, 0.0, 1.0)
	vfx("spear_push", null, dir)

## The spear lands: shards burst up, the slow zone (its real radius) spreads with a spinning crystal and a
## chill puff; 1.8 s later it detonates.
func _spear_land(at0: Vector3) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	var at := ground(at0)
	zone_n += 1
	zones.append({"at": at, "left": float(ld["delay"]), "total": float(ld["delay"]), "id": zone_n})
	lk().burst("spikes", at, {"r": 1.1, "dur": 0.35})
	vfx("spear_land", at, null, {"r": float(ld["zone_r"])})        # shards, a frosted ground and the chill puff
	m.sfx("rime_zone", at, -1.0, 0.85)
	m.sfx("rimewright_chime", at, -5.0, 0.9)          # the spinning crystal
	# the landing hit (the source's small area): foes right where it lands take it and a short slow
	for f in foes_in(at, float(ld["impact_r"])):
		f.hurt(
				float(ld["dmg"]) * power("sec"), h,
				{"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "slow": 0.6, "slow_k": 0.35})
		add_chill(f)

func _tick_zones(dt: float) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	for z in zones.duplicate():
		z["left"] = float(z["left"]) - dt
		var at: Vector3 = z["at"]
		var k := 1.0 - float(z["left"]) / maxf(0.01, float(z["total"]))
		var key := "zone%d" % int(z["id"])
		lk().keep(
				key, "zone", at,
				{
					"r": float(ld["zone_r"]), "col": Color("7fd8ff"), "rim": Color("e8ffff"), "fill": 0.8,
					"sweep": k, "pattern": 2.0, "spin": m.time * 0.6, "a": 0.9})
		AimKit.circle(
				h, key,
				{"at": at, "r": float(ld["burst_r"]), "fill": k, "all": true, "dashed": true, "col": Color("bff7ef")})
		for f in foes_in(at, float(ld["zone_r"])):
			f.slow_k = maxf(f.slow_k if f.slow_t > 0.0 else 0.0, float(ld["zone_slow"]))
			f.slow_t = maxf(f.slow_t, 0.2)
			add_chill(f)
		if float(z["left"]) <= 0.0:
			zones.erase(z)
			lk().drop(key)
			AimKit.hide(h, key)
			_detonate(at)

func _detonate(at: Vector3) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	var rr := float(ld["burst_r"])
	var blast_k := float(ld.get("r3_dmg_k", 1.45)) if rank("sec") >= 3 else 1.0
	stats["detonations"] += 1
	# the big hit: a full-size starburst of ice spikes, a flash, shards thrown high, frost, mist, a glassy shatter
	lk().burst("spikes", at, {"r": rr * 0.95, "dur": 0.6})
	vfx("spear_burst", at, null, {"r": rr})
	m.sfx("rime_burst", at, 1.0, 0.9)
	m.sfx("rime_splinter", at, -3.0, 0.75)
	Shake.incoming_big(m, at, 0.6, h)
	play_soft("tm_clench")
	for f in foes_in(at, rr):
		f.hurt(
				float(ld["burst_dmg"]) * power("sec") * blast_k, h,
				{
					"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "slow": 0.8, "slow_k": 0.3,
					"payoff": true})
		lk().burst("shell", f.pos, {"dur": float(ld["encase_t"]), "ent": f})

# ------------------------------------------------------------------ E: Rink Wall
## E: a 0.2 s tell (a sparkle at her feet, and everyone sees the path), then the wall erupts.
func cast_e() -> bool:
	if not rime.is_empty():
		return false
	var ed := e_def()
	var dir := h.aim_dir()
	# it slides until its middle reaches the cursor (clamped to its travel)
	var travel_d := clampf(AimMode.cursor_dist(h) - float(ed["reach"]), float(ed["travel_min"]), float(ed["travel"]))
	wall_cast = {"t": float(ed["tell"]), "dir": dir, "travel": travel_d}
	e_t = float(ed["tell"]) + 0.1
	play("tm_wall")
	vfx("wall_tell")
	AimKit.lane(
			h, "e",
			{
				"len": float(ed["reach"]) + travel_d, "width": float(ed["length_max"]), "all": true,
				"dur": float(ed["tell"]) + 0.3, "col": Color("9af0e6")})
	m.sfx("rime_wall_tell", h.pos, -3.0, 1.0)
	return true

func _tick_wall_cast(dt: float) -> void:
	if wall_cast.is_empty():
		return
	wall_cast["t"] = float(wall_cast["t"]) - dt
	if float(wall_cast["t"]) <= 0.0:
		var wc := wall_cast
		wall_cast = {}
		_raise_wall(wc["dir"], float(wc["travel"]))

func _raise_wall(dir: Vector2, travel_d: float) -> void:
	var ed := e_def()
	var at := h.pos + Vector3(dir.x, 0, dir.y) * float(ed["reach"])
	at.y = h.pos.y
	var g: float = m.world.ground_at(at.x, at.z)
	if g <= World.VOID + 1.0 or m.world.is_block(at.x, at.z):
		at = h.pos + Vector3(dir.x, 0, dir.y) * 1.0
	var hp := float(ed["hp"]) + (40.0 if rank("kin") >= 3 else 0.0)
	var w: Dictionary = m.verbs.add_wall(
			h, at, dir,
			{
				"length": float(ed["length"]), "hp": hp, "time": float(ed["time"]), "move": true,
				"color": String(ed["col"]), "block": "enemy",
				"touch": {"kb": float(ed["push"]), "dmg": 0.5, "slow": 1.0, "slow_k": 0.3}},
			power("kin"))
	w["y"] = at.y
	# her own ice look instead (CareLook "wall")
	if is_instance_valid(w["node"]): (w["node"] as Node3D).visible = false
	wall = {
			"w": w, "dir": dir, "sliding": true, "t": 0.0, "slide_t": travel_d / float(ed["slide"]),
			"hp0": float(w["hp"]), "hit": 0.0}
	e_t = float(ed["time"])
	m.sfx("rime_wall", at, -1.0, 1.0)
	vfx("wall_rise", at, dir)

func e_recastable() -> bool:
	return not wall.is_empty() and bool(wall.get("sliding", false))

func e_recast() -> bool:
	if not wall_cast.is_empty():
		return true          # still in its tell
	if wall.is_empty() or not bool(wall["sliding"]):
		return true
	_freeze_wall()
	play("tm_freeze")
	return true

func _freeze_wall() -> void:
	var ed := e_def()
	wall["sliding"] = false
	wall["frozen"] = true
	var w: Dictionary = wall["w"]
	w["t"] = float(ed["frozen_t"])
	e_t = float(ed["frozen_t"])
	wall["hit"] = 1.0
	var mid := ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	vfx("wall_freeze", Vector3(mid.x, float(w["y"]), mid.y), wall["dir"])
	m.sfx("rime_freeze", h.pos, -3.0, 1.0)
	m.sfx("rimewright_chime", Vector3(mid.x, float(w["y"]), mid.y), -5.0, 1.1)

## Sliding toward the cursor and widening from a narrow block to its full width; it stops at the
## cursor distance, at a cliff or a wall, then stands until its time runs out.
func _tick_wall(dt: float) -> void:
	if not carried.is_empty() and (wall.is_empty() or not bool(wall["sliding"]) or not m.verbs.walls.has(wall["w"])):
		_drop_carried()
	if wall.is_empty():
		return
	var w: Dictionary = wall["w"]
	if not m.verbs.walls.has(w):
		wall = {}
		e_t = 0.0
		return
	var ed := e_def()
	var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	if bool(wall["sliding"]) and st.has("bot_freeze_t") and float(wall["t"]) >= float(st["bot_freeze_t"]):
		st.erase("bot_freeze_t")
		e_recast()
	if bool(wall["sliding"]):
		wall["t"] = float(wall["t"]) + dt
		var dir: Vector2 = wall["dir"]
		var nmid := mid + dir * float(ed["slide"]) * dt
		if (m.world.is_void(nmid.x, nmid.y)
				or m.world.is_block(nmid.x, nmid.y)
				or float(wall["t"]) >= float(wall["slide_t"])):
			wall["sliding"] = false          # it stops where it got to and stands for the rest of its time
		else:
			mid = nmid
			_carry(w, dir, float(ed["slide"]))
	var gk := clampf(float(wall["t"]) / maxf(0.1, minf(float(ed["grow_t"]), float(wall["slide_t"]))), 0.0, 1.0)
	var ln := lerpf(float(ed["length"]), float(ed["length_max"]), gk)
	var side := Vector2(-(wall["dir"] as Vector2).y, (wall["dir"] as Vector2).x)
	w["a"] = mid - side * ln * 0.5
	w["b"] = mid + side * ln * 0.5
	w["len"] = ln
	# a hit whitens it for a beat
	if float(w["hp"]) < float(wall["hp0"]) - 0.01:
		wall["hp0"] = float(w["hp"])
		wall["hit"] = 1.0
	wall["hit"] = maxf(0.0, float(wall["hit"]) - dt * 4.0)
	var rise := clampf(float(wall["t"]) / 0.15, 0.0, 1.0) if not bool(wall.get("frozen", false)) else 1.0
	lk().keep(
			"wall", "wall", Vector3(mid.x, float(w["y"]), mid.y),
			{"a": w["a"], "b": w["b"], "y": float(w["y"]), "hit": float(wall["hit"]), "rise": maxf(rise, 0.1)})
	if is_instance_valid(w["node"]):
		(w["node"] as Node3D).visible = false

## A foe on the wall's front face rides along with it (it pushes and carries, it never passes through):
## Displace pushes it at the wall's speed until the wall stops (a player online, on their own game).
func _carry(w: Dictionary, dir: Vector2, speed: float) -> void:
	for f in m.foes_of(h.team):
		if f.dead or absf(f.pos.y - float(w["y"])) > 2.0 or carried.has(f.get_instance_id()):
			continue
		var p2 := Vector2(f.pos.x, f.pos.z)
		var off := p2 - Geometry2D.get_closest_point_to_segment(p2, w["a"], w["b"])
		if off.length() < f.r + 0.55 and off.dot(dir) > -0.1:
			var left := float(wall["slide_t"]) - float(wall["t"])
			carried[f.get_instance_id()] = m.displace.tow(f, null, {
				"mode": "push", "dir": [dir.x, dir.y], "spd": speed, "dist": speed * left, "dur": left + 0.1})

## The wall stopped sliding (or is gone): whoever it carried stays where it got to.
func _drop_carried() -> void:
	for rec in carried.values():
		m.displace.stop(rec)
	carried = {}

func in_e() -> bool: return not wall.is_empty() or not wall_cast.is_empty()

func _e_end() -> void:
	pass

func teardown() -> void:
	super.teardown()
	rinkrun = {}
	throw_t = -1.0
	rime = {}
	zones.clear()
	if look != null:
		look.teardown()
		look = null
	if ult_look != null:
		ult_look.teardown()
		ult_look = null

# ------------------------------------------------------------------ X: Rimelock
func ulk() -> UltLook:
	if ult_look == null:
		ult_look = UltLook.new(m, h)
	return ult_look


func ult_running() -> bool:
	return not rime.is_empty()


func cast_ult() -> bool: return HeroUlt.press(self, _start_rime)
func has_ult() -> bool: return true


## Sealed in: invulnerable and rooted, and the rink snaps out round her. Nothing else fires inside. Cast from
## a skate, her momentum carries her on as the shell closes (x.carry_t, slowing evenly from the skate's speed
## to a stop, so she travels speed * carry_t / 2), the rink riding with her; then she is rooted.
func _start_rime() -> bool:
	var carry := {}
	if not rinkrun.is_empty():
		carry = {"v": h.roll_speed, "dir": rinkrun["dir"]}
		_rinkrun_end(true)
	if spear_aim or rmb_down:
		spear_aim = false
		rmb_down = false
		AimKit.hide(h, "rmb")
	rime = {"t": 0.0, "at": h.pos, "slow": {}, "creak": 0.6, "carry": carry, "face": h.face}
	stats["rimes"] += 1
	_rime_hold_body()
	play("tm_rime" if carry.is_empty() else "tm_rime_carry")
	m.sfx("rime_lock", h.pos, 0.0, 1.0)
	m.fx.word(h.pos + Vector3(0, 3.0, 0), "RIMELOCK", col_of(x_def()), true)
	vfx("rime")
	return true


func _rime_hold_body() -> void:
	h.face = float(rime["face"])        # a statue: facing and pose locked from the cast frame
	h.inv_t = maxf(h.inv_t, 0.12)
	h.root_t = maxf(h.root_t, 0.12)
	if _rime_carrying():
		var carry: Dictionary = rime["carry"]
		h.roll_dir = carry["dir"]
		# the statue slides on its ice: the skate's speed, easing to a stop (item 65), no steering
		var k := clampf(float(rime["t"]) / float(x_def()["carry_t"]), 0.0, 1.0)
		h.roll_speed = float(carry["v"]) * (1.0 - k * k)
		h.roll_t = 0.1
		rime["at"] = h.pos
		return
	h.roll_t = 0.0
	h.vel.x = 0.0
	h.vel.z = 0.0


## Still sliding on the skate's momentum as the shell closes.
func _rime_carrying() -> bool:
	if rime.is_empty() or (rime["carry"] as Dictionary).is_empty():
		return false
	return float(rime["t"]) < float(x_def()["carry_t"])


## X again: in the last `late` seconds it cracks open early at late_k; any earlier the shell just breaks
## (no damage, no stun, no bond).
func ult_recast() -> bool:
	var xd := x_def()
	if float(rime["t"]) >= float(xd["hold"]) - float(xd["late"]):
		_rime_crash(float(xd["late_k"]))
	else:
		_rime_cancel()
	return true


func _tick_rime(dt: float) -> void:
	if rime.is_empty():
		return
	var xd := x_def()
	if h.out or h.downed:
		_rime_clear()
		return
	if bool(h.inp.get("dash", false)):
		_rime_skate_out()
		return
	rime["t"] = float(rime["t"]) + dt
	var t := float(rime["t"])
	var hold := float(xd["hold"])
	_rime_hold_body()
	_rime_no_glide()
	var at: Vector3 = rime["at"]
	var radius := float(xd["radius"])
	_rime_slow(at, radius, dt)
	_rime_look(at, radius, t / hold, dt)
	HeroVfx.of(m).hold(h, "rime_hold")
	if anim_id == "" or (anim_id != "tm_rime_hold" and m.time - anim_at >= KMovesCare.length(anim_id)):
		play("tm_rime_hold")
	if t >= hold:
		_rime_crash(1.0)


## No glide while sealed: over the abyss she falls, and only ending Rimelock (X or Shift) frees the glider.
## Each glide press is refused out loud.
func _rime_no_glide() -> void:
	h.glide_cd = maxf(h.glide_cd, 0.1)
	h.gliding = false
	var glide_now := bool(h.inp.get("glide", false))
	if glide_now and not glide_held and not h.grounded:
		h._ab_feedback("x", "deny")
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "NO GLIDE", Color("bff7ef"), false)
	glide_held = glide_now


## Shift while sealed: Rimelock ends as X again would (a late press still cracks it open) and she skates
## straight out at full speed, keeping any speed she had for CARRY_T; in the air the skate starts at once.
func _rime_skate_out() -> void:
	var had := Vector2(h.vel.x, h.vel.z).length()
	ult_recast()
	if h.dashes < 1.0:
		h._ab_feedback("dash", "deny")
		return
	_begin_skate()
	rinkrun["carry"] = maxf(had, float(dash_def().get("speed", 11.5)))


## Foes in the rink are Chilled and slowed more the longer they stay (a stacking slow up to slow_max).
func _rime_slow(at: Vector3, radius: float, dt: float) -> void:
	var xd := x_def()
	var slow: Dictionary = rime["slow"]
	for f in foes_in(at, radius):
		var key: int = f.get_instance_id()
		slow[key] = float(slow.get(key, 0.0)) + dt
		var k := minf(float(xd["slow_max"]), float(xd["slow_base"]) + float(xd["slow_per_s"]) * float(slow[key]))
		f.slow_k = maxf(f.slow_k if f.slow_t > 0.0 else 0.0, k)
		f.slow_t = maxf(f.slow_t, 0.2)
		add_chill(f)


func rime_slow_of(f: Ent) -> float:
	if rime.is_empty():
		return 0.0
	return float((rime["slow"] as Dictionary).get(f.get_instance_id(), 0.0))


## The rink (snaps out in snap_t, its cracks brighter as it builds), the countdown fill everyone sees,
## her frost bud and the creaks.
func _rime_look(at: Vector3, radius: float, k: float, dt: float) -> void:
	var xd := x_def()
	var snap := clampf(float(rime["t"]) / float(xd["snap_t"]), 0.0, 1.0)
	ulk().keep("rink", "rink", at, {"r": radius * lerpf(0.25, 1.0, snap), "crack": k})
	var close_t := float(xd["carry_t"]) if not (rime["carry"] as Dictionary).is_empty() else BUD_CLOSE_T
	ulk().keep("bud", "frostbud", h.pos, {"k": clampf(float(rime["t"]) / close_t, 0.0, 1.0)})
	AimKit.circle(h, "x", {"at": at, "r": radius, "fill": k, "all": true, "col": col_of(xd), "hot": k})
	rime["creak"] = float(rime["creak"]) - dt
	if float(rime["creak"]) <= 0.0:
		rime["creak"] = lerpf(0.8, 0.35, k)
		m.sfx("rime_creak", at, -8.0, 0.9 + 0.3 * k)
		var a := randf() * TAU
		vfx("rime_creak", at + Vector3(cos(a) * radius * 0.6, 0.0, sin(a) * radius * 0.6))


## The crash: a light pillar comes down on her, the shell bursts into shards, and every foe in the rink
## she can see takes the damage and an ice-block stun (k < 1: an early crack).
func _rime_crash(k: float) -> void:
	var xd := x_def()
	var at: Vector3 = rime["at"]
	var radius := float(xd["radius"])
	var stun := float(xd["stun"]) * k
	var stunned := 0
	for f in foes_in(at, radius):
		if not m.world.los(at, f.pos, at.y + 0.95):
			continue
		f.hurt(float(xd["dmg"]) * power("ult") * k, h, {"src": "abil", "ab": "ult", "stun": stun, "dr": true,
			"payoff": true, "tags": ["ult", "rimelock"]})
		add_chill(f)
		ulk().burst("block", f.pos, {"ent": f, "dur": maxf(0.3, stun)})
		stunned += 1
		HeroUlt.landed(self, f)      # the cast's best event (hit, knock, kill) pays the bond once
	last_stunned = stunned
	stats["crashes"] += 1
	ulk().burst("pillar", h.pos, {"r": 1.4, "dur": 0.5})
	ulk().burst("spikes", h.pos, {"r": 3.6, "dur": 0.55})
	vfx("rime_crash", h.pos, null, {"r": radius})
	m.sfx("rime_crash", at, 1.0, 1.0)
	play("tm_rime_crash")
	_rime_clear()


func _rime_cancel() -> void:
	stats["cancels"] += 1
	ulk().burst("spikes", h.pos, {"r": 1.6, "dur": 0.35})
	vfx("rime_cancel")
	m.sfx("rime_crack", h.pos, -3.0, 1.0)
	play("tm_rime_break")
	_rime_clear()


func _rime_clear() -> void:
	rime = {}
	h.inv_t = minf(h.inv_t, 0.05)
	h.root_t = 0.0
	AimKit.hide(h, "x")
	if ult_look != null:
		ult_look.drop("rink")
		ult_look.drop("bud")
		if anim_id == "tm_rime_hold":
			anim_id = ""


# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var x_ready := HeroUlt.ready(self)
	if rime.is_empty() and x_ready and los and dist < float(x_def()["radius"]) * 0.6 and tgt is Hunter:
		HunterKeys.ult_pressed(h)          # sealed in with a rival close: it cracks open on them
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 12.0 and dist > 3.0 and tgt is Hunter:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.6 + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.15      # held past the tap, then released
	if (int(h.slot_lv["kin"]) > 0
			and float(cd["e"]) <= 0.0
			and dist < 9.0
			and los
			and (h.hp < h.max_hp * 0.8 or randf() < 0.1)):
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
		st["bot_freeze_t"] = randf_range(0.15, 0.45)      # s into the slide the bot freezes the wall where it stands
	# skate in to the darts' range, or away when hurt
	if rinkrun.is_empty() and h.dashes >= 1.0 and h.grounded and randf() < 0.25:
		if h.hp < h.max_hp * 0.4:
			h.inp["move"] = -h.dir_to(tgt)
		elif dist > 8.0:
			h.inp["move"] = h.dir_to(tgt)
		else:
			return
		h.inp["dash"] = true
		bot_hold["dash"] = 0.8
