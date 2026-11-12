extends "res://tools/abyss_check.gd"
## --glide-hold-check (DECISIONS "holding Space NEVER opens the glider"): with a player's keys
## (inp glide_press_only) the glider opens only from a fresh press in the air; Space held from the jump, or
## held while LMB/RMB are used, never opens it; a folded glider stays shut while still held, until a new press.
## Every Hunter: a fresh Space press during and after its air Shift glides (by the move's end at the latest),
## except a Shift in SWALLOWS. Online, the other games' copy of a glide button's mid-fall open opens on the first
## snapshot after it: at most one Net tick (SNAP_S) behind, whatever the press's phase on the snapshot clock.
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const SECS := 2.0       # how long each scenario runs
const HIGH := 12.0      # m: a start in the air, well above the ground, for the in-air presses
const SNAP_S := 0.1     # s between a player's snapshots (Net.tick's send_t)
const BUTTONS := {"juggernaut": "RMB", "archer": "LMB", "bulwark": "LMB"}      # Kael, Lace, Albert
## Air Shifts that drop a Space press by design (MOVEMENT_FEEL "Dash into glide": a kit's own move is not cancelled)
const SWALLOWS := {"mage": "Sparkle's wire: her keys do nothing while it holds (mage_kit _tick_wire)"}

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

## A glide button press 0.5s into a fall, at each phase of the snapshot clock: a remote copy fed only by the
## snapshots (Match._ser -> _net_apply, as Net.tick sends them) opens on the first one after the local open.
func _remote_case() -> void:
	var snap := roundi(SNAP_S / Match.DT)
	var s: Array = m._ser(h)
	s[1] = "Pmirror"
	var R: Hunter = m._net_make(s)
	var lags: Array = []
	for phase in snap:
		_reset(w.random_ground() + Vector3(0, HIGH, 0), Vector3.ZERO)
		h.coyote = 0.0
		h.inp["glide_press_only"] = true
		var press := 30 + phase
		var local := -1
		var remote := -1
		for i in 60:
			h.inp["glide"] = i >= press
			h.inp["glide_btn"] = i >= press
			m.step(Match.DT)
			if i % snap == 0:
				s = m._ser(h)
				s[1] = R.nid
				m._net_apply(R, s, m.time)
			if h.gliding and local < 0: local = i
			if R.gliding and remote < 0: remote = i
		lags.append(remote - local if local >= 0 and remote >= 0 else 99)
		ok(local == press, "glide button 0.5s into a fall (phase %d): opens on the press step" % phase)
	var worst: int = lags.max()
	ok(worst < snap, "the remote copy opens <= 1 Net tick (%d steps) behind the local open: %s steps" % [snap, lags])
	for k in ["glide", "glide_btn"]: h.inp[k] = false
	m.hunters.erase(R)
	m.ents_by_id.erase(R.nid)
	R.queue_free()

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
	var line := "%s: Space pressed 0.07s into the air Shift and held glides %.2fs of 1.93s" % [arch, r["t"]]
	if SWALLOWS.has(arch):
		ok(r["t"] == 0.0, line + " (by design: %s)" % SWALLOWS[arch])
	else:
		ok(r["t"] > 0.3, line)

func run(main: Node) -> void:
	Save.no_write = true
	_start(main, "")
	_base_cases()
	_remote_case()
	m.queue_free()
	for arch in Arch.ORDER:
		await main.get_tree().process_frame
		_start(main, arch)
		if BUTTONS.has(arch):
			_button_cases(arch)
		_shift_case(arch)
		m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
