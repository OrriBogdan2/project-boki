class_name ArcherKit
extends ArchKit
## Hem (id archer, light; docs/heroes/archer.md, hero sheet pin.md). Spirit Walk (Shift), the Heavy Shot
## (RMB, hold only: a charged arrow that knocks the first foe back and stuns it into a wall), Hail Wall (E, a curved arc of rain at the cursor distance), and on X
## Starpiercer (level 6, PinUlt: three empowered piercing beams). R is the Merge.
## The bow (PinDraw): hold to draw through two stages with a filling aim line and a perfect-timing circle; tap and
## Empowered shots land at the cursor, Supercharged ones fly past it to max range; let go right as a stage
## comes up (a gold fletch burst) and the next draw is faster; hold too long and the arrow is overdrawn (half).
## Passive: Hawk Sense (hurt rivals are seen through cover). No resource meter: the old Focus and Deadeye were invented.

var rain := {}                 # the live Hail Wall: {a, b, t, tick, patter, tele}
var draw: PinDraw             # the bow's stages, reticle, perfect release and overdraw
var spirit: PinSpirit          # Shift: Spirit Walk
var fx: PinFx                  # Hem's pooled effects
var ult: PinUlt                # X: Starpiercer
var perfects: int:
	get: return draw.perfects if draw else 0
var pin_aim := false           # the Heavy Shot is being held (the needle on the bow and its growing bar show)
var needle: PinNeedle          # the Heavy Shot's needle while it's held
var sense_t := 0.0
var pins := 0                  # wall pins landed (tests)
var heavy_kicks := 0           # Heavy Shot releases that kicked the screen (tests)
var cremations := 0            # Heavy Shots that knocked a foe burning in the Hail Wall (tests)

func _setup() -> void:
	fx = PinFx.new(h)
	h.add_child(fx)
	self_nodes.append(fx)
	needle = PinNeedle.new()
	h.add_child(needle)
	self_nodes.append(needle)
	draw = PinDraw.new(self)
	ult = PinUlt.new(self)
	h.add_child(ult)
	self_nodes.append(ult)
	spirit = PinSpirit.new(self)

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t != null and t.team != h.team and String(o.get("src", "")) == "shot" and not o.has("ab"):
		_arrow_hit(t)

func _tick(dt: float) -> void:
	sense_t -= dt
	if sense_t <= 0.0:
		sense_t = 0.3
		_sense_injured()
	if pin_aim and rmb_down:
		_heavy_tele()
	if pin_aim and rmb_down and tells_visible():
		needle.hold(h.position, h.aim_dir(), heavy_k(), float(h.cdat.get("scale", 1.0)), dt)
	elif needle.visible:
		needle.put_away()
	if not rain.is_empty():
		_tick_rain(dt)
	draw.tick()
	ult.tick(dt)
	spirit.tick(dt)
	spirit.tick_orbs(dt)
	_tag_shots()
	fx.tick_shots()
	_tick_bow()

## The bow's own looks: the glowing thread string, and thread gathering at the nock while she draws.
func _tick_bow() -> void:
	if not tells_visible():
		return
	var vfx_on := HeroVfx.of(m)
	var drawing := h.draw_t >= 0.0
	vfx_on.hold(h, "string_draw" if drawing else "string_idle")
	if drawing:
		vfx_on.hold(h, "draw")
	if pin_aim and rmb_down:
		vfx_on.hold(h, "heavy_hold", heavy_k())
	if spirit.active():
		vfx_on.hold(h, "spirit")
	if ult.active():
		vfx_on.hold(h, "ult_armed")

## The player's own draw shows only on the filling line: no shared wind-up ring at her feet, ticks or ping.
## Anyone else still sees the ring (the wind-up tell), and the Heavy Shot keeps it.
func charge_now() -> Array:
	var cn := super.charge_now()
	return ["", -1.0] if h.is_local() and String(cn[0]) == "draw" else cn

## Her bow hand carries its own tell (PinFx's fletch glint), so the shared charge orb stays off.
func charge_orb() -> bool:
	return false

## Her dash after-image: green fletch streaks instead of the shared ghost.
func dash_afterimage() -> bool:
	fx.afterimage(h.position, h.face, float(h.cdat.get("scale", 1.0)))
	return true

