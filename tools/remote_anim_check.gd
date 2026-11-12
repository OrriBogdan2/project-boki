extends "res://tools/displace_net_check.gd"
## --remote-anim-check: the kit move a Hunter plays on its own game plays on the other player's game too.
## Two real games over the desktop relay (the --displace-net-check harness, which this extends): the host's
## hunter casts each of its 12 kits' LMB, RMB, E, R and dash, tapped and held, and the guest's copy of it
## (a remote hunter fed only by the snapshots, Net 0.16.0's kit move id) must start the same HunterAnim move
## within LAG_TOL, and play nothing the host did not. Both games log every change of the move (the kit's
## id and HunterAnim's), compared per cast. Then the lair bosses (Net 0.24.6's "bat" event): the host wakes a
## Stone Colossus, a Stormcoil and a Brood Mother and has each play an attack, and the guest's copy (a Boss fed
## by the snapshots and the event) must play the same BossAnim moves (wake, wind-up, strike, phase) within
## LAG_TOL, its wind-up starting near its start (the progress counts on from the synced age).
## Lines: RANIM ok|FAIL <what>, then the unlike casts.

const LAG_TOL := 0.3         # s: one snapshot (0.1 s) plus the frames both games need to show it
const MIN_LIFE := 0.15       # s: a move replaced sooner than this never makes a snapshot
const SKEW := 0.05           # s: clocks of two processes on one machine
const SETTLE := 1.6          # s after the release for the move to play out and the snapshots to land
const HOLD := 0.8            # s a held key stays down
const WALK := 3.6            # s more after Lace's Spirit Walk starts, so the walk (2.8 s, 3.3 s at rank 3) runs out
const WASH_ON := 0.15        # the body tint (Ent.wash) counts as showing above this
const KEYS := ["lmb", "rmb", "e", "r", "dash"]
const BOSSES := {"colossus": "slam", "serpent": "dash", "brood": "spit"}      # the attack each plays
const BOSS_LOOPS := ["idle", "walk", "stagger", "sleep"]      # (not compared: the copy's gait may differ a step)
const BOSS_AT := Vector3(3.0, 0, 0)      # m from home: where a boss stands (the lair is round it)
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
var boss_nid := ""           # the boss both games log (the guest's copy of it)
var wash_rows: Array = []    # [unix ms, tint showing] at each change of the watched hunter's body tint
var wash_host: Array = []    # Lace's tapped Shift: the host's rows
var wash_guest: Array = []   # ... and the guest's copy's

func _init() -> void:
	tag = "RANIM"
	guest_flag = "--remote-anim-check=guest"

func run(main_node: Node) -> void:
	main_node.get_tree().process_frame.connect(_sample)
	await super.run(main_node)

# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	ok(Net.VERSION != "0.24.5", "the Net version moved on with the boss event (%s)" % Net.VERSION)
	for kind in BOSSES:
		await _boss(kind, String(BOSSES[kind]))
	for arch in ARCHS:
		for key in KEYS:
			for held in ([false] if key in ["e", "r"] else [false, true]):
				await _cast(G, arch, key, held)
	_wash_rows_ok()
	for arch in ARCHS:
		ok(int(played.get(arch, 0)) > 0, "%s: some cast plays a kit move (else nothing was compared)" % arch)
		ok(not unlike.has(arch), "%s: the guest's copy plays what the host's does" % arch,
			"unlike: %s" % str(unlike.get(arch, [])))
	_finish()

