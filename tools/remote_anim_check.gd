extends "res://tools/displace_net_check.gd"
## --remote-anim-check: the kit move a Hunter plays on its own game plays on the other player's game too.
## Two real games over the desktop relay (the --displace-net-check harness, which this extends): the host's
## hunter casts each of its 12 kits' LMB, RMB, E, R and dash, tapped and held, and the guest's copy of it
## (a remote hunter fed only by the snapshots, Net 0.16.0's kit move id) must start the same HunterAnim move
## within LAG_TOL, and play nothing the host did not. Both games log every change of the move (the kit's
## id and HunterAnim's), compared per cast. Every AimKit `all` telegraph the host's hunter draws in a cast
## must show on the guest under its copy too (AimNet, Net 0.24.6), asserted once per shape kind.
## Lines: RANIM ok|FAIL <what>, then the unlike casts.

const LAG_TOL := 0.3         # s: one snapshot (0.1 s) plus the frames both games need to show it
const MIN_LIFE := 0.15       # s: a move replaced sooner than this never makes a snapshot
const SKEW := 0.05           # s: clocks of two processes on one machine
const SETTLE := 1.6          # s after the release for the move to play out and the snapshots to land
const HOLD := 0.8            # s a held key stays down
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
var wash_rows: Array = []    # [unix ms, tint showing] at each change of the watched hunter's body tint
var wash_host: Array = []    # Lace's tapped Shift: the host's rows
var wash_guest: Array = []   # ... and the guest's copy's
var tele := {}               # the watched hunter's `all` telegraphs this cast: id -> [shape kind, first ms, last ms]
var tele_kinds := {}         # shape kind -> host telegraphs of that kind over every cast ("arch key: id")
var tele_miss := {}          # shape kind -> the ones the guest never showed

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
	for arch in ARCHS:
		for key in KEYS:
			for held in ([false] if key in ["e", "r"] else [false, true]):
				await _cast(G, arch, key, held)
	_wash_rows_ok()
	ok(not tele_kinds.is_empty(), "some cast draws an all telegraph (else none was compared)")
	for kind in tele_kinds:
		var drawn: int = tele_kinds[kind].size()
		ok(not tele_miss.has(kind), "telegraph %s: all %d the host drew show on the guest" % [kind, drawn],
			"missing: %s" % str(tele_miss.get(kind, [])))
	for arch in ARCHS:
		ok(int(played.get(arch, 0)) > 0, "%s: some cast plays a kit move (else nothing was compared)" % arch)
		ok(not unlike.has(arch), "%s: the guest's copy plays what the host's does" % arch,
			"unlike: %s" % str(unlike.get(arch, [])))
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
	tele.clear()
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
	_tele_ok(what, replies[0].get("tele", {}) if not replies.is_empty() else {})
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

## Every `all` telegraph the host's hunter drew this cast for MIN_LIFE or more showed on the guest under its
## copy, same kind (one up for less can show and drop in the same 0.1 s flush).
func _tele_ok(what: String, theirs: Dictionary) -> void:
	for id in tele:
		var kind := String(tele[id][0])
		if (float(tele[id][2]) - float(tele[id][1])) / 1000.0 < MIN_LIFE:
			continue
		tele_kinds[kind] = tele_kinds.get(kind, []) + ["%s: %s" % [what, id]]
		if String(theirs.get(id, [""])[0]) != kind:
			tele_miss[kind] = tele_miss.get(kind, []) + ["%s: %s" % [what, id]]
			print("%s FAIL %s: telegraph %s (%s) not on the guest" % [tag, what, id, kind])
	if not tele.is_empty():
		var ids := tele.keys().map(func(id): return "%s %s" % [tele[id][0], id])
		print("%s %s  telegraphs: %s (guest shows %d)" % [tag, what, ", ".join(ids), theirs.size()])

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
			"kit":
				if R: R.reclass(Arch.weight(String(data["arch"])), String(data["arch"]))
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"mark":
				log_rows.clear()
				wash_rows.clear()
				tele.clear()
				last_row = ["?", "?"]
			"log":
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0], "log": log_rows, "wash": wash_rows, "tele": tele})
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
	var H := _copy()
	H.render(DT, 1.0)      # (Match's own render pass is off in the checks)
	if H.ak == null or H.anim == null:
		return
	_tele_sample(H)
	var shown := H.wash > WASH_ON
	if wash_rows.is_empty() and shown or not wash_rows.is_empty() and shown != wash_rows[-1][1]:
		wash_rows.append([int(Time.get_unix_time_from_system() * 1000.0), shown])
	var row := [H.ak.anim_id, H.anim.km_id]
	var restart: bool = H.anim.km_prev_t < last_prev_t - 0.001
	last_prev_t = H.anim.km_prev_t
	if row != last_row or restart:
		last_row = row
		log_rows.append([int(Time.get_unix_time_from_system() * 1000.0), row[0], row[1]])

## The `all` telegraphs up under the watched hunter now (the host's own, the guest's copy's).
func _tele_sample(h: Hunter) -> void:
	var d := AimKit.layer(m)
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	for k in d.entries:
		var e: Dictionary = d.entries[k]
		if e["h"] == h and e["all"] and d.live(e):
			var id := String(k).substr(String(k).find(":") + 1)
			if not tele.has(id): tele[id] = [String(e["kind"]), now, now]
			tele[id][2] = now
