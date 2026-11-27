extends "res://tools/abyss_check.gd"
## --glider-parity-check (movement parity 11-27): the glider's timing numbers, measured from the running game, not
## read from the data (the same file runs on the old tree for the "before" column). Each row prints "PARITY <what>
## <measured> (want <number>)" so a PR can quote before and after.
##   1. a spiked glider hangs frozen SPIKE_FREEZE s, then its speed is SET to SPIKE_FALL m/s straight down
##   2. after a slam's heat or a spike landing the glider's heat does not refill for REGEN_STUN s
##   3. a slam burns SLAM_HEAT of the victim's heat; the slammer pays nothing; a slam spikes only an empty glider
##   4. a level glide lasts GLIDE_S s from cool to overheated
##   5. the glider opens after GLIDE_HOLD s of a held press in the air, never from a tap; feathering = hold, let go
##      (it closes at once), hold again
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const SPIKE_FREEZE := 0.18      # s the spiked body hangs (the reference's spike stun hold)
const SPIKE_FALL := 80.0        # m/s the body is then set falling (8000 uu/s)
const LAND_STUN := 0.7          # s stunned on landing
const REGEN_STUN := 1.5         # s the heat stays unrefilled after a slam's heat / the landing stun
const SLAM_HEAT := 0.5          # of the max heat a slam burns off its victim
const GLIDE_S := 6.25           # s a level glide lasts (500 fuel at 80 a second)
const GLIDE_HOLD := 0.4         # s a press must be held before the glider opens
const HIGH := 60.0              # m: a start high enough to watch a whole spiked fall

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(w.random_ground())
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	m.opts["god"] = true
	marker = w.random_ground()
	h.ai["land"] = marker
	var o: Hunter = m.hunters[1]
	o.ctrl = "idle"
	_spike_fall(o)
	_slam_heat(o)
	_regen_after_landing(o)
	_glide_length()
	_hold_to_open()
	print("ACHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _line(what: String, got: float, want: float, tol: float) -> void:
	print("PARITY %s: %.3f (want %.3f)" % [what, got, want])
	ok(absf(got - want) <= tol, "%s %.3f (want %.3f +-%.2f)" % [what, got, want, tol])

## A glider `o` over the marker, `fuel` heat left, nothing else on it.
func _glider(o: Hunter, fuel: float, up := 12.0) -> void:
	o.teleport(marker + Vector3(0, up, 0))
	o.grounded = false
	o.vel = Vector3(4.0, -1.0, 0)
	o.gliding = true
	o.inp["glide"] = true
	o.glide_fuel = fuel
	o.glide_cd = 0.0
	o.stun_t = 0.0
	o.shot_down = false
	o.kb_t = -9.0
	o.hp = o.max_hp
	o.inv_t = 0.0
	o.air_t = 1.0
	h.gliding = true
	h.glide_fuel = 0.2

## Seconds the spiked body hangs (|vy| under 1 m/s), and its fall speed once it falls.
func _spike_fall(o: Hunter) -> void:
	_glider(o, 0.0, HIGH)
	o.glide_fuel = 0.0
	o.hurt(1.0, h, {})            # any player hit on an overheated glider spikes it
	ok(o.shot_down, "an overheated glider is spiked")
	var hang := 0.0
	var fall := 0.0
	var t := 0.0
	while t < 2.0 and not o.grounded:
		o.inp["glide"] = true
		m.step(Match.DT)
		t += Match.DT
		if absf(o.vel.y) < 1.0 and fall == 0.0:
			hang += Match.DT
		else:
			fall = maxf(fall, -o.vel.y)
	_line("spike freeze (s)", hang, SPIKE_FREEZE, 0.04)
	_line("spike fall speed (m/s)", fall, SPIKE_FALL, 2.0)
	o.inp["glide"] = false

## One slam of a full glider: the heat it burns, whether it spikes, what the slammer pays.
func _slam_heat(o: Hunter) -> void:
	_glider(o, 1.0)
	h.glide_fuel = 0.2
	m.displace.spike(o, -16.0, h)
	_line("slam heat burned (share of the tank)", 1.0 - o.glide_fuel, SLAM_HEAT, 0.02)
	ok(not o.shot_down, "a slam on a full glider burns heat but does not spike it")
	ok(h.glide_fuel <= 0.2 + 0.001 + GlideSpike.cool_by, "the slammer's own heat is not charged (%.2f)" % h.glide_fuel)
	_glider(o, SLAM_HEAT)
	m.displace.spike(o, -16.0, h)
	ok(o.shot_down, "a slam that empties the heat spikes the glider")
	_glider(o, 1.0)
	o.glide_fuel = 1.0
	o.gliding = false
	o.grounded = false
	m.displace.spike(o, -0.5 * GlideSpike.slam_min, h)
	_line("a slam under the minimum burns", 1.0 - o.glide_fuel, 0.0, 0.001)
	o.inp["glide"] = false

## Seconds the heat stays empty on the ground after a spike landing (the 0.7 s stun, then the regen stun), and
## after a slam's heat (from the slam).
func _regen_after_landing(o: Hunter) -> void:
	_glider(o, 0.0, 8.0)
	o.hurt(1.0, h, {})
	var t := 0.0
	var landed := -1.0
	var refill := -1.0
	while t < 6.0:
		o.inp["glide"] = false
		m.step(Match.DT)
		t += Match.DT
		if o.grounded and landed < 0.0: landed = t
		if landed >= 0.0 and o.glide_fuel > 0.001:
			refill = t - landed
			break
	_line("heat refill starts after the landing (s)", refill, LAND_STUN + REGEN_STUN, 0.12)
	# a slam's heat blocks the refill on the ground too: a grounded, half-burnt glider
	o.stun_t = 0.0
	o.glide_regen_t = 0.0
	o.glide_fuel = 0.5
	GlideSpike.slam(o, -16.0)
	var fuel0 := o.glide_fuel
	t = 0.0
	var start := -1.0
	while t < 4.0:
		o.stun_t = 0.0
		m.step(Match.DT)
		t += Match.DT
		if o.glide_fuel > fuel0 + 0.001 and o.grounded:
			start = t
			break
	_line("heat refill starts after a slam's heat (s)", start, REGEN_STUN, 0.12)

## A level glide from a cool tank: seconds until it overheats.
func _glide_length() -> void:
	var lane := w.random_ground()
	var y := lane.y + 40.0
	_reset(Vector3(lane.x, y, lane.z), Vector3(0, -HunterMove.glide_sink, 0))
	h.last_gy = lane.y
	h.air_t = 1.0
	h.gliding = true
	var t := 0.0
	while t < 20.0 and h.glide_fuel > 0.001:
		h.inp["glide"] = true
		m.step(Match.DT)
		t += Match.DT
		h.pos.y = y
	h.inp["glide"] = false
	_line("level glide, cool to overheated (s)", t, GLIDE_S, 0.15)

## A real player's press (press_only): jump, then a second press held `hold` s. Returns the seconds from the press to
## the glider opening (-1 if it never opened within the hold plus 1 s).
func _hold_press(hold: float, btn := false) -> float:
	_reset(w.random_ground() + Vector3(0, 30.0, 0), Vector3(0, -2.0, 0))
	h.last_gy = h.pos.y - 30.0
	h.air_t = 1.0
	h.inp["glide_press_only"] = true
	var t := 0.0
	var opened := -1.0
	while t < hold + 1.0:
		var down := t < hold
		h.inp["glide"] = down
		h.inp["glide_btn"] = down and btn
		h.inp["jump"] = down and not btn and t < Match.DT * 0.5
		m.step(Match.DT)
		t += Match.DT
		if h.gliding and opened < 0.0:
			opened = t
			break
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	h.inp["jump"] = false
	for i in 6: m.step(Match.DT)       # let go: a glider that opened closes before the next row
	h.inp["glide_press_only"] = false
	return opened

func _hold_to_open() -> void:
	var held := _hold_press(1.0)
	_line("a held second Space opens the glider after (s)", held, GLIDE_HOLD, 0.06)
	var btn := _hold_press(1.0, true)
	_line("a held glide button opens the glider after (s)", btn, GLIDE_HOLD, 0.06)
	for tap in [0.05, 0.15, 0.3]:
		var r := _hold_press(tap)
		print("PARITY a %.2f s tap opens: %s" % [tap, "yes at %.2f s" % r if r >= 0.0 else "no"])
		ok(r < 0.0, "a %.2f s tap never opens the glider" % tap)
	# feathering: hold open, let go (closes at once), tap again (stays shut), hold again (opens after the hold)
	_reset(w.random_ground() + Vector3(0, 80.0, 0), Vector3(0, -2.0, 0))
	h.last_gy = h.pos.y - 80.0
	h.air_t = 1.0
	h.inp["glide_press_only"] = true
	var steps := {"open1": -1, "closed": -1, "tap_open": false, "open2": -1}
	var i := 0
	while i < int(4.0 / Match.DT):
		var t := i * Match.DT
		# 0-0.6 held, 0.6-1.0 let go, 1.0-1.2 tap, 1.2-1.6 let go, 1.6-2.4 held
		var down := t < 0.6 or (t >= 1.0 and t < 1.2) or (t >= 1.6 and t < 2.4)
		h.inp["glide"] = down
		h.inp["glide_btn"] = down
		m.step(Match.DT)
		if h.gliding and int(steps["open1"]) < 0 and t < 0.9: steps["open1"] = i
		if not down and t >= 0.6 and t < 1.0 and not h.gliding and int(steps["closed"]) < 0: steps["closed"] = i
		if t >= 1.0 and t < 1.6 and h.gliding: steps["tap_open"] = true
		if t >= 1.6 and h.gliding and int(steps["open2"]) < 0: steps["open2"] = i
		i += 1
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	h.inp["glide_press_only"] = false
	ok(int(steps["open1"]) >= 0, "feathering: the first hold opens the glider")
	ok(int(steps["closed"]) >= 0, "feathering: letting go closes it")
	ok(not bool(steps["tap_open"]), "feathering: a tap does not reopen it")
	var again: float = (int(steps["open2"]) - int(1.6 / Match.DT)) * Match.DT
	print("PARITY feathering reopen takes %.2f s of hold" % again)
	ok(int(steps["open2"]) >= 0 and absf(again - GLIDE_HOLD) <= 0.06,
		"feathering: holding again reopens it after the hold (%.2f s)" % again)

