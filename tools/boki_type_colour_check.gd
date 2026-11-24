extends RefCounted
## --boki-type-colour-check: no Boki ability effect draws a colour outside its type's palette. A type's palette is
## its Bokidex colour (DexView.type_col), its cast accent (KinTypeFx) and the four effect-category colours
## (KinRules.CAT_COLORS: a stage's colour means its effect, docs/HERO_VFX.md). Every stage of every Boki's active,
## auto and merge ability must draw one of them (the stock fallback is none), and the accent must keep the hue
## of the type colour. --verbose prints the table that docs/HERO_VFX.md holds. Never touches the save.

const HUE_TOL := 30.0            # degrees: how far an accent may sit from its type's Bokidex hue
const MIN_SAT := 0.1             # below this a colour is grey, and grey has no hue to keep

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("BOKITYPECOL FAIL ", what)
		bad += 1

func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d) * 360.0

func _stages(list: Array, out: Array) -> void:
	for st: StageSpec in list:
		out.append(st)
		for ev in st.then:
			_stages(st.then[ev], out)

## Every stage an ability or merge form draws: [[label, StageSpec]].
func _drawn(ks: KinSpec) -> Array:
	var rows := []
	for slot in ["active", "auto"]:
		var ab := KinLib.ability(String(ks.get(slot)))
		var all := []
		if ab:
			_stages(ab.stages, all)
		for st in all:
			rows.append(["%s %s" % [slot, ab.id], st])
	var mg := KinLib.merge(ks.merge)
	if mg:
		var all := []
		_stages(mg.on_start, all)
		_stages(mg.on_end, all)
		for p in mg.pulses:
			_stages([p["stage"]], all)
		for st in all:
			rows.append(["merge %s" % mg.id, st])
	return rows

func run(_main: Node) -> void:
	Save.no_write = true
	var verbose := OS.get_cmdline_user_args().has("--verbose")
	var cats: Array = KinRules.CAT_COLORS.values()
	var stages := 0
	for t: String in KinParts.THEMES.filter(func(x): return x != "none"):
		var look: Dictionary = KinTypeFx.LOOKS.get(KinTypeFx.key(t), {})
		var dex := DexView.type_col(t)
		ok(not look.is_empty(), "%s has an accent" % t)
		if look.is_empty():
			continue
		var accent := Color(String(look["col"]))
		var gap := _hue_gap(accent, dex)
		ok(gap <= HUE_TOL or minf(accent.s, dex.s) < MIN_SAT,
			"%s accent #%s is %.0f degrees off its Bokidex colour #%s" % [t, accent.to_html(), gap, dex.to_html()])
		var palette: Array = cats + [dex, accent]
		var seen := {}
		for id in KinLib.kin_ids():
			var ks := KinLib.kin(id)
			if ks.theme != t:
				continue
			for row: Array in _drawn(ks):
				stages += 1
				var col: Color = KinExec._color(row[1], {})
				ok(palette.has(col), "%s %s draws #%s, outside the %s palette" % [id, row[0], col.to_html(false), t])
				seen["%s=#%s" % [row[0], col.to_html(false)]] = true
		if verbose:
			var hexes := [dex.to_html(false), accent.to_html(false)]
			print("BOKITYPECOL %s dex #%s accent #%s | %s" % [t, hexes[0], hexes[1], " ".join(seen.keys())])
	ok(stages > 0, "some Boki stages were checked")
	print("BOKITYPECOL %s (%d stages)" % ["FAIL %d" % bad if bad else "PASS", stages])
	_main.get_tree().quit(1 if bad else 0)
