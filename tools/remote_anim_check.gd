extends "res://tools/displace_net_check.gd"
## --remote-anim-check: the kit move a Hunter plays on its own game plays on the other player's game too.
## Two real games over the desktop relay (the --displace-net-check harness, which this extends): the host's
## hunter casts each of its 12 kits' LMB, RMB, E, R and dash, tapped and held, and the guest's copy of it
## (a remote hunter fed only by the snapshots, Net 0.16.0's kit move id, or its clear) must start, and drop, the same
## HunterAnim move within LAG_TOL, and play nothing the host did not. CUTS: holds cancelled mid-move. Both games log
## every change of the
## move (the kit's id and HunterAnim's), compared per cast. Vex's tapped RMB also
## compares the ground cone her Burr Charge shows stuck on a wall (a row of rock tiles 4 m out on the host only;
## the "cone" fx, Net 0.24.5): the guest's copy must draw it as long as the host's.
## Then the lair bosses (Net 0.24.6's "bat" event): the
## host wakes a Stone Colossus, a Stormcoil and a Brood Mother and has each play an attack, and the guest's copy (a
## Boss fed by the snapshots and the event) must play the same BossAnim moves (wake, wind-up, strike, phase) within
## LAG_TOL, its wind-up starting near its start (the progress counts on from the synced age).
## Every AimKit `all` telegraph the host's hunter draws in a cast must show on the guest under its copy too
## (AimNet, Net 0.24.6), asserted once per shape kind.
## Grimble's Deep Reach (Net 0.24.20): the host's Grimble hooks the guest's hunter and reels them in; on the guest his
## arm (the model's WardenReach.TIP) reaches out, as far, within a snapshot of the host's, and no plain shot flies.
## Lines: RANIM ok|FAIL <what>, then the unlike casts. The registry splits the run into four flags
## (tools/checks/net.gd: --remote-anim-1/2/3-check cast a third of ARCHS each, --remote-anim-rest-check the bosses, the
## re-time and Grimble's reach; each under the gate's 300 s cap); the guest is started with --remote-anim-guest.

const LAG_TOL := 0.3  # s: one snapshot (0.1 s) plus the frames both games need to show it
const MIN_LIFE := 0.15  # s: a move replaced sooner than this never makes a snapshot
const SKEW := 0.05  # s: clocks of two processes on one machine
const NET_SNAP_TOL := 0.08  # s: a re-time on the copy is the host's to within the age snap plus a frame
const SETTLE := 1.6  # s after the release for the move to play out and the snapshots to land
const HOLD := 0.8  # s a held key stays down
const WALK := 3.6  # s more after Lace's Spirit Walk starts, so the walk (2.8 s, 3.3 s at rank 3) runs out
const WASH_ON := 0.15  # the body tint (Ent.wash) counts as showing above this
const REST := "rest"  # the shard with the bosses, the re-time and the reach row (no Hunter casts)
const SHARDS := 3  # Hunter shards "1".."3": each casts its third of ARCHS
const KEYS := ["lmb", "rmb", "e", "r", "dash"]
const BOSSES := {"colossus": "slam", "serpent": "dash", "brood": "spit"}  # the attack each plays
const BOSS_LOOPS := ["idle", "walk", "stagger", "sleep"]  # (not compared: the copy's gait may differ a step)
const BOSS_AT := Vector3(3.0, 0, 0)  # m from home: where a boss stands (the lair is round it)
const ARCHS := [
	"archer",
	"ashwick",
	"bulwark",
	"dolm",
	"dredge",
	"gunslinger",
	"juggernaut",
	"mage",
	"ostra",
	"rimewright",
	"tender",
	"thief"
]

## Holds a kit cancels by clearing its move id (Albert's raised shield, Lace's Heavy Shot draw, Kael's Lunge
## wind-up): held CUT_AT s, then cut as a Boki merge cuts them (MergeAugment), the key let go after.
const CUTS := ["archer rmb", "bulwark rmb", "juggernaut rmb"]
const CUT_AT := 0.6  # s: past every RMB hold threshold (0.1-0.3 s) plus a snapshot, so the hold move shows

## Casts whose copy still differs, and why (docs/DEBT.md): printed as GAP, not failures (timing may hide one
## run to run).
const KNOWN := {
	"gunslinger lmb held": "one restart in ten (2.36 s in, rpc5 11-15) still does not show on the copy",
}

