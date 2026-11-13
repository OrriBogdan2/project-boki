class_name DashState
extends RefCounted
## One hero's dash: its charges, their recharge and the long (air) dash's cooldown, with the rules that
## size them. The match Hunter and the home avatar each own one and read the same rules (one movement
## model, DECISIONS 2026-11-08): a tuning change to the class dodge, the hero kit's dash or its rank
## table moves both. The Hunter adds its match-only modifiers (perks, kit extras, ranks, gear, Boki)
## through the arguments; home runs rank 1 with none.

var charges := 2.0
var air_cd := 0.0               # seconds until the long dash is back (Hunter.ex_cd)
var cdat: Dictionary = {}       # the class row (Data.CLASSES)
var dodge: AbilityDef = null    # the class dodge (Content.class_dodge)
var kit: Dictionary = {}        # the hero kit's data (Arch.def), {} with no kit

## Points the rules at a class and hero kit (cheap: three references). Returns self.
func use(c: Dictionary, dd: AbilityDef, k: Dictionary) -> DashState:
	cdat = c
	dodge = dd
	kit = k
	return self

## The rules for a saved class and hero (home): the same inputs a match Hunter of that hero gets.
func use_hero(cls: String, arch: String) -> DashState:
	var c: Dictionary = Data.CLASSES.get(cls, Data.CLASSES["medium"])
	return use(c, Content.class_dodge(cls), Arch.def(arch) if arch != "" and Arch.exists(arch) else {})

func dash_def() -> Dictionary:
	return kit.get("dash", {})

## Charges: the class dodge's (else the class row's) plus the kit data's extra_charges plus `extra`.
func cap(extra := 0.0) -> float:
	var base := float(dodge.charges) if dodge else float(cdat.get("dashes", 2))
	return base + float(dash_def().get("extra_charges", 0.0)) + extra

## The kit's rank_cd row for the dash at `rank`, else 15% faster a rank past the first.
func rank_k(rank := 1) -> float:
	var row: Array = kit.get("rank_cd", {}).get("dash", [])
	if row.is_empty():
		return 1.0 - 0.15 * float(maxi(0, rank - 1))
	return float(row[clampi(rank - 1, 0, row.size() - 1)])

## Seconds per charge: the kit's dash cd (else the class dodge's), by rank, minus `faster` (0..0.9).
func regen(rank := 1, faster := 0.0) -> float:
	var base := Hunter.DASH_REGEN
	if not kit.is_empty():
		base = float(dash_def().get("cd", 9.0))
	elif dodge:
		base = dodge.cooldown
	return base * rank_k(rank) * (1.0 - minf(0.9, faster))

## Has the hero the class long dash (Shift in the air)? Not when its kit data says "long": false (Neve's skate).
func has_long() -> bool:
	return bool(dash_def().get("long", true))

## The long dash's cooldown: the kit's dash.air.cd (times its rank_cd.air row, less air.rank_cut a rank), else
## the class ex_cd.
func air_max(rank := 1) -> float:
	var air: Dictionary = dash_def().get("air", {})
	var cd := float(air.get("cd", cdat.get("ex_cd", Hunter.EX_DASH_CD)))
	var row: Array = kit.get("rank_cd", {}).get("air", [])
	if not row.is_empty():
		cd *= float(row[clampi(rank - 1, 0, row.size() - 1)])
	return maxf(0.01, cd - float(air.get("rank_cut", 0.0)) * float(maxi(0, rank - 1)))

## The class dodge's own shape (home, and a Hunter with no kit): short dash speed/time, long dash dist/time.
func shape() -> Dictionary:
	var out := {"speed": Hunter.DASH_SPEED, "time": Hunter.DASH_TIME,
		"ex_dist": float(cdat.get("ex_dist", 5.0)), "ex_time": float(cdat.get("ex_time", Hunter.DASH_TIME * 1.45))}
	for e in (dodge.effects if dodge else []):
		if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "dash":
			out["speed"] = float(e.get("speed", out["speed"]))
			out["time"] = float(e.get("time", out["time"]))
			break
	return out

## One step: charges come back at `per` seconds each up to `top`; the long dash cools down.
func tick(dt: float, top: float, per: float) -> void:
	if charges < top:
		charges = minf(top, charges + dt / maxf(0.01, per))
	air_cd = maxf(0.0, air_cd - dt)

## Spends a short charge, or the long dash when `long` (cooling down for `cd`, else air_max at rank 1);
## false when there is none to spend.
func spend(long: bool, cd := -1.0) -> bool:
	if long:
		if air_cd > 0.0:
			return false
		air_cd = cd if cd >= 0.0 else air_max()
		return true
	if charges < 1.0:
		return false
	charges -= 1.0
	return true
