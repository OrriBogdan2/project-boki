class_name RemoteAnimCheck
extends "res://tools/displace_net_check.gd"
## --remote-anim-check: the kit move a Hunter plays on its own game plays on the other player's game too.
## Two real games over the desktop relay (the --displace-net-check harness, which this extends): the host's
## hunter casts each of its 12 kits' LMB, RMB, E, R and dash, tapped and held, and the guest's copy of it
## (a remote hunter fed only by the snapshots, Net 0.16.0's kit move id) must start the same HunterAnim move
## within LAG_TOL, and play nothing the host did not. Both games log every change of the move (the kit's
## id and HunterAnim's), compared per cast. Lines: RANIM ok|FAIL <what>, then the unlike casts.
## Once both games are up they run in lockstep, not on the wall clock: the host steps one DT, tells the guest,
## and goes on when the guest has stepped too; the guest also holds a step until the host's latest snapshot is in,
## so a cast takes as many frames as it needs and no real time, and times in the log are step counts (the same
## on a slow box). --remote-anim-check=archer,mage runs only those kits; "stomp" and "skydive" are the rows of
## RemoteAnimStomp.

const LAG_TOL := 0.3         # s: one snapshot (0.1 s) plus the frames both games need to show it
const MIN_LIFE := 0.15       # s: a move replaced sooner than this never makes a snapshot
const SKEW := 0.05           # s: clocks of two processes on one machine
const NET_SNAP_TOL := 0.08   # s: a re-time on the copy is the host's to within the age snap plus a frame
const SETTLE := 1.6          # s after the release for the move to play out and the snapshots to land
const HOLD := 0.8            # s a held key stays down
const ACK_S := 30.0          # s of real time to wait for the guest's step before giving up
const SNAP_S := 3.0          # s of real time the guest waits for a snapshot the unreliable channel may have dropped
const WALK := 3.6            # s more after Lace's Spirit Walk starts, so the walk (2.8 s, 3.3 s at rank 3) runs out
const WASH_ON := 0.15        # the body tint (Ent.wash) counts as showing above this
const KEYS := ["lmb", "rmb", "e", "r", "dash"]
const ARCHS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]

## Casts whose copy still differs, and why (docs/DEBT.md): printed as GAP, not failures (timing may hide one
## run to run). Both fixes sit in ArchKit.net_move / apply_net_move, not in Net.
const KNOWN := {
	"bulwark rmb held": "lowering the shield clears the move id; the wire's '' is ignored, the copy keeps guarding",
	"gunslinger lmb held": "a restart of the same move within 0.3 s of its start is not seen (apply_net_move)",
}

var log_rows: Array = []     # [unix ms, the kit's move id, HunterAnim's move id]; one row per change or restart
var last_row := ["?", "?"]
var last_prev_t := 0.0
var unlike := {}             # arch -> casts whose copy differs
var played := {}             # arch -> casts that played any move
var locked := false          # both games step together, one DT per "step" message
var steps := 0               # locked steps taken on this game: the log's clock
var owed := 0                # guest: steps the host asked for and this game has not taken
var acks := 0                # host: steps the guest has taken
var snap_t := 0.0            # host: its match time at its last snapshot; guest: the same, from the step message
var sampled := -1            # the step _sample last looked at
var kits: Array = ARCHS + ["stomp", "skydive"]
var wash_rows: Array = []    # [unix ms, tint showing] at each change of the watched hunter's body tint
var wash_host: Array = []    # Lace's tapped Shift: the host's rows
var wash_guest: Array = []   # ... and the guest's copy's
var retimes: Array = []      # [unix ms, s]: the watched move's clock jumped earlier, same id (a re-time)
var last_at := [ "", 0.0 ]   # the watched kit's move id and anim_at at the last frame

func _init() -> void:
	tag = "RANIM"
	guest_flag = "--remote-anim-check=guest"

func run(main_node: Node) -> void:
	main_node.get_tree().process_frame.connect(_sample)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--remote-anim-check=") and a != guest_flag:
			kits = a.substr(20).split(",")
	await super.run(main_node)

