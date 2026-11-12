extends RefCounted
## Sable's move timing through her clips (docs/heroes/thief.md, "Animation timing"), run inside --thief-combo-check:
## each keyed move is played in a real match with the model rendered and the beats the footage gives
## (briefs/hero-ref/dancer.md, 5 fps, 0.2 s a frame) are read off the kit's move clock (K.anim_id / K.anim_at):
## when the move is played, when the clip owns the body, the frame its release or hit lands on, how far into the
## clip that is, and when the hand is handed back. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const FRAME := 0.2           # s: one frame of the footage
const BOLT_KEY := 0.0        # clip s: the lmb clip's shot key (tools/art1/sable_clips.py)
const BOLA_SLING := 0.42     # clip s: the bola clip's sling key
const KNIFE_KEY := 0.12      # clip s: the knife clip's release key
const VAULT_FLIP := [0.1, 0.3]   # clip s: the Vault clip's turn (push-off to landed)
const VAULT_UP := 0.48       # clip s: the Vault clip stands her up
const SOURCE_STRIDE := 2.3   # Hz: the sheet's run cycle (4.5 steps/s)
var A                        # the combo check (ok, step, aim_at)

func _init(check) -> void:
	A = check

func run(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	if P.model == null or not P.model.has_node("Warden/Sync"):
		A.ok("Sable timing: her clips are on (nothing to time)", false)
		return
	var t_at := T.pos
	A.fresh(T)
	T.teleport(home + Vector3(0, 0, -30.0))        # out of every ring and lane
	_settle(m, P, K, home, 0.6)
	_lmb(m, P, K, home)
	_bola(m, P, K, home)
	_knife(m, P, K, home)
	_vault(m, P, K, home)
	_vault_air(m, P, K, home)
	_encore(m, P, K, home)
	_run(m, P, K, home)
	_settle(m, P, K, home, 1.0)
	A.fresh(T)
	T.teleport(t_at)                               # the checks after this one find the foe where they left it

func _clips(P: Hunter) -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(m: Match, P: Hunter, K: ThiefKit, home: Vector3, secs: float) -> void:
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	K.primed_t = 0.0
	K.haste_t = 0.0
	K.knife = {}
	K.e_t = 0.0
	K.anim_id = ""
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	P.roll_t = 0.0
	for f in int(secs / DT):
		_frame(m, P)

## Plays `secs` of frames and reads the move's beats off the clips, in s from t0: when the kit plays one of
## `moves` (play), when it owns the body (in), when the kit's event fires (hit, `event` turns true) and how far
## into the clip that is (at), the clip and its length, and when the body is back (out).
func _time(m: Match, P: Hunter, K: ThiefKit, moves: Array, secs: float, event: Callable,
		each := Callable()) -> Dictionary:
	var c := _clips(P)
	var r := {"move": "", "play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame(m, P)
		var t := m.time - t0
		if float(r["hit"]) < 0.0 and event.call():
			r["hit"] = t
		if not K.anim_id in moves:
			continue
		if String(r["move"]) == "":
			r["move"] = K.anim_id
			r["play"] = K.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		if float(r["at"]) < 0.0 and float(r["hit"]) >= 0.0:
			r["at"] = m.time - K.anim_at
		var live := c.cur
		if live == "" and c.up_w > 0.0:
			live = String(c.d["kmoves"].get(K.anim_id, {}).get("clip", ""))
		if live != "" and String(r["clip"]) == "" and c.lib.has_animation(live):
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f"
			% [r["move"], r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"]])
	return r

## LMB: the bolt leaves on the press's frame with its throw (the shot key at the clip's start), the clip owns
## the body inside the blend-in, then one bolt every 0.45 s held (the card), the hands alternating.
func _lmb(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	_settle(m, P, K, home, 0.3)
	var n0 := K.bolts
	P.inp["fire"] = true
	var r := _time(m, P, K, ["thf_lmb_r", "thf_lmb_l"], 0.4, func() -> bool: return K.bolts > n0)
	P.inp["fire"] = false
	A.ok("Sable timing LMB: the bolt and its throw leave on the press's frame, the clip is on within the blend-in",
			float(r["hit"]) >= 0.0 and float(r["hit"]) <= DT * 2.5 and absf(float(r["play"]) - float(r["hit"])) < DT
			and float(r["in"]) <= BLEND_IN and absf(float(r["at"]) - BOLT_KEY) < 0.04,
			"hit %.2f play %.2f in %.2f clip %.2f" % [r["hit"], r["play"], r["in"], r["at"]])
	_settle(m, P, K, home, 0.8)
	var at: Array = []
	var hands: Array = []
	var last := K.bolts
	P.inp["fire"] = true
	var t0 := m.time
	for f in int(1.5 / DT):
		_frame(m, P)
		if K.bolts != last:
			last = K.bolts
			at.append(m.time - t0)
			hands.append(K.anim_id)
	P.inp["fire"] = false
	var gap := (float(at[-1]) - float(at[0])) / maxf(at.size() - 1, 1) if at.size() > 1 else 0.0
	print("TIME thf_lmb held: %d bolts in 1.5 s, one every %.3f s, throws %s" % [at.size(), gap, str(hands)])
	A.ok("Sable timing LMB held: a bolt every 0.45 s (the card; the footage's 2-3 frames), each hand's throw in turn",
			at.size() >= 3 and absf(gap - 0.45) < 0.03 and hands[0] != hands[1], "gap %.3f %s" % [gap, str(hands)])
	_settle(m, P, K, home, 0.8)

## RMB Bola: the lane shows 0.4 s (the footage's 0.4-0.6 s), the sling leaves on the clip's sling key.
func _bola(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	_settle(m, P, K, home, 0.3)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	var r := _time(m, P, K, ["thf_bola"], 1.2, func() -> bool: return not K.bola.is_empty())
	A.ok("Sable timing Bola: thrown 0.4-0.6 s after the press (the source's lane), on the clip's sling key",
			float(r["hit"]) >= 0.4 - DT and float(r["hit"]) <= 0.6 and absf(float(r["at"]) - BOLA_SLING) < FRAME * 0.5
			and float(r["in"]) <= BLEND_IN, "thrown %.2f clip %.2f in %.2f" % [r["hit"], r["at"], r["in"]])
	_settle(m, P, K, home, 0.6)

## E Shadow Knife: the throw is released on the clip's key (spun into a side-arm throw), the recast is one
## frame (the source: under 0.2 s) and arrives with its clip; the forced return at 6 s steps to the dagger too,
## from a cartwheel as well.
func _knife(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	A.aim_at(P, home + Vector3(8.0, 0, 0))
	_settle(m, P, K, home, 0.3)
	K.cd["e"] = 0.0
	var n0 := m.shots.size()
	P.ak.use_e()
	var r := _time(m, P, K, ["thf_knife"], 0.8, func() -> bool: return m.shots.size() > n0)
	A.ok("Sable timing dagger: it leaves her hand on the clip's release key",
			absf(float(r["hit"]) - KNIFE_KEY) < DT * 2.0 and absf(float(r["at"]) - KNIFE_KEY) < DT * 2.0
			and float(r["in"]) <= BLEND_IN, "released %.2f clip %.2f in %.2f" % [r["hit"], r["at"], r["in"]])
	var stuck := not K.knife.is_empty()
	var at: Vector3 = K.knife["pos"] if stuck else home
	P.ak.use_e()
	var t0 := m.time
	var blink := -1.0
	for f in 12:
		_frame(m, P)
		if blink < 0.0 and P.flat_dist(at) < 0.8:
			blink = m.time - t0
	print("TIME thf_arrive recast: dagger %s, there after %.2f s, anim %s"
			% ["stuck" if stuck else "missing", blink, K.anim_id])
	A.ok("Sable timing dagger recast: she is at the dagger within a frame (the source: under 0.2 s) in the arrive clip",
			stuck and blink >= 0.0 and blink <= FRAME and K.anim_id == "thf_arrive",
			"blink %.2f %s" % [blink, K.anim_id])
	_settle(m, P, K, home, 0.8)
	# the forced return: the window runs out and she steps to the dagger, a cartwheel in flight included
	for from_flip in [false, true]:
		K.cd["e"] = 0.0
		A.aim_at(P, home + Vector3(8.0, 0, 0))
		P.ak.use_e()
		for f in 60:
			_frame(m, P)
		var kn := K.knife.duplicate()
		K.e_t = 5.0
		if from_flip:
			P.inp["move"] = Vector2(0, 1)
			P.do_dash()
			P.inp["move"] = Vector2.ZERO
			for f in 6:
				_frame(m, P)
		K.e_t = 0.05
		var pre := P.pos
		var seen := false
		for f in 30:
			_frame(m, P)
			seen = seen or K.anim_id == "thf_arrive"
		# a dagger in a foe steps her to their far side (_shadow_step), else onto the dagger
		var foe = kn.get("target")
		var there := not kn.is_empty() and (P.flat_dist(kn["pos"]) < 1.0 if foe == null or not is_instance_valid(foe)
				else P.flat_dist((foe as Ent).pos) < (foe as Ent).r + P.r + 0.6)
		var how := " from a cartwheel" if from_flip else ""
		A.ok("Sable timing dagger forced return%s: the window's end steps her to the dagger in the arrive clip" % how,
				there and seen and K.knife.is_empty() and P.roll_t <= 0.0 and K.vault.is_empty(),
				"there %s (%.1f m off) arrive %s moved %.1f m knife %s roll %.2f vault %s" % [there,
				P.flat_dist(kn.get("pos", P.pos)), seen, P.flat_dist(pre),
				K.knife.is_empty(), P.roll_t, K.vault.is_empty()])
		_settle(m, P, K, home, 0.8)

## Shift on the ground: the clip's turn (push-off 0.1, landed 0.3) runs with the dash, it is up by 0.48 s,
## the legs are back past it.
func _vault(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_settle(m, P, K, home, 0.3)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	P.inp["move"] = Vector2.ZERO
	var r := _time(m, P, K, ThiefKit.CARTWHEELS, 1.2, func() -> bool: return false)
	var dd := K.dash_def()
	print("TIME vault dash %.2f s clip %s" % [float(dd["time"]), r["clip"]])
	A.ok("Sable timing Vault (ground): flip clip from the first frame, %.2f s, ends with the dash" % VAULT_UP,
			float(r["play"]) <= DT * 2.0 and float(r["in"]) <= BLEND_IN and absf(float(r["len"]) - VAULT_UP) < 0.04
			and absf(float(dd["time"]) - VAULT_UP) < 0.04 and float(r["out"]) <= VAULT_UP + 0.25,
			"play %.2f in %.2f len %.2f out %.2f" % [r["play"], r["in"], r["len"], r["out"]])
	_settle(m, P, K, home, 0.6)

## Shift from a jump: the long cartwheel (8.4 m, 0.95 s) holds its carried pose until she touches down, then the
## landing crouch plays on the touchdown frame.
func _vault_air(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_settle(m, P, K, home, 0.3)
	P.do_jump()
	for f in 6:
		_frame(m, P)
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	P.inp["move"] = Vector2.ZERO
	var down := -1.0
	var land := -1.0
	var t0 := m.time
	var x0 := P.global_position
	var dist := 0.0
	for f in int(1.6 / DT):
		_frame(m, P)
		if down < 0.0:
			dist = Vector2(P.global_position.x - x0.x, P.global_position.z - x0.z).length()
		if down < 0.0 and P.grounded and m.time - t0 > 0.1:
			down = m.time - t0
		if land < 0.0 and K.anim_id == "thf_land":
			land = m.time - t0
	print("TIME thf_exdash air: %.2f m, down %.2f s, thf_land from %.2f s (sheet 8.4 m / 0.95 s)" % [dist, down, land])
	A.ok("Sable timing Vault (air): the landing crouch plays on the touchdown frame",
			down > 0.0 and land >= down - DT and land <= down + DT * 2.0, "down %.2f land %.2f" % [down, land])
	_settle(m, P, K, home, 0.8)

## X Encore: the ring grows 0.4 s, then a blade every 0.2 s for 2 s (10 beats), the dance clip on the beat from
## 0.4 s, and nothing after 2.4 s.
func _encore(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_settle(m, P, K, home, 0.3)
	var U := K.encore
	var d := K.x_def()
	var beats: Array = []
	var b0 := U.beat
	var first := ""
	var dance_at := -1.0
	var danced_at := 0.0
	U.start()
	var t0 := m.time
	var gone := -1.0
	for f in int(3.0 / DT):
		_frame(m, P)
		var t := m.time - t0
		if U.beat != b0 + beats.size():
			beats.append(t)
		if first == "":
			first = K.anim_id
		if dance_at < 0.0 and K.anim_id == ThiefUlt.DANCE:
			dance_at = t
			danced_at = m.time - K.anim_at
		if gone < 0.0 and not U.running():
			gone = t
	var gap := (float(beats[-1]) - float(beats[0])) / maxf(beats.size() - 1, 1) if beats.size() > 1 else 0.0
	print("TIME thf_encore: first %s, beats %d from %.2f every %.3f, dance from %.2f (clip clock %.2f), over %.2f"
			% [first, beats.size(), beats[0] if beats.size() > 0 else -1.0, gap, dance_at, danced_at, gone])
	A.ok("Sable timing Encore: the cast clip on the press, a blade beat at 0.4 s then every 0.2 s (10 beats)",
			first == "thf_encore" and beats.size() == int(d["shots"])
			and absf(float(beats[0]) - float(d["grow"])) < DT * 2.0
			and absf(gap - float(d["time"]) / float(d["shots"])) < 0.02
			and absf(gone - float(d["grow"]) - float(d["time"])) < 0.1,
			"%s %d beats first %.2f gap %.3f over %.2f"
			% [first, beats.size(), beats[0] if beats.size() > 0 else -1.0, gap, gone])
	A.ok("Sable timing Encore: the dance takes over by the first beat, on the beat's clock",
			dance_at >= 0.0 and dance_at <= float(d["grow"]) + DT * 2.0
			and absf(dance_at - danced_at - float(d["grow"])) < DT * 2.0,
			"dance from %.2f, clip clock starts %.2f" % [dance_at, dance_at - danced_at])
	_settle(m, P, K, home, 0.8)

## The run cycle against the sheet's stride (2.3 Hz): the gait clip's cycle at her run speed.
func _run(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_settle(m, P, K, home, 0.3)
	P.inp["move"] = Vector2(0, 1)
	for f in 40:
		_frame(m, P)
	var c := _clips(P)
	var speed := Vector2(P.vel.x, P.vel.z).length()
	var hz := _stride_hz(c, P, speed)
	P.inp["move"] = Vector2.ZERO
	print("TIME run: %.2f m/s, stride %.2f Hz (sheet %.1f Hz)" % [speed, hz, SOURCE_STRIDE])
	A.ok("Sable timing run: the stride matches the sheet's (about 2.3 Hz)", absf(hz - SOURCE_STRIDE) < 0.2,
			"%.2f Hz at %.2f m/s" % [hz, speed])
	_settle(m, P, K, home, 0.6)

## Gait cycles a second at this speed: the run clip's length and the rate WardenClips plays it at (WardenGait.plan:
## the speed over the clip's foot speed, clamped).
func _stride_hz(c: WardenClips, _P: Hunter, speed: float) -> float:
	var lc: Dictionary = c.d["loco"]
	var clip_len := c.lib.get_animation(String(lc["run"]["f"])).length
	return c.gait.plan(speed, lc) / clip_len
