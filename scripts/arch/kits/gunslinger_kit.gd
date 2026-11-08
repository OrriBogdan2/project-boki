class_name GunslingerKit
extends ArchKit
## Vex (archetype id "gunslinger", medium): the ember-rifle skirmisher. docs/heroes/gunslinger.md
## has the per-slot table, the assumptions and the research notes (briefs/hero-ref/venator.md, owner notes).
##
## Loop: tap RMB and she flicks the Coin Blast, her big coin, from her cyborg left hand along the aim. Only a hit
## counts: a foe (Hunter, Boki or mob) it strikes is damaged and Dazed ("rat" Rattled in code) on the spot; terrain or
## the end of its 10.5 m is a quiet fizzle (no damage, no area, no refund). The rifle does +90% to a Dazed foe, in big
## gold numbers, and the string doesn't decay on them. Slipstep goes where you move and you keep
## shooting. Palm Lance: stand still, the left palm raised, while the line narrows, then a long beam out of the palm
## through walls. A knock
## gives Slipstep back (Hot Streak); abilities that land add a little lifesteal (Fever).

# her signature lime (Arch.color) and its slots: the palette's main, hot and deep in content/vfx/gunslinger.json
const LIME := Color("b8f03c")
const HOT := Color("eaffa8")
const DEEP := Color("4f8a12")
const GOLD := Color("ffcf3f")        # the Coin Blast's coin (unshaded: the toon light turns gold red-brown)
const GOLD_DARK := Color("d99a1e")   # its struck faces
const SCRAPE := Color("6b4a2e")      # the slide's dust scrape under her
const BURR_HIT_HEIGHT := 2.6         # m above a foe's feet the coin can still strike
const SKID_LEN := 2.2                # m, the faint streaks at a slide's start
const SKID_SPREAD := 0.28            # m off the path's centre line
const SKID_WIDTH := 0.1
const SKID_SECONDS := 0.45
const ECHO_GAP := 0.05               # s between her after-images on a slide or the air dash
const ECHO_ALPHA := 0.35             # see-through, so the trail never covers her live body
const ECHO_BACK := 0.35              # m behind her along her travel: the echoes trail, not overlap
const PIP_LIFT := 0.9                # m up the screen the Fever pips sit, clear of her cap and face
const COIN_FLIP := 22.0              # rad/s: the coin turns end over end in flight
const BRACKET_R := 1.25              # m: the firing brackets either side of her (footage: about 0.7 bh)
const BRACKET_DEG := 56.0            # each bracket's arc
const SPIN_REST := 0.5               # s without a round before the next string winds the barrels up again

var slide := {}                # {t, held, dir} while a Slipstep runs
## Coin Blasts in flight (id "burr"): {pos, dir, t, node, range, y0, g0, spin}.
var burrs: Array = []
var burr_pool: Array = []      # their nodes, reused
var needle := {}               # the Palm Lance's charge: {t}
var knocked := {}
var direct_hits := 0           # Coin Blasts that struck a foe (tests)
var fizzles := 0               # Coin Blasts that met terrain or ran out (tests)
var dazed_hits := 0            # rifle rounds on a Dazed foe (tests)
var skewers := 0               # Palm Lance payoffs
var needle_hits := 0
var needle_dir := Vector2.ZERO # tests: the line the last Palm Lance fired along
var last_dash_kind := ""
var last_shot := 0
var flicks := 0                # tests: coins flicked from the hand
var last_flick := Vector3.ZERO # tests: where the last one left
var echo_t := 0.0
var refill_part := 0.0         # rounds the resting drum has part-refilled
var dry := false               # the drum ran dry: no round until it is full again
var round_at := -9.0           # match time of her last rifle round (the firing brackets)
var ult: GunslingerUlt         # Cinderfall, her ultimate on X

func _setup() -> void:
	ult = GunslingerUlt.new(self)

func fx() -> VVFx:
	return VVFx.of(m)

