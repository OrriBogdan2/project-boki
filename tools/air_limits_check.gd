extends RefCounted
## --air-limits-check: owner items 162 and 162b (AirLimits), for every hero.
##  1. In the opening drop Shift, RMB, E, R, Space, G and LMB do nothing: still dropping, no dash, no cast, no
##     shot. Once landed, a dash goes off again.
##  2. A held ability (each kit's RMB and LMB hold, started on the ground, then carried off a ledge): the glider
##     never opens while it's held, and opens on its own once the move has ended with glide still held (or the
##     kit's move runs to the landing, as Tarek's Quakefall does).
##  3. A free fall with Shift mashed: no chain of dashes, never more than the hero's ground charges in FALL_S
##     (a kit's own air version, like Vex's air taps, spends those charges; item 183 audits each air dash).
##  4. The "In the air" tables of Vex, Kael, Lace, Cinder, Meeko and Tenzo (docs/heroes/*.md): LMB, RMB tap, RMB
##     hold and E cast mid-jump and mid-fall as on the ground (Kael's RMB goes to his own Air Slam slot), none
##     fire out of a glide on LMB (the glider shuts the weapon), and Tenzo's RMB folds the glider and slams.

const HEIGHT := 60.0
const HOLD_S := 0.35            # s a hold is charged on the ground before it's carried off the ledge
const GLIDE_HELD_S := 0.4       # s glide is held while the ability is still held
const OPEN_WAIT_S := 3.0        # s after the release the glider has to open in
const FALL_S := 1.5
const KEEP := 0.7                # of the speed on the step before the glider opens (as --airdash-glide-check)
## Vex, Kael, Lace, Cinder, Meeko, Tenzo
const SIX := ["gunslinger", "juggernaut", "archer", "ashwick", "tender", "dolm"]
const CAST_KEYS := ["fire", "sec", "sec_hold", "sig"]      # LMB, RMB tap, RMB hold, E
const CAST_S := 1.6              # s a cast is watched for (Meeko's Burrseed winds up for 1 s)
const CAST_HEIGHT := 40.0        # m above the pad: a fall or a glide that lasts the whole cast
const DROP_KEYS := ["dash", "sec", "sig", "ult", "jump", "throw", "fire"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AIRLIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(Match.DT)

func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 162, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(80, 0, 80))
	var w: World = m.world
	var hx := int(floor(hunter.pos.x))
	var hz := int(floor(hunter.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi])
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			w.stairs.erase(i)
			w.walls.erase(i)
			w.props.erase(i)
			w.bush.erase(i)
	hunter.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	_steps(m, 20)
	return m

