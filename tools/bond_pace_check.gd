extends RefCounted
## --bond-pace-check (docs/FARM_LOOP.md, Bond from care): minutes of play and number of pets and plays
## to each bond rank (Care.BONDS), for three players on the real Care.trust_up / Care.trust_add code, and
## the per-day taper that stops one session maxing a Boki (content/rules/garden_trust.json "taper").
## Players (sim clock, no real time): "balanced" does a typical farm day (2 pets, a meal, fetch, a chat,
## one minigame win); "pet spam" pets every 4 s (PetReact pays only `cap` pats a farm day); "grinder" also
## spams its habit food every cooldown and wins a minigame every 45 s. The taper is switched off for the
## "before" rows. Asserts the taper resets at the garden day. Never touches the real save.

const START := 1000000.0
const GIVE_UP_S := 14.0 * 24.0 * 3600.0
const RANK_NAMES := ["Friendly", "Close", "Devoted", "Soulbound"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BONDPACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin() -> Dictionary:
	var rec := Save.new_kin("cindle", "Pace")
	rec["trust"] = 0.0
	rec["traits"] = {"bravery": 0.5, "temper": 0.5, "loyalty": 0.5, "curiosity": 0.6}   # a playful one: cap 3
	return rec

func _taper(on: bool) -> void:
	var T: Dictionary = Content.rules("garden_trust")["taper"]
	if not T.has("_live"): T["_live"] = int(T["free"])
	T["free"] = int(T["_live"]) if on else 1000000

## One player over the sim clock. Returns {"min": [minutes to each rank], "acts": [pets+plays to each rank]}.
func _play(who: String) -> Dictionary:
	var rec := _kin()
	var R: Dictionary = Content.rules("garden_trust")
	var cap := int(PetReact.rules()["kinds"][PetReact.kind(rec)]["cap"])
	var pet_mul := float(PetReact.rules()["kinds"][PetReact.kind(rec)]["trust"])
	var day_s := float(Content.rules("care")["care_day_s"])
	var t := 0.0
	var acts := 0
	var out := {"min": [], "acts": []}
	var next_rank := 1
	var pats := 0
	var day_at := 0.0
	while t < GIVE_UP_S and next_rank < Care.BONDS.size():
		var now := START + t
		if t - day_at >= day_s:           # the pat window and the care days restart together
			day_at = t
			pats = 0
		match who:
			"balanced":                   # six acts a day, spread through it
				var phase := int(fmod(t, day_s) / (day_s / 6.0))
				var step := day_s / 6.0
				if fmod(t, step) < 1.0:
					match phase:
						0, 3:
							if Care.trust_up(rec, "pet", now, "", pet_mul) != "":
								acts += 1
						1:
							if Care.trust_up(rec, "food", now, "kibble") != "":
								acts += 1
						2:
							Care.trust_add(rec, 1.5, now)   # fetch (Save.remember +1.5)
							acts += 1
						4:
							Care.trust_add(rec, 2.0, now)   # a chat (+2.0)
							acts += 1
						5:
							Care.trust_add(rec, 3.0, now)   # a minigame win (win_trust 3.0)
							acts += 1
				t += 1.0
			"pet_spam":
				if pats < cap and Care.trust_up(rec, "pet", now, "", pet_mul) != "":
					pats += 1
					acts += 1
				t += 4.0
			_:                            # grinder
				if pats < cap and Care.trust_up(rec, "pet", now, "", pet_mul) != "":
					pats += 1
					acts += 1
				if Care.trust_up(rec, "food", now, "kibble") != "": acts += 1
				if fmod(t, 45.0) < 4.0:
					Care.trust_add(rec, 3.0, now)
					acts += 1
				t += 4.0
		if Care.bond_index(rec) >= next_rank:
			out["min"].append(t / 60.0)
			out["acts"].append(acts)
			next_rank += 1
	while out["min"].size() < RANK_NAMES.size():
		out["min"].append(-1.0)
		out["acts"].append(acts)
	return out

func _row(label: String, r: Dictionary) -> void:
	var s := "BONDPACE %-18s" % label
	for i in RANK_NAMES.size():
		var m: float = r["min"][i]
		s += "  %s %s (%d acts)" % [RANK_NAMES[i], ("%.0f min" % m) if m >= 0.0 else "never", int(r["acts"][i])]
	print(s)

func run(m: Node) -> void:
	Save.no_write = true
	var res := {}
	for on in [false, true]:
		_taper(on)
		for who in ["balanced", "pet_spam", "grinder"]:
			res["%s %s" % [who, "after" if on else "before"]] = _play(who)
	for k in res: _row(k, res[k])
	_taper(true)
	# the taper: a day's first `free` acts pay in full, then each pays less, floored; a new day resets it
	var T: Dictionary = Content.rules("garden_trust")["taper"]
	var free := int(T["free"])
	var day_s := float(Content.rules("care")["care_day_s"])
	var rec := _kin()
	var got: Array = []
	for i in free + 8:
		got.append(Care.trust_add(rec, 1.0, START + float(i)))
	var full := true
	for i in free: full = full and is_equal_approx(got[i], 1.0)
	ok(full, "the first %d acts of a day pay in full" % free)
	var less := "act %d pays %.2f, act %d %.2f: each pays less"
	ok(got[free] < 1.0 and got[free + 1] < got[free], less % [free + 1, got[free], free + 2, got[free + 1]])
	var fl := float(T["floor"])
	ok(is_equal_approx(got[free + 7], fl) and fl > 0.0, "the taper bottoms at its floor %.2f, never zero" % fl)
	var late := Care.trust_add(rec, 1.0, START + day_s - 1.0)
	ok(late <= float(T["floor"]) + 0.001, "still tapered one second before the day ends (%.2f)" % late)
	var next_day := Care.trust_add(rec, 1.0, START + day_s + 1.0)
	ok(is_equal_approx(next_day, 1.0), "the next garden day pays in full again (%.2f)" % next_day)
	rec["trust"] = 20.0
	ok(Care.trust_add(rec, -3.0, START + day_s + 2.0) == -3.0, "a loss is never tapered")
	ok(Care.trust_add(_kin(), 2.0, START) == 2.0, "a fresh Boki's first act pays in full")
	# what the player sees: a grinder spamming for one session does not max the Boki
	var g: Dictionary = res["grinder after"]
	var gb: Dictionary = res["grinder before"]
	var gs := float(g["min"][3])
	var gbs := float(gb["min"][3])
	ok(gs > gbs * 3.0, "a grinder's Soulbound moves from %.0f to %.0f min (over 3x slower)" % [gbs, gs])
	var b: Dictionary = res["balanced after"]
	var bb: Dictionary = res["balanced before"]
	var bs := float(b["min"][3])
	ok(is_equal_approx(bs, float(bb["min"][3])), "a balanced day is not slowed (%.0f min both)" % bs)
	ok(gs >= bs * 0.5, "spamming is never over 2x faster than a balanced player (%.0f vs %.0f min)" % [gs, bs])
	print("BONDPACE DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