## X: Starpiercer, the next shots empowered.
func cast_ult() -> bool: return HeroUlt.press(self, ult.cast)
func has_ult() -> bool: return true

func ult_running() -> bool:
	return ult.active()

## While Starpiercer is up the bow is the ult's: nock, then a beam (PinUlt.lmb).
func lmb_override(held: bool, dt: float) -> bool:
	return ult.lmb(held, dt)

## Hunter.trigger scales the bow's draw by this (the quick draw after a perfect release).
func draw_rate() -> float:
	return draw.rate()

## Hunter._loose asks once per arrow: where it goes and its damage factor (PinDraw.bonus).
func draw_bonus(t: float) -> float:
	return draw.bonus(t)

## Our shots the match just spawned get Hem's own look (PinFx): the bow's arrows by the kind PinDraw
## loosed, the Heavy Shot's gold arrow.
func _tag_shots() -> void:
	for s in m.shots:
		if s["by"] != h or (s["x"] as Dictionary).has("pin"):
			continue
		var x: Dictionary = s["x"]
		if x.get("cos", false):
			continue
		var kind := "arrow"
		if String(x.get("ab", "")) == "ultimate":
			kind = "ult"
		elif String(x.get("src", "")) == "abil" or x.has("ab"):
			kind = "heavy"          # (an ability's projectile carries its slot as "ab"; the bow's arrows have none)
		elif draw.pending != "":
			kind = draw.pending
		var arrow: Node3D = fx.skin(s, kind)
		if arrow != null:
			vfx("fire_" + kind, s["pos"], h.aim_dir(), {"follow": arrow})
	draw.pending = ""

## Passive, Hawk Sense: rivals under half health are seen through cover and fog within 22m.
func _sense_injured() -> void:
	var rd := res_def()
	for f in m.foes_of(h.team):
		var hurt_enough: bool = f.hp < f.max_hp * float(rd.get("sense_hp", 0.5))
		if f is Hunter and not f.dead and hurt_enough and h.flat_dist(f) < float(rd.get("sense_r", 22.0)):
			f.reveal_t = maxf(f.reveal_t, 0.4)

func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	if dmg > 0.5 and spirit.active():
		spirit.end("hit")

## One of the bow's arrows hit: the spent-arrow pool skips it; a Supercharged one bursts in a teal X-star.
func _arrow_hit(t: Ent) -> void:
	fx.note_hit(t.pos)
	var kind := ""
	for sid in fx.live:
		var e: Dictionary = fx.live[sid]
		if (e["pos"] as Vector3).distance_to(t.pos) < 2.8: kind = String(e["kind"])
	if kind == "":
		kind = draw.last_kind          # a fast arrow can be gone from the pool on the step it lands
	if kind == "super":
		vfx("super_hit", t.pos, h.dir_to(t))
	elif kind in ["arrow", "tap"]:
		vfx("arrow_hit", t.pos, h.dir_to(t))

# ------------------------------------------------------------------ dash: Spirit Walk
func on_dash(use_ex: bool) -> bool:
	var ex := use_ex and not h.gliding
	if not spend_dash(ex):
		return true
	if ex:
		# the long dash (in the air, or out of charges): Hem's own flick and tumble with her fletch
		# after-images (no bursts on a dash); 19 m/s, the base dash speed
		travel(float(h.cdat.get("ex_dist", 4.2)), 0.22, {"invuln": 0.1, "trail": "roll"})
		play("pin_flick")
		vfx("flick")
		st["last_dash"] = "flick"
		return true
	CombatBus.ability_used.emit(h, "spirit_walk", "dodge")
	spirit.start()
	return true

## While walking as a spirit she moves quicker; at rank 3 inside something she starts faster still and
## that fades with the walk. A draw right after a perfect release slows her less (wiki: perfect shots ease
## the self-slow). Holding the Heavy Shot slows her hard (pin.hold_move of her speed).
func move_k() -> float:
	var k := 1.0
	if spirit and spirit.active():
		k = float(dash_def().get("walk_k", 1.1)) + spirit.inside_boost()
	if draw and draw.quick and h.draw_t >= 0.0:
		k *= float(h.wpn.get("perfect_slow", 0.85)) / maxf(0.05, float(h.wpn.get("draw_slow", 0.7)))
	if pin_aim and rmb_down:
		k *= float(rmb_def()["pin"]["hold_move"])
	return k

