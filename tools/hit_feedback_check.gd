extends "res://tools/archetype_check.gd"
## Hit feedback (OWNER_REVIEW_1103 item 96.4, docs/HUD.md "Hit feedback"), run inside --hero-combo-check or
## alone as --hit-feedback-check: every Hunter's LMB on a dummy at 2.2 m and 6 m. Prints one AUDIT row per
## Hunter (the sounds its first hit played, the number's look, the body flash, the hold) and asserts the
## shared rules: a hit flash, a number, the Hunter's own hit sound, no camera shake from a plain hit; then
## the looks of a plain, an empowered (heavy) and a crit hit, your Boki's and the hits you take.

const HUNTERS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("hit_feedback_check", self)
	await audit()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Every check of this file, for a caller that sums n and fails itself.
func audit() -> void:
	for arch in HUNTERS:
		await _lmb(arch)
	await _empowered()
	await _looks()

## The sounds that played during one step (names whose last play time moved).
func _step_sounds(m: Match) -> Array:
	var before: Dictionary = Sfx.last_played.duplicate()
	m.step(DT)
	var out: Array = []
	for k in Sfx.last_played:
		if int(Sfx.last_played[k]) != int(before.get(k, -1)):
			out.append(k)
	return out

func _lmb(arch: String) -> void:
	for dist in [2.2, 6.0]:
		var s: Array = setup(arch, dist)
		var m: Match = s[0]
		var P: Hunter = s[1]
		var T: Hunter = s[2]
		var heard := _until_hit(m, P, T)
		var shook := m.cam.shake_amp if m.cam else 0.0
		P.inp["fire"] = false
		if not heard.is_empty() or T.hp < T.max_hp:
			var num: Label3D = m.fx.nums[-1]["node"] if not m.fx.nums.is_empty() else null
			print("AUDIT %s @%.1fm: sounds %s, number %s, flash %.2f, hold %.3f" % [arch, dist, str(heard),
				("%d/%s" % [num.font_size, num.modulate.to_html(false)]) if num else "none", T.flash_t, T.freeze_t])
			ok("%s LMB: body flash" % arch, T.flash_t > 0.0)
			ok("%s LMB: a damage number" % arch, num != null and num.visible)
			var own := HeroSfx.hit_sound(P)
			ok("%s LMB: its own hit sound" % arch, heard.has(own) and own == arch + "_hit", str(heard))
			ok("%s LMB: no camera shake" % arch, shook < 0.05, "shake %.2f" % shook)
			await done(m)
			return
		await done(m)
	ok("%s LMB lands within 2.5 s at 2.2 m or 6 m" % arch, false)

## Holds LMB at T until a hit lands (up to 2.5 s): the sounds that played on that step.
func _until_hit(m: Match, P: Hunter, T: Hunter) -> Array:
	Sfx.last_played.clear()
	Sfx.listener = P.pos          # (the match's own process, which moves it, is off here)
	for i in 150:
		aim_at(P, T.pos)
		P.inp["fire"] = i < 120         # (a held charge lets go at 2 s)
		var hp0 := T.hp
		var got := _step_sounds(m)
		if T.hp < hp0 - 0.4:
			return got
	return []

## Two empowered hits on the real path: Grimble's scattergun point-blank (most of a volley on one body)
## and Sable's empowered bolt each get the empowered number, the heavy thud and a hold on the target.
func _empowered() -> void:
	for arch in ["dredge", "thief"]:
		var s: Array = setup(arch, 2.0 if arch == "dredge" else 6.0)
		var m: Match = s[0]
		var P: Hunter = s[1]
		var T: Hunter = s[2]
		if arch == "thief":
			P.ak.set("primed_t", 2.0)
		var heard := _until_hit(m, P, T)
		var hold := T.freeze_t
		for i in 8:
			heard.append_array(_step_sounds(m))
			hold = maxf(hold, T.freeze_t)
		P.inp["fire"] = false
		var look := -1
		for nm in m.fx.nums:
			look = maxi(look, int(nm.get("look", -1)))
		ok("%s empowered hit: its own number look" % arch, look == Fx.NUM_HEAVY, "look %d" % look)
		ok("%s empowered hit: the heavy thud" % arch, heard.has("hit_heavy"), str(heard))
		ok("%s empowered hit: holds the target" % arch, hold >= Feel.HITSTOP[3][1] - 0.001, "%.3f" % hold)
		await done(m)

## The looks of the shared number: plain < empowered < crit, yours brighter than your Boki's, the hits you
## take smaller; an empowered hit holds (hit-stop) where a plain one of the same size does not.
func _looks() -> void:
	var s: Array = setup("gunslinger", 4.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	var look := func(o: Dictionary, by: Ent = P, to: Hunter = T) -> Label3D:
		m.fx.nums.clear()
		m.hitstop = 0.0
		Feel._budget.clear()
		Feel._pair_t.clear()
		to.hurt(9.0, by, o)
		return m.fx.nums[-1]["node"] if not m.fx.nums.is_empty() else null
	var plain: Label3D = look.call({"src": "shot"})
	var plain_hold := m.hitstop + T.freeze_t
	T.freeze_t = 0.0
	var heavy: Label3D = look.call({"src": "shot", "heavy": true})
	var heavy_hold := m.hitstop
	var held := T.freeze_t
	var crit: Label3D = look.call({"src": "shot", "crit": true})
	ok("number: empowered bigger than plain", heavy.font_size > plain.font_size,
		"%d vs %d" % [heavy.font_size, plain.font_size])
	ok("number: empowered has its own colour", heavy.modulate != plain.modulate and heavy.modulate != crit.modulate)
	ok("number: crit biggest", crit.font_size > heavy.font_size, "%d vs %d" % [crit.font_size, heavy.font_size])
	ok("hit-stop: an empowered hit holds the target", held >= Feel.HITSTOP[3][1] - 0.001, "%.3f" % held)
	ok("hit-stop: never on your ranged shot itself", heavy_hold == 0.0 and plain_hold < Feel.HITSTOP[3][1])
	var rec := Save.new_kin("zapple", "Pip")
	rec["trust"] = 95.0
	var k: Kin = m.give_kin(P, rec)
	var kin_num: Label3D = look.call({"src": "kin"}, k)
	var dimmer := kin_num.modulate.v < plain.modulate.v
	ok("number: your Boki's smaller and dimmer than yours", kin_num.font_size < plain.font_size and dimmer,
		"%d %s" % [kin_num.font_size, kin_num.modulate.to_html(false)])
	var hurt: Label3D = look.call({"src": "shot"}, T, P)
	ok("number: hits on you smaller than yours, red",
		hurt.font_size < plain.font_size and hurt.modulate == HudStyle.HURT)
	await done(m)
