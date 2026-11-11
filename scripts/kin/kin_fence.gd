class_name KinFence
extends RefCounted
## The agency fence (DECISIONS 2026-11-06, OWNER_REVIEW 184b, docs/BOKI_AGENCY_AUDIT.md): a Boki never
## moves, stops, steers, swaps, teleports, launches or roots its own hunter. Boki act on foes, the world
## and the hunter's stats (heal, shield, buff). The one exception is the abyss rescue: a lift on the
## hunter in an ability cued by owner_falling (Moonlift). The grammar check fails on anything else.

## Effects that move or hold a body: never on the hunter.
const MOTION := ["lift", "pull", "push", "slow", "root", "stun"]

## A kin ability. from:owner abilities are cast by the hunter, so their dash, leap or blink would move it.
static func ability(a: AbilitySpec, rep: GrammarReport) -> void:
	var rescue := a.cue != null and a.cue.type == "owner_falling"
	for i in a.stages.size():
		stages([a.stages[i]], a.from == "owner", rescue, GrammarReport.join("stages", i), rep)

## A Fusion's automatic stages (on_start, on_end, pulses) run with the hunter as the caster.
static func merge(ms: MergeSpec, rep: GrammarReport) -> void:
	stages(ms.on_start, true, false, "on_start", rep)
	stages(ms.on_end, true, false, "on_end", rep)
	for i in ms.pulses.size():
		stages([ms.pulses[i]["stage"]], true, false, GrammarReport.join("pulses", i), rep)

## Each stage and its followups. `hunter_casts`: the hunter is the caster ("self" and origin caster are the hunter).
static func stages(list: Array, hunter_casts: bool, rescue: bool, path: String, rep: GrammarReport) -> void:
	var all: Array[StageSpec] = []
	for top: StageSpec in list:
		all.append_array(top.walk())
	for st in all:
		if st.delivery and st.delivery.type in KinExec.MOVERS:
			var origin := String(st.delivery.params.get("origin", "caster"))
			if origin == "owner" or hunter_casts:
				var why := "a Boki never moves its hunter: a %s from the hunter" % st.delivery.type
				rep.err(path + ".delivery", why + " (make the Boki do it, or act on foes)")
		effects(st.effects, hunter_casts, rescue, path + ".effects", rep)

## Effects (a stage's, or a throw's): none moves or holds the hunter.
static func effects(list: Array, hunter_casts: bool, rescue: bool, path: String, rep: GrammarReport) -> void:
	for e: PartSpec in list:
		var on_hunter := e.target == "owner" or (e.target == "self" and hunter_casts)
		if on_hunter and e.type in MOTION and not (rescue and e.type == "lift"):
			rep.err(path, "a Boki never %ss its hunter (only an owner_falling rescue lifts)" % e.type)
