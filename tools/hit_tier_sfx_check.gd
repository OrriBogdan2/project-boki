extends RefCounted
## --sfx-set-check section 11: the hit confirm follows the hit-weight tier (ImpactWeight).
## One hit per tier lands on a dummy through Match.on_damage; the cue it plays is read from Sfx.cue_log:
## Vex's bullet (light) -> hit_light, Kael's E (solid) -> hit_solid, his RMB slam (heavy) -> hit_heavy.
## Every tier has its own take (files), all three cues are different, each is gapped and capped like any sound.

## (hunter, hit tags, tier the rules give it, cue it must play)
const ROWS := [
	["gunslinger", {"src": "shot"}, "light", "hit_light"],
	["juggernaut", {"src": "abil", "ab": "e"}, "solid", "hit_solid"],
	["juggernaut", {"src": "abil", "ab": "utility"}, "heavy", "hit_heavy"],
]
const HIT_DAMAGE := 3.0  # a poke: far under SOLID_HP_FRAC of any Hunter's HP, so the tier comes from the rules

var ac
var ok: Callable


func run(main: Node, report: Callable) -> void:
	Save.no_write = true
	ok = report
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var cues := []
	for row in ROWS:
		var r: Array = ac.setup(row[0], 4.0)
		var m: Match = r[0]
		var me: Hunter = r[1]
		var dummy: Hunter = r[2]
		Sfx.listener = me.pos
		var tier := ImpactWeight.of_hit(me, dummy, HIT_DAMAGE, row[1])
		ok.call(tier == row[2], "hit confirm: %s %s is the %s tier (got '%s')" % [row[0], row[1], row[2], tier])
		var heard := _confirms(m, me, dummy, row[1])
		ok.call(heard == [row[3]], "hit confirm: the %s hit plays %s, once (heard %s)" % [row[2], row[3], heard])
		cues.append(row[3])
		await ac.done(m)
	for tier in ImpactWeight.TIERS:
		ok.call(Sfx.ensure(ImpactWeight.confirm(tier)), "hit confirm: the %s tier has its own sound file" % tier)
		var cue := ImpactWeight.confirm(tier)
		ok.call(Sfx.MIN_GAP.has(cue), "hit confirm: %s keeps a MIN_GAP" % cue)
	ok.call(cues[0] != cues[1] and cues[1] != cues[2], "hit confirm: light, solid and heavy confirm with three sounds")
	ok.call(Sfx.STACK_MAX == 3, "hit confirm: the stacking cap stays at %d" % Sfx.STACK_MAX)


## The tier confirm cues (hit_<tier>) one landed hit plays.
func _confirms(m: Match, me: Hunter, dummy: Hunter, tags: Dictionary) -> Array:
	ac.fresh(dummy)
	Sfx.cue_log = []
	m.on_damage(dummy, me, HIT_DAMAGE, tags.duplicate())
	var out := []
	var all := ImpactWeight.TIERS.map(func(t): return ImpactWeight.confirm(t))
	for c in Sfx.cue_log:
		if String(c[0]) in all:
			out.append(String(c[0]))
	Sfx.cue_log = null
	return out