# ------------------------------------------------------------------ RMB: Heavy Shot
## The Heavy Shot's cooldown drops by a flat "cd_per_rank" seconds a rank; the other slots keep the shared rule.
func cd_k(slot: String) -> float:
	if slot != "sec":
		return super.cd_k(slot)
	var cut := float(rmb_def().get("cd_per_rank", 3.0)) * float(rank("sec") - 1)
	return 1.0 - cut / float(rmb_def()["cooldown"])

## The press always starts a draw (in the air too): the Heavy Shot has no tap and no air variant.
func press_rmb() -> void:
	if busy():
		h._ab_feedback("sec", "deny")
		return
	if rmb_down:
		return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": false, "e": in_e(), "r": false, "full": full_ready()}

func rmb_hold_tick(t: float) -> void:
	if t > float(rmb_def()["hold"]) and not pin_aim:
		# the Heavy Shot's draw: the needle on the bow, a red bar growing from it (its own creak)
		play("arc_heavy_wind")
		anim_at = m.time - t          # on the hold's clock: the clip's full-draw key (1.1) lands with "full" (1.1)
		pin_aim = true
		m.sfx("pin_heavy_draw", h.pos, -6.0 if h.is_local() else -10.0)
		_heavy_tele()

const HEAVY_GOLD := Color("ff4a3a")      # (named for its old colour: red now)

## The Heavy Shot held: a thick red bar out of the bow that
## grows to 2 body heights, the cursor ring filling (AimKit; own player).
func _heavy_tele() -> void:
	var hk := heavy_k()
	AimKit.lane(h, "rmb_bar", {"len": 2.0 * AimKit.BH, "len0": 0.3, "k": hk, "width": 0.5, "fill": hk, "tip": true,
		"col": HEAVY_GOLD, "col2": Color("fff0b0")})
	AimKit.charge(h, hk, {"col": HEAVY_GOLD, "col2": Color("fff0b0")})
	fx.bow_glint_at(draw.bow_at(), 1.0 if hk >= 0.99 else 0.0, HEAVY_GOLD)

## The Heavy Shot charges from the hold threshold to full.
func rmb_charge_full() -> float:
	return float(rmb_def()["pin"]["full"])

func heavy_k() -> float:
	var pd: Dictionary = rmb_def()["pin"]
	var hold_t := float(rmb_def()["hold"])
	return clampf((rmb_t - hold_t) / maxf(0.05, float(pd["full"]) - hold_t), 0.0, 1.0)

## How far the Heavy Shot flies uncharged; rank 3 adds "range_rank3" metres.
func heavy_reach() -> float:
	var pd: Dictionary = rmb_def()["pin"]
	return float(pd["range"]) + (float(pd["range_rank3"]) if rank("sec") >= 3 else 0.0)

## The Heavy Shot can be held up to 3 s after it's full before it looses by itself (wiki patch 20.11.24).
func rmb_auto_t() -> float:
	return float(rmb_def()["pin"].get("max_hold", 3.0))

## A Boki merge ends every hold and channel of this kit with no shot: the bow draw (Hunter.draw_t, cleared by
## MergeKit.drop_class_holds; its reticle here), the Heavy Shot's hold and its gold telegraph, and Spirit Walk
## (Hunter.spirit_t; ending inside something still puts her back where she entered).
func _drop_holds() -> void:
	rmb_down = false
	h.draw_t = -1.0
	_drop_tele()
	draw.drop()
	spirit.end("merge")
	if ult: ult.drop()
	if anim_id in ["arc_draw", "arc_over", "arc_heavy_wind", "pin_roll", "pin_walk", "pin_ult_nock"]:
		anim_id = ""

func _drop_tele() -> void:
	pin_aim = false
	fx.bow_glint_at(Vector3.ZERO, 0.0, HEAVY_GOLD)
	needle.put_away()
	AimKit.hide(h, "rmb_bar")

func fire_rmb(c: Dictionary) -> void:
	_drop_tele()
	last_variant = String(c["variant"])
	if not c.get("hold", false):
		return                     # a tap before the draw starts looses nothing and costs nothing
	if not spend_rmb(): return
	var pd: Dictionary = rmb_def()["pin"]
	play("arc_heavy")
	_pin(aim(), clampf((float(c["t"]) - float(rmb_def()["hold"])) / maxf(0.05, float(pd["full"]) - float(rmb_def()["hold"])), 0.0, 1.0))

