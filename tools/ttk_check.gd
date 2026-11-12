extends "res://tools/archetype_check.gd"
## --ttk-check: time to knock for all 12 Hunters against the source (PARITY FIRST, briefs/DECISIONS.md 2026-11-07).
## Ours: a live Match, the Hunter against an idle standard target (roster mean health, full armour).
## Source: the same fight worked out from supervive_kits.md (briefs/supervive-data on origin/ext/agent-briefs).
## (a) LMB alone; (b) the kit's simple combo: every direct-damage non-ult ability once, then again whenever its
## cooldown or charge is back, LMB between. Each at rank 0 (unspent, slot_lv 1) and max.
## Rows outside RATIO_LO..RATIO_HI fail unless OVERRIDES cites the owner decision. --write updates docs/TTK.md.

const RATIO_LO := 0.85     # ours / source time to knock: the parity bar, +-15% (owner digest 1112)
const RATIO_HI := 1.15
const SOURCE_DR := 0.2     # Common armour reduction (docs/SUPERVIVE_DATA.md section 3; its durability outlasts it)
const OUR_HP := 154.0      # mean of the 12 Hunters' health (light 124, medium 145, heavy 193)
const SRC_HP := 1285.0     # mean Base HP of the 12 (supervive_physics.md attribute table)
const SRC_HP_LV := 77.1    # mean HP per level; the level 15 tooltips face a level 15 target
const DIST := 1.5          # m to the target: inside every melee reach, short of the sweet-spot tips
const DRAW_S := 1.1        # s a bow is held before the release (the full draw)
const STATIC_NEVER := 99   # Static stacks Sparkle's Blowout waits for: out of reach, see _fight
const MAX_S := 20.0        # a row that has not knocked by then counts as never
const DT_SRC := 0.01       # s step of the source model

## One row per Hunter: [id, source name, our LMB mode (hold / tap / draw), read at level 15, source LMB, abilities,
## and optionally the Daze its combo puts on the target]. LMB is [damage, interval s, extra damage per consecutive
## hit], optionally + [front-load share, rounds]: the first round deals that much extra, falling off by that round.
## The Daze is {"from": slot that applies it, "t": s, "lmb": flat extra per round, slot: extra share}.
## Abilities map a slot to [damage, damage gain at max rank, cooldown s, cooldown cut at max rank, charges,
## extra charges at max rank]. Every number is a supervive_kits.md tooltip (level 1, or level 15 where its
## section says so) unless its row's comment names another source. A Hunter whose
## LMB has no damage number there has no source row (n/a).
const HEROES := [
	# MK7: 51/round, the first 10 extra (supervive_kits.md:48), opening at 2x (wiki: "decays over your first 10
	# rounds to 50%"); its Spike Grenade Dazes: +39 a round, Railgun +20% (:48-51), 1.2 s (docs/SUPERVIVE_DATA.md)
	["gunslinger", "Ghost", "hold", false, [51.0, 0.08, 0.0, 1.0, 10], {
		"rmb": [165.0, 0.0, 9.0, 3.0, 1, 0], "e": [202.0, 0.4, 12.0, 0.0, 1, 0]},
		{"from": "rmb", "t": 1.2, "lmb": 39.0, "e": 0.2}],
	["juggernaut", "Brall", "tap", false, [43.0, 0.35, 0.0], {
		"rmb": [130.0, 0.4, 2.5, 0.0, 1, 0], "dash": [49.0, 0.0, 13.0, 5.0, 2, 1],
		"e": [30.0, 0.0, 16.0, 6.0, 1, 0]}],
	["ashwick", "Felix", "hold", false, [25.8, 0.1, 0.0], {
		"rmb": [106.0, 0.5, 9.0, 3.0, 1, 1], "dash": [150.4, 0.266, 9.0, 1.5, 2, 0],
		"e": [76.8, 0.5, 13.0, 4.0, 1, 0]}],
	["mage", "Joule", "hold", false, [90.0, 0.8, 0.0], {
		"rmb": [133.0, 0.9, 10.0, 2.0, 1, 0], "dash": [153.0, 1.0, 9.0, 1.5, 1, 0],
		"e": [162.0, 0.5, 12.0, 3.0, 1, 0]}],
	["bulwark", "Oath", "tap", true, [192.0, 0.45, 0.0], {"dash": [364.0, 0.0, 8.0, 3.0, 1, 0]}],
	["thief", "Shiv", "hold", true, [160.0, 0.45, 16.0], {"rmb": [46.0, 0.5, 13.0, 4.0, 1, 0]}],
	["ostra", "Void", "hold", true, [263.0, 0.6, 0.0], {
		"rmb": [277.0, 0.4, 10.0, 3.0, 1, 0], "e": [365.0, 0.2, 10.0, 2.0, 1, 0]}],
	["archer", "Myth", "draw", false, [], {}],
	["tender", "Elluna", "hold", false, [], {}],
	["dolm", "Tetra", "tap", false, [], {}],
	["dredge", "Kingpin", "hold", false, [], {}],
	["rimewright", "Celeste", "hold", false, [], {"rmb": [346.0, 0.547, 12.0, 3.5, 2, 0]}],
]