func cast_ult() -> bool:
	return HeroUlt.press(self, ult.cast)

func has_ult() -> bool:
	return true

func full_ready() -> bool:
	return false

func res_text() -> String:
	return "%d" % int(res)

func fever_k() -> float:
	return float(res_def()["vamp"]) * floorf(res)

func ready_label() -> String:
	return ""

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	if res_wait <= 0.0 and res > 0.0:
		res = 0.0
	if not slide.is_empty():
		_tick_slide(dt)
	if not burrs.is_empty():
		_tick_burrs(dt)
	if not needle.is_empty():
		_tick_needle(dt)
	if ult.running():
		ult.tick(dt)
	_tick_lmb()
	_tick_mag(dt)
	_tick_brackets()
	_tick_echo(dt)
	_tick_trail()
	self_pips(int(res_def()["max"]), int(floor(res + 0.01)), false, dt, PIP_LIFT, 0.65)

func own_dash_trail() -> bool:
	return true

func dodge_anim() -> String:
	return "slide" if not slide.is_empty() else ""      # Slipstep: the kit move is the whole pose (no roll)

func shows_charge_ball() -> bool:
	return false                   # the Palm Lance charges green fire in her palm instead

## Moves whose hand leaves an ember swoosh: [hand, from s, to s].
const TRAILS := {"gunslinger_knock": ["r", 0.0, 0.25]}

func _tick_trail() -> void:
	var tr: Array = TRAILS.get(anim_id, [])
	var t := float(m.time) - anim_at
	if tr.is_empty() or h.anim == null or t < float(tr[1]) or t > float(tr[2]):
		return
	var hand: Node3D = h.anim.hand_l if String(tr[0]) == "l" else h.anim.hand_r
	if hand != null:
		fx().trail("vn%d" % h.get_instance_id(), hand.global_position, LIME, HOT, 0.24)

## Her after-image colour: a deeper ember, so the trail reads apart from her warm live body.
static func echo_col() -> Color:
	return LIME.lerp(DEEP, 0.5)

## Her own after-images on Slipstep and the air dash: her silhouette in ember, cooling to deep red.
func _tick_echo(dt: float) -> void:
	if h.roll_t <= 0.0 and slide.is_empty():
		echo_t = 0.0
		return
	echo_t -= dt
	if echo_t > 0.0:
		return
	echo_t = ECHO_GAP
	fx().echo(h, echo_col(), 0.4, ECHO_ALPHA, ECHO_BACK)

func teardown() -> void:
	super.teardown()
	for b in burrs:
		if b["node"] != null and is_instance_valid(b["node"]): (b["node"] as Node3D).visible = false
	burrs.clear()
	ult.clear()
	_end_needle()

func move_k() -> float:
	return 1.0 - float(e_def()["self_slow"]) if not needle.is_empty() else 1.0

## The rifle can't fire while a dry drum refills (_tick_mag).
func fire_ok() -> bool:
	return not dry

func add_fever(n := 1) -> void:
	res = minf(res_max(), res + float(n))
	touch_res(float(res_def()["wait"]))

## Dazed foes take +90% from the rifle: a crit-style big gold number, and the string's decay pauses.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if t is Hunter or t is Mob:
		if String(o.get("src", "")) == "shot" and not o.has("ab") and KitStatus.rattled(t):
			o["crit"] = true
			dazed_hits += 1
			h.sus_n = maxi(0, h.sus_n - 1)
			return dmg * (1.0 + float(res_def()["rattle_k"]))
	return dmg