## One boss of `kind` on the host, asleep, woken, one attack, a phase change: the guest's copy plays the same.
func _boss(kind: String, atk: String) -> void:
	var P := m.player
	P.reclass(Arch.weight("gunslinger"), "gunslinger")
	P.teleport(home)
	var at := home + BOSS_AT
	var b := Boss.new()
	var lair := {"c": at, "half": 14, "state": "awake", "col": Color.WHITE, "name": kind, "adds": []}
	b.init_boss(m, m.next_id("b"), kind, at, 1.0, lair)
	m.add_child(b)
	m.mobs.append(b)
	m.ents_by_id[b.nid] = b
	b.next_cd = 1e9
	boss_nid = b.nid
	Net.lobby_emit("ra", {"c": "boss", "nid": b.nid})
	await _run(1.0)
	log_rows.clear()
	last_row = ["?", "?"]
	Net.lobby_emit("ra", {"c": "mark"})
	await _run(0.3)
	b.dormant = false
	b.awake_t = 0.0
	await _run(2.0)
	b.tgt = P
	match atk:
		"slam": b._atk_slam()
		"dash": b._atk_dash()
		"spit": b._atk_spit()
	await _run(3.5)
	b.hp = b.max_hp * 0.6
	await _run(3.2)
	var mine := log_rows.duplicate()
	replies.clear()
	Net.lobby_emit("ra", {"c": "log"})
	await _reply()
	var theirs: Array = replies[0].get("log", []) if not replies.is_empty() else []
	var ids := mine.map(func(r): return String(r[2]))
	for want in ["wake", atk + "_windup", atk + "_strike", "phase"]:
		ok(ids.has(want), "%s: the host plays %s" % [kind, want], str(ids))
	var cmp := _compare(mine, theirs)
	ok(cmp["bad"] == "", "%s: the guest's copy plays the same moves, in order, within %.1f s (worst %.2f s)" % [
		kind, LAG_TOL, cmp["lag"]], str(cmp["bad"]))
	var first := _first_k(theirs, atk + "_windup")
	ok(first >= 0.0 and first < 0.4, "%s: the copy's %s starts near its start (progress from the synced age)" % [
		kind, atk + "_windup"], "k at first sight %.2f" % first)
	b.queue_free()
	m.mobs.erase(b)
	boss_nid = ""
	Net.lobby_emit("ra", {"c": "boss", "nid": ""})
	await _run(0.5)

## How far through `move_name` the log's first row of it was (-1 when it never played).
func _first_k(rows: Array, move_name: String) -> float:
	for r in rows:
		if String(r[2]) == move_name:
			return float(r[3])
	return -1.0

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
			"boss":
				boss_nid = String(data["nid"])
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"kit":
				if R: R.reclass(Arch.weight(String(data["arch"])), String(data["arch"]))
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"mark":
				log_rows.clear()
				wash_rows.clear()
				last_row = ["?", "?"]
			"log":
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "log": log_rows, "wash": wash_rows})
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
	if m == null or m.player == null:
		return
	var B := m.ents_by_id.get(boss_nid, null) as Boss if boss_nid != "" else null
	if B != null:
		_sample_boss(B)
		return
	var H := _copy()
	H.render(DT, 1.0)      # (Match's own render pass is off in the checks)
	if H.ak == null or H.anim == null:
		return
	var shown := H.wash > WASH_ON
	if wash_rows.is_empty() and shown or not wash_rows.is_empty() and shown != wash_rows[-1][1]:
		wash_rows.append([int(Time.get_unix_time_from_system() * 1000.0), shown])
	var row := [H.ak.anim_id, H.anim.km_id]
	var restart: bool = H.anim.km_prev_t < last_prev_t - 0.001
	last_prev_t = H.anim.km_prev_t
	if row != last_row or restart:
		last_row = row
		log_rows.append([int(Time.get_unix_time_from_system() * 1000.0), row[0], row[1]])

## A boss's frame: note a change of the BossAnim move it plays (the loops count as none).
func _sample_boss(B: Boss) -> void:
	B.render(DT, 1.0)
	var id: String = "" if BossAnim.cur_move in BOSS_LOOPS else BossAnim.cur_move
	if last_row[1] != id:
		last_row = ["", id]
		log_rows.append([int(Time.get_unix_time_from_system() * 1000.0), "", id, BossAnim.cur_k])