## Ults the share table lists (never in a combo): hero -> source damage of one cast. our_hit casts it, then
## waits ULT_WAIT s for a held ult to go off (Rimelock cracks open at 3.5 s).
const ULT_HITS := {"rimewright": 155.0}
const ULT_WAIT := 4.5

## Casts whose hit hands another slot back: hero -> [slot, slot it resets]. Joule's Voltaic Spear leaves a Lightning
## Orb that resets Surge (supervive_kits.md:66); the fight takes the orb at once, so each Spear adds one Surge.
const RESETS := {"mage": ["rmb", "dash"]}

## Owner decisions that explain an outlier row: hero -> "DECISIONS date: what" (none cover a whole row yet).
const OVERRIDES := {}

var rows: Array = []
var hits: Array = []      # [id, source name, slot, our share of the target, source share]
var blowout := false      # Sparkle's Blowout live: only for the rows that show it, never judged
var static_max := 0       # her own Static cap, put back for those rows (the parity rows lift it out of reach)

## Seconds until the [time, damage] hits add up to `need`, or -1.
func _src_knock(shots: Array, need: float) -> float:
	shots.sort_custom(func(a, b): return a[0] < b[0])
	var sum := 0.0
	for shot in shots:
		sum += shot[1]
		if sum >= need:
			return shot[0]
	return -1.0

## The source fight: LMB shots and abilities at their cooldowns, until `need` raw damage lands.
func src_ttk(hero: Array, combo: bool, max_rank: bool) -> float:
	var lmb: Array = hero[4]
	if lmb.is_empty():
		return -1.0
	var need := _src_hp(hero) / (1.0 - SOURCE_DR)
	var daze: Dictionary = hero[6] if combo and hero.size() > 6 else {}
	var dazed := _casts(hero, String(daze.get("from", "")), max_rank)
	var shots := []
	var t := 0.0
	var n := 0
	while t <= MAX_S:
		var dmg := float(lmb[0]) + float(lmb[2]) * n
		if lmb.size() > 3:
			dmg += float(lmb[0]) * float(lmb[3]) * maxf(0.0, 1.0 - float(n) / float(lmb[4]))
		if _in_daze(dazed, daze, t):
			dmg += float(daze["lmb"])
		shots.append([t, dmg])
		n += 1
		t += float(lmb[1])
	for slot in hero[5] if combo else {}:
		var dmg := _cast_dmg(hero[5][slot], max_rank)
		for at in _casts(hero, slot, max_rank):
			var k := 1.0 + float(daze.get(slot, 0.0)) * float(_in_daze(dazed, daze, at))
			shots.append([at, dmg * k])
	var reset: Array = RESETS.get(hero[0], []) if combo else []
	if not reset.is_empty():
		for at in _casts(hero, reset[0], max_rank):
			shots.append([at, _cast_dmg(hero[5][reset[1]], max_rank)])
	return _src_knock(shots, need)

## One source cast's damage at rank 0 or max.
func _cast_dmg(a: Array, max_rank: bool) -> float:
	return float(a[0]) * (1.0 + float(a[1]) * float(max_rank))

## The times the source casts `slot` in a fight: every charge at 0 s, then again each cooldown.
func _casts(hero: Array, slot: String, max_rank: bool) -> Array:
	var out := []
	if not hero[5].has(slot):
		return out
	var a: Array = hero[5][slot]
	var cd := float(a[2]) - float(a[3]) * float(max_rank)
	for c in int(a[4]) + int(a[5]) * int(max_rank):
		var t := 0.0
		while t <= MAX_S:
			out.append(t)
			t += cd
	return out

## Does a hit at `t` land while one of the Daze casts at `starts` holds.
func _in_daze(starts: Array, daze: Dictionary, t: float) -> bool:
	for s in starts:
		if t >= s and t <= s + float(daze["t"]):
			return true
	return false