func on_deal(t: Ent, dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		vfx("shot_hit", t.pos + Vector3(0, 1.0, 0), h.dir_to(t))
	if res > 0.0:
		h.heal(dmg * fever_k())
	if o.has("ab") and String(o.get("ab")) != "dodge":
		add_fever(1)
	if t is Hunter and ((t as Hunter).downed or t.hp <= 0.0) and not knocked.has(t.get_instance_id()):
		_on_knock(t)

## Hot Streak: a knock gives Slipstep back (the takedown heal is DashReset's); rank 3 also resets the Coin Blast.
func _on_knock(t: Ent) -> void:
	knocked[t.get_instance_id()] = true
	h.dashes = h.max_dashes()
	if rank("sec") >= 3:
		ch_rmb = float(rmb_charges())
		cd["rmb"] = 0.0
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+KNOCK", Color("8ff0a0"), false)
	m.sfx("vn_stim", h.pos, -3.0)
	play("gunslinger_knock")
	DashReset.cue(h)

# ------------------------------------------------------------------ LMB: the rifle's rounds
## Each round: a lime tracer with a white-hot core, a muzzle flash the size of the gatling's mouth, the shoulder kick.
func _tick_lmb() -> void:
	if h.shot_n == last_shot:
		return
	last_shot = h.shot_n
	if m.time - round_at > SPIN_REST:
		m.sfx("gunslinger_spinup", h.pos, -6.0)      # the shoulder cannon winds up as a string starts
	round_at = m.time
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		var sd: Dictionary = shots[i]
		if sd["by"] == h and not (sd["x"] as Dictionary).has("src"):
			vfx("shot", sd["start"], sd["vel"] as Vector2)
			HeroVfx.of(m).trail(h, "shot_trail", sd["node"])
			break
	if anim_id == "" or anim_id == "gunslinger_lmb" or m.time - anim_at > 1.2:
		play("gunslinger_lmb")

## While the rifle fires, two thin arcs bracket her left and right (your screen only; the footage's firing
## brackets), gone a beat after the trigger rests.
func _tick_brackets() -> void:
	if not _rifle_in_hand() or m.time - round_at > float(h.wpn["rate"]) + 0.1 or busy():
		return
	var d := h.aim_dir()
	for side in [-1.0, 1.0]:
		AimKit.arc_wall(h, "lmb_bracket%d" % int(side), {"dir": Vector2(-d.y, d.x) * side, "radius": BRACKET_R,
				"deg": BRACKET_DEG, "thick": 0.05, "panels": 1})

func _rifle_in_hand() -> bool:
	return h.wid == String(d.get("signature", ""))

## The drum (the source's rifle: 30 rounds that "rapidly reload when not firing"; there is no reload key): once no
## round has left for `refill_after` it refills at `refill_rate`, so a string after a pause starts full. Run dry,
## the trigger is dead until the drum is full again (held or not), then the string picks up and the drum clicks home
## (the reload look).
func _tick_mag(dt: float) -> void:
	if not _rifle_in_hand():
		dry = false
		return
	var mag := int(h.wpn["mag"])
	if h.ammo <= 0:
		dry = true
	if h.ammo >= mag or h.idle_fire < float(h.wpn["refill_after"]):
		refill_part = 0.0
		if h.ammo >= mag and dry:
			dry = false
			vfx("reload")
		return
	refill_part += float(h.wpn["refill_rate"]) * dt
	var add := int(refill_part)
	refill_part -= float(add)
	h.ammo = mini(mag, h.ammo + add)

# ------------------------------------------------------------------ dash: Slipstep
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex and h.dashes >= 1.0 and not h.grounded:
		# an air tap: a slide of 2/3 the full hold's distance (source patch notes), spending a charge
		h.dashes -= 1.0
		var ad := float(dd["slide"]) * float(dd.get("air_k", 0.667))
		var air_t := float(dd["slide_t"]) * 0.6
		travel(ad, air_t, {"invuln": float(dd["invuln"])})
		slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "fx": 0.0, "air": true, "len_t": air_t}
		play("gunslinger_dash")
		fx().echo(h, echo_col(), 0.5, ECHO_ALPHA, ECHO_BACK)
		m.sfx("vn_slide", h.pos, -4.0, 1.2)
		last_dash_kind = "air_slide"
		return true
	if use_ex:
		if not spend_dash(true):
			return true
		travel(float(h.cdat.get("ex_dist", 4.6)) * 0.9, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.08})
		play("gunslinger_dash_ex")
		fx().echo(h, echo_col(), 0.45, ECHO_ALPHA, ECHO_BACK)
		last_dash_kind = "air"
		return true
	if not spend_dash(false):
		return true
	var start := h.position
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"])})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "fx": 0.0}
	play("gunslinger_dash")
	# where it began: her ember after-image standing there (0.6 s), dust, and two faint skid streaks.
	# No rings or discs: those mean damage or an area in this game
	fx().echo(h, echo_col(), 0.6, ECHO_ALPHA, ECHO_BACK)
	_skid_streaks(start, h.roll_dir)
	m.fx.dust(h.pos, 10)
	m.sfx("vn_slide", h.pos, -4.0)
	return true