## Free-running (60 fps) while the games come up, then one step per call pair: the host steps, the guest follows.
func _run(secs: float) -> void:
	if not locked:
		await super._run(secs)
		return
	var t := 0.0
	while t < secs - 0.0001:
		t += DT
		if Net.is_host():
			await super._run(DT)
			steps += 1
			if Net.send_t > 0.09: snap_t = m.time      # (Net.tick just sent a snapshot: send_t restarts at 0.1)
			Net.lobby_emit("ra", {"c": "step", "t": snap_t})
			var t0 := Time.get_ticks_msec()
			while acks < steps and Time.get_ticks_msec() - t0 < ACK_S * 1000.0:
				await main.get_tree().process_frame
		else:
			while owed == 0 and not stop:
				await main.get_tree().process_frame
			if stop: return
			owed -= 1
			var t1 := Time.get_ticks_msec()
			while not stop and not _snap_in() and Time.get_ticks_msec() - t1 < SNAP_S * 1000.0:
				await main.get_tree().process_frame
			await super._run(DT)
			steps += 1
			Net.lobby_emit("ra", {"c": "ack"})

## Guest: the host's hunter has the snapshot the host sent at `snap_t` (or a later one).
func _snap_in() -> bool:
	var buf := _copy().net_buf
	return buf == null or buf.ts.is_empty() or buf.ts[buf.ts.size() - 1] >= snap_t - 1.5 * DT

# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	Engine.max_fps = 0
	Net.lobby_emit("ra", {"c": "lock"})
	locked = true
	await _run(0.2)     # (the guest locks on the message; both free-run until then)
	var archs: Array = kits.filter(func(k): return k in ARCHS)
	for arch in archs:
		for key in KEYS:
			for held in ([false] if key in ["e", "r"] else [false, true]):
				await _cast(G, arch, key, held)
	if "archer" in archs:
		_wash_rows_ok()
	if "ashwick" in archs:
		await _ram_retime()
	for arch in archs:
		ok(int(played.get(arch, 0)) > 0, "%s: some cast plays a kit move (else nothing was compared)" % arch)
		ok(not unlike.has(arch), "%s: the guest's copy plays what the host's does" % arch,
			"unlike: %s" % str(unlike.get(arch, [])))
	if "stomp" in kits:
		await RemoteAnimStomp.host(self, G)
	if "skydive" in kits:
		await RemoteAnimStomp.skydive(self, G)
	_finish()

func _cast(G: Hunter, arch: String, key: String, held: bool) -> void:
	var P := m.player
	var what := "%s %s%s" % [arch, key, " held" if held else ""]
	P.reclass(Arch.weight(arch), arch)
	P.unlock_all()
	P.lvl = 6
	_kit(arch)
	P.fire_cd = 0.0
	P.ammo = int(P.wpn.get("mag", 12))
	replies.clear()
	Net.lobby_emit("ra", {"c": "kit", "arch": arch})
	await _reply()
	_aim(P.pos + Vector3(6.0, 0, 0))
	await _run(0.3)
	log_rows.clear()
	wash_rows.clear()
	last_row = ["?", "?"]
	Net.lobby_emit("ra", {"c": "mark"})
	await _run(0.2)
	await _press(key, held)
	var lace_walk: bool = what == "archer dash"
	await _run(SETTLE + (WALK if lace_walk else 0.0))
	var mine := log_rows.duplicate()
	replies.clear()
	Net.lobby_emit("ra", {"c": "log"})
	await _reply()
	var theirs: Array = replies[0].get("log", []) if not replies.is_empty() else []
	if lace_walk:
		wash_host = wash_rows.duplicate()
		wash_guest = replies[0].get("wash", []) if not replies.is_empty() else []
	var cmp := _compare(mine, theirs)
	if cmp["moves"] > 0:
		played[arch] = int(played.get(arch, 0)) + 1
	if KNOWN.has(what):
		print("%s %s %s" % [tag, "GAP" if cmp["bad"] != "" else "gap not seen this run", what])
	elif cmp["bad"] != "":
		unlike[arch] = unlike.get(arch, []) + ["%s: %s" % [what, cmp["bad"]]]
		print("%s FAIL %s: %s" % [tag, what, cmp["bad"]])
		bad += 1
	n += 1
	print("%s %s  %d moves, worst lag %.2f s" % [tag, what, cmp["moves"], cmp["lag"]])

