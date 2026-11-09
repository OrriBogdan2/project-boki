class_name Ent
extends Node3D
## Base for everything that moves and takes damage: hunters, kin and monsters.
## The simulation writes `pos`; the visual node is moved toward it every rendered frame.

const GRAV := 30.0

var m: Node = null          # the Match
var nid := ""
var team := -1
var kind := ""
var pos := Vector3.ZERO
var prev := Vector3.ZERO
var vel := Vector3.ZERO
var r := 0.4
var hp := 100.0
var max_hp := 100.0
var grounded := true
var dead := false
var face := 0.0             # yaw the model looks toward
var model: Node3D = null
var mats: Array = []
var flash_t := 0.0
var freeze_t := 0.0         # visual hit-pause
var burn_t := 0.0
var burn_dps := 0.0
var burn_by: Ent = null
var slow_t := 0.0
var root_t := 0.0
var stun_t := 0.0
var guard_t := 0.0          # taking less damage for a moment (Rock Guard)
var blight_t := 0.0         # venom's anti-heal: healing on this body is cut to 40% for a while
var guard_k := 0.0
var slow_k := 0.0           # how much speed the current slow takes away (0 = the body's usual slow)
var blight_k := 0.6         # how much healing the current blight cuts
var vuln_t := 0.0           # a vulnerable mark: takes vuln_k more damage (never above KinRules.VULN_MAX)
var vuln_k := 0.0
var dr := {}                # diminishing returns on crowd control: kind -> [applications, last time]
var dr_stun := false        # the running stun counts toward the immunity that follows it
var cc_immune_t := 0.0      # just came out of a stun: stuns and roots don't land (KinRules.STUN_IMMUNE)
var stacks := {}            # stack counts on this body, shared by every caster: key -> [count, time left] (Stacks)
var marks := {}             # combo setups on this body: status -> {by, owner, until}
var squash := 0.0           # landing / hit squash for the model
var remote := false         # driven by another player's game
var last_hit_by: Ent = null
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_t := -1.0
var net_seen := 0.0

func setup(match_node: Node, id: String) -> void:
	m = match_node
	nid = id

func set_model(n: Node3D) -> void:
	if model:
		model.queue_free()
	model = n
	add_child(n)
	mats = n.get_meta("mats", [])

func teleport(p: Vector3) -> void:
	pos = p
	prev = p
	position = p

func ground() -> float:
	var g: float = m.world.ground_at(pos.x, pos.z)
	var st = m.get("skytrain")
	if st:
		# the sky train's cars are ground too; riding one under a bridge, the bridge is overhead, not underfoot
		var d: float = st.deck_y(pos)
		if d > World.VOID + 1.0 and (g < d or g > pos.y + 0.9):
			g = d
	return StoneStand.top_under(m.world.dyn_walls, pos, r, g)

## The height shots and blasts aim at to hit this body. (A hunter who has dropped below an
## island's lip is hit through the balloon floating at ground level above them.)
func hit_y() -> float:
	return pos.y

func over_void() -> bool:
	if not m.world.is_void(pos.x, pos.z):
		return false
	var st = m.get("skytrain")
	if st and st.deck_y(pos, 3.0) > World.VOID + 1.0:
		return false
	# a standable rock under the feet is ground (Tarek's Basalt Spine over the abyss)
	return StoneStand.top_under(m.world.dyn_walls, pos, r, World.VOID) <= World.VOID + 1.0

func flat_dist(o) -> float:
	var p: Vector3 = o.pos if o is Ent else o
	return Vector2(p.x - pos.x, p.z - pos.z).length()

func dir_to(o) -> Vector2:
	var p: Vector3 = o.pos if o is Ent else o
	return Vector2(p.x - pos.x, p.z - pos.z).normalized()

func alive() -> bool:
	return not dead

func hittable() -> bool:
	return not dead