var log_rows: Array = []  # [unix ms, the kit's move id, HunterAnim's move id]; one row per change or restart
var last_row := ["?", "?"]
var last_prev_t := 0.0
var unlike := {}  # arch -> casts whose copy differs
var played := {}  # arch -> casts that played any move
var boss_nid := ""  # the boss both games log (the guest's copy of it)
var cone_len := 0.0  # m: the longest ground cone the watched hunter showed since the mark
var reach := {}  # the watched hunter's arm out since the mark: {from, to (unix ms), len (m, the farthest)}
var balls := 0  # the most plain (cosmetic) shots this game had flying at once since the mark
var wash_rows: Array = []  # [unix ms, tint showing] at each change of the watched hunter's body tint
var wash_host: Array = []  # Lace's tapped Shift: the host's rows
var wash_guest: Array = []  # ... and the guest's copy's
var tele := {}  # the watched hunter's `all` telegraphs this cast: id -> [shape kind, first ms, last ms]
var tele_kinds := {}  # shape kind -> host telegraphs of that kind over every cast ("arch key: id")
var tele_miss := {}  # shape kind -> the ones the guest never showed
var retimes: Array = []  # [unix ms, s]: the watched move's clock jumped earlier, same id (a re-time)
var archs: Array = ARCHS  # the Hunters this shard casts
var rest := true  # this shard runs the bosses, the re-time and the reach row
var last_at := ["", 0.0]  # the watched kit's move id and anim_at at the last frame


func _init() -> void:
	tag = "RANIM"
	guest_flag = "--remote-anim-guest"


func run(main_node: Node, shard := "") -> void:
	if shard != "":
		rest = shard == REST
		var n_v := ARCHS.size()
		var i := int(shard) - 1
		archs = [] if rest else ARCHS.slice(ceili(i * n_v / float(SHARDS)), ceili((i + 1) * n_v / float(SHARDS)))
	main_node.get_tree().process_frame.connect(_sample)
	await super.run(main_node)


# ------------------------------------------------------------------ the host
func _host() -> void:
	var g := await _host_up()
	if g == null:
		return _finish()
	ok(Net.VERSION != "0.24.5", "the Net version moved on with the boss event (%s)" % Net.VERSION)
	if rest:
		for kind in BOSSES:
			await _boss(kind, String(BOSSES[kind]))
	for arch in archs:
		for key in KEYS:
			for held in [false] if key in ["e", "r"] else [false, true]:
				await _cast(g, arch, key, held)
			if "%s %s" % [arch, key] in CUTS:
				await _cast(g, arch, key, true, true)
	if "archer" in archs:
		_wash_rows_ok()
	if not archs.is_empty():
		ok(not tele_kinds.is_empty(), "some cast draws an all telegraph (else none was compared)")
	for kind in tele_kinds:
		var drawn: int = tele_kinds[kind].size()
		ok(
			not tele_miss.has(kind),
			"telegraph %s: all %d the host drew show on the guest" % [kind, drawn],
			"missing: %s" % str(tele_miss.get(kind, []))
		)
	if rest:
		await _ram_retime()
		await _reach_row(g)
	for arch in archs:
		ok(int(played.get(arch, 0)) > 0, "%s: some cast plays a kit move (else nothing was compared)" % arch)
		ok(
			not unlike.has(arch),
			"%s: the guest's copy plays what the host's does" % arch,
			"unlike: %s" % str(unlike.get(arch, []))
		)
	if rest:
		await _hazard_moves()
	_finish()


## One boss of `kind` on the host, asleep, woken, one attack, a phase change: the guest's copy plays the same.
func _boss(kind: String, atk: String) -> void:
	var p := m.player
	p.reclass(Arch.weight("gunslinger"), "gunslinger")
	p.teleport(home)
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
	b.set_asleep(false)
	b.awake_t = 0.0
	await _run(2.0)
	b.tgt = p
	match atk:
		"slam":
			b._atk_slam()
		"dash":
			b._atk_dash()
		"spit":
			b._atk_spit()
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
	ok(
		cmp["bad"] == "",
		(
			"%s: the guest's copy plays the same moves, in order, within %.1f s (worst %.2f s)"
			% [kind, LAG_TOL, cmp["lag"]]
		),
		str(cmp["bad"])
	)
	var first := _first_k(theirs, atk + "_windup")
	ok(
		first >= 0.0 and first < 0.4,
		"%s: the copy's %s starts near its start (progress from the synced age)" % [kind, atk + "_windup"],
		"k at first sight %.2f" % first
	)
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


