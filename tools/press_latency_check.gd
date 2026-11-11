extends RefCounted
## --press-latency-check: frames from a key press to the first frame its result shows, for every hero's
## LMB, RMB, E, R, dash and jump at 60 and 144 Hz. It drives Match._process (the real path: Input actions,
## _gather_input, the fixed 60 Hz steps, the interpolated render) one call per engine frame at the case's
## refresh rate and stamps two frames per press: "sim", the first frame the simulation acted on it (a shot,
## a charge spent, a cast, a dash or jump under way, a draw or wind-up started), and "vis", the first frame
## something shows on screen (a shot or node spawned, the hunter's rendered position moving, the cast or
## kit-move pose, a swing, the bow draw, the muzzle flash). Frame 0 is the frame of the press.
## Taps are 33 ms (2 frames at 60 Hz, 5 at 144). An RMB with a hold variant (archetype rmb "hold") and a
## sword with a charge (weapon "charge_time") go off on the release by design: those are stamped from the
## release, and the press-to-first-sign frame is printed beside them. At 144 Hz each press is tried at
## every phase of the 60 Hz accumulator (0, 1 and 2 frames into a tick) and the latest kept.
## Budget: 2 frames at 60 Hz, the same 33 ms at 144 Hz (4 frames). The findings and the per-hero table
## are in docs/MOVEMENT_FEEL.md ("Press to picture"). It never touches the save.
##
## Prints "PRESS <hz>Hz <hero> <key> sim <n> vis <n> (<what>) [press->sign <n>]  allow <= N  ok|FAIL" per
## case and "PRESS LATENCY CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var P: Hunter
var T: Hunter                # a foe 4 m ahead, so hooks, marks and shots have something to land on
var main: Node
var flat := Vector3.ZERO     # where this press happens
var spots: Array = []        # flat spots far apart; each press takes the next, away from the last one's leftovers
var spot_i := 0
var noisy := false           # nodes were still spawning on their own before the press: the node signal is off
var unrest := ""             # the hunter was not at rest when the press came (the case is void): what still moved
var km_last := {}            # the kit-move channels one frame ago (a move still playing changes them)
const HZ := [60, 144]
const BUDGET_S := 2.0 / 60.0           # s: two frames at 60 Hz, the same wall time at every refresh rate
const TAP_S := 0.033                   # s: how long a key is down (a quick click)
const WATCH_S := 0.6                   # s: how long a press is watched for its result
const SETTLE_S := 0.75                 # s: the least rest between cases
const SETTLE_MAX_S := 4.0              # s: the most, waiting for the last case's move, flight or lantern to end
const BASE_S := 0.15                   # s: the end of the settle, watched for nodes spawning on their own
const MOVE_EPS := 0.003                # m: a rendered move this big counts as seen
const SPOTS := 24                      # spots in the ring: a spot is reused only ~24 presses (30 s+) later
const SPOT_GAP := 14.0                 # m: between spots, out of reach of a late shot's blast or a raised rock
const SPOT_TRIES := 3                  # spots tried for one press before it is void (a leftover outlived the ring)
const KEYS := ["lmb", "rmb", "e", "dash", "jump", "r"]      # R last: the Merge changes the hunter's form
const ACTION := {
	"lmb": "fire", "rmb": "secondary", "e": "signature", "dash": "dash", "jump": "jump", "r": "ultimate",
}
const CALIB_SPOT := Vector3(12.0, 0.0, -32.0)       # move_feel_check's flat spot, when the seed keeps it
const FAR := Vector3(-500, 50, -500)

func run(main_: Node) -> void:
	main = main_
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_tree().root.size = Vector2i(1280, 720)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(FAR)
			h.out = true
			if T == null and h.team != P.team: T = h
	for k in m.kins.duplicate():
		if (k as Kin).owner_h != P:
			m.kins.erase(k)          # the foe's Boki would wake with it and fight; only its hunter is wanted
			if (k as Kin).owner_h: ((k as Kin).owner_h as Hunter).kin = null
			k.queue_free()
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	m.paused = false
	spots = _flat_spots()
	print("PRESS %d flat spots, first %s, target %s" % [spots.size(), str(spots[0]), T.name if T else "none"])
	var heroes := _only()
	for hz in HZ:
		for hero in Arch.ORDER:
			if heroes.is_empty() or hero in heroes:
				for key in KEYS:
					await _case(int(hz), String(hero), String(key))
	print("PRESS LATENCY CHECK DONE, failures: ", bad)
	main.get_tree().quit()