## Generic damage. opts: kb (Vector2 impulse), lift, crit, src ("shot","kin","mob","boom","fall"), burn, slow, root
func hurt(dmg: float, by: Ent, opts := {}) -> float:
	if dead or dmg <= 0.0:
		return 0.0
	# the Demo match: a fresh lander who hasn't started anything takes no damage (Match.demo_shielded)
	if m is Match:
		var mt := m as Match
		if by and by == mt.player and self != mt.player:
			mt.player_engaged = true
		if mt.demo_shielded(self):
			return 0.0
	if remote:
		# someone else's game owns this body: show the hit here, let the owner apply it
		if m.net_send_hit(self, dmg, by, opts):
			flash_t = 0.12
			freeze_t = 0.04
			m.on_damage(self, by, dmg, opts)
			return dmg
		return 0.0
	# a combo: a status your partner (or you) set up pays off on this hit
	if by and not opts.has("combo") and not marks.is_empty():
		dmg = Combos.payoff(self, by, dmg, opts)
	if guard_t > 0.0:
		dmg *= 1.0 - guard_k
	if vuln_t > 0.0:
		dmg *= 1.0 + minf(vuln_k, KinRules.VULN_MAX)
	# archetype passives: what the attacker's kit adds (a Thief's Marks), what ours takes off
	# (Iron Hide, an Interpose guard, an unstoppable Avalanche)
	var bk = by.get("ak") if by and is_instance_valid(by) else null
	if bk:
		dmg = bk.outgoing(self, dmg, opts)
	var mk = get("ak")
	if mk:
		var io: Array = mk.incoming(by, dmg, opts)
		dmg = float(io[0]); opts = io[1]
		if dmg <= 0.0:
			return 0.0
	var d := _mitigate(dmg, by, opts)
	if d <= 0.0:
		return 0.0
	hp -= d
	last_hit_by = by
	flash_t = 0.12
	freeze_t = 0.05 if d >= 10.0 else 0.03
	squash = 0.1
	if opts.has("kb") or float(opts.get("lift", -1.0)) > 0.0:
		if "knock_steer" in self:
			set("knock_steer", float(opts.get("kbi", 0.3)))
		impulse(opts.get("kb", Vector2.ZERO), opts.get("lift", -1.0))
	# recall weakness (just based to a teammate): the crowd control you apply is half as strong
	var cc_k := 1.0
	var cred = by.owner_h if by is Kin and by.owner_h else by
	if cred and "weak_t" in cred and float(cred.weak_t) > 0.0:
		cc_k = 0.5
		opts = opts.duplicate()
		for st0 in ["slow", "root", "stun"]:
			if opts.has(st0): opts[st0] = float(opts[st0]) * cc_k
	# crowd control from abilities ("dr" in opts) has diminishing returns per target (KinRules)
	var use_dr := bool(opts.get("dr", false))
	if use_dr:
		opts = opts.duplicate()
		for st1 in ["stun", "root", "slow"]:
			if float(opts.get(st1, 0.0)) > 0.0:
				opts[st1] = cc_dr(st1, float(opts[st1]))
	if opts.get("burn", 0.0) > 0.0:
		add_burn(float(opts["burn"]), float(opts.get("burn_for", 3.0)), by)
	if opts.get("slow", 0.0) > 0.0:
		add_slow(float(opts["slow"]), float(opts.get("slow_k", 0.0)))
	if opts.get("root", 0.0) > 0.0:
		root_t = Stacks.merge_time("root", root_t, float(opts["root"]))
	if opts.get("blight", 0.0) > 0.0:
		blight_t = maxf(blight_t, float(opts["blight"]))
	if opts.get("stun", 0.0) > 0.0:
		stun_t = Stacks.merge_time("stun", stun_t, float(opts["stun"]))
		if use_dr: dr_stun = true
	for st in ["stun", "root", "slow", "burn"]:
		if float(opts.get(st, 0.0)) > 0.0:
			CombatBus.status_applied.emit(self, st, by, float(opts[st]))
	m.on_damage(self, by, d, opts)
	# kin learn from fighting: count the hits and knockouts they land for their owner
	if opts.get("src", "") == "kin":
		var kn = by.kin if by is Hunter and by.kin else (by if by is Kin else null)
		if kn:
			kn.st_hits += 1
			if hp <= 0.0: kn.st_kos += 1
	if hp <= 0.0:
		_on_zero(by, opts)
	return d