## The Heavy Shot: a held, charged arrow (0.5s -> full at 1.1s) that stops on the first foe, knocks it back by
## its charge and, driven into a wall within 3m, stuns (PINNED). Full charge is a heavy hit.
func _pin(a: Vector3, k: float) -> void:
	var pd: Dictionary = rmb_def()["pin"]
	var reach := heavy_reach()

	var dmg := lerpf(float(pd["dmg"][0]), float(pd["dmg"][1]), k)
	var push := lerpf(float(pd["push"][0]), float(pd["push"][1]), k)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(pd["speed"]), "range": reach * (1.0 + 0.2 * k), "size": lerpf(0.2, 0.34, k)},
		"effects": [{"type": "damage", "amount": dmg}, {"type": "push", "strength": push, "from": "caster"}]})
	var dir := Vector2(a.x - h.pos.x, a.z - h.pos.z).normalized()
	var extra := {"hit_extra": {"heavy": true}} if k >= 0.99 else {}
	extra["on_foe"] = func(f: Ent, _c: Dictionary):
		# the impact: a red-white burst, a white dust cloud as it's driven back, a white ring round it
		var at := f.pos + Vector3(0, 1.0, 0)
		fx.note_hit(f.pos)
		vfx("heavy_hit", f.pos, dir, {"k": k})
		f.flash_t = 0.2                      # a hit flash on the body
		# knocked while burning in the Hail Wall: Cremated (a burst of the blue fire)
		if not rain.is_empty() and _in_rain(f):
			cremations += 1
			f.hurt(float(e_def().get("cremate", 10.0)) * power("kin"), h, {"src": "abil", "ab": "signature", "tags": ["signature", "cremate"]})
			if "blight_t" in f: f.set("blight_t", maxf(float(f.get("blight_t")), float(e_def()["blight"]) + 1.5))
			vfx("cremate", f.pos, dir)
			m.fx.word(f.pos + Vector3(0, 2.4, 0), "CREMATED", Color("8ac8ff"), false)
		# driven into terrain within 3m: pinned (a stun)
		if _wall_behind(f, dir, float(pd["wall"])):
			pins += 1
			fx.stake(at + Vector3(dir.x, 0, dir.y) * 0.9, dir)
			vfx("heavy_pin", at + Vector3(dir.x, 0, dir.y) * 0.9, dir)
			if rank("sec") >= 3:
				h.dashes = minf(h.max_dashes(), h.dashes + 1.0)       # rank 3: a wall stun gives a dash charge
			f.hurt(float(pd["wall_mult"]) * dmg * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "pin"], "heavy": true})
			m.later(0.12, func():
				if is_instance_valid(f) and not f.dead:
					f.hurt(0.1, h, {"stun": float(pd["stun"]), "src": "abil", "ab": "utility", "tags": ["utility", "pin"], "exploit": true, "dr": true})
					m.fx.word(f.pos + Vector3(0, 2.2, 0), "PINNED", Feel.cat_color("control"), true)
					m.fx.dust(f.pos, 10))
	run_own(stg, cx("rmb", "heavy_shot", a, extra))
	vfx("heavy_go", h.pos, dir, {"k": k, "len": reach * (1.0 + 0.2 * k)})
	# the release burst sits on the aim line at the bow, bigger than any bow cue, and a screen kick along the shot
	fx.fletch_burst(draw.bow_at(), 1.4 + 0.8 * k, HEAVY_GOLD, 0.08, 0.14, 1.0, 5.0)
	heavy_kicks += 1

func _wall_behind(f: Ent, dir: Vector2, reach: float) -> bool:
	var g0: float = f.pos.y
	var k := 0.4
	while k <= reach:
		var q := f.pos + Vector3(dir.x, 0, dir.y) * k
		if m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > g0 + 0.8:
			return true
		k += 0.3
	return false

# ------------------------------------------------------------------ E: Hail Wall
## A wall of falling arrows on a curved arc round you (hero sheet: Rain of Arrows): centred on your aim at
## the cursor distance (clamped to rmin..reach), "deg" wide and "width" deep. Lobbed up first ("tell" s,
## everyone sees the arc), then it rains for "time" s: damage over time, a slow and a blight (healing
## barely takes, the blue burn) on foes inside.
func in_e() -> bool:
	return not rain.is_empty()