## Two short, low-contrast scrape lines on the ground along the first stretch of the slide.
func _skid_streaks(from: Vector3, dir: Vector2) -> void:
	var along := Vector3(dir.x, 0.0, dir.y)
	var side := Vector3(-dir.y, 0.0, dir.x) * SKID_SPREAD
	var low := Vector3(0.0, 0.05, 0.0)
	for sign_k in [-1.0, 1.0]:
		var begin: Vector3 = ground(from) + low + side * sign_k
		fx().smear(begin, begin + along * SKID_LEN, SCRAPE, SCRAPE.lightened(0.2), SKID_WIDTH, SKID_SECONDS)

func _slide_end() -> void:
	h.roll_t = 0.0
	if rank("dash") >= 3:
		h.add_buff("move_speed", 0.25, 2.0)
	var air := bool(slide.get("air", false))
	if air:
		h.vel.x *= 0.25          # an air slide stops short instead of carrying on
		h.vel.z *= 0.25
	var kind := "slide" if bool(slide.get("held", false)) else "step"
	st["last_dash"] = "air_slide" if air else kind
	last_dash_kind = String(st["last_dash"])
	slide = {}

## A tap: a skid that starts fast and bleeds off to a run over roll_t, covering `roll` m (you shoot
## through it); the speed falls linearly from the peak that covers the distance.
func _skid(t: float, dd: Dictionary) -> void:
	var feel := dash_feel()                 # the global dash feel, as travel() applies it
	var dur := float(dd["roll_t"]) * float(feel["time"])
	if t >= dur:
		_slide_end()
		return
	var run := float(h.cdat["speed"])
	var peak := 2.0 * float(dd["roll"]) * float(feel["dist"]) / dur - run
	h.roll_speed = lerpf(peak, run, t / dur)

func _tick_slide(dt: float) -> void:
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	slide["fx"] = float(slide["fx"]) - dt
	if float(slide["fx"]) <= 0.0:
		slide["fx"] = 0.06
		m.fx.dust(h.pos, 2)            # (the after-images and the scrape are _tick_echo's)
	if not bool(slide["held"]):
		if bool(slide.get("air", false)):
			if t >= float(slide["len_t"]):
				_slide_end()
			return
		var can_hold := not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded
		if t >= float(dd["tap_t"]) and not bool(slide.get("tap", false)):
			if held("dash") and can_hold:
				slide["held"] = true
				slide["t0"] = t
				h.dashes -= float(dd["hold_cost"])       # the longer slide takes longer to come back
				h.roll_dir = slide["dir"]
				h.move_kind = "dash"
				m.fx.dust(h.pos, 8)
				return
			slide["tap"] = true
		_skid(t, dd)
		return
	var st_t := t - float(slide["t0"])
	var dur := float(dd["slide_t"])
	if not held("dash") or st_t >= dur or h.stun_t > 0.0 or h.root_t > 0.0:
		_slide_end()
		return
	var k := 1.0 - st_t / dur
	h.roll_t = maxf(h.roll_t, dt * 1.5)
	h.roll_speed = float(dd["slide"]) / dur * (0.5 + k)
	h.inv_t = 0.0

