class_name DolmKit
extends ArchKit
## Dolm (medium): Tremor Sense, Rubble Fists (tap boulder / hold punch), Rubble Rush, Quakefall, Stone Row.
## docs/heroes/dolm.md. The loop: raise rocks (Stone Row, or the boulder Rubble Rush shoves out), then
## launch them with a punch, a slam or a dash into the enemy. A slam that knocks or kills resets itself.
##
## Rocks are Verbs walls that block movement (HeroZones.rock), so they respect collision, placement
## legality and the abyss edge; they are synced over Net as ["zone", ...] events.

const ROCK_PAY := "ROCKFALL"

var lmb_t := -1.0              # how long the attack key has been down (-1: not pressed)
var lmb_was := false
var rid_n := 0
var slam_hit := {}             # foe instance id -> time our slam hit it (a knock inside 6s resets Quakefall)
var dive := false              # the air Quakefall: slam on landing
var sight_t := 0.0
var shield_stacks := 0
var shield_at := -99.0
var launch_pay := 0            # launched rocks that hit a hunter (payoff counter)
# counters for the checks
var punches := 0
var boulders := 0
var launches := 0
var slams := 0
var dunks := 0
var wall_stuns := 0
var qf_resets := 0
var rocks_made := 0
var sight_pings := 0
var bridges := 0
var landslides := 0

func lmb_def() -> Dictionary: return d.get("lmb", {})
func rock_def() -> Dictionary: return d.get("rock", {})
func slam_def() -> Dictionary: return rmb_def()["slam"]

func _setup() -> void:
	pass

# ------------------------------------------------------------------ rocks
func my_rocks() -> Array:
	var out: Array = []
	for w in m.verbs.walls:
		if w.get("rock", false) and w.get("by") == h:
			out.append(w)
	return out

func rocks_up() -> int:
	return my_rocks().size()

func res_text() -> String: return "%d/6" % mini(6, rocks_up())

func _rock_cap() -> int:
	return int(rock_def()["cap"]) + (3 if rank("kin") >= 3 else 0)

func rock_mid(w: Dictionary) -> Vector3:
	var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	return Vector3(mid.x, float(w["y"]), mid.y)

func _new_rock(p: Vector3, dir: Vector2) -> bool:
	if not HeroZones.fits(m, p, h.pos.y):
		return false
	var mine := my_rocks()
	while mine.size() >= _rock_cap():
		var old: Dictionary = mine.pop_front()
		m.verbs._break_wall(old)
		HeroZones.tx(m, ["zone", "rockgo", String(old.get("rid", ""))])
	rid_n += 1
	var rd := rock_def()
	HeroZones.rock(m, h, p, dir, "%s.r%d" % [h.nid if h.nid != "" else str(h.get_instance_id()), rid_n], float(rd["len"]), float(rd["time"]), float(rd["hp"]))
	rocks_made += 1
	return true

## A rock leaves the ground along `dir` and flies; where it ends it bursts (HeroZones-free: the shot
## carries the kit's end callback). src: "punch" | "slam" | "dash".
func launch(w: Dictionary, dir: Vector2, src: String) -> void:
	var rd := rock_def()
	var mid := rock_mid(w)
	HeroZones.remove_rock(m, w)
	m.fx.burst(mid + Vector3(0, 0.6, 0), Color("d9b27a"), 14, 5.0, 0.4, 6.0, 1.1)
	_fire_rock(mid + Vector3(0, 0.9, 0), dir, float(rd["dmg"]) * power("kin"), src)
	launches += 1

func _fire_rock(start: Vector3, dir: Vector2, dmg: float, src: String) -> void:
	var rd := rock_def()
	var spd := float(rd["speed"])
	m.spawn_shot(h, start, dir * spd, dmg, float(rd["range"]) / spd, 0.45, Color("d9a35b"), {"kb": 5.0, "tracer": 1.0, "kx": func(s, at, e, why): _rock_end(s, at, e, why, src)})
	m.sfx("ab_throw", h.pos, -4.0, 0.6)