func _arc_deg() -> float:
	return float(e_def().get("deg", 120.0)) * (1.3 if rank("kin") >= 3 else 1.0)

func cast_e() -> bool:
	var ed := e_def()
	var d := h.aim_dir()
	var radius := clampf(AimMode.cursor_dist(h), float(ed.get("rmin", 2.0)), float(ed["reach"]))
	var c := AimMode.ground(m, h.pos + Vector3(d.x, 0, d.y) * radius)
	var tell := float(ed["tell"])
	var center := h.pos
	# the arrows go up first (everyone sees the arc), then the rain starts
	AimKit.arc_wall(h, "e", {"center": center, "dir": d, "radius": radius, "deg": _arc_deg(), "thick": float(ed["width"]), "panels": 7, "all": true, "dur": tell, "col": col_of(ed)})
	for i in 5:
		var u := (float(i) - 2.0) / 2.0 * deg_to_rad(_arc_deg()) * 0.4
		var dv := d.rotated(u)
		# (cosmetic: small and green so the five don't stack into one white blob at the bow; PinFx.lob draws
		# the arrows going up)
		var lob_v := dv * maxf(4.0, radius / tell)
		m.spawn_shot(h, h.pos + Vector3(0, 1.4, 0), lob_v, 0.0, tell, 0.05, PinFx.GREEN, {"lob": 3.5, "cos": true})
	fx.lob(h.pos + Vector3(0, 1.6, 0), d)
	vfx("hail_go", h.pos, d)
	play("arc_hail")
	var t := float(ed["time"])
	rain = {"center": center, "c": c, "d": d, "radius": radius, "t": t + tell, "start": tell, "tick": 0.0, "patter": 0.0}
	e_t = t + tell
	return true

func _in_rain(f: Ent) -> bool:
	var ed := e_def()
	return AimMode.in_arc(rain["center"], rain["d"], float(rain["radius"]), _arc_deg(), float(ed["width"]), f.pos, f.r) and absf(f.pos.y - (rain["c"] as Vector3).y) < 2.5

func _tick_rain(dt: float) -> void:
	var ed := e_def()
	rain["t"] = float(rain["t"]) - dt
	if float(rain["t"]) <= 0.0:
		rain = {}
		fx.rain_off()
		return
	if float(rain["start"]) > 0.0:
		rain["start"] = float(rain["start"]) - dt
		if float(rain["start"]) <= 0.0:
			fx.rain_on(rain["center"], rain["d"], float(rain["radius"]), _arc_deg(), float(rain["t"]))
			m.sfx("pin_rain", rain["c"], -3.0)
		return
	rain["patter"] = float(rain["patter"]) - dt
	if float(rain["patter"]) <= 0.0:
		rain["patter"] = randf_range(0.08, 0.14)
		m.sfx("pin_patter", rain["c"], -12.0, randf_range(0.85, 1.25))
	HeroVfx.of(m).hold(h, "rain", 0.0, {"at": rain["center"], "radius": rain["radius"], "deg": _arc_deg(),
			"dir_x": (rain["d"] as Vector2).x, "dir_y": (rain["d"] as Vector2).y})
	var inside: Array = []
	for f in m.foes_of(h.team):
		if f.hittable() and _in_rain(f): inside.append(f)
	fx.burn(inside)
	rain["tick"] = float(rain["tick"]) - dt
	if float(rain["tick"]) > 0.0:
		return
	rain["tick"] = float(ed["every"])
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": 0.8, "strength": float(ed["slow"])}]})
	for f in inside:
		KinExec.apply_foe(stg.effects, f, cx("e", "hail_wall", f.pos, {"at": f.pos}), f.pos, stg)
		if "blight_t" in f: f.set("blight_t", maxf(float(f.get("blight_t")), float(ed["blight"])))

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# Hail Wall across their path (lead them a little), from mid range
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["reach"]) + 1.0 and dist > 3.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.4; h.inp["sig"] = true; return
	# a full Heavy Shot first, unless they are already pinned
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 13.0 and tgt.stun_t <= 0.0:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = float(rmb_def()["pin"]["full"]) + 0.1
	# Spirit Walk away from a brawler
	if dist < 3.0 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true