func _src_hp(hero: Array) -> float:
	return SRC_HP + (SRC_HP_LV * 14.0 if hero[3] else 0.0)

## A fresh fight: the Hunter at `rank` and the standard target (armoured or not) held on its spot.
func _fight(arch: String, rank: int, armoured: bool) -> Array:
	var r := setup(arch, DIST, "", false)
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	for s in ["sec", "dash", "kin"]:
		P.slot_lv[s] = rank
	P.dashes = P.max_dashes()
	_leave_out_blowout(P)
	T.max_hp = OUR_HP
	T.hp = OUR_HP
	T.max_armor = round(OUR_HP * Hunter.ARMOR_DUR) if armoured else 0.0
	T.armor = T.max_armor
	return [r[0], P, T, T.pos]

## Sparkle's Blowout (4 Static, run through) is a conditional bonus the source gives no number for ("massive bonus",
## supervive_kits.md:64-67), so the parity rows leave it out of ours as the source side does; her charge orb is
## counted on both sides (RESETS). The "+ Blowout" rows show it live; --mage-combo-check holds the passive itself.
func _leave_out_blowout(P: Hunter) -> void:
	var rd := P.ak.res_def()
	if rd.get("id", "") != "sparks":
		return
	if static_max == 0:
		static_max = int(rd["max"])
	rd["max"] = static_max if blowout else STATIC_NEVER

## One step: the target stays put, the Hunter aims at it, then the world moves on.
func _tick(m: Match, P: Hunter, T: Hunter, spot: Vector3) -> void:
	T.pos = spot
	T.vel = Vector3.ZERO
	T.stun_t = 0.0
	aim_at(P, spot)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.step(DT)
	P.inp["dash"] = false
	P.inp["sig"] = false

## Our fight: seconds to knock, or -1.
func our_ttk(hero: Array, combo: bool, rank: int) -> float:
	var f := _fight(hero[0], rank, true)
	var m: Match = f[0]
	var P: Hunter = f[1]
	var T: Hunter = f[2]
	var slots: Array = hero[5].keys() if combo else []
	var t := 0.0
	var out := -1.0
	while t < MAX_S and out < 0.0:
		P.inp["fire"] = _fire_down(hero[2], t)
		_abilities(P, slots)
		_tick(m, P, T, f[3])
		t += DT
		if T.hp <= 0.0 or T.downed:
			out = t
	await done(m)
	return out

## Is the LMB down at time t: held, tapped every other step, or drawn DRAW_S then released a step.
func _fire_down(mode: String, t: float) -> bool:
	if mode == "tap":
		return int(t / DT) % 2 == 0
	if mode == "draw":
		return fmod(t, DRAW_S + DT) < DRAW_S
	return true

## What one cast of `slot` does to the target at rank 1, as a share of its health.
func our_hit(arch: String, slot: String) -> float:
	var f := _fight(arch, 1, false)
	var m: Match = f[0]
	var P: Hunter = f[1]
	var T: Hunter = f[2]
	var wait := 2.0
	if slot == "x":
		P.slot_lv["ult"] = 1
		P.ak.cast_ult()
		wait = ULT_WAIT
	else:
		_abilities(P, [slot])
	var t := 0.0
	while t < wait:
		if slot == "e":
			_abilities(P, [slot])      # (the recast that sets a planted E off)
		_tick(m, P, T, f[3])
		t += DT
	var share := (OUR_HP - T.hp) / OUR_HP
	await done(m)
	return share

## Casts one listed ability that is ready (RMB is a tap; E is pressed again while its window is up).
func _abilities(P: Hunter, slots: Array) -> void:
	var K: ArchKit = P.ak
	if K.busy() or K.cast_locked():
		return
	if "dash" in slots and P.dashes >= 1.0 and K.dash_t < 0.0:
		P.inp["dash"] = true
	elif "rmb" in slots and K.rmb_ready():
		P.inp["sec_hold"] = false
		K.press_rmb()
	elif "e" in slots and (float(K.cd["e"]) <= 0.0 or K.e_t > 0.0):
		P.inp["sig"] = true

func _fmt(v: float) -> String:
	return "never" if v < 0.0 else "%.2f" % v

func _ratio_text(ratio: float) -> String:
	return "%.2f" % ratio if ratio > 0.0 else "n/a"

