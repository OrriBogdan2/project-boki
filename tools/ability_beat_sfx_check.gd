extends RefCounted
## --sfx-set-check section 11: Sparkle's and Sable's abilities have a cue on each of their beats (cast, travel, hit,
## end: the table in docs/AUDIO.md "Ability cues"). Every cue named there exists in its set, and the ones that
## filled a gap play on their own event in a short training match: Sparkle's missed finger bolt (MissFx, HeroSfx
## "miss"), Wirerun through a foe, a Storm Rod that hits nothing, each foe Skycall pins; Sable's Shadow Knife in
## flight, in the ground (not the foe's stick), her step behind a foe, a Bola off a wall and on nothing, Encore
## running out (and not on a knock). Each new hit is its own sound, not another of the kit's.

const DT := 1.0 / 60.0
## set -> the new cues of this pass (each is a different file, none is another ability's sound)
const NEW := {
	"mage": ["mage_miss", "mage_wire_hit", "mage_rod_fizzle", "mage_sky_ground"],
	"thief":
	[
		"thief_knife_whisk",
		"thief_knife_ground",
		"thief_shadow_whisk",
		"thief_bola_bounce",
		"thief_bola_tie",
		"thief_encore_end"
	],
}

var ac
var ok: Callable


func run(main: Node, report: Callable) -> void:
	Save.no_write = true
	ok = report
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	for g in NEW:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/%s.json" % g))
		var missing: Array = NEW[g].filter(func(s): return not d["sounds"].has(s) or not Sfx.ensure(s))
		ok.call(
			missing.is_empty(),
			"%s ability beats: the new cues are in the set and have files (missing %s)" % [g, missing]
		)
	_sparkle()
	_sable()


## Did `act` make `sname` start (it stamps Sfx.last_played)?
func _plays(sname: String, act: Callable) -> bool:
	Sfx.last_played.erase(sname)
	act.call()
	return Sfx.last_played.has(sname)


## Steps the match up to `secs`, true once `sname` has started.
func _heard_within(m: Match, sname: String, secs: float) -> bool:
	Sfx.last_played.erase(sname)
	var t := 0.0
	while t < secs and not Sfx.last_played.has(sname):
		ac.step(m, DT)
		t += DT
	return Sfx.last_played.has(sname)


func _sparkle() -> void:
	var r: Array = ac.setup("mage", 4.0)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var dummy: Hunter = r[2]
	var kit := me.ak as MageKit
	Sfx.listener = me.pos
	var miss := {"x": {}, "by": me, "vel": Vector2(1, 0)}
	ok.call(
		_plays("mage_miss", func(): MissFx.shot_ended(m, miss, me.pos + Vector3(8, 0, 0), "expire")),
		"Sparkle LMB end: a finger bolt that hits nothing fizzles (mage_miss)"
	)
	var abil := {"x": {"src": "abil"}, "by": me, "vel": Vector2(1, 0)}
	ok.call(
		not _plays("mage_miss", func(): MissFx.shot_ended(m, abil, me.pos + Vector3(8, 0, 0), "expire")),
		"Sparkle: an ability shot's miss is not the finger bolt's fizzle"
	)
	ok.call(HeroSfx.of(dummy, "miss", "") == "", "a Hunter with no <arch>_miss stays silent on a miss")
	ok.call(_plays("mage_wire_hit", func(): kit._wire_hit(dummy, 1.0)), "Sparkle Wirerun hit: mage_wire_hit on the foe")
	ac.fresh(dummy)
	me.inp["aim"] = me.pos + Vector3(0, 0, -9)  # away from the dummy: nothing to hit
	kit._coil(0.5)
	ok.call(
		_heard_within(m, "mage_rod_fizzle", 1.0), "Sparkle Storm Rod end: a rod that hits nothing (mage_rod_fizzle)"
	)
	me.inp["aim"] = dummy.pos
	kit._coil(0.5)
	ok.call(not _heard_within(m, "mage_rod_fizzle", 1.0), "Sparkle Storm Rod: a rod that hits a foe does not fizzle")
	ac.fresh(dummy)
	ok.call(
		_plays("mage_sky_ground", func(): kit.sky._strike({"at": dummy.pos, "dir": Vector2(-1, 0)})),
		"Sparkle Skycall hit: each pinned foe gets mage_sky_ground"
	)
	var empty := {"at": dummy.pos + Vector3(0, 0, 9), "dir": Vector2(-1, 0)}
	ok.call(
		not _plays("mage_sky_ground", func(): kit.sky._strike(empty)),
		"Sparkle Skycall: no pin sound with no foe inside"
	)
	m.queue_free()


func _sable() -> void:
	var r: Array = ac.setup("thief", 4.0)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var dummy: Hunter = r[2]
	var kit := me.ak as ThiefKit
	Sfx.listener = me.pos
	me.inp["aim"] = dummy.pos
	ok.call(_plays("thief_knife_whisk", func(): kit._throw_knife()), "Sable Shadow Knife travel: thief_knife_whisk")
	ac.step(m, 0.3)
	kit.knife = {}
	ok.call(
		_plays("thief_knife_ground", func(): kit._stick(null, me.pos + Vector3(0, 0, 3))),
		"Sable Shadow Knife in the ground: thief_knife_ground"
	)
	kit.knife = {}
	ok.call(
		not _plays("thief_knife_ground", func(): kit._stick(dummy, dummy.pos)),
		"Sable Shadow Knife in a foe keeps its stick"
	)
	kit.knife = {}
	ok.call(
		_plays("thief_shadow_whisk", func(): kit._shadow_step(dummy)), "Sable step behind a foe: thief_shadow_whisk"
	)
	ac.fresh(dummy)
	me.teleport(r[4])  # back home, 4 m from the dummy (the step put her beside it)
	me.vel = Vector3.ZERO
	me.inp["aim"] = me.pos + Vector3(-9, 0, 0)  # down the empty lane, away from the dummy
	kit._throw_bola()
	ok.call(
		_heard_within(m, "thief_bola_tie", 1.0), "Sable Bola end: a Bola that catches nobody ties off (thief_bola_tie)"
	)
	ac.fresh(dummy)
	me.inp["aim"] = dummy.pos
	kit._throw_bola()
	ok.call(
		not _heard_within(m, "thief_bola_tie", 1.0), "Sable Bola: one that wraps a foe and flies on does not tie off"
	)
	var ring := kit.encore
	ring.start()
	ok.call(_heard_within(m, "thief_encore_end", 3.5) and not ring.running(), "Sable Encore end: thief_encore_end")
	ring.start()
	ac.step(m, 0.6)
	ok.call(not _plays("thief_encore_end", func(): ring.drop()), "Sable Encore cut short (a knock): no end cue")
	m.queue_free()
