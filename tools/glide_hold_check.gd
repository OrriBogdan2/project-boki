extends "res://tools/abyss_check.gd"
## --glide-hold-check (DECISIONS "holding Space NEVER opens the glider"): with a player's keys
## (inp glide_press_only) the glider opens only from a fresh press in the air; Space held from the jump, or
## held while LMB/RMB are used, never opens it; a folded glider stays shut while still held, until a new press.
## Every Hunter: a fresh Space press during and after its air Shift glides (by the move's end at the latest),
## The sweep presses at 25/50/75% of every Shift move, held or chained: except a held Shift in SWALLOWS.
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const SECS := 2.0       # how long each scenario runs
const HIGH := 12.0      # m: a start in the air, well above the ground, for the in-air presses
const BUTTONS := {"juggernaut": "RMB", "archer": "LMB", "bulwark": "LMB"}      # Kael, Lace, Albert
## A held Shift that drops a Space press by design (MOVEMENT_FEEL "Dash into glide")
const SWALLOWS := {"mage": "Sparkle's wire: her keys do nothing while she holds Shift (mage_kit _tick_wire)"}

## A training match as `arch` ("" keeps the default kit), the player on an empty patch of ground.
func _start(main: Node, arch: String) -> void:
	m = Match.new()
	main.add_child(m)
	var opts := {"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}
	if arch != "":
		opts.merge({"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
	m.start(opts)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.player
	h.set_arch(arch)
	h.unlock_all()
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(60, 0, 60))
	m.opts["god"] = true

## One scenario: stand on flat ground (or `lift` m above it), then step SECS with `script` (Callable(i) -> void)
## setting inputs each step. Returns {t: seconds the glider was open, opens: how many times it opened}.
func _scenario(script: Callable, lift := 0.3) -> Dictionary:
	_reset(w.random_ground() + Vector3(0, 0.3, 0), Vector3.ZERO)
	for i in 60: m.step(Match.DT)        # 1s on the ground: the last scenario's attack animation ends
	if lift > 0.3:
		_reset(h.pos + Vector3(0, lift, 0), Vector3.ZERO)
		h.coyote = 0.0           # the ground's grace would make the first press a jump
		for i in 2: m.step(Match.DT)      # the locomotion state leaves GROUNDED (a glide from it is refused)
	h.inp["glide_press_only"] = true
	h.inp["aim"] = h.pos + Vector3(8, 0.9, 0)
	var out := {"t": 0.0, "opens": 0}
	var was := false
	for i in int(SECS / Match.DT):
		for k in ["jump", "fire", "glide_btn", "sec", "sec_hold", "dash"]:
			h.inp[k] = false
		script.call(i)
		m.step(Match.DT)
		if h.gliding:
			out["t"] += Match.DT
			if not was: out["opens"] += 1
		was = h.gliding
	h.inp["fire"] = false
	h.inp["sec_hold"] = false
	_reset(h.pos, Vector3.ZERO)
	return out

## Holds `button` ("LMB" or "RMB") from step `from`: the press on that step, held after it.
func _hold(button: String, i: int, from: int) -> void:
	if i < from: return
	if button == "LMB":
		h.inp["fire"] = true
	else:
		h.inp["sec"] = i == from
		h.inp["sec_hold"] = true

func _base_cases() -> void:
	var held := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
	ok(_scenario(held)["t"] == 0.0, "jump and hold Space for 2s: never glides")
	var held_fire := func(i: int) -> void:
		held.call(i)
		h.inp["fire"] = true
	ok(_scenario(held_fire)["t"] == 0.0, "LMB held, jump and hold Space for 2s: never glides")
	var held_btn := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 5          # the button goes down on the ground, then the jump
		h.inp["glide_btn"] = true
	ok(_scenario(held_btn)["t"] == 0.0, "glide button held since before the jump: never glides")
	var double := func(i: int) -> void:
		h.inp["glide"] = i == 0 or i >= 12
		h.inp["jump"] = i == 0 or i == 12
	ok(_scenario(double)["t"] > 0.5, "jump, release, press Space again and hold: glides")
	var btn := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
		h.inp["glide_btn"] = i >= 12
	ok(_scenario(btn)["t"] > 0.5, "jump, then a fresh glide-button press and hold: glides")
	# in the air: a fresh press opens it, a heal's fold (glide_cd) at 0.5s closes it while Space stays held
	var refold := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
		if i == 30:
			h.glide_cd = 0.4
	var r := _scenario(refold, HIGH)
	var what := "a folded glider stays shut while Space is still held (opened %d times)" % r["opens"]
	ok(r["opens"] == 1 and r["t"] < 0.6, what)
	var repress := func(i: int) -> void:
		refold.call(i)
		h.inp["glide"] = i < 70 or i >= 72
		h.inp["jump"] = i == 0 or i == 72
	ok(_scenario(repress, HIGH)["opens"] == 2, "a folded glider re-opens on a fresh Space press")
	var dash_hold := func(i: int) -> void:
		held.call(i)
		if i == 20:
			h.roll_t = 0.1
			h.roll_dir = Vector2(1, 0)
			h.roll_speed = 14.0
	ok(_scenario(dash_hold)["t"] == 0.0, "Space held since the jump, an air dash ending: still no glider")

## Kael's RMB, Lace's and Albert's LMB held never become a glide.
func _button_cases(arch: String) -> void:
	var b: String = BUTTONS[arch]
	var tap := func(i: int) -> void:
		h.inp["glide"] = i == 0
		h.inp["jump"] = i == 0
		_hold(b, i, 6)
	ok(_scenario(tap)["t"] == 0.0, "%s: jump, let go of Space, hold %s for 2s: never glides" % [arch, b])
	var with_space := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
		_hold(b, i, 6)
	ok(_scenario(with_space)["t"] == 0.0, "%s: jump and hold Space and %s for 2s: never glides" % [arch, b])
	var gliding := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
		_hold(b, i, 10)
	var r := _scenario(gliding, HIGH)
	ok(r["opens"] == 1, "%s: gliding, then %s held with Space: opens once, never again after a fold (%d)"
		% [arch, b, r["opens"]])

## Every Hunter, player keys, high in the air moving east: Shift, then a fresh Space press 0.07s into the move
## and, separately, 1s after it (the move is over). Both open the glider, the first by the move's end.
func _shift_case(arch: String) -> void:
	var mid := func(i: int) -> void:
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = i == 0
		h.inp["glide"] = i >= 4
		h.inp["jump"] = i == 4
	var late := func(i: int) -> void:
		mid.call(i)
		h.inp["glide"] = i >= 60
		h.inp["jump"] = i == 60
	var r := _scenario(mid, 30.0)
	var after := _scenario(late, 30.0)
	ok(after["t"] > 0.3, "%s: a fresh Space press 1s after the air Shift glides" % arch)
	ok(r["t"] > 0.3, "%s: Space pressed 0.07s into the air Shift and held glides %.2fs of 1.93s" % [arch, r["t"]])

## The dash/glide sweep (DECISIONS 11-08: Shift cancels into a glide at once for every Hunter). Each pattern is the
## frames Shift goes down, how many frames it is then held, and where it starts: "air" high up, or "ground" (the
## press is then a jump out of the move on the ground and a fresh Space press SWEEP_GAP steps later, in the air).
const SWEEP := {
	"air tap": {"taps": [0], "hold": 0, "lift": 40.0},
	"air chain": {"taps": [0, 15, 30], "hold": 0, "lift": 40.0},
	"air hold": {"taps": [0], "hold": 50, "lift": 40.0},
	"ground tap": {"taps": [0], "hold": 0, "lift": 0.0},
	"ground chain": {"taps": [0, 15, 30], "hold": 0, "lift": 0.0},
	"ground hold": {"taps": [0], "hold": 50, "lift": 0.0}}
const SWEEP_AT := [0.25, 0.5, 0.75]     # where in the move a press lands
const SWEEP_LANE := 12                  # m of flat ground east of the start (a dash, or a hop chain's first hops)
const SWEEP_GAP := 12                   # steps from a ground move's jump to the fresh press
const SWEEP_HIGH := 1.2                 # m: a ground move's jump is still this high at the fresh press (not landing)
const SWEEP_STAY := 8                   # steps the opened glider must stay open (a kit's wind-down must not fold it)
const SWEEP_OPEN := 1                   # steps from the fresh press to the glider (MOVEMENT_FEEL reglide <= 1 frame)
## Motley's Shift on the ground is the Trade's aim (a held aim before the lob, no travel), and the lob moves him by
## teleport: a jump out of it is not a dash to cancel, so only his air rows (the sling and drift) are swept.
const SWEEP_SKIP := {"ostra": "ground"}
## A dash that ends in an attack keeps the glider shut for that attack's wind-down (the no-glider-in-an-attack
## rule): Albert's 360 Smash spin lands as his dash ends.
const SWEEP_WINDDOWN := {"bulwark": BulwarkKit.WINDDOWN}
## One probe of a Shift pattern moving east, the player's press on step `press` (-1: none). Returns {busy: steps
## the move kept a roll running or the glider shut, open: steps from the fresh press to the open glider (1 = the
## press step, 0 = never), before/after: horizontal m/s the step before that press / the step it opened}.
func _sweep_probe(pat: Dictionary, press: int) -> Dictionary:
	_reset(_open_lane(SWEEP_LANE) + Vector3(0, 0.3, 0), Vector3.ZERO)
	for i in 40: m.step(Match.DT)
	var air: bool = pat["lift"] > 0.0
	if air:
		_reset(h.pos + Vector3(0, float(pat["lift"]), 0), Vector3.ZERO)
		h.coyote = 0.0
		for i in 2: m.step(Match.DT)
	h.inp["glide_press_only"] = true
	h.inp["move"] = Vector2(1, 0)
	h.inp["aim"] = h.pos + Vector3(8, 0.9, 0)
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	var fresh := press if air or press < 0 else press + SWEEP_GAP       # the press that must open the glider
	var jumped_out := false
	var out := {"busy": 0, "open": 0, "before": 0.0, "after": 0.0, "jumped": true, "stayed": true}
	for i in 100:
		var shifting: bool = press < 0 or i < press        # no more Shift taps once the player presses
		h.inp["dash"] = shifting and i in pat["taps"]
		h.inp["dash_down"] = i < int(pat["hold"]) or h.inp["dash"]       # a held Shift stays held
		h.inp["jump"] = i == fresh or (not air and i == press)
		h.inp["glide"] = press >= 0 and i >= (fresh if air else press) and (air or i == press or i >= fresh)
		if i == press and not air:
			jumped_out = h.roll_t > 0.0 or h.ak.in_dash()       # the jump comes out of a move, not between two
		if i == fresh:
			h.dash_buf = 0.0            # a queued Shift would fire after the glider opens and fold it (by design)
			out["before"] = Vector2(h.vel.x, h.vel.z).length()
			# (a ground move needs a jump out of it, still high at the press: no wall at the lane's end, no landing)
			out["jumped"] = air or (jumped_out and h.pos.y - h.ground() > SWEEP_HIGH and h.stun_t <= 0.0)
		m.step(Match.DT)
		if press >= 0 and i >= fresh and h.gliding:
			out["open"] = i - fresh + 1
			out["after"] = Vector2(h.vel.x, h.vel.z).length()
			h.inp["jump"] = false
			h.inp["dash"] = false
			for k in SWEEP_STAY:
				m.step(Match.DT)
			out["stayed"] = h.gliding or h.grounded or h.stun_t > 0.0       # (landed, or a wall stunned it)
			break
		if press < 0 and (h.roll_t > 0.0 or AirLimits.glide_locked(h) or h.ak.in_dash()):
			out["busy"] = i + 1
		if press < 0 and i > out["busy"] + 10 and i > 40:
			break
		if press >= 0 and i > fresh + 45:
			break
	for k in ["dash", "dash_down", "glide", "jump", "move"]:
		h.inp[k] = false if k != "move" else Vector2.ZERO
	return out

## Every Hunter, every pattern: a fresh press at 25/50/75% of the move opens the glider within SWEEP_OPEN steps.
func _sweep_case(arch: String) -> void:
	for name in SWEEP:
		var pat: Dictionary = SWEEP[name]
		if name.begins_with(SWEEP_SKIP.get(arch, "-")):
			continue
		var busy: int = _sweep_probe(pat, -1)["busy"]
		if busy < 4:
			print("ACHECK note sweep (%s %s): holds nothing for %d steps: nothing to cancel" % [arch, name, busy])
			continue
		var row := []
		var shut := false
		var limit := SWEEP_OPEN + (ceili(SWEEP_WINDDOWN[arch] / Match.DT) + 1 if SWEEP_WINDDOWN.has(arch) else 0)
		for at in SWEEP_AT:
			var r := _sweep_probe(pat, maxi(1, int(busy * at)))
			if not r["jumped"]:
				row.append("no jump out@%d%%" % int(at * 100))
				continue
			row.append("%d@%d%% %.1f>%.1f" % [r["open"], int(at * 100), r["before"], r["after"]])
			shut = shut or r["open"] == 0 or r["open"] > limit or not r["stayed"]
		var line := "%s %s (move %d steps): steps to glide, m/s before>after: %s" % [arch, name, busy, ", ".join(row)]
		if SWALLOWS.has(arch) and name.ends_with("hold"):
			print("ACHECK note sweep " + line + " (by design: %s)" % SWALLOWS[arch])
		else:
			ok(not shut, "sweep " + line)

func run(main: Node) -> void:
	Save.no_write = true
	_start(main, "")
	ok(_open_lane(SWEEP_LANE).is_finite(), "the sweep's map has %d m of flat open ground" % SWEEP_LANE)
	_base_cases()
	m.queue_free()
	for arch in Arch.ORDER:
		await main.get_tree().process_frame
		_start(main, arch)
		if BUTTONS.has(arch):
			_button_cases(arch)
		_shift_case(arch)
		_sweep_case(arch)
		m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
