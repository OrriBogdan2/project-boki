class_name RunPayoff
extends RefCounted
## How raising a Boki at home pays off on runs (decision 0079): its trained stats and its food lean
## make one score, 0..1, that makes its carry passive a little stronger and its summon last a little
## longer. Small and capped: content/rules/care.json run_payoff; the carry passive still stops at its
## per-stat carry cap (KinParts.OWNER_STATS), so a raised Boki is never past what the cap allows.

static func rules() -> Dictionary:
	return Content.rules("care")["run_payoff"]

## 0..1: how far its expedition stat points (StatBudget.match_points) and its lean (Evo.lean) have come.
static func score(rec: Dictionary) -> float:
	if rec.is_empty():
		return 0.0
	var r := rules()
	var pts := 0
	for s in Care.STATS:
		pts += StatBudget.match_points(rec, s) if rec.get("stats", {}).has(s) else 0
	var most := Care.STATS.size() * int(StatBudget.rules()["expedition_stat_points"])
	var lean := float(Evo.lean(rec)[1])
	return clampf(float(r["stats_w"]) * pts / most + float(r["lean_w"]) * lean, 0.0, 1.0)

## What its carry passive amounts are multiplied by (1.0 to 1 + carry_max).
static func carry_mult(rec: Dictionary) -> float:
	return 1.0 + score(rec) * float(rules()["carry_max"])

## What its summon window is multiplied by (1.0 to 1 + summon_max), for KinSummon.
static func summon_mult(rec: Dictionary) -> float:
	return 1.0 + score(rec) * float(rules()["summon_max"])

## One carry passive's amount on a run: float stats scale, whole-number ones (jumps, charges) don't.
static func amount(ps: Dictionary, mult: float) -> float:
	var whole := String(KinParts.OWNER_STATS[ps["stat"]][1]) == "int"
	return float(ps["amount"]) * (1.0 if whole else mult)

## The Boki card line: "Raised for runs: carry passive +9%" ("" before any).
static func line(rec: Dictionary) -> String:
	var carry := roundi((carry_mult(rec) - 1.0) * 100.0)
	return "Raised for runs: carry passive +%d%%" % carry if carry > 0 else ""