## Deep water and ice on the host's strip (the training island has none; only the owner's game needs the areas:
## the copy's move comes from the snapshot). Its hunter, with no ward, stands in each and on dry ground.
func _hazard_moves() -> void:
	var p := m.player
	p.perks.clear()
	if m.biomes == null:
		m.biomes = BiomeRun.new(m)
	m.biomes.terrain = TerrainHazards.new(m)
	var tz := m.biomes.terrain
	var spots := {"deep_water": home + Vector3(-5.0, 0, -6.0), "ice": home + Vector3(10.0, 0, -6.0), "": home}
	for kind in ["deep_water", "ice"]:
		var c: Vector3 = spots[kind]
		tz._add_area(
			kind,
			[[c.x - 2.5, c.z - 2.5], [c.x + 2.5, c.z - 2.5], [c.x + 2.5, c.z + 2.5], [c.x - 2.5, c.z + 2.5]]
		)
	for kind: String in spots:
		_fresh(p)
		p.teleport(spots[kind])
		await _run(0.8)
		var mine := [bool(p.anim_s.get("swim", false)), not (p.anim_s.get("footing", {}) as Dictionary).is_empty()]
		replies.clear()
		Net.lobby_emit("ra", {"c": "hz"})
		await _reply()
		var got: Dictionary = replies[0] if not replies.is_empty() else {}
		var theirs := [bool(got.get("swim", false)), bool(got.get("footing", false))]
		var want := [kind == "deep_water", kind == "ice"]
		var where := kind if kind != "" else "dry ground"
		ok(mine == want, "hazard moves: the host's hunter on %s (swim, footing) = %s" % [where, str(want)], str(mine))
		ok(theirs == want, "hazard moves: the guest's copy on %s shows the same" % where, str(theirs))
		var sunk := -float(got.get("sink", 0.0))
		ok(
			(sunk > 0.4) == (kind == "deep_water"),
			"hazard moves: the copy is sunk in only in deep water (%s)" % where,
			"%.2f m" % sunk
		)
	_fresh(p)


func _cast(_g: Hunter, arch: String, key: String, held: bool, cut := false) -> void:
	var p := m.player
	var what := "%s %s%s" % [arch, key, " held" if held else ""]
	if cut:
		what = "%s %s cut" % [arch, key]
	p.reclass(Arch.weight(arch), arch)
	p.unlock_all()
	p.lvl = 6
	_kit(arch)
	p.fire_cd = 0.0
	p.ammo = int(p.wpn.get("mag", 12))
	replies.clear()
	Net.lobby_emit("ra", {"c": "kit", "arch": arch})
	await _reply()
	_aim(p.pos + Vector3(6.0, 0, 0))
	await _run(0.3)
	log_rows.clear()
	wash_rows.clear()
	tele.clear()
	last_row = ["?", "?"]
	cone_len = 0.0
	Net.lobby_emit("ra", {"c": "mark"})
	await _run(0.2)
	var rocks := what == "gunslinger rmb"  # only a wall gives the cone
	if rocks:
		_rocks(World.T_BLOCK)
	await _press(key, held, cut)
	var lace_walk: bool = what == "archer dash"
	await _run(SETTLE + (WALK if lace_walk else 0.0))
	if rocks:
		_rocks(World.T_GROUND)
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
	if what == "gunslinger rmb":
		var their_cone := float(replies[0].get("cone", 0.0)) if not replies.is_empty() else 0.0
		ok(
			cone_len > 0.0 and absf(their_cone - cone_len) < 0.05,
			"gunslinger rmb: the guest draws the Burr cone as long as the host",
			"host %.2f m, guest %.2f m" % [cone_len, their_cone]
		)
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


