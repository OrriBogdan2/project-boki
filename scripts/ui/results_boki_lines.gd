class_name ResultsBokiLines
extends RefCounted
## The Boki block on the results card: one line per Boki you carried (lead, second), each with its portrait,
## name, the XP it got and what happened to its bond, read from the numbers the save applied
## (Game._kin_after -> out["kin_gains"]). A stolen wisp you carried says it is going home.

const PORTRAIT_PX := 36.0
const BOND_SHOWN := 0.5  # bond points; a smaller change reads as "unchanged"


## "+80 XP, bond up 3, Power +2": plain words for one Boki's gains (stats: the points this expedition taught
## it, PlayStyle.run_growth; lucky: the extra points Luck added, {stat: n}).
static func gain_text(xp: int, bond: float, stats := {}, lucky := {}) -> String:
	var b := "bond unchanged"
	if absf(bond) >= BOND_SHOWN:
		b = "bond %s %d" % ["up" if bond > 0.0 else "down", int(round(absf(bond)))]
	var out := "+%d XP, %s" % [xp, b]
	for stat in stats:
		out += ", %s +%d" % [Care.STATS[stat]["name"], int(stats[stat])]
		if lucky.has(stat):
			out += " (%s)" % Luck.words(int(lucky[stat]))
	return out


## Every line's text, in order: the Boki you brought, then the wisps you carried home.
static func texts(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for g in s.get("kin_gains", []):
		out.append(
			(
				"%s  %s"
				% [
					String(g["kin"]["name"]),
					gain_text(int(g["xp"]), float(g["bond"]), g.get("stats", {}), g.get("lucky", {}))
				]
			)
		)
	for w in s.get("wisps_home", []):
		out.append("%s  going home" % String(w.get("name", "A wisp")))
	return out


## The card with the lines (null when there is nothing to say).
static func card(s: Dictionary, tree: SceneTree) -> Control:
	var recs: Array = (s.get("kin_gains", []) as Array).map(func(g): return g["kin"])
	recs.append_array(s.get("wisps_home", []))
	var lines := texts(s)
	if lines.is_empty():
		return null
	var v := UI.vbox(6)
	v.set_meta("boki_lines", true)
	for i in lines.size():
		var h := UI.hbox(10)
		h.add_child(KinPortrait.view(recs[i], tree, PORTRAIT_PX))
		var l := UI.label(lines[i], 15, UI.GOLD if lines[i].contains("Lucky!") else UI.INK)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		v.add_child(h)
	var c := UI.card(UI.CARD, 12, 14)
	c.add_child(v)
	return c
