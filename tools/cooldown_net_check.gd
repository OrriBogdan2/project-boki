extends RefCounted
## --cooldown-net-check: a press on the first frame an ability shows ready is never refused online.
## A headless relay (`--relay`) runs as its own process; this game joins it through tools/udp_delay.py
## (100 ms each way, 20 ms jitter) and plays a net match on open ground, the training bots parked and no
## Boki. For every Hunter it uses RMB, E, R, dash and LMB (a fresh kit each time), waits for the slot to go
## dark and light again, and presses on the first step it shows ready (the HUD slot's `ready`; LMB has no
## slot, so the weapon's can_fire and fire_cd). A refusal is the HUD's deny shake, or nothing starting
## within BUFFER_S (an attack, a cast, a charge, a dash). Cooldowns are cut to WAIT_S once the kit is idle.
## Then two rows: Sable with Second Wind (the slot is dark while the Trade flies, a press in its last 0.15 s
## is kept) and a class change mid-whirl (Mossy's pending spin is dropped, it used to crash). God mode is off.
## Lines: CDNET ok|FAIL <what>, then CDNET DONE.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const DELAY_MS := 100
const JITTER_MS := 20
const REPS := 2             # first-ready presses per hero and slot
const WAIT_S := 3.0         # s: cooldowns left after a use are cut to this (once idle), so a run stays short
const BUFFER_S := 0.15      # s: a press taken within this counts (DECISIONS: recast presses buffer about 0.15 s)
const SETTLE_S := 12.0      # s at most for what the last use left running to finish
const DARK_S := 2.0         # s: a slot still lit this long after a use has no cooldown to wait for
const GIVE_UP_S := 25.0     # s of game time to wait for a slot to show ready again
const FLAT_R := 20          # m: half the side of the open square the presses happen on
const SLOTS := ["rmb", "e", "r", "dash", "lmb"]

var main: Node
var m: Match = null
var bad := 0
var n := 0
var pids: Array = []
var home := Vector3.ZERO
var used := 0               # CombatBus.ability_used by the player

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("CDNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Game.god = false            # mod mode (an owner's settings) refills every dash each step
	Engine.max_fps = 60
	var port := 7990 + OS.get_process_id() % 60
	var res := ProjectSettings.globalize_path("res://")
	var relay := "cd '%s' && exec %s --headless -- --relay --port=%d > /dev/null 2>&1" % [res, GODOT, port]
	pids.append(OS.create_process("/bin/sh", ["-c", relay]))
	pids.append(OS.create_process("/bin/sh", ["-c", "cd '%s' && exec python3 -I tools/udp_delay.py %d %d %d %d" % [
		res, port + 100, port, DELAY_MS, JITTER_MS]]))
	ok(await _connect(port + 100), "on the relay through %d ms +- %d ms" % [DELAY_MS, JITTER_MS], Net.me)
	if Net.mode != "server":
		return _finish()
	await _build()
	CombatBus.ability_used.connect(func(c, _id, _s): if c == m.player: used += 1)
	for arch in Arch.ids():
		await _settle()             # nothing of the last kit may still be due when the class changes
		for slot in SLOTS:
			await _slot(arch, slot)
	await _trade_second_wind()
	await _class_change_mid_whirl()
	_finish()

func _finish() -> void:
	for p in pids:
		if p > 0 and OS.is_process_running(p): OS.kill(p)
	print("CDNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _connect(at: int) -> bool:
	Net.server_addr = "127.0.0.1:%d" % at
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 60000:
		Net.start()
		await main.get_tree().create_timer(0.5).timeout
	Net.set_presence({"name": "cdnet"})
	return Net.mode == "server"

## A net match with this game as its host and a dummy foe to aim at.
func _build() -> void:
	m = Match.new()
	main.add_child(m)
	var d := {"mid": "cdn%d" % OS.get_process_id(), "seed": 4242, "host": Net.me, "teams": 2, "squad": 1, "tier": 0,
		"roster": [{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}}]}
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"cls": "medium", "net": d})
	m.set_process(false)
	_flatten()
	var P := m.player
	for h in m.hunters:             # the training bots and every Boki would stun the player mid-test
		if h.kin:
			h.kin.dead = true
			m.kins.erase(h.kin)
			h.kin.queue_free()
			h.kin = null
		if h != P:
			h.ctrl = "idle"
			h.teleport(home + Vector3(0, 0, -FLAT_R + 2.0))
	var B: Hunter = m.make_hunter("B", 1, "medium", "Dummy", "idle", {}, home + Vector3(5.0, 0, 0), {"arch": "none"})
	B.max_hp = 1e9
	B.hp = B.max_hp
	P.max_hp = 1e9