## Where a launched rock ends: it bursts, shreds what it caught and splashes whoever is next to it.
func _rock_end(s: Dictionary, at: Vector3, e: Ent, _why: String, _src: String) -> void:
	var rd := rock_def()
	var dmg := float(s["dmg"])
	var x: Dictionary = s["x"]
	if x.get("burst_done", false):
		return
	x["burst_done"] = true
	m.fx.ring(at, float(rd["blast"]), Color("d9a35b"), 0.3)
	m.fx.burst(at + Vector3(0, 0.4, 0), Color("c98d4a"), 22, 6.0, 0.5, 8.0, 1.1)
	m.sfx("boom", at, -6.0, 1.5)
	net_ring(at, float(rd["blast"]), Color("d9a35b"))
	for f in foes_in(at, float(rd["blast"])):
		if f == e: continue
		f.hurt(dmg * 0.6, h, {"src": "abil", "ab": "rock", "kb": Vector2(f.pos.x - at.x, f.pos.z - at.z).normalized() * 4.0})
		KitStatus.apply(f, "vul", float(rd["shred_t"]), float(rd["shred"]))
	if e != null and is_instance_valid(e) and e.team != h.team:
		KitStatus.apply(e, "vul", float(rd["shred_t"]), float(rd["shred"]))
		if e is Hunter:
			launch_pay += 1
			payoff_fx(e.pos, ROCK_PAY, Color("ffb36a"), "pay_rockfall", h.dir_to(e), e)

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	var n := rocks_up()
	res = float(n)
	self_pips(6, mini(6, n), false, dt)
	tell = "full" if n >= 6 else ("half" if n > 0 else "")
	if shield_stacks > 0 and m.time - shield_at > float(slam_def()["shield_t"]):
		shield_stacks = 0
	if dive:
		if h.grounded or h.downed:
			dive = false
			if h.grounded and not h.downed:
				_slam(0.5, true)
		else:
			h.vel.y = minf(h.vel.y, -float(slam_def()["dive_speed"]))
	# Tremor Sense: sneaking shows the foes in front, through walls and fog
	if h.crouch and h.is_local() and not h.downed:
		sight_t -= dt
		if sight_t <= 0.0:
			sight_t = 0.5
			stonesight()
	else:
		sight_t = 0.0

func stonesight() -> int:
	var dir := h.aim_dir()
	var n := 0
	for o in m.hunters:
		if o.team == h.team or not is_instance_valid(o) or o.dead or o.downed: continue
		var to := Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z)
		if to.length() > 16.0 or to.length() < 0.1: continue
		if dir.angle_to(to) > deg_to_rad(35.0): continue
		m.fx.ring(o.pos, 0.9, Color("ffb36a"), 0.55)
		n += 1
	sight_pings += n
	return n

# ------------------------------------------------------------------ LMB: boulder / punch
func punch_k() -> float:
	var ld := lmb_def()
	return clampf((lmb_t - float(ld["tap"])) / maxf(0.05, float(ld["full"]) - float(ld["tap"])), 0.0, 1.0)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "rubble_fists":
		return false
	var ld := lmb_def()
	var pressed := held and not lmb_was
	lmb_was = held
	if not h.can_fire():
		if lmb_t >= 0.0:
			lmb_t = -1.0; h.mel_hold = 0.0
		return true
	if h.ctrl != "local":
		# a bot: punches up close, throws boulders from range
		if held and h.fire_cd <= 0.0:
			var tg := _bot_target()
			if tg and h.flat_dist(tg) < 3.0: _punch(0.6)
			else: _boulder()
		return true
	if held:
		if lmb_t < 0.0:
			if h.fire_cd > 0.0:
				return true
			lmb_t = 0.0
		lmb_t += dt
		if lmb_t > float(ld["tap"]):
			h.mel_hold = punch_k()
			if anim_id != "dolm_wind" or m.time - anim_at > 3.0: play("dolm_wind")
		if lmb_t >= float(ld["full"]) + 0.5: _punch(punch_k())
	elif lmb_t >= 0.0:
		if lmb_t < float(ld["tap"]): _boulder()
		else: _punch(punch_k())
	elif pressed:
		pass
	return true

func _bot_target() -> Ent:
	var best: Ent = null; var bd := 12.0
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < bd: bd = h.flat_dist(f); best = f
	return best