# ------------------------------------------------------------------ RMB: Coin Blast
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		return
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	var n: Node3D = null
	for p in burr_pool:
		if is_instance_valid(p) and not (p as Node3D).visible:
			n = p
			break
	if n == null:
		n = _coin_mesh()
		burr_pool.append(n)
	n.visible = true
	n.scale = Vector3.ONE
	var at := palm_at()
	n.global_position = at
	var burr := {"pos": at, "dir": d, "t": 0.0, "node": n, "range": float(bd["range"]), "y0": at.y,
			"g0": ground(h.pos).y, "spin": 0.0}
	burrs.append(burr)
	play("gunslinger_rmb")
	flicks += 1
	last_flick = at
	vfx("rmb_flick", at, d)                       # a green muzzle flash off her fingers as the coin leaves
	HeroVfx.of(m).trail(h, "rmb_trail", n)        # its short green-fire trail

## Her cyborg left palm where the clip has it now (the "palm" anchor in content/vfx/gunslinger.json: a point on
## hand.L, read off the skeleton's pose), else a fixed point by her left shoulder.
func palm_at() -> Vector3:
	return HeroVfx.of(m).anchor_pos(h, "palm")

## The coin: a chunky gold disc 0.44 m across, a darker struck face each side and a green-fire rim
## ("Glow"). Solid colours, so it reads gold and lime on any ground.
func _coin_mesh() -> Node3D:
	var n := own_node()
	var spin := Node3D.new()
	spin.name = "Spin"
	n.add_child(spin)
	var body := Models.part(spin, Models.cyl(0.22, 0.22, 0.07, 20), solid_mat(GOLD))
	body.rotation.x = PI * 0.5                      # face on along the travel, so the flip shows its faces
	for side in [-1.0, 1.0]:
		var disc := Models.cyl(0.15, 0.15, 0.012, 16)
		var face := Models.part(spin, disc, solid_mat(GOLD_DARK), Vector3(0, 0, side * 0.035))
		face.rotation.x = PI * 0.5
	var rim := Models.part(spin, Models.cyl(0.245, 0.245, 0.04, 20), solid_mat(LIME))
	rim.rotation.x = PI * 0.5
	rim.name = "Glow"
	for ch in n.find_children("*", "GeometryInstance3D", true, false):
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func _tick_burrs(dt: float) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	for b in burrs.duplicate():
		var n: Node3D = b["node"]
		var p: Vector3 = b["pos"]
		var dir: Vector2 = b["dir"]
		b["t"] = float(b["t"]) + dt
		var flat := p + Vector3(dir.x, 0, dir.y) * float(bd["speed"]) * dt
		var dist: float = float(b["t"]) * float(bd["speed"])
		var u := clampf(dist / float(b["range"]), 0.0, 1.0)
		# a slight lob: up a little, then down onto the lane's end, the coin flipping end over end
		var gy := ground(flat).y
		flat.y = lerpf(float(b["y0"]), gy + 0.25, u * u) + 0.6 * sin(PI * u)
		var victim := _burr_victim(p, flat)
		if victim != null:
			burrs.erase(b)
			_direct_hit(b, victim, flat)
			continue
		var ledge: bool = m.world.ground_at(flat.x, flat.z) > float(b["g0"]) + 0.6
		if m.world.is_block(flat.x, flat.z) or ledge or dist >= float(b["range"]):
			burrs.erase(b)
			_fizzle(b, p)
			continue
		b["pos"] = flat
		b["spin"] = float(b["spin"]) + dt * COIN_FLIP
		if is_instance_valid(n):
			n.global_position = flat
			n.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
			(n.get_node("Spin") as Node3D).rotation.x = float(b["spin"])