## One table row: ours, source and the verdict.
func _cell(hero: Array, label: String, ours: float, src: float) -> Dictionary:
	var row := {"hero": hero[0], "name": hero[1], "label": label, "ours": ours, "src": src}
	row["ratio"] = -1.0
	row["state"] = "n/a"
	if src <= 0.0:
		return row
	row["ratio"] = ours / src if ours > 0.0 else 99.0
	if row["ratio"] >= RATIO_LO and row["ratio"] <= RATIO_HI:
		row["state"] = "ok"
	elif row["ratio"] > RATIO_HI and row["ratio"] <= RATIO_HI / (1.0 - _given_up(hero[0])):
		row["state"] = "override"
	else:
		row["state"] = "FAIL"
	return row

## The damage share an owner decision lets this Hunter give up (OVERRIDES), else 0.
func _given_up(id: String) -> float:
	return float(OVERRIDES[id][0]) if OVERRIDES.has(id) else 0.0

func run(main_node: Node) -> void:
	main = main_node
	var bad := 0
	for hero in HEROES:
		for combo in [false, true]:
			if combo and hero[5].is_empty():
				continue
			for rank in [1, 3]:
				var ours: float = await our_ttk(hero, combo, rank)
				var src := src_ttk(hero, combo, rank == 3)
				var kind := "combo" if combo else "LMB"
				var label := "%s %s" % [kind, "rank 0" if rank == 1 else "rank max"]
				var row := _cell(hero, label, ours, src)
				rows.append(row)
				bad += int(row["state"] == "FAIL")
				print("TTK %-4s %-11s %-14s ours %s s, source %s s, ratio %s" % [
					row["state"], hero[0], label, _fmt(ours), _fmt(src), _ratio_text(row["ratio"])])
	for hero in HEROES:
		for slot in hero[5]:
			var src_share: float = float(hero[5][slot][0]) / _src_hp(hero)
			var ours_share: float = await our_hit(hero[0], slot)
			_add_hit(hero, slot, ours_share, src_share)
	blowout = true
	var mage: Array = HEROES.filter(func(h): return h[0] == "mage")[0]
	for rank in [1, 3]:
		var row := _cell(mage, "combo + Blowout %s" % ("rank 0" if rank == 1 else "rank max"),
			await our_ttk(mage, true, rank), src_ttk(mage, true, rank == 3))
		row["state"] = "shown"
		rows.append(row)
		print("TTK shown mage combo + Blowout ours %s s, ratio %s" % [_fmt(row["ours"]), _ratio_text(row["ratio"])])
	blowout = false
	for id in ULT_HITS:
		var ult_hero: Array = HEROES.filter(func(h): return h[0] == id)[0]
		_add_hit(ult_hero, "x", await our_hit(id, "x"), float(ULT_HITS[id]) / _src_hp(ult_hero))
	if "--write" in OS.get_cmdline_user_args():
		_write()
	print("TTK CHECK DONE, rows: %d, failures: %d" % [rows.size(), bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## One share-of-target row: printed and kept for the table.
func _add_hit(hero: Array, slot: String, ours_share: float, src_share: float) -> void:
	hits.append([hero[0], hero[1], slot, ours_share, src_share])
	print("TTK hit %-11s %-4s ours %.3f of the target, source %.3f, ratio %.2f" % [
		hero[0], slot, ours_share, src_share, ours_share / src_share])

const TABLE_MARK := "<!-- ttk:table -->"      # docs/TTK.md keeps its tables between two of these

## Rewrites the tables between the markers in docs/TTK.md.
func _write() -> void:
	var lines := ["| Hunter (source) | Row | Ours s | Source s | Ours / source | Verdict |"]
	lines.append("|---|---|---|---|---|---|")
	for r in rows:
		lines.append("| %s (%s) | %s | %s | %s | %s | %s |" % [
			r["hero"], r["name"], r["label"], _fmt(r["ours"]), _fmt(r["src"]), _ratio_text(r["ratio"]), r["state"]])
	lines.append_array(["", "| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source |"])
	lines.append("|---|---|---|---|---|")
	for h in hits:
		lines.append("| %s (%s) | %s | %.3f | %.3f | %.2f |" % [h[0], h[1], h[2], h[3], h[4], h[3] / h[4]])
	var path := "res://docs/TTK.md"
	var parts := FileAccess.get_file_as_string(path).split(TABLE_MARK)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(parts[0] + TABLE_MARK + "\n" + "\n".join(lines) + "\n" + TABLE_MARK + parts[2])