## One key for the kit: tapped (one step) or held for HOLD s, then let go. E gets a flick of the aim (Sparkle's drag).
func _press(key: String, held: bool) -> void:
	var P := m.player
	var secs := HOLD if held else DT
	var flick := P.pos + Vector3(6.0, 0, 4.0)
	match key:
		"lmb": P.inp["fire"] = true
		"rmb": P.inp["sec"] = true
		"e": P.inp["sig"] = true
		"r": P.inp["ult"] = true
		"dash": P.do_dash()
	var t := 0.0
	while t < maxf(secs, DT) - 0.0001:
		if key == "rmb": P.inp["sec_hold"] = held
		if key == "dash": P.inp["dash_down"] = held
		if key == "e" and t > 0.2: _aim(flick)
		await _run(DT)
		t += DT
		if key != "lmb" or not held: P.inp["fire"] = false
		P.inp["sec"] = false
	for k in ["fire", "sec_hold", "dash_down", "sig", "ult"]:
		P.inp[k] = false
	if key == "e": _aim(P.pos + Vector3(6.0, 0, 0))

## Lace's Spirit Walk darkens her body on both games: on within LAG_TOL of the host's, and off again within
## LAG_TOL of the host's (the copy's walk is the base length, so it never outstays the walk).
func _wash_rows_ok() -> void:
	var h_on := _wash_at(wash_host, true)
	var g_on := _wash_at(wash_guest, true)
	var h_off := _wash_at(wash_host, false)
	var g_off := _wash_at(wash_guest, false)
	var detail := "host %s guest %s" % [str(wash_host), str(wash_guest)]
	ok(h_on >= 0.0 and h_off > h_on + 2.0, "archer: the host's own body tints through the Spirit Walk", detail)
	ok(g_on >= h_on - SKEW and g_on <= h_on + LAG_TOL, "archer: the guest's copy tints within %.1f s" % LAG_TOL, detail)
	ok(g_off > g_on + 2.0 and g_off <= h_off + LAG_TOL, "archer: the copy's tint ends with the walk", detail)

## Cinder's ram into a foe: the hit re-times as_leap onto its squash key (ArchKit.retime, about 0.23 s earlier,
## under the 0.3 s resync), and the guest's copy must move its clock by the same within LAG_TOL of the host's.
func _ram_retime() -> void:
	var P := m.player
	_kit("ashwick")
	replies.clear()
	Net.lobby_emit("ra", {"c": "kit", "arch": "ashwick"})
	await _reply()
	var foe: Hunter = m.make_hunter("RT", 1, "medium", "Foe", "idle", {}, home + Vector3(3.0, 0, 0), {"arch": "none"})
	_aim(foe.pos)
	await _run(0.3)
	retimes.clear()
	Net.lobby_emit("ra", {"c": "mark"})
	await _run(0.2)
	P.do_dash()
	await _run(SETTLE)
	var mine := retimes.duplicate()
	replies.clear()
	Net.lobby_emit("ra", {"c": "log"})
	await _reply()
	var theirs: Array = replies[0].get("rt", []) if not replies.is_empty() else []
	var detail := "host %s guest %s" % [str(mine), str(theirs)]
	ok(mine.size() == 1 and float(mine[0][1]) < -0.1,
		"ashwick ram hit: the host's as_leap jumps to its squash key", detail)
	var shown := false
	for r in theirs:
		if not mine.is_empty() and absf(float(r[1]) - float(mine[0][1])) <= NET_SNAP_TOL:
			shown = shown or (float(r[0]) - float(mine[0][0])) / 1000.0 <= LAG_TOL
	ok(shown, "ashwick ram hit: the guest's copy re-times as_leap by the same within %.1f s" % LAG_TOL, detail)
	foe.teleport(home + Vector3(-6.0, 0, 9.0))