func _boulder() -> void:
	var bd: Dictionary = lmb_def()["boulder"]
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(bd["rate"])
	h.idle_fire = 0.0
	boulders += 1
	play("dolm_lmb")
	var dir := h.aim_dir()
	var spd := float(bd["speed"])
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + dir.y * 0.6)
	m.spawn_shot(h, start, dir * spd, float(bd["dmg"]) * m.dmg_mult(h), float(bd["range"]) / spd, float(bd["size"]), Color("d9a35b"), {"kb": float(bd["kb"]), "tracer": 1.0})
	m.sfx("thump", h.pos, -3.0, 1.5)
	Juice.shot(h, start, dir)

## The punch: a cone in front. Foes are thrown back (into a wall: stunned) and rocks in reach fly.
func _punch(k: float) -> void:
	var pd: Dictionary = lmb_def()["punch"]
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(pd["rate"])
	h.idle_fire = 0.0
	punches += 1
	play("dolm_punch")
	var dir := h.aim_dir()
	var dmg: float = lerpf(float(pd["dmg"][0]), float(pd["dmg"][1]), k) * m.dmg_mult(h)
	var kb := lerpf(float(pd["kb"][0]), float(pd["kb"][1]), k)
	var fp := h.pos + Vector3(dir.x * 1.3, 1.0, dir.y * 1.3)
	m.fx.ring(h.pos + Vector3(dir.x * 1.2, 0.1, dir.y * 1.2), 1.4, Color("d9a35b"), 0.2)
	m.fx.burst(fp, Color("e8c07a"), int(8 + 10 * k), 4.0 + 4.0 * k, 0.3, 4.0, 1.0, Vector3(dir.x, 0.1, dir.y), 40.0)
	m.sfx("hit_heavy", h.pos, -2.0, 0.8)
	m.sfx("thump", h.pos, -1.0, 0.7)
	Feel.shake(m, "t3" if k > 0.6 else "t2", h, fp)
	for w in my_all_rocks_near(float(pd["rock_reach"]), dir):
		launch(w, dir, "punch")
	for f in foes_in(h.pos, float(pd["reach"])):
		var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		if to.length() > 0.2 and dir.angle_to(to) > deg_to_rad(float(pd["arc"]) * 0.5):
			continue
		var o := {"src": "abil", "ab": "lmb", "kb": dir * kb, "lift": 2.0, "melee": true, "wallstun": float(pd["wall_stun"]), "heavy": true}
		var hp0: float = f.hp
		f.hurt(dmg, h, o)
		if terrain_behind(f, dir, 1.6):
			wall_stuns += 1
			if not (f is Hunter):
				f.hurt(2.0, h, {"src": "abil", "ab": "lmb", "stun": float(pd["wall_stun"])})
			m.fx.word(f.pos + Vector3(0, 2.0, 0), "WALLED", Color("ffb36a"), false)
		if f.hp < hp0 and h.is_local() and m.cam: m.cam.punch(0.03)

func my_all_rocks_near(reach: float, dir: Vector2) -> Array:
	var out: Array = []
	for w in m.verbs.walls:
		if not w.get("rock", false) or int(w["team"]) != h.team:
			continue
		var mid := rock_mid(w)
		var to := Vector2(mid.x - h.pos.x, mid.z - h.pos.z)
		if to.length() <= reach and absf(mid.y - h.pos.y) < 2.0 and (to.length() < 0.5 or dir.angle_to(to) <= deg_to_rad(60.0)):
			out.append(w)
	return out

# ------------------------------------------------------------------ dash: Rubble Rush
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.6)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1}, true)
		return true
	if not spend_dash(false):
		return true
	var dist := float(dd["dist"]) * (float(dd["speed_k"]) if rank("dash") >= 3 else 1.0)
	var t := float(dd["time"]) * (float(dd["speed_k"]) if rank("dash") >= 3 else 1.0)
	play("dolm_dash")
	travel(dist, t, {"invuln": float(dd["invuln"]), "trail": "roll"})
	m.fx.dust(h.pos, 10)
	m.later(t + 0.03, func(): if is_instance_valid(h) and not h.downed: _landslide_launch())
	return true