func _clear(h: Hunter) -> void:
	for k in ["dash", "sec", "sec_hold", "sig", "ult", "jump", "throw", "fire", "glide", "glide_btn", "x_down"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

func _ready_all(h: Hunter) -> void:
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	for key in h.ak.cd:
		h.ak.cd[key] = 0.0
	h.ak.ch_rmb = float(h.ak.rmb_charges())

## 1. The opening drop ignores every key but steering.
func _drop(m: Match, home: Vector3, arch: String) -> void:
	var h: Hunter = m.player
	for key in DROP_KEYS:
		_clear(h)
		_ready_all(h)
		h.teleport(home + Vector3(0, HEIGHT, 0))
		h.vel = Vector3(4.0, -2.0, 0.0)
		h.grounded = false
		h.dropping = true
		h.diving = false
		h.gliding = true
		_steps(m, 2)
		var ammo0 := h.ammo
		var cd0: Dictionary = h.ak.cd.duplicate()
		var dashes0 := h.dashes
		h.inp[key] = true
		if key == "sec":
			h.inp["sec_hold"] = true
		_steps(m, 6)
		var acted := h.roll_t > 0.0 or h.dashes < dashes0 or h.ammo < ammo0 or h.ak.rmb_down or h.ak.cd != cd0
		ok(h.dropping and h.gliding and not acted, "%s: %s mid-drop does nothing (dropping %s, roll %.2f, cds %s)" % [
			arch, key, h.dropping, h.roll_t, h.ak.cd])
	_clear(h)
	h.teleport(home)
	h.vel = Vector3.ZERO
	h.dropping = false
	h.gliding = false
	_steps(m, 30)
	_ready_all(h)
	h.inp["move"] = Vector2(1, 0)
	h.inp["dash"] = true
	_steps(m, 2)
	ok(h.roll_t > 0.0 or h.ak.in_dash() or h.dashes < h.max_dashes(), "%s: landed, the dash works again" % arch)
	_clear(h)
	_steps(m, 40)

## 2. A hold carried into the air keeps the glider shut until its move is over.
func _hold(m: Match, home: Vector3, arch: String, slot: String) -> void:
	var h: Hunter = m.player
	_clear(h)
	h.teleport(home)
	h.vel = Vector3.ZERO
	_steps(m, 30)
	_ready_all(h)
	h.inp["aim"] = home + Vector3(8, 0.9, 0)
	var keys := ["fire"] if slot == "lmb" else ["sec", "sec_hold"]
	for k in keys:
		h.inp[k] = true
	_steps(m, int(HOLD_S / Match.DT))
	if not (h.ak.rmb_down if slot == "rmb" else not h.ak.chg.is_empty()):
		print("AIRLIM note %s %s: no hold to carry into the air (n/a)" % [arch, slot])
		_clear(h)
		_steps(m, 60)
		return
	h.teleport(h.pos + Vector3(0, HEIGHT, 0))
	h.grounded = false
	h.inp["glide"] = true
	h.inp["glide_btn"] = true
	var opened := false
	for i in int(GLIDE_HELD_S / Match.DT):
		m.step(Match.DT)
		opened = opened or h.gliding
	ok(not opened, "%s %s held in the air: the glider stays shut (move %s)" % [arch, slot, h.ak.anim_id])
	for k in keys:
		h.inp[k] = false
	var t := 0.0
	var locked_at_open := false
	var kit_move := false            # a kit's own move that runs to the landing (DolmKit's Quakefall)
	var before := 0.0
	while t < OPEN_WAIT_S and not h.gliding and not h.grounded:
		kit_move = h.ak.locks_glide()
		before = Vector2(h.vel.x, h.vel.z).length()
		m.step(Match.DT)
		t += Match.DT
		locked_at_open = AirLimits.glide_locked(h) and h.gliding
	ok((h.gliding and not locked_at_open) or (h.grounded and kit_move),
		"%s %s let go: the held glide opens once the move ends (%.2fs; gliding %s, landed %s, move %s)" % [
			arch, slot, t, h.gliding, h.grounded, h.ak.anim_id])
	if h.gliding:
		var now := Vector2(h.vel.x, h.vel.z).length()
		ok(now >= minf(before, Hunter.GLIDE_BOOST_MAX) * KEEP,
			"%s %s: the glide keeps the move's speed (%.1f -> %.1f m/s)" % [arch, slot, before, now])
	_clear(h)
	h.teleport(home)
	h.vel = Vector3.ZERO
	h.gliding = false
	_steps(m, 60)

## 3. Mashing Shift in a free fall.
func _fall(m: Match, home: Vector3, arch: String) -> void:
	var h: Hunter = m.player
	_clear(h)
	_ready_all(h)
	h.teleport(home + Vector3(0, HEIGHT, 0))
	h.vel = Vector3.ZERO
	h.grounded = false
	var starts := 0
	var was := false
	for i in int(FALL_S / Match.DT):
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = i % 6 == 0
		m.step(Match.DT)
		var rolling := h.roll_t > 0.0
		if rolling and not was:
			starts += 1
		was = rolling
	var allowed := int(h.max_dashes()) + (1 if h.ak.has_long_dash() else 0)      # the ground's charges + the long dash
	ok(starts <= allowed, "%s: Shift mashed in a free fall makes %d dash(es) (ground: %d)" % [arch, starts, allowed])
	_clear(h)
	h.teleport(home)
	h.vel = Vector3.ZERO
	_steps(m, 30)

## 4. One cast (key: "fire", "sec" tap, "sec_hold" held 0.3 s, "sig") from the ground, a jump's rise, a fall or a
## glide: {acted, cd (the cooldowns it spent), closed (a glider that was open shut)}.
func _cast(m: Match, home: Vector3, state: String, key: String) -> Dictionary:
	var h: Hunter = m.player
	_clear(h)
	h.teleport(home)
	h.vel = Vector3.ZERO
	h.gliding = false
	_steps(m, 40)
	_ready_all(h)
	h.inp["aim"] = home + Vector3(7, 0.0, 0)
	if state == "rise":
		h.inp["jump"] = true
		_steps(m, 4)
		h.inp["jump"] = false
	elif state != "ground":
		h.teleport(home + Vector3(0, CAST_HEIGHT, 0))
		h.grounded = false
		if state == "glide":
			h.vel = Vector3(3, 0, 0)
			h.inp["glide"] = true
			h.inp["glide_btn"] = true
			_steps(m, 20)
			h.inp["glide_btn"] = false
		_steps(m, 3)
	h.ak.anim_id = ""
	var cd0: Dictionary = h.ak.cd.duplicate()
	var was_glide := h.gliding
	var out := {"acted": false, "cd": [], "closed": false}
	var pad := "sec" if key.begins_with("sec") else key
	h.inp[pad] = true
	h.inp["sec_hold"] = key.begins_with("sec")
	for i in int(CAST_S / Match.DT):
		if i == (int(0.3 / Match.DT) if key == "sec_hold" else 8):
			h.inp[pad] = false
			h.inp["sec_hold"] = false
		m.step(Match.DT)
		out["acted"] = out["acted"] or h.ak.anim_id != ""
		out["closed"] = out["closed"] or (was_glide and not h.gliding)
	for c in h.ak.cd:
		if h.ak.cd[c] > cd0[c] + 0.05:
			out["cd"].append(c)
	out["acted"] = out["acted"] or not out["cd"].is_empty()
	_clear(h)
	return out

func _cast_table(m: Match, home: Vector3, arch: String) -> void:
	for key in CAST_KEYS:
		var ground: Dictionary = _cast(m, home, "ground", key)
		for state in ["rise", "fall", "glide"]:
			var got: Dictionary = _cast(m, home, state, key)
			var what := "%s %s %s" % [arch, key, state]
			var want: bool = ground["acted"]
			if key == "fire" and state == "glide":
				want = false                  # the glider shuts the weapon
			elif arch == "dolm" and key == "sig":
				if state == "rise":
					continue              # ground-only rocks: a jump's first inch fits, its apex may not
				want = false
			elif arch == "tender" and key.begins_with("sec") and state != "rise":
				continue                      # Burrseed's press is held for the landing (--dash-flow-check)
			ok(got["acted"] == want, "%s: %s as on the ground (ground %s, here %s %s)" % [
				what, "acts" if want else "does nothing", ground["acted"], got["acted"], got["cd"]])
			if arch == "juggernaut" and key.begins_with("sec") and want:
				ok("air" in got["cd"] and not "rmb" in got["cd"],
					"%s: the Air Slam's own slot, not the ground slam's (%s)" % [what, got["cd"]])
			if arch == "dolm" and key.begins_with("sec") and state == "glide":
				ok(got["closed"], "%s: the glider folds and the slam goes (decision: it never blocks it)" % what)
	_clear(m.player)
	m.player.teleport(home)
	_steps(m, 40)

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		var home: Vector3 = m.player.pos
		_drop(m, home, arch)
		_hold(m, home, arch, "rmb")
		_hold(m, home, arch, "lmb")
		_fall(m, home, arch)
		if arch in SIX:
			_cast_table(m, home, arch)
		m.queue_free()
		await main.get_tree().process_frame
	print("AIRLIM DONE, failures: %d" % bad)
	main.get_tree().quit()
