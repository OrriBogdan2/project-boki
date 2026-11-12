class_name KinGuardian
extends RefCounted
## The guardian summon (DECISIONS 2026-11-09, briefs/boki-art/WISP_DESIGN_OPEN.md Q4, decision 0040).
## Boki wisps on, a Hunter goes down with the Boki's summon ready: the Boki bursts out by itself beside the
## Hunter Wisp and fights there (the normal summon AI on a short leash to the downed owner). No Summon key
## while downed. The window is the species' own, clamped to min_s..max_s; it uses the summon and the full
## cooldown starts when it ends. It never touches the bond meter. It takes more damage (damage_mult). A
## white ring pulses on the ground round the Hunter Wisp and the HUD ring turns white: round = Hunter, the
## critter = Boki. Revived inside the window, it finishes the window beside you as a plain summon.
## Stealing (WISP_DESIGN_OPEN.md Q6, not built here): a downed Hunter's wisps may scatter only once
## protecting(h) is false, i.e. the window ended, the guardian was beaten (KinSummon.knocked), or they died.
## Numbers: content/rules/boki_summon.json "guardian".

static func rules() -> Dictionary:
	return KinSummon.rules()["guardian"]

## True while the Hunter's Boki is out guarding them: the steal rules wait for this to be false.
static func protecting(h: Hunter) -> bool:
	return h.downed and not h.out and h.kin != null and h.kin.summon != null and h.kin.summon.guardian

## The Hunter just went down (Match.knock): the Boki bursts out if its summon is ready. True if it did.
static func on_down(h: Hunter) -> bool:
	var k: Kin = h.kin
	if k == null or k.summon == null or not k.wisp or k.dead or k.state != "shoulder" or h.out:
		return false
	var s := k.summon
	if s.cd > 0.0 or s.out():
		return false
	var r := rules()
	s.burst(clampf(s.dur, float(r["min_s"]), float(r["max_s"])), true)
	KinCommand.say(h, "%s guards you" % k.rec.get("name", "Your Boki"), Color("ffffff"))
	return true

## The white ground ring round the Hunter Wisp, one pulse per pulse_s (drawing, on every game).
static func pulse(k: Kin) -> void:
	var o := k.owner_h
	var n := int(k.m.time / float(rules()["pulse_s"]))
	if o == null or n == k.summon.beat:
		return
	k.summon.beat = n
	k.m.fx.ring(o.pos, float(rules()["leash"]), Color(1, 1, 1, 0.9), float(rules()["pulse_s"]))
