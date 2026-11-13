extends RefCounted
## --perk-orb-check: every perk an orb can carry matches its row in docs/PERK_PARITY.md (the source's
## perks): the Data column against Data.PERKS, the Text column word for word, one plain line. Then the
## source-matched ones on a real hunter: Second Wind adds no dash charge and recharges dashes 5% faster,
## Fleet Foot adds 0.96% run speed, Tough Skin 8 health, Remedy 10% to any heal, the Spyglass only
## while sneaking. Prints PERKPARITY PASS/FAIL.

const TABLE := "res://docs/PERK_PARITY.md"

var main: Node
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("PERKPARITY %-62s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_table()
	await _on_hunter()
	print("PERKPARITY DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Table rows by orb id: {"text": String, "data": {path: value string}}.
func _rows() -> Dictionary:
	var rows := {}
	for line in FileAccess.get_file_as_string(TABLE).split("\n"):
		var cells := line.split("|")
		if cells.size() < 8 or not cells[1].strip_edges().begins_with("`"):
			continue
		var data := {}
		for pair in cells[5].split(","):
			var kv := pair.strip_edges().split("=")
			data[kv[0]] = kv[1]
		rows[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = {"text": cells[4].strip_edges(), "data": data}
	return rows

## The value at a dotted path in a perk entry ("stats.speed"), or null.
func _at(pd: Dictionary, path: String) -> Variant:
	var v: Variant = pd
	for k in path.split("."):
		if not (v is Dictionary and (v as Dictionary).has(k)):
			return null
		v = v[k]
	return v

func _same(v: Variant, want: String) -> bool:
	if v is String:
		return v == want
	return v != null and absf(float(v) - want.to_float()) < 0.00005

func _table() -> void:
	var rows := _rows()
	var kinds: Dictionary = PerkOrbs.rules()["kinds"]
	for kind in kinds:
		for id in kinds[kind]:
			var pd: Dictionary = Data.PERKS.get(id, {})
			if not rows.has(id):
				ok("%s has a row in the parity table" % id, false)
				continue
			var row: Dictionary = rows[id]
			var bad := []
			for path in row["data"]:
				var v: Variant = int(pd.get("max", 1)) if path == "max" else _at(pd, path)
				if not _same(v, row["data"][path]): bad.append("%s=%s" % [path, str(v)])
			ok("%s numbers match the table" % id, bad.is_empty(), ", ".join(bad))
			var desc := String(pd.get("desc", ""))
			var plain_line := not desc.contains("\n") and desc.count(". ") == 0
			ok("%s text is the table's, one plain line" % id, desc == row["text"] and plain_line, desc)

# ------------------------------------------------------------------ on a hunter
func _on_hunter() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 7, "no_drop": true,
		"arch": "gunslinger", "cls": Arch.weight("gunslinger")})
	m.set_process(false)
	var h: Hunter = m.player
	var dash0 := h.max_dashes()
	var regen0 := h.dash_regen()
	var hp0 := h.max_hp
	var spd0 := h.gear_stat("speed")
	h.add_perk("secondwind")
	ok("Second Wind adds no dash charge", h.max_dashes() == dash0, "%.0f -> %.0f" % [dash0, h.max_dashes()])
	var haste := regen0 / h.dash_regen()
	ok("Second Wind: dashes recharge 5% faster (5% haste)", absf(haste - 1.05) < 0.001, "%.3f" % haste)
	h.add_perk("fleet")
	ok("Fleet Foot: +0.96% run speed", absf(h.gear_stat("speed") - spd0 - 0.0096) < 0.00001)
	h.add_perk("toughskin")
	ok("Tough Skin: +8 max health", absf(h.max_hp - hp0 - 8.0) < 0.001, "%.1f" % (h.max_hp - hp0))
	var plain := _healed(h)
	h.add_perk("remedy")
	var boosted := _healed(h)
	var heals := "%.2f vs %.2f" % [boosted, plain]
	ok("Remedy: any heal on you is 10% stronger", absf(boosted / plain - 1.10) < 0.001, heals)
	h.add_perk("spyglass")
	var spots := _open_spots(m, h, m.view_range(false) * 1.06)      # 6% past plain sight: [stand, sneak]
	h.crouch = true
	var seen_sneak := m.sees(h.team, spots[1])
	h.crouch = false
	var seen_stand := m.sees(h.team, spots[0])
	h.perks.erase("spyglass")
	h.crouch = true
	var seen_without := m.sees(h.team, spots[1])
	var seen := "%s %s %s" % [seen_sneak, seen_stand, seen_without]
	var only_sneak := seen_sneak and not (seen_stand or seen_without)
	ok("the Spyglass sees 12% further while sneaking, not standing", only_sneak, seen)
	m.queue_free()

## HP gained from one 10-point heal at low health.
func _healed(h: Hunter) -> float:
	h.hp = 10.0
	h.heal(10.0)
	return h.hp - 10.0

## Two ground spots on one open line from h (no grass, smoke or wall), r and r * 1.25 (the sneak
## bonus) metres out; h faces them.
func _open_spots(m: Match, h: Hunter, r: float) -> Array:
	for i in 16:
		var dir := Vector3(cos(TAU * float(i) / 16.0), 0, sin(TAU * float(i) / 16.0))
		var spots := []
		for k in [1.0, 1.25]:
			var p: Vector3 = h.pos + dir * r * k
			p.y = m.world.ground_at(p.x, p.z)
			if m.world.los(h.pos, p, h.pos.y + 1.1) and not (m.world.in_bush(p.x, p.z) or m.in_smoke(p)):
				spots.append(p)
		if spots.size() == 2:
			h.inp["aim"] = spots[1]
			return spots
	return [h.pos + Vector3(r, 0, 0), h.pos + Vector3(r * 1.25, 0, 0)]