## Open ground 40 m around the first spawn: no dash, pull or swap ends off an edge or against a wall.
func _flatten() -> void:
	var W: World = m.world
	var sp: Vector3 = W.spawns[0]
	var hx := int(floor(sp.x))
	var hz := int(floor(sp.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-FLAT_R, FLAT_R + 1):
		for dx in range(-FLAT_R, FLAT_R + 1):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for tiles in [W.stairs, W.walls, W.props, W.bush]:
				tiles.erase(i)
	for b in m.breaks: b["dead"] = true
	home = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)

## REPS presses of one slot, each on the first step the slot shows ready after a use.
func _slot(arch: String, slot: String) -> void:
	var what := "%s %s" % [Arch.name_of(arch), slot]
	var refused := 0
	var steps: Array = []
	for rep in REPS:
		await _settle()             # what the last use left running (a chain, an ult) is done with
		var side := 1.0 if rep % 2 == 0 else -1.0     # each rep aims somewhere new (Tenzo's rocks stay a while)
		_kit(arch, Vector3(5.0 * side, 0, 0))
		if not await _prime(slot):
			ok(false, "%s: the first use goes off" % what)
			return
		var dark := false           # the slot goes dark (its cooldown starts), then lights again
		var t := 0.0
		while t < GIVE_UP_S:
			if _idle(): _cut_cooldowns()
			await _run(DT)
			t += DT
			var lit := _shown_ready(slot)
			if not lit: dark = true
			elif dark or t >= DARK_S: break     # never dark (no cooldown on this use): it is lit now
		if t >= GIVE_UP_S:
			ok(false, "%s: shows ready again" % what, "went dark: %s" % dark)
			return
		_aim(Vector3(0, 0, 5.0 * side))     # a fresh spot: nothing the first use left (Tenzo's rocks) is in the way
		var f := await _press_frames(slot, BUFFER_S)
		if f < 0: refused += 1
		else: steps.append(f)
	ok(refused == 0, "%s: first-ready presses taken" % what,
		"refused %d/%d, steps to take %s" % [refused, REPS, str(steps)])

## The use that starts the cooldown. A press may first end something still out (Mossy's hammer comes back,
## Sable's lantern lands), so up to 3 tries until one is taken or the slot goes dark.
func _prime(slot: String) -> bool:
	for attempt in 3:
		if await _press_frames(slot, 0.6) >= 0 or not _shown_ready(slot):
			return true
	return false

## Sable with Second Wind (two charges): while the Trade flies the slot reads dark (a press then does
## nothing), and a press in its last BUF_S goes off as the lantern lands.
func _trade_second_wind() -> void:
	await _settle()
	_kit("ostra", Vector3(5.0, 0, 0))
	var P := m.player
	var K: OstraKit = P.ak
	P.perks.append("secondwind")
	P.dashes = P.max_dashes()
	await _press_frames("dash", 0.6)
	for i in 10:
		if not K.swap.is_empty(): break
		await _run(DT)
	var lit_mid := false
	var flew := 0
	while not K.swap.is_empty() and float(K.swap["t"]) > K.BUF_S - 0.05:
		lit_mid = lit_mid or _shown_ready("dash")
		flew += 1
		await _run(DT)
	ok(flew > 30 and not lit_mid and P.dashes >= 1.0, "Sable + Second Wind: the dash slot is dark in flight",
		"%d steps in flight, charges %.2f" % [flew, P.dashes])
	var n0 := K.swaps
	_aim(Vector3(0, 0, 5.0))
	var f := await _press_frames("dash", 0.3)
	ok(f >= 0 and K.swaps == n0 + 1, "Sable + Second Wind: a press just before the landing lobs the next Trade",
		"steps %d, landed %d" % [f, K.swaps - n0])
	P.perks.erase("secondwind")

## Mossy's whirl lands its spin later (Match.later); a class change before then frees his kit's nodes, and
## that pending hit used to crash the game. It is dropped now. (A crash ends the run with no DONE line.)
func _class_change_mid_whirl() -> void:
	await _settle()
	_kit("bulwark", Vector3(5, 0, 0))
	await _press_frames("dash", 0.02)
	var due := m._later.size()
	_kit("ostra", Vector3(5, 0, 0))
	await _run(1.0)
	ok(due > 0 and m._later.is_empty(), "a class change mid-whirl drops Mossy's pending spin", "%d pending" % due)