## A slow of strength `k` (0 = this body's usual) lands: the strongest running slow wins, the time is the
## longer of the two (status_stacking.json). Two slows never add or multiply.
func add_slow(secs: float, k := 0.0) -> void:
	if slow_t > 0.0 and (slow_k > 0.0 or k > 0.0):
		k = Stacks.merge_k("slow", _slow_or_usual(slow_k), _slow_or_usual(k))
	slow_k = k
	slow_t = Stacks.merge_time("slow", slow_t, secs)

func _slow_or_usual(k: float) -> float:
	return k if k > 0.0 else KinRules.DEFAULT_SLOW

## A burn of `dps` lands: the strongest burn wins, the time is the longer, and the one who set the
## strongest takes the credit (status_stacking.json).
func add_burn(dps: float, secs: float, by: Ent) -> void:
	if burn_t <= 0.0 or dps >= burn_dps:
		burn_by = by
	burn_dps = Stacks.merge_k("burn", burn_dps if burn_t > 0.0 else 0.0, dps)
	burn_t = Stacks.merge_time("burn", burn_t, secs)

func _mitigate(dmg: float, _by: Ent, _opts: Dictionary) -> float:
	return dmg

## Diminishing returns (KinRules.DR_STEPS): how long a stun, root or slow of `dur` really lasts on
## this body, counting it. A stun or root right after a stun doesn't land at all (cc_immune_t).
## Topping up a slow that's still running doesn't count as a new one.
func cc_dr(kind: String, dur: float) -> float:
	if dur <= 0.0:
		return 0.0
	if kind in ["stun", "root"] and cc_immune_t > 0.0:
		return 0.0
	var now: float = float(m.time) if m else 0.0
	var st: Array = dr.get(kind, [0, -1e9])
	if now - float(st[1]) > KinRules.DR_WINDOW:
		st = [0, -1e9]
	var steps: Array = KinRules.DR_STEPS[kind]
	var n := int(st[0])
	if kind == "slow" and slow_t > 0.0 and n > 0:
		n -= 1                 # a refresh of the same slow
	else:
		st[0] = n + 1
	st[1] = now
	dr[kind] = st
	return dur * float(steps[mini(n, steps.size() - 1)])

## Speed multiplier from a slow: its own strength if it has one, else this body's usual slow.
func slow_mult(usual: float) -> float:
	if slow_t <= 0.0:
		return 1.0
	return 1.0 - slow_k if slow_k > 0.0 else usual

func _on_zero(_by: Ent, _opts: Dictionary) -> void:
	die()

func die() -> void:
	dead = true

func mass() -> float:
	return 1.0

var kb_time := -9.0

func impulse(kb: Vector2, lift := -1.0) -> void:
	var ms := mass()
	if kb.length() / ms > 4.0 and m: kb_time = m.time
	vel.x += kb.x / ms
	vel.z += kb.y / ms
	var s := kb.length() / ms
	if lift >= 0.0 or s > 6.0:
		var up := lift / ms if lift >= 0.0 else s * 0.45
		vel.y = maxf(vel.y, minf(9.0, up))
		grounded = false

## Gravity and landing for bodies that don't need hunter physics.
func body_vertical(dt: float) -> void:
	var g := ground()
	if grounded and g < pos.y - 0.05:
		grounded = false
		vel.y = minf(vel.y, 0.0)
	if not grounded:
		vel.y -= GRAV * dt
		pos.y += vel.y * dt
		if g > World.VOID + 1.0 and vel.y <= 0.0 and pos.y <= g and pos.y > g - 1.2:
			pos.y = g
			vel.y = 0.0
			grounded = true
			squash = 0.2
	else:
		pos.y = g
	# over the void the abyss takes you a few metres under the islands around (World.abyss_floor)
	if pos.y < -40.0 or (not grounded and g <= World.VOID + 1.0 and pos.y < m.world.abyss_floor(pos.x, pos.z)):
		fall_out()

func fall_out() -> void:
	m.on_fell(self)