## Grimble's Deep Reach on the guest: the host's Grimble hooks the guest's hunter 6 m out and reels them in.
func _reach_row(g: Hunter) -> void:
	var p := m.player
	p.reclass(Arch.weight("dredge"), "dredge")
	replies.clear()
	Net.lobby_emit("ra", {"c": "kit", "arch": "dredge"})
	await _reply()
	await _place(g, home + Vector3(6.0, 0, 0))
	_kit("dredge")
	_aim(g.pos)
	reach = {}
	balls = 0
	Net.lobby_emit("ra", {"c": "mark"})
	await _run(0.2)
	p.inp["sec_hold"] = false
	p.ak.press_rmb()
	await _run(SETTLE + 1.0)
	replies.clear()
	Net.lobby_emit("ra", {"c": "log"})
	await _reply()
	var theirs: Dictionary = replies[0].get("reach", {}) if not replies.is_empty() else {}
	var lag_in := (float(theirs.get("from", 0)) - float(reach.get("from", 0))) / 1000.0
	var lag_out := (float(theirs.get("to", 0)) - float(reach.get("to", 0))) / 1000.0
	var len_h := float(reach.get("len", 0.0))
	var len_g := float(theirs.get("len", 0.0))
	var arrived := (p.ak as DredgeKit).arrivals
	ok(
		(
			len_h > 3.0
			and arrived > 0
			and absf(len_g - len_h) < 0.6
			and lag_in > -SKEW
			and lag_in < LAG_TOL
			and absf(lag_out) < LAG_TOL
		),
		"Grimble's Deep Reach: on the guest his arm reaches and holds as on the host",
		"host %.2f m, guest %.2f m, in +%.2f s, out %+.2f s, arrivals %d" % [len_h, len_g, lag_in, lag_out, arrived]
	)
	var their_balls := int(replies[0].get("balls", -1)) if not replies.is_empty() else -1
	ok(their_balls == 0, "Grimble's Deep Reach: the guest draws no plain shot for his hook", "%d" % their_balls)
	var out_h := int(reach.get("to", 0)) - int(reach.get("from", 0))
	var out_g := int(theirs.get("to", 0)) - int(theirs.get("from", 0))
	print("%s reach host %.2f m %d ms, guest %.2f m %d ms" % [tag, len_h, out_h, len_g, out_g])


## Three tiles 4 m out on the cast line (+x of the hunter), set to `kind`.
func _rocks(kind: int) -> void:
	var w := m.world
	for dz in [-1, 0, 1]:
		w.kind[w.idx(int(floor(m.player.pos.x + 4.0)), int(floor(m.player.pos.z)) + dz)] = kind


## One key for the kit: tapped (one step) or held for HOLD s (CUT_AT, then cut), then let go. E gets a flick of the
## aim (Sparkle's drag).
func _press(key: String, held: bool, cut := false) -> void:
	var p := m.player
	var secs := HOLD if held else DT
	if cut:
		secs = CUT_AT
	var flick := p.pos + Vector3(6.0, 0, 4.0)
	match key:
		"lmb":
			p.inp["fire"] = true
		"rmb":
			p.inp["sec"] = true
		"e":
			p.inp["sig"] = true
		"r":
			p.inp["ult"] = true
		"dash":
			p.do_dash()
	var t := 0.0
	while t < maxf(secs, DT) - 0.0001:
		if key == "rmb":
			p.inp["sec_hold"] = held
		if key == "dash":
			p.inp["dash_down"] = held
		if key == "e" and t > 0.2:
			_aim(flick)
		await _run(DT)
		t += DT
		if key != "lmb" or not held:
			p.inp["fire"] = false
		p.inp["sec"] = false
	if cut:
		MergeAugment.drop_class_holds(p)
		p.ak.drop_holds()
	for k in ["fire", "sec_hold", "dash_down", "sig", "ult"]:
		p.inp[k] = false
	if key == "e":
		_aim(p.pos + Vector3(6.0, 0, 0))


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


## Cinder's ram into a foe: the hit re-times as_leap onto its squash key (ArchKit.retime, about 0.23 s earlier,
## under the 0.3 s resync), and the guest's copy must move its clock by the same within LAG_TOL of the host's.
func _ram_retime() -> void:
	var p := m.player
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
	p.do_dash()
	await _run(SETTLE)
	var mine := retimes.duplicate()
	replies.clear()
	Net.lobby_emit("ra", {"c": "log"})
	await _reply()
	var theirs: Array = replies[0].get("rt", []) if not replies.is_empty() else []
	var detail := "host %s guest %s" % [str(mine), str(theirs)]
	ok(
		mine.size() == 1 and float(mine[0][1]) < -0.1,
		"ashwick ram hit: the host's as_leap jumps to its squash key",
		detail
	)
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
	for r in mine:
		ids[String(r[2])] = true
	for r in theirs:
		if not ids.has(String(r[2])) and out["bad"] == "":
			out["bad"] = "the copy plays '%s', the host never did" % r[2]
	var at := 0
	var shown := ""  # the host's last move that lasted a snapshot
	for i in mine.size():
		var id := String(mine[i][2])
		var life: float = (float(mine[i + 1][0]) - float(mine[i][0])) / 1000.0 if i + 1 < mine.size() else 9.0
		if life < MIN_LIFE or i == 0:
			if i == 0:
				shown = id
			continue
		if id == "" and shown == "":
			continue  # (no move again after one no snapshot carried, a tapped shield: the copy never changed)
		shown = id
		if id != "":
			out["moves"] += 1
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
		var r := _copy()
		match String(data.get("c", "")):
			"boss":
				boss_nid = String(data["nid"])
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"kit":
				if r:
					r.reclass(Arch.weight(String(data["arch"])), String(data["arch"]))
				Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
			"mark":
				log_rows.clear()
				retimes.clear()
				wash_rows.clear()
				tele.clear()
				last_row = ["?", "?"]
				cone_len = 0.0
				reach = {}
				balls = 0
			"log":
				var reply := {"pos": [0, 0, 0], "log": log_rows, "wash": wash_rows, "rt": retimes, "cone": cone_len}
				reply.merge({"tele": tele, "reach": reach, "balls": balls})
				Net.lobby_emit("dn_r", reply)
			"hz":
				Net.lobby_emit(
					"dn_r",
					{
						"pos": [0, 0, 0],
						"swim": bool(r.anim_s.get("swim", false)),
						"footing": not (r.anim_s.get("footing", {}) as Dictionary).is_empty(),
						"sink": r.model.position.y if r.model else 0.0
					}
				)
		return
	super._on_msg(topic, data, from)