func _landslide_launch() -> void:
	var dd := dash_def()
	landslides += 1
	var dir := h.aim_dir()
	var rd := rock_def()
	var start := h.pos + Vector3(dir.x * 0.9, 0.9, dir.y * 0.9)
	var spd := float(rd["speed"])
	m.fx.burst(start, Color("e8c07a"), 14, 5.0, 0.4, 6.0, 1.1, Vector3(dir.x, 0.1, dir.y), 35.0)
	m.spawn_shot(h, start, dir * spd, float(dd["dmg"]) * power("dash"), float(rd["range"]) / spd, 0.45, Color("d9a35b"), {"kb": float(dd["kb"]), "tracer": 1.0, "kx": func(s, at, e, why): _rock_end(s, at, e, why, "dash")})
	m.sfx("ab_throw", h.pos, -3.0, 0.55)

# ------------------------------------------------------------------ RMB: Quakefall
func rmb_charge_full() -> float:
	return float(rmb_def()["hold"]) + float(slam_def()["time"])

func rmb_auto_t() -> float:
	return rmb_charge_full() + 0.5

func rmb_hold_tick(t: float) -> void:
	if t > float(rmb_def()["hold"]) and anim_id != "dolm_rmb_wind":
		play("dolm_rmb_wind")

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		anim_id = ""      # (the held pose ends)
		return
	if c.get("air", false):
		dive = true
		play("dolm_rmb")
		m.sfx("ab_leap", h.pos, -2.0, 0.7)
		return
	var k := 0.0
	if c.get("hold", false):
		k = clampf((float(c["t"]) - float(rmb_def()["hold"])) / float(slam_def()["time"]), 0.0, 1.0)
	play("dolm_rmb")
	var delay := 0.16
	m.later(delay, func(): if is_instance_valid(h) and not h.downed: _slam(k, false))

func _slam(k: float, at_feet: bool) -> void:
	var sd := slam_def()
	var center := h.pos
	if not at_feet:
		var pw := HeroZones.walk(m, h.pos, aim(), float(sd["reach"]))
		center = pw["pos"] if pw["ok"] else h.pos
	slams += 1
	var radius := lerpf(float(sd["radius"][0]), float(sd["radius"][1]), k)
	var core := lerpf(float(sd["core"][0]), float(sd["core"][1]), k)
	var dmg := lerpf(float(sd["dmg"][0]), float(sd["dmg"][1]), k) * power("sec")
	m.fx.ring(center, radius, Color("ffb36a"), 0.35)
	m.fx.ring(center, core, Color("ffe0a0"), 0.2)
	m.fx.burst(center + Vector3(0, 0.3, 0), Color("c98d4a"), int(16 + 20 * k), 6.0 + 3.0 * k, 0.6, 8.0, 1.2)
	m.fx.flash(center + Vector3(0, 0.5, 0), Color("ffd9a0"), 1.0 + k, 0.08)
	m.sfx("ab_slam", center, 0.0, 0.8)
	m.sfx("boom", center, -4.0, 1.2)
	Feel.shake(m, "t3" if k > 0.5 else "t2", h, center)
	net_ring(center, radius, Color("ffb36a"))
	var gained := false
	for f in foes_in(center, radius, 3.2):
		var away := Vector2(f.pos.x - center.x, f.pos.z - center.z)
		away = away.normalized() if away.length() > 0.05 else h.aim_dir()
		var in_core: bool = Vector2(f.pos.x - center.x, f.pos.z - center.z).length() <= core + f.r
		var d2 := dmg
		var air := f is Hunter and (not (f as Hunter).grounded or (f as Hunter).gliding)
		var o := {"src": "abil", "ab": "rmb", "kb": away * float(sd["kb"]), "lift": 2.0, "heavy": true}
		if in_core:
			o["stun"] = lerpf(float(sd["stun"][0]), float(sd["stun"][1]), k)
			o["dr"] = true
		if air:
			d2 *= 1.0 + float(sd["dunk_k"])
			if m.world.is_void(f.pos.x, f.pos.z): d2 += float(sd["dunk_void"])
			o.erase("lift")
			dunks += 1
			m.fx.word(f.pos + Vector3(0, 2.0, 0), "DUNKED", Color("ffb36a"), true)
		slam_hit[f.get_instance_id()] = m.time
		f.hurt(d2, h, o)
		if air:
			f.vel.y = minf(f.vel.y, -22.0)      # spiked down (after the hit, which would lift it)
		gained = true
		if f.dead or (f is Hunter and (f as Hunter).downed):
			_reset_quake()
	for w in m.verbs.walls.duplicate():
		if not w.get("rock", false) or int(w["team"]) != h.team: continue
		var mid := rock_mid(w)
		var rel := Vector2(mid.x - center.x, mid.z - center.z)
		if rel.length() <= radius + 1.1 and absf(mid.y - center.y) < 2.0:
			launch(w, rel.normalized() if rel.length() > 0.2 else h.aim_dir(), "slam")
			gained = true
	if gained and rank("sec") >= 3:
		shield_stacks = mini(int(sd["shield_cap"]), shield_stacks + 1)
		shield_at = m.time
		h.shield = maxf(h.shield, float(sd["shield"]) * shield_stacks)
		h.shield_t = float(sd["shield_t"])