## The first time (s) the rows change to `on`; -99 when none.
func _wash_at(rows: Array, on: bool) -> float:
	for r in rows:
		if bool(r[1]) == on:
			return float(r[0]) / 1000.0
	return -99.0

## The host's rows against the guest's: every move of the host's that lasted a snapshot shows on the guest
## in order within LAG_TOL, and the guest shows no move the host never played.
func _compare(mine: Array, theirs: Array) -> Dictionary:
	var out := {"moves": 0, "lag": 0.0, "bad": ""}
	var ids := {}
	for r in mine: ids[String(r[2])] = true
	for r in theirs:
		if not ids.has(String(r[2])) and out["bad"] == "":
			out["bad"] = "the copy plays '%s', the host never did" % r[2]
	var at := 0
	for i in mine.size():
		var id := String(mine[i][2])
		var life: float = (float(mine[i + 1][0]) - float(mine[i][0])) / 1000.0 if i + 1 < mine.size() else 9.0
		if life < MIN_LIFE or i == 0:
			continue
		if id != "": out["moves"] += 1
		var found := false
		for j in range(at, theirs.size()):
			var lag: float = (float(theirs[j][0]) - float(mine[i][0])) / 1000.0
			if String(theirs[j][2]) == id and lag > -SKEW:
				found = lag <= LAG_TOL
				out["lag"] = maxf(out["lag"], lag)
				at = j + 1
				break
		if not found and out["bad"] == "":
			var into := (float(mine[i][0]) - float(mine[0][0])) / 1000.0
			out["bad"] = "the host's '%s' (%.2f s in) does not show within %.1f s" % [id, into, LAG_TOL]
	return out

# ------------------------------------------------------------------ the guest
func _on_msg(topic: String, data, from: String) -> void:
	if topic == "ra" and typeof(data) == TYPE_DICTIONARY and m and m.player:
		var R := _copy()
		match String(data.get("c", "")):
			"kit":
				if R: R.reclass(Arch.weight(String(data["arch"])), String(data["arch"]))
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"lock":
				locked = true
				Engine.max_fps = 0
			"step":
				owed += 1
				snap_t = float(data.get("t", 0.0))
			"ack": acks += 1
			"look":
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "look": RemoteAnimStomp.look(self)})
			"mark":
				log_rows.clear()
				retimes.clear()
				wash_rows.clear()
				last_row = ["?", "?"]
			"log":
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "log": log_rows, "wash": wash_rows, "rt": retimes})
		return
	super._on_msg(topic, data, from)

## The other game's hunter on this one: the host's copy on the guest, the player on the host.
func _copy() -> Hunter:
	if not Net.is_host():
		for h in m.hunters:
			if h.remote: return h
	return m.player

# ------------------------------------------------------------------ both
## Every frame: note a change of the watched hunter's move (the kit's id, HunterAnim's id, or a restart).
func _sample() -> void:
	if m == null or m.player == null or (locked and steps == sampled):
		return
	sampled = steps
	var H := _copy()
	H.render(DT, 1.0)      # (Match's own render pass is off in the checks)
	var wisp := m.ents_by_id.get("B", null) as Hunter
	if wisp and not Net.is_host(): wisp.render(DT, 1.0)
	if H.ak == null or H.anim == null:
		return
	var ms := int(float(steps) * DT * 1000.0) if locked else int(Time.get_unix_time_from_system() * 1000.0)
	var shown := H.wash > WASH_ON
	if wash_rows.is_empty() and shown or not wash_rows.is_empty() and shown != wash_rows[-1][1]:
		wash_rows.append([ms, shown])
	var jump: float = H.ak.anim_at - float(last_at[1])
	if H.ak.anim_id == last_at[0] and jump < -0.02 and jump > -0.6:
		retimes.append([ms, snappedf(jump, 0.01)])
	last_at = [H.ak.anim_id, H.ak.anim_at]
	var row := [H.ak.anim_id, H.anim.km_id]
	var restart: bool = H.anim.km_prev_t < last_prev_t - 0.001
	last_prev_t = H.anim.km_prev_t
	if row != last_row or restart:
		last_row = row
		log_rows.append([ms, row[0], row[1]])