## The first foe the coin touches between two steps, or null. Reach is the foe's body plus the lane's half width.
func _burr_victim(from: Vector3, to: Vector3) -> Ent:
	var reach_extra := float(rmb_def()["burr"]["lane_w"]) * 0.5
	var from_flat := Vector2(from.x, from.z)
	var to_flat := Vector2(to.x, to.z)
	var best: Ent = null
	var best_along := INF
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var height: float = to.y - f.pos.y
		if height < -0.3 or height > BURR_HIT_HEIGHT:
			continue
		var foe_flat := Vector2(f.pos.x, f.pos.z)
		var closest := Geometry2D.get_closest_point_to_segment(foe_flat, from_flat, to_flat)
		if closest.distance_to(foe_flat) > f.r + reach_extra:
			continue
		var along := from_flat.distance_to(closest)
		if along < best_along:
			best_along = along
			best = f
	return best

## A hit: it hurts and Dazes the foe it struck and is spent.
func _direct_hit(b: Dictionary, victim: Ent, at: Vector3) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
	direct_hits += 1
	vfx("rmb_hit", at, -(b["dir"] as Vector2))       # a small green burst back off the foe
	var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"]}
	victim.hurt(float(bd["hit_dmg"]) * power("sec"), h, o)
	daze(victim, float(bd["daze"]))

## Dazed: the foe takes more from the rifle and the Palm Lance (rattle_k in the data) and is slowed.
func daze(foe: Ent, seconds: float) -> void:
	KitStatus.apply(foe, "rat", seconds)
	fx().swirl(foe, LIME, HOT, seconds)

## Terrain or the lane's end: the coin is spent with a quiet puff where it stopped, and nothing else happens.
func _fizzle(b: Dictionary, at: Vector3) -> void:
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
	fizzles += 1
	vfx("rmb_fizzle", at, b["dir"] as Vector2)

# ------------------------------------------------------------------ E: Palm Lance
func cast_e() -> bool:
	if not needle.is_empty(): return false
	var ed := e_def()
	needle = {"t": 0.0}
	e_t = float(ed["charge"]) + 0.1
	m.sfx("vn_ion_charge", h.pos, -3.0)
	play("gunslinger_e")
	return true

## A Boki merge ends the Palm Lance's charge with no shot and cuts a Slipstep short (no refund, no speed buff).
func _drop_holds() -> void:
	_end_needle()
	if not slide.is_empty():
		slide = {}
		h.roll_t = 0.0
	rmb_down = false
	rmb_t = 0.0

func _end_needle() -> void:
	if needle.is_empty():
		return
	needle = {}
	e_t = 0.0
	AimKit.hide(h, "e")

func _tick_needle(dt: float) -> void:
	var ed := e_def()
	needle["t"] = float(needle["t"]) + dt
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
		_end_needle()
		return
	var k := clampf(float(needle["t"]) / float(ed["charge"]), 0.0, 1.0)
	# a bright wide line drawn full length at once, narrowing to a thin core as the cast completes
	var wide := beam_width()
	var lane := {"len": float(ed["range"]), "width": wide, "width_to": wide * 0.12, "k": k, "all": true}
	lane.merge({"col": LIME, "col2": HOT})
	AimKit.lane(h, "e", lane)
	if h.is_local() and m.cam:
		_needle_view(ed, dt)
	AimKit.charge(h, k, {"col": LIME, "col2": HOT})
	HeroVfx.of(m).hold(h, "e_charge", k)          # green fire gathering in her raised palm through the cast
	if float(needle["t"]) >= float(ed["charge"]) + 0.03:          # (a beat at full so the full tick plays)
		_end_needle()
		_fire_needle()

## The view pulls out along the line by how far away the cursor is (only the caster's camera): a hair point-blank,
## a little at mid range, the whole view_zoom only when far. The share eases toward that, so moving the cursor
## never snaps the view.
func _needle_view(ed: Dictionary, dt: float) -> void:
	var want := needle_zoom_k(h.flat_dist(h.inp.get("aim", h.pos)))
	var k := float(needle.get("view", want))
	k = lerpf(k, want, 1.0 - exp(-float(Tuning.of("vex")["e_zoom_ease"]) * dt))
	needle["view"] = k
	m.cam.cast_view(h.aim_dir(), float(ed["view_zoom"]) * k, float(ed["range"]) * k)