func _reset_quake() -> void:
	qf_resets += 1
	cd["rmb"] = 0.0
	ch_rmb = float(rmb_charges())
	armed_fx("QUAKE RESET", "sec")

func on_knock(t: Hunter, mine: bool) -> void:
	if mine and slam_hit.has(t.get_instance_id()) and m.time - float(slam_hit[t.get_instance_id()]) < 6.0:
		slam_hit.erase(t.get_instance_id())
		_reset_quake()

# ------------------------------------------------------------------ E: Stone Row
func cast_e() -> bool:
	var ed := e_def()
	var dir := h.aim_dir()
	var side := Vector2(-dir.y, dir.x)
	# rank 3 over the abyss: a temporary rock bridge instead of a wall
	if rank("kin") >= 3:
		var aimp := aim()
		if m.world.is_void(aimp.x, aimp.z) or HeroZones.walk(m, h.pos, aimp, float(ed["bridge_len"]))["stopped"] == "abyss":
			var pw := HeroZones.walk(m, h.pos, aimp, float(ed["bridge_len"]))
			var from: Vector3 = pw["pos"] if pw["ok"] else h.pos
			var n := HeroZones.bridge(m, h, from, dir, float(ed["bridge_len"]), 2.0, float(ed["bridge_t"]))
			if n > 0:
				bridges += 1
				play("dolm_e")
				m.sfx("ab_wall", from, -2.0, 0.6)
				m.fx.ring(from, 1.6, Color("d9b27a"), 0.3)
				return true
	var rows := 2 if rank("kin") >= 3 else 1
	# every spot is judged before the first rock goes up (rocks block sight and walking themselves)
	var spots: Array = []
	for r in rows:
		var base := h.pos + Vector3(dir.x, 0, dir.y) * (float(ed["dist"]) + 2.8 * r)
		var wk := HeroZones.walk(m, h.pos, base, float(ed["dist"]) + 2.8 * r)
		if not wk["ok"] or wk["stopped"] == "wall" or wk["stopped"] == "abyss":
			continue      # a wall or the abyss lies between you and the row
		for i in [-1, 0, 1]:
			var p := base + Vector3(side.x, 0, side.y) * float(ed["gap"]) * float(i)
			p.y = m.world.ground_at(p.x, p.z)
			# the rock must be reachable in line from the caster (no building through a wall)
			if m.world.los(h.pos + Vector3(0, 0.5, 0), p + Vector3(0, 0.5, 0), h.pos.y + 0.5):
				spots.append(p)
	var placed := 0
	for p in spots:
		if _new_rock(p, dir):
			placed += 1
	if placed == 0:
		if h.is_local() and m.hud: m.hud.toast_small("No room for rocks here", col_of(ed))
		return false
	play("dolm_e")
	m.sfx("ab_wall", h.pos, -1.0, 0.6)
	m.sfx("thump", h.pos, -3.0, 0.6)
	Feel.shake(m, "t2", h, h.pos)
	net_ring(h.pos, 2.0, col_of(ed))
	return true

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist > 4.0 and dist < 9.0 and los and randf() < 0.25:
		h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and dist < 3.4 and los:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = float(rmb_def()["hold"]) + float(slam_def()["time"]) * randf_range(0.3, 1.0)
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and dist > 5.0 and dist < 9.0 and los and randf() < 0.2:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["dash"] = true