# ---------------------------------------------------------------- one press
func _case(hz: int, hero: String, key: String) -> void:
	var allow := int(floor(BUDGET_S * hz + 1e-6))
	var phases := 3 if hz > 60 else 1
	var worst := {"sim": -1, "vis": -1, "via": "", "sign": -1}
	for ph in phases:
		var r := await _press(hz, hero, key, ph)
		if r["vis"] < 0 or r["vis"] > worst["vis"] or worst["via"] == "":
			worst = r
		if r["vis"] < 0: break
	var ok_: bool = worst["sim"] >= 0 and worst["vis"] >= 0 and worst["vis"] <= allow
	if not ok_: bad += 1
	var extra := ("  press->sign %s" % _n(worst["sign"])) if _on_release(hero, key) else ""
	print("PRESS %3dHz %-10s %-4s sim %s vis %s (%s)%s  allow <= %d  %s" % [
		hz, hero, key, _n(worst["sim"]), _n(worst["vis"]), worst["via"], extra, allow, "ok" if ok_ else "FAIL"])

## --press-latency-check=<hero>,<hero>: only those heroes (while iterating on one kit); bare: all twelve.
static func _only() -> Array:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--press-latency-check="):
			return Array(String(a).get_slice("=", 1).split(","))
	return []

static func _n(v: int) -> String:
	return "%2d" % v if v >= 0 else "--"

## Does this key's effect go on the release (a hold variant, a charge)?
func _on_release(hero: String, key: String) -> bool:
	if key == "rmb":
		return float((Arch.def(hero)).get("rmb", {}).get("hold", 0.0)) > 0.0
	if key == "lmb":
		return P.wpn.get("melee", false) and P.wpn.has("charge_time")
	return false

## One press at one accumulator phase: {sim, vis, via, sign}, frames counted from the event (the press, or
## the release for release-shaped keys), -1 for never within WATCH_S. sign: press to the first visible sign.
func _press(hz: int, hero: String, key: String, phase: int) -> Dictionary:
	var dt := 1.0 / hz
	for attempt in SPOT_TRIES:
		await _prep(hero, key, dt)
		if unrest == "": break
		print("PRESS %3dHz %-10s %-4s moved on from a spot still %s" % [hz, hero, key, unrest])
	if unrest != "":
		return {"sim": -1, "vis": -1, "via": "not at rest: " + unrest, "sign": -1}
	var tap := maxi(1, int(round(TAP_S * hz)))
	var ev := tap if _on_release(hero, key) else 0
	m.acc = phase * dt      # 144 Hz: where in the 60 Hz tick the press lands
	var n0 := m.shots.size()
	var nodes0 := main.get_tree().get_node_count()
	var rest := P.position
	var km0: Dictionary = P.anim.km.duplicate()
	var base := _state()
	var sim := -1
	var vis := -1
	var via := ""
	var first_sign := -1
	var act := String(ACTION[key])
	for f in int(ceil(WATCH_S * hz)) + ev:
		if f == 0: Input.action_press(act)
		if f == tap: Input.action_release(act)
		m._process(dt)
		var seen := _visible(n0, nodes0, rest, km0)
		if first_sign < 0 and seen != "": first_sign = f
		if f >= ev:
			if sim < 0 and _state() != base: sim = f - ev
			if vis < 0 and seen != "":
				vis = f - ev
				via = seen
		if sim >= 0 and vis >= 0: break
		await main.get_tree().process_frame
	if Input.is_action_pressed(act): Input.action_release(act)
	return {"sim": sim, "vis": vis, "via": via, "sign": first_sign}

## The simulation's view of the press: whatever a key can change the frame it lands.
func _state() -> String:
	var ak := P.ak
	var s := "%d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %s %s %d" % [
		m.shots.size(), P.fire_cd, P.warm_t, P.draw_t, P.spin, P.mel_hold, P.roll_t, P.vel.y, P.cast_at,
		str(P.used), str(P.merge_st.get("phase", "")), P.swing_n]
	if ak:
		s += " %s %.1f %.3f %.3f %s %s %s %d" % [
			str(ak.cd), ak.ch_rmb, ak.e_t, ak.r_t, str(ak.fuse.keys()), str(ak.rmb_down), ak.anim_id,
			int(ak.dash_press_at * 1000.0)]
	return s

## What shows on screen this frame, "" for nothing yet.
func _visible(n0: int, nodes0: int, rest: Vector3, km0: Dictionary) -> String:
	if m.shots.size() > n0: return "shot"
	if P.position.distance_to(rest) > MOVE_EPS: return "move"
	if P.muzzle_t > 0.0: return "muzzle"
	var a: HunterAnim = P.anim
	if a:
		if a.cast_now > 0.0 and a.cast_now < 0.6: return "cast pose"
		if a.km != km0: return "kit move"
		if a.swing_t > 0.0 and a.swing_t < a.swing_dur: return "swing"
	if P.draw_t > 0.0: return "draw"
	if P.spin > 0.0: return "spin-up"
	if P.merge_st.get("phase", "") != "": return "merge"
	if not noisy and main.get_tree().get_node_count() > nodes0: return "node"
	return ""