## The other game's hunter on this one: the host's copy on the guest, the player on the host.
func _copy() -> Hunter:
	if not Net.is_host():
		for h in m.hunters:
			if h.remote:
				return h
	return m.player


# ------------------------------------------------------------------ both
## Every frame: note a change of the watched hunter's move (the kit's id, HunterAnim's id, or a restart).
func _sample() -> void:
	if m == null or m.player == null:
		return
	var b := m.ents_by_id.get(boss_nid, null) as Boss if boss_nid != "" else null
	if b != null:
		_sample_boss(b)
		return
	var h_v := _copy()
	h_v.render(DT, 1.0)  # (Match's own render pass is off in the checks)
	var aims := AimKit.layer(m)
	for e: Dictionary in aims.entries.values():
		if e["h"] == h_v and e["kind"] == "cone" and aims.live(e):
			cone_len = maxf(cone_len, float(e["len"]))
	_reach_sample(h_v)
	if h_v.ak == null or h_v.anim == null:
		return
	_tele_sample(h_v)
	var shown := h_v.wash > WASH_ON
	if wash_rows.is_empty() and shown or not wash_rows.is_empty() and shown != wash_rows[-1][1]:
		wash_rows.append([int(Time.get_unix_time_from_system() * 1000.0), shown])
	var jump: float = h_v.ak.anim_at - float(last_at[1])
	if h_v.ak.anim_id == last_at[0] and jump < -0.02 and jump > -0.6:
		retimes.append([int(Time.get_unix_time_from_system() * 1000.0), snappedf(jump, 0.01)])
	last_at = [h_v.ak.anim_id, h_v.ak.anim_at]
	var row := [h_v.ak.anim_id, h_v.anim.km_id]
	var restart: bool = h_v.anim.km_prev_t < last_prev_t - 0.001
	last_prev_t = h_v.anim.km_prev_t
	if row != last_row or restart:
		last_row = row
		log_rows.append([int(Time.get_unix_time_from_system() * 1000.0), row[0], row[1]])


## Grimble's arm on the watched hunter (its model's WardenReach.TIP): when it is out and how far it reaches.
func _reach_sample(h_v: Hunter) -> void:
	balls = maxi(balls, m.shots.filter(func(s: Dictionary) -> bool: return s["x"].get("cos", false)).size())
	var tip: Vector3 = h_v.model.get_meta(WardenReach.TIP, Vector3.INF) if h_v.model else Vector3.INF
	if not tip.is_finite():
		return
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	reach["from"] = reach.get("from", ms)
	reach["to"] = ms
	reach["len"] = maxf(float(reach.get("len", 0.0)), Vector2(tip.x - h_v.pos.x, tip.z - h_v.pos.z).length())


## The `all` telegraphs up under the watched hunter now (the host's own, the guest's copy's).
func _tele_sample(h: Hunter) -> void:
	var d := AimKit.layer(m)
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	for k in d.entries:
		var e: Dictionary = d.entries[k]
		if e["h"] == h and e["all"] and d.live(e):
			var id := String(k).substr(String(k).find(":") + 1)
			if not tele.has(id):
				tele[id] = [String(e["kind"]), now, now]
			tele[id][2] = now


## A boss's frame: note a change of the BossAnim move it plays (the loops count as none).
func _sample_boss(b: Boss) -> void:
	b.render(DT, 1.0)
	var id: String = "" if BossAnim.cur_move in BOSS_LOOPS else BossAnim.cur_move
	if last_row[1] != id:
		last_row = ["", id]
		log_rows.append([int(Time.get_unix_time_from_system() * 1000.0), "", id, BossAnim.cur_k])
