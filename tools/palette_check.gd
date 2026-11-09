extends RefCounted
## --palette-check: the colour filters (Palette, Settings > Accessibility > Colour filter). Each
## filter's colours are run through a simulation of that kind of colour blindness (Machado et al.
## 2009, full severity, in linear RGB) and compared in CIELAB (delta E 76). It asserts a minimum
## contrast between you, ally and rival, between good news and damage, between every pair of rarity
## tiers and among the CC icons, that each filter beats Off for the people it is for, and that the
## setting is saved and read back. Writes user://settings.cfg: run with a temporary XDG_DATA_HOME.

const MIN_SIDES := 45.0     # delta E: you / ally / rival, and good (revive, hidden) against damage
const MIN_RARITY := 30.0    # delta E: any two rarity tiers
const MIN_CC := 30.0        # delta E: any two CC icon colours
## Linear-RGB matrices that turn a normal colour into how that kind of eye sees it, by filter index
## (Off, Deuteranopia, Protanopia, Tritanopia).
const SIM := [
	[],
	[0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	[0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	[1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
]
const CC_ROLES := [Palette.STUN, Palette.ROOT, Palette.SLOW, Palette.BURN, Palette.WEAK]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("PALETTE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

static func _lin(x: float) -> float:
	return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)

static func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0

## `c` as CIELAB, seen through filter `f` (0 = a normal eye).
static func lab(c: Color, f: int) -> Vector3:
	var rgb := Vector3(_lin(c.r), _lin(c.g), _lin(c.b))
	if f > 0:
		var m: Array = SIM[f]
		rgb = Vector3(m[0] * rgb.x + m[1] * rgb.y + m[2] * rgb.z, m[3] * rgb.x + m[4] * rgb.y + m[5] * rgb.z,
			m[6] * rgb.x + m[7] * rgb.y + m[8] * rgb.z).clampf(0.0, 1.0)
	var x := (0.4124 * rgb.x + 0.3576 * rgb.y + 0.1805 * rgb.z) / 0.95047
	var y := 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
	var z := (0.0193 * rgb.x + 0.1192 * rgb.y + 0.9505 * rgb.z) / 1.08883
	return Vector3(116.0 * _lab_f(y) - 16.0, 500.0 * (_lab_f(x) - _lab_f(y)), 200.0 * (_lab_f(y) - _lab_f(z)))

## The least delta E between any two of `cols`, as seen through filter `f`.
static func spread(cols: Array, f: int) -> float:
	var least := INF
	for i in cols.size():
		for j in range(i + 1, cols.size()):
			least = minf(least, lab(cols[i], f).distance_to(lab(cols[j], f)))
	return least

## Delta E between roles `a` and `b` in the colours of filter `pal`, seen through filter `seen`.
func _gap(a: int, b: int, pal: int, seen: int) -> float:
	return lab(Palette.col_in(a, pal), seen).distance_to(lab(Palette.col_in(b, pal), seen))

func _roles(r: Array, f: int) -> Array:
	return r.map(func(x): return Palette.col_in(x, f))

func _rarities(f: int) -> Array:
	var out: Array = []
	for t in Palette.RARITY.size():
		out.append(Palette.rarity_in(t, f))
	return out

func run(main: Node) -> void:
	Save.no_write = true
	Settings.reset_all()
	var sides := [Palette.YOU, Palette.ALLY, Palette.FOE]
	for f in range(1, Palette.MODES.size()):
		var nm: String = Palette.MODE_NAMES[f]
		var side := spread(_roles(sides, f), f)
		ok(side >= MIN_SIDES, "%s: you / ally / rival at least %d apart (%.0f)" % [nm, int(MIN_SIDES), side])
		var off_gap := _gap(Palette.ALLY, Palette.FOE, 0, f)
		var ally_foe := _gap(Palette.ALLY, Palette.FOE, f, f)
		ok(ally_foe >= off_gap, "%s: ally against rival beats the Off colours (%.0f vs %.0f)" % [nm, ally_foe, off_gap])
		var good := _gap(Palette.GOOD, Palette.HURT, f, f)
		ok(good >= MIN_SIDES, "%s: good news against damage at least %d apart (%.0f)" % [nm, int(MIN_SIDES), good])
		var tiers := spread(_rarities(f), f)
		ok(tiers >= MIN_RARITY, "%s: every rarity tier at least %d apart (%.0f)" % [nm, int(MIN_RARITY), tiers])
		var cc := spread(_roles(CC_ROLES, f), f)
		ok(cc >= MIN_CC, "%s: CC icons at least %d apart (%.0f)" % [nm, int(MIN_CC), cc])
		var off_tiers := spread(_rarities(0), f)
		ok(tiers > off_tiers, "%s: rarity tiers beat the Off colours (%.0f vs %.0f)" % [nm, tiers, off_tiers])
	ok(Palette.mode() == 0 and Palette.col(Palette.FOE) == Palette.col_in(Palette.FOE, 0), "default: Off")
	Settings.set_v("cvd_filter", "tritanopia")
	var cf := ConfigFile.new()
	var saved: bool = cf.load(Settings.PATH) == OK and cf.get_value("s", "cvd_filter", "") == "tritanopia"
	ok(saved, "the filter is in the settings file")
	var foe: Color = SideColor.of_team(0, 1)
	var follows := Palette.rarity(4) == Palette.rarity_in(4, 3) and foe == Palette.col_in(Palette.FOE, 3)
	ok(follows, "rarity and the colour rule follow it")
	Settings.set_v("cvd_filter", "nonsense")
	ok(Palette.mode() == 0, "an unknown filter id falls back to Off")
	Settings.reset_all()
	print("PALETTE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