# ---------------------------------------------------------------- setup
## A fresh hunter of this hero, at rest on the flat spot, the foe ahead and the cursor on it. The rest waits for
## the last case to end (a long kit move, a lantern still in the air, the Merge), then puts the hunter back.
func _prep(hero: String, key: String, dt: float) -> void:
	if KinMerge.active(P): KinMerge.end(P, "check")
	flat = spots[spot_i % spots.size()]
	spot_i += 1
	P.set_arch(hero)
	_rest(key)
	m.hitstop = 0.0
	m.slowmo = 0.0
	var n := 0
	var least := int(ceil(SETTLE_S / dt))
	while n < int(ceil(SETTLE_MAX_S / dt)):
		_aim_at_target()
		m._process(dt)
		await main.get_tree().process_frame
		n += 1
		var still := _quiet() == ""
		km_last = P.anim.km.duplicate()
		if n >= least and still: break
	_rest(key)
	noisy = false
	var nodes := main.get_tree().get_node_count()
	for i in int(ceil(BASE_S / dt)):
		_aim_at_target()
		m._process(dt)
		if main.get_tree().get_node_count() > nodes:
			noisy = true
		await main.get_tree().process_frame
		unrest = _quiet()
		km_last = P.anim.km.duplicate()

## Standing on the spot, still, full charges and ammo, the foe back in front.
func _rest(key: String) -> void:
	P.out = false
	P.gone = false
	P.downed = false
	P.teleport(flat)
	P.vel = Vector3.ZERO
	P.grounded = true
	for zero in ["roll_t", "knock_t", "stun_t", "root_t", "coyote", "jump_buf", "reload_t", "fire_cd",
			"warm_t", "spin", "mel_hold", "swing_buf", "dash_buf", "ex_cd", "merge_cd"]:
		P.set(zero, 0.0)
	for off in ["gliding", "dropping", "diving"]:
		P.set(off, false)
	P.pad = {}
	P.grap = {}
	P.draw_t = -1.0
	P.ammo = int(P.wpn["mag"])
	P.dashes = P.max_dashes()
	P.hp = P.max_hp
	P.ult = 1.0 if key == "r" else 0.0
	if P.kin and (P.kin as Kin).state != "shoulder":
		(P.kin as Kin).stow()        # back on the shoulder (a Merge leaves it out, and it shoves)
	if P.ak: P.ak.cd_off = true
	for kk in ["sec", "sig", "ult", "jump", "dash", "fire", "glide", "glide_btn", "dash_down", "crouch"]:
		P.inp[kk] = false
	if T:
		T.out = false
		T.downed = false
		T.hp = T.max_hp
		T.teleport(flat + Vector3(4.0, 0, 0))
		T.vel = Vector3.ZERO

## "" when the hunter is at rest, else what still moves.
func _quiet() -> String:
	if not P.grounded: return "airborne"
	if P.vel.length() > 0.01: return "moving"
	if P.roll_t > 0.0: return "dash"
	if P.ak and P.ak.in_dash(): return "kit dash"
	if P.anim and P.anim.km != km_last: return "kit move"
	if KinMerge.active(P): return "merged"
	if P.position.distance_to(P.pos) > 0.01: return "render catching up"
	return ""

## The cursor on the foe's chest: a mouse motion event is what the viewport reads, in window pixels (the
## canvas point times the content scale, which a real window may have; headless it is 1).
func _aim_at_target() -> void:
	if T == null or m.cam == null: return
	var ev := InputEventMouseMotion.new()
	ev.position = m.cam.unproject_position(T.pos + Vector3(0, 0.9, 0)) * main.get_tree().root.content_scale_factor
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## Flat open spots 6 m clear all round (move_feel_check's rule), SPOT_GAP apart, up to SPOTS of them.
func _flat_spots() -> Array:
	var w: World = m.world
	var found: Array = []
	for k in 20001:
		var g: Vector3 = w.random_ground()
		if k == 0:
			g = Vector3(CALIB_SPOT.x, w.ground_at(CALIB_SPOT.x, CALIB_SPOT.z), CALIB_SPOT.z)
		if g.y > 2.0 and k < 15000:
			continue
		if found.any(func(f: Vector3) -> bool: return f.distance_to(g) < SPOT_GAP):
			continue
		if _clear_around(g):
			found.append(g)
			if found.size() >= SPOTS: break
	return found if not found.is_empty() else [m.world.spawns[0]]

func _clear_around(g: Vector3) -> bool:
	var w: World = m.world
	if w.is_void(g.x, g.z) or w.is_block(g.x, g.z):
		return false
	for i in 16:
		var a := TAU * i / 16.0
		for d in [2.0, 4.0, 6.0]:
			var x: float = g.x + cos(a) * d
			var z: float = g.z + sin(a) * d
			if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
				return false
	return true
