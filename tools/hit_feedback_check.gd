extends "res://tools/archetype_check.gd"
## Hit feedback (OWNER_REVIEW_1103 item 96.4, docs/HUD.md "Hit feedback"), run inside --hero-combo-check or
## alone as --hit-feedback-check: every Hunter's LMB on a dummy at 2.2 m and 6 m. Prints one AUDIT row per
## Hunter (the sounds its first hit played, the number, the body flash, the hold) and asserts the
## shared rules: a hit flash, a number, the Hunter's own hit sound, no camera shake from a plain hit; then
## two empowered hits: the heavy thud and a hold. (The number's looks are main's Fx.hit_number rolls.)

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
## and Sable's empowered bolt each get the heavy thud and a hold on the target.
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
		ok("%s empowered hit: the heavy thud" % arch, heard.has("hit_heavy"), str(heard))
		ok("%s empowered hit: holds the target" % arch, hold >= Feel.HITSTOP[3][1] - 0.001, "%.3f" % hold)
		await done(m)