## Presses and lets go after one step (RMB: held through the window, then let go). Returns the steps from
## the press to the first sign it was taken (0: that same step), or -1 for the HUD's deny or nothing at all.
func _press_frames(slot: String, secs: float) -> int:
	var P := m.player
	var fx_id: String = {"lmb": "", "rmb": "sec", "e": "k1", "r": "x", "dash": "dash"}[slot]
	m.hud.slot_fx.erase(fx_id)
	var before := _mark()
	var stun0 := P.stun_t
	if slot == "r": HunterKeys.ult_pressed(P)      # R is polled by the Match each frame, outside the step
	else: P.inp[_key(slot)] = true
	P.inp["dash_down"] = slot == "dash"
	var f := 0
	while f * DT < secs + 0.0001:
		P.inp["sec_hold"] = slot == "rmb"         # held through the window (Mossy's shield)
		await _run(DT)
		P.inp["fire"] = false
		P.inp["sec_hold"] = false
		P.inp["dash_down"] = false
		if P.stun_t > stun0:
			ok(false, "nothing stuns the player during a press", "%s at %.1f s" % [slot, m.time])
		if String(m.hud.slot_fx.get(fx_id, {}).get("kind", "")) == "deny":
			return -1
		if _taken(before):
			return f
		f += 1
	if slot == "rmb":                # let go: a tap fires on the release (Kael's Smash, Lace's shot)
		await _run(DT)
		if _taken(before):
			return f
	return -1

static func _key(slot: String) -> String:
	return {"lmb": "fire", "rmb": "sec", "e": "sig", "dash": "dash"}[slot]

## What the player sees: the slot's ready flag (LMB has no slot: the weapon can fire).
func _shown_ready(slot: String) -> bool:
	var P := m.player
	if slot == "lmb":
		return P.fire_cd <= 0.0 and P.warm_t <= 0.0 and P.can_fire()
	return bool(P.slot_info({"rmb": "sec", "e": "k1", "r": "x", "dash": "dash"}[slot])["ready"])

## Everything a taken press changes on the player.
func _mark() -> Dictionary:
	var P := m.player
	return {"used": used, "shots": m.shots.size(), "fire_cd": P.fire_cd, "ammo": P.ammo, "swing": P.swing_t,
		"mel": P.mel_hold, "draw": P.draw_t, "anim": P.ak.anim_at, "dashes": P.dashes, "roll": P.roll_t,
		"ch": P.ak.ch_rmb, "cd": P.ak.cd.duplicate()}

func _taken(a: Dictionary) -> bool:
	var b := _mark()
	if b["used"] != a["used"] or b["shots"] > a["shots"] or b["ammo"] < a["ammo"] or b["dashes"] < a["dashes"] - 0.01:
		return true
	if b["fire_cd"] > a["fire_cd"] or b["swing"] > a["swing"] or b["mel"] > a["mel"] or b["draw"] > a["draw"]:
		return true
	if b["roll"] > a["roll"] or b["ch"] < a["ch"] or b["anim"] != a["anim"]:
		return true
	for k in a["cd"]:
		if float(b["cd"][k]) > float(a["cd"][k]): return true
	return false

## Nothing the kit started is still running: a cooldown can be cut without ending a cast early.
func _idle() -> bool:
	var K := m.player.ak
	return not K.busy() and not K.ult_running() and K.e_t <= 0.0 and K.r_t <= 0.0 and m.player.roll_t <= 0.0

func _settle() -> void:
	var t := 0.0
	while t < SETTLE_S and (t < 0.5 or not _idle()):
		await _run(DT)
		t += DT

func _cut_cooldowns() -> void:
	var P := m.player
	for k in P.ak.cd:
		P.ak.cd[k] = minf(float(P.ak.cd[k]), WAIT_S)
	P.fire_cd = minf(P.fire_cd, WAIT_S)
	if P.dashes < 1.0:
		P.dashes = maxf(P.dashes, 1.0 - WAIT_S / P.dash_regen())

func _kit(arch: String, aim_off: Vector3) -> void:
	var P := m.player
	P.reclass(Arch.weight(arch), arch)      # a fresh kit: no hook or hammer from the last rep is still out
	P.unlock_all()
	P.lvl = 6
	P.hp = P.max_hp
	P.vel = Vector3.ZERO
	P.stun_t = 0.0
	P.dashes = 1.0              # the last charge of each: one use darkens the slot
	for k in P.ak.cd: P.ak.cd[k] = 0.0
	P.ak.ch_rmb = 1.0
	P.fire_cd = 0.0
	P.ammo = int(P.wpn["mag"])
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	P.ex_cd = 0.0
	_aim(aim_off)

## The dummy stands `off` from home and the player aims at it.
func _aim(off: Vector3) -> void:
	var B: Ent = m.ents_by_id.get("B", null)
	B.teleport(home + off)
	m.player.inp["aim"] = B.pos + Vector3(0, 0.9, 0)
	m.player.inp["aim_y"] = B.pos.y

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		await main.get_tree().process_frame