## The share of the Palm Lance's view pull at a cursor `dist` m away (tuning.json "vex"): 0..1.
static func needle_zoom_k(dist: float) -> float:
	var t := Tuning.of("vex")
	var near := float(t["e_zoom_near_m"])
	var mid := float(t["e_zoom_mid_m"])
	if dist <= mid:
		return lerpf(float(t["e_zoom_near_k"]), float(t["e_zoom_mid_k"]), smoothstep(near, mid, dist))
	return lerpf(float(t["e_zoom_mid_k"]), 1.0, smoothstep(mid, float(t["e_zoom_far_m"]), dist))

## The beam's full width in m: what it hits, so the line, the beam and the hit all agree.
func beam_width() -> float:
	return float(e_def()["width"]) * 2.0

func dash_charge() -> float:
	return -1.0

func charge_now() -> Array:
	if not needle.is_empty():
		return ["needle", clampf(float(needle["t"]) / float(e_def()["charge"]), 0.0, 1.0)]
	return super.charge_now()

func _fire_needle() -> void:
	var ed := e_def()
	var d := h.aim_dir()
	var a := palm_at()                        # the beam leaves her open palm; what it hits is still from her feet
	var L := float(ed["range"])
	var b := a + Vector3(d.x, 0, d.y) * L
	needle_dir = d
	# a taut lance of light (deep body, white-hot core, sparks shed along it), a palm bloom, recoil smoke round her
	vfx("e_fire", a, d, {"len": L, "r": beam_width()})
	h.impulse(-d * float(ed.get("recoil", 6.0)))                  # the recoil shoves her back a step
	var hits := 0
	var dmg0: float = float(ed["dmg"]) * power("kin")
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var v := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		var along := v.dot(d)
		if along < 0.0 or along > L + f.r: continue
		if absf(v.cross(d)) > float(ed["width"]) + f.r: continue
		if absf(f.pos.y - h.pos.y) > 2.6: continue
		var rat := KitStatus.rattled(f)
		var dmg: float = dmg0 * ((1.0 + float(ed["rattle_k"])) if rat else 1.0)
		var o := {"src": "abil", "ab": "k1", "tags": ["k1", "needle"]}
		if rat and f is Hunter: o["payoff"] = true
		f.hurt(dmg, h, o)
		needle_hits += 1
		vfx("e_hit", f.pos + Vector3(0, 1.0, 0), d)
		if f is Hunter:
			hits += 1
			if rat:
				skewers += 1
				# the word rides up the screen, clear of the damage number on the body
				payoff_fx(f.pos, "", LIME, "", h.dir_to(f), f)
				m.fx.word(f.pos + Vector3(0, 2.7, 0) + fx().screen_up() * 1.3, "SKEWERED", LIME, true)
				m.sfx("hero_skewer", f.pos, 0.0)
	if hits > 0:
		var maxcd := float(ed["cooldown"]) * cd_k("kin")
		var cut := float(ed["shave"])
		if rank("kin") >= 3:
			cut = float(ed["shave_rank3"]) * hits       # rank 3: 30% for every hunter hit
		cd["e"] = maxf(0.0, float(cd["e"]) - maxcd * cut)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not needle.is_empty() or rmb_down:
		h.inp["aim"] = aimp
		return
	if HeroUlt.ready(self) and tgt is Hunter and los and dist > 2.5 and randf() < 0.35:
		h.inp["aim"] = aimp
		if HunterKeys.ult_pressed(h):
			return
	var needle_ok := int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist > 4.0 and dist < 17.0
	if needle_ok and (KitStatus.rattled(tgt) or randf() < 0.15):
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.0 and randf() < 0.4:
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		return
	if h.hp < h.max_hp * 0.4 and h.dashes >= 1.0 and randf() < 0.1:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.5
