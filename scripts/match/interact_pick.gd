class_name InteractPick
extends RefCounted
## Which thing the interact key (F) works on, when several are in reach: one rule, one prompt.
##  1. Reviving a teammate comes first (their wisp or their deathbox).
##  2. Otherwise a target the cursor is on (within CURSOR_R of it): the one nearest the cursor.
##  3. Otherwise the target nearest the body. Prompts that only inform (a closed dock) come last.
## The pick sticks for HYST_S, while it is within MARGIN of the best in the same tier, and for as
## long as interact is held, so the prompt does not flicker
## and a hold never changes target halfway. Match._update_interact asks for the candidates
## (gather, plus the wisp ones it adds with cand) and then for the pick. Never touches saves or Net.

const CURSOR_R := 2.5      # m: the cursor counts as "on" a target this close to it
const HYST_S := 0.25       # s: a pick holds this long before a better one may replace it
const MARGIN := 0.35       # m: in the same tier a challenger must be this much nearer to take over
const TIER_STEP := 100.0   # keeps tiers apart in rank(); larger than any distance used

var _held := {}            # hunter nid -> {id, t}: the last pick and when it was made

## A candidate: `it` is the prompt dict Match acts on, `id` the target (kept while it stays the best),
## `rev` true when it revives a teammate. The prompt names the target, so one line says what and who.
static func cand(it: Dictionary, pos: Vector3, id: Variant, tname: String, rev := false) -> Dictionary:
	var label := String(it["label"])
	if tname != "" and not label.contains(tname):
		it["label"] = "%s  ·  %s" % [tname, label]
	return {"it": it, "pos": pos, "id": id, "rev": rev}

## Everything in reach of h that interact could work on, except the wisps (Match adds those).
static func gather(m: Match, h: Hunter) -> Array:
	var out: Array = []
	var key := Settings.key_cap("interact")
	for b in m.boxes:
		if h.flat_dist(b["pos"]) <= 1.5 and absf(h.pos.y - float(b["pos"].y)) <= 1.4:
			out.append(_box(m, h, b, key))
	out = out.filter(func(c): return not c.is_empty())
	if not m.opts.get("training", false):       # practice kin go home with nobody
		for k in m.kins:
			if KinLoss.scannable_by(h, k) and h.flat_dist(k) < float(Capture.rules()["range"]):
				var kn := String(Data.KIN[k.species]["name"])
				out.append(cand({"kind": "catch", "ent": k, "label": CaptureHud.prompt(h, k)}, k.pos, k, kn))
	for wp in m.wpicks:      # gear on the ground (tunings are taken by walking over them)
		var takes: bool = wp.has("gear") or (wp.has("val") and h == m.player)
		if takes and h.flat_dist(wp["pos"]) < 1.5 and absf(h.pos.y - float(wp["pos"].y)) < 1.2:
			var gi := Pack.ground_item(wp)
			var it := {"kind": "weapon", "wp": wp, "label": m._pickup_label(h, wp), "col": Loot.col_of(gi)}
			out.append(cand(it, wp["pos"], wp, Loot.name_of(gi)))
	for c in m.chests:
		if not c["open"] and h.flat_dist(c["pos"]) < 1.6:
			out.append(cand(KeyChest.prompt(h, c), c["pos"], c, "Chest"))
	for sh in m.shrines:
		if not sh["used"] and h.flat_dist(sh["pos"]) < 1.8:
			var pray := {"kind": "shrine", "shrine": sh, "label": "Hold %s to pray: heal, a blessing and a perk" % key}
			out.append(cand(pray, sh["pos"], sh, "Shrine"))
	if m.exits:
		var ex := m.exits.interact_for(h)
		if not ex.is_empty():
			out.append(cand(ex, ex["x"]["pos"], ex["x"], ""))
	if m.lairs:
		var lx := m.lairs.interact_for(h)
		if not lx.is_empty():
			out.append(cand(lx, _lair_pos(lx), lx["lair"], String(lx["lair"]["name"])))
	return out

## A deathbox in reach: bring its teammate back (while their soul is there), or take what's in it.
static func _box(m: Match, h: Hunter, b: Dictionary, key: String) -> Dictionary:
	var o: Hunter = b["owner"]
	if o.team == h.team and o != h and Life.soul_here(m, b) and not o.remote:
		var rev := {"kind": "boxrev", "box": b, "label": BoxRevive.prompt(h, o), "col": Color("9ee2a0")}
		return cand(rev, b["pos"], b, o.pname, true)
	if b["empty"]:
		return {}
	var whose: String = "your box" if o == h else o.pname + "'s box"
	var label := "Hold %s to loot %s" % [key, whose]
	if h == m.player:
		var open_now: bool = m.hud != null and m.hud.loot_is(b)
		label = "Press %s again to smart loot  ·  click items to take them" % key
		if not open_now:
			label = "Press %s to open %s  ·  twice to smart loot" % [key, whose]
	return cand({"kind": "loot", "box": b, "label": label, "col": Life.box_color(b)}, b["pos"], b, whose)

static func _lair_pos(lx: Dictionary) -> Vector3:
	match String(lx["what"]):
		"lever": return lx["lair"]["lever"]
		"rune": return lx["rune"]["pos"]
	return lx["lair"]["dial"]

## Picks one candidate for h (null cursor: no mouse, so the nearest to the body wins).
func pick(h: Hunter, cands: Array, cursor: Variant, want: bool, now: float) -> Dictionary:
	if cands.is_empty():
		_held.erase(h.nid)
		return {}
	var win: Dictionary = cands[0]
	for c in cands:
		if _rank(h, c, cursor) < _rank(h, win, cursor):
			win = c
	var prev: Variant = _held.get(h.nid)
	if prev != null and not is_same(prev["id"], win["id"]) and not win["rev"]:
		var wr := _rank(h, win, cursor)
		for c in cands:
			var cr := _rank(h, c, cursor)
			var close: bool = floorf(cr / TIER_STEP) == floorf(wr / TIER_STEP) and cr - wr < MARGIN
			var holds: bool = want or now - float(prev["t"]) < HYST_S or close
			if is_same(c["id"], prev["id"]) and not c["rev"] and (not _info(c) or _info(win)) and holds:
				return c["it"]
	if prev == null or not is_same(prev["id"], win["id"]):
		_held[h.nid] = {"id": win["id"], "t": now}
	return win["it"]

## Lower wins: revives, then what the cursor is on, then what is nearest the body, then info lines.
func _rank(h: Hunter, c: Dictionary, cursor: Variant) -> float:
	if c["rev"]:
		return h.flat_dist(c["pos"])
	if _info(c):
		return 3.0 * TIER_STEP + h.flat_dist(c["pos"])
	if cursor != null:
		var dc := Vector2(c["pos"].x - cursor.x, c["pos"].z - cursor.z).length()
		if dc <= CURSOR_R:
			return TIER_STEP + dc
	return 2.0 * TIER_STEP + h.flat_dist(c["pos"])

## A line that only informs (a dock that is closed, an uplink charging): never beats something you can do.
func _info(c: Dictionary) -> bool:
	var it: Dictionary = c["it"]
	return it["kind"] == "exit" and not it.has("act")
