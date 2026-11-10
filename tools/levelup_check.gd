extends RefCounted
## --levelup-check: a level-up refills nothing (DECISIONS 2026-11-05: level-ups only rank abilities;
## the source's per-level change is quiet growth, nothing restored). Mid-fight in a bot match, level 1
## to 10 for the local hunter and a bot: health rises only by the max-health growth, and shield, armour,
## dash charges, ammo, every cooldown and the bond meter stay as they were. The world cue is the one
## body glow, no ring or burst. Never touches the save.

const DT := 1.0 / 60.0
const CD_VARS := ["fire_cd", "sig_cd", "grap_cd", "glide_cd", "mantle_cd", "swap_cd", "merge_cd", "ex_cd"]

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("LEVELUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Everything a refill would touch.
func _snap(h: Hunter) -> Dictionary:
	var s := {"shield": h.shield, "armor": h.armor, "dashes": h.dashes, "ammo": h.ammo,
			"ult": h.ult, "hp": h.hp, "max_hp": h.max_hp, "ak_cd": h.ak.cd.duplicate()}
	for v in CD_VARS: s[v] = h.get(v)
	return s

func _unchanged(h: Hunter, a: Dictionary) -> String:
	var b := _snap(h)
	for k in a:
		if k in ["hp", "max_hp"]: continue
		if str(a[k]) != str(b[k]): return "%s %s -> %s" % [k, str(a[k]), str(b[k])]
	return ""

## Puts a hunter mid-fight and hurt, with every refillable thing partly spent.
func _spend(h: Hunter) -> void:
	h.hp = h.max_hp * 0.5
	h.shield = 5.0
	h.armor = 10.0
	h.dashes = 0.0
	h.ammo = 1
	h.ult = 0.3
	for k in ["rmb", "e", "r", "x"]: h.ak.cd[k] = 4.0
	for v in CD_VARS: h.set(v, 1.5)

func _level_through(h: Hunter, who: String) -> void:
	while h.lvl < Hunter.XP_TO.size():
		for i in 20: m.step(DT)      # the fight goes on between levels
		_spend(h)
		var glows := m.fx.ghosts.size()
		var radial := m.fx.radial
		var rings := m.fx.rings.size()
		var a := _snap(h)
		var lvl0 := h.lvl
		h.gain_xp(float(Hunter.XP_TO[lvl0]) - h.xp + 1.0)
		var grown := h.max_hp - float(a["max_hp"])
		var moved := _unchanged(h, a)
		var tag := "%s level %d" % [who, h.lvl]
		ok(h.lvl == lvl0 + 1 and moved == "", tag + ": nothing refilled (%s)" % moved)
		var gained := h.hp - float(a["hp"])
		ok(absf(gained - grown) < 0.01 and h.hp < h.max_hp, tag + ": health up only by growth (+%.1f)" % gained)
		var quiet := m.fx.radial == radial and m.fx.rings.size() == rings
		ok(m.fx.ghosts.size() == glows + 1 and quiet, tag + ": one body glow, no ring or burst")

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
			"arch": "dredge", "cls": Arch.weight("dredge"), "weapon": Arch.signature("dredge")})
	m.set_process(false)
	var P: Hunter = m.player
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	P.ctrl = "local"
	B.ctrl = "bot"
	B.teleport(P.pos + Vector3(6, 0, 0))
	B.merge_free = false      # (the free bond meter on a first ult unlock is the Boki's own rule)
	P.merge_free = false
	ok(P.ak != null and B.ak != null, "a bot match with two kits (%s vs %s)" % [P.arch, B.arch])
	_level_through(P, "player")
	_level_through(B, "bot")
	print("LEVELUP %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)