## Horizontal move with walls and rocks; returns true if it bumped something.
func slide(dt: float, guard := false) -> bool:
	var bumped := false
	# rocks and trees: pushed straight out of them (sliding round), never caught on a corner
	var tgt := Vector2(pos.x + vel.x * dt, pos.z + vel.z * dt)
	var po: Vector2 = m.world.push_out_blocks(tgt.x, tgt.y, r, pos.y)
	if po.distance_squared_to(tgt) > 1e-10:
		var bn := (po - tgt).normalized()
		var hv := Vector2(vel.x, vel.z)
		if hv.dot(bn) < 0.0:
			hv -= bn * hv.dot(bn)
			vel.x = hv.x; vel.z = hv.y
		tgt = po
		bumped = true
	var nx := tgt.x
	var b1: float = m.world.occupy(nx, pos.z, r, pos.y, guard)
	if b1 == 0.0:
		pos.x = nx
	else:
		vel.x *= -0.1; bumped = true
	var nz := tgt.y
	var b2: float = m.world.occupy(pos.x, nz, r, pos.y, guard)
	if b2 == 0.0:
		pos.z = nz
	else:
		vel.z *= -0.1; bumped = true
	return bumped

func tick_status(dt: float) -> void:
	if flash_t > 0.0: flash_t -= dt
	if freeze_t > 0.0: freeze_t -= dt
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0: slow_k = 0.0
	if root_t > 0.0: root_t -= dt
	if cc_immune_t > 0.0: cc_immune_t -= dt
	if vuln_t > 0.0: vuln_t -= dt
	if stun_t > 0.0:
		stun_t -= dt
		if stun_t <= 0.0 and dr_stun:
			# coming out of an ability's stun: a moment where nothing can stun or root you again
			dr_stun = false
			cc_immune_t = KinRules.STUN_IMMUNE
	if guard_t > 0.0: guard_t -= dt
	if blight_t > 0.0: blight_t -= dt
	Stacks.tick(self, dt)
	if burn_t > 0.0 and not dead:
		burn_t -= dt
		if not remote:
			hp -= burn_dps * dt
			if int(burn_t * 4.0) != int((burn_t + dt) * 4.0):
				m.fx.number(pos + Vector3(0, 1.4, 0), burn_dps * 0.25, Color("ff9a4a"), false)
			if hp <= 0.0:
				_on_zero(burn_by, {"src": "burn"})

## Proxies glide toward the last position their owner reported.
func net_follow(dt: float) -> void:
	prev = pos
	if net_t < 0.0:
		return
	var age := clampf(m.time - net_t, 0.0, 0.25)
	var tgt := net_pos + net_vel * age
	if pos.distance_to(tgt) > 4.0:
		pos = tgt
	else:
		pos = pos.lerp(tgt, 1.0 - exp(-14.0 * dt))
	vel = net_vel

## Called every rendered frame. alpha blends between the last two simulation steps.
var lod_dt := 0.0       # frame time a far-away entity's visuals skipped (Match renders it less often)
var _flash_set := -1.0
var _flash_n := -1
## Presentation only: a hit shoves the model a little along the hit (Juice.hit adds to it) and it
## springs back; during a hit's freeze the model holds where it was and shivers along that line.
var flinch := Vector3.ZERO
var _held := Vector3.INF
func render(delta: float, alpha: float) -> void:
	if freeze_t <= 0.0 or _held == Vector3.INF:
		_held = prev.lerp(pos, alpha)
	if flinch.length_squared() > 0.0001:
		var fo := flinch
		if freeze_t > 0.0: fo *= 1.0 if (Engine.get_frames_drawn() & 1) == 0 else -0.6
		position = _held + fo
		flinch *= exp(-delta * 16.0)
	else:
		flinch = Vector3.ZERO
		position = _held
	squash = maxf(0.0, squash - delta * 2.5)
	var f := clampf(flash_t / 0.12, 0.0, 1.0)
	# (only when it changes: most frames nothing is flashing, and every set is a render-server call)
	if f != _flash_set or mats.size() != _flash_n:
		_flash_set = f
		_flash_n = mats.size()
		for mt in mats:
			mt.set_shader_parameter("flash", f)
