class_name HudHover
extends RefCounted
## Hover tips, moved out of hud.gd (a god file). Point at anything on the bottom bar (abilities,
## health, weapon, kin) to see what it is (the rects come from Hud.hover_spots), or rest the cursor
## on a monster, a Boki or another hunter for a card about it. Hud keeps hover_id / hover_t (checks
## and RankMarks read them); this file builds the lines and draws the cards.

var H      # the Hud that owns this (hud.gd has no class_name: Match loads it by path)
var _wh_mp := Vector2.ZERO
var _wh_still := 0.0

func _init(hud) -> void:
	H = hud

func draw_hud_tip(sz: Vector2, p: Hunter) -> void:
	var mp: Vector2 = H.c.get_local_mouse_position()
	var hit: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hover="):      # test hook: point at a HUD element
			for hs in H.hover_spots:
				if hs[1] == arg.substr(8): mp = (hs[0] as Rect2).get_center()
	for hs in H.hover_spots:
		if (hs[0] as Rect2).has_point(mp):
			hit = hs
	var id: String = hit[1] if hit.size() > 0 else ""
	if id != H.hover_id:
		H.hover_id = id
		H.hover_t = 0.0
	H.hover_t += H.get_process_delta_time()
	if id == "" or H.hover_t < 0.25:
		return
	var lines := tip_lines(id, p)
	if lines.is_empty():
		return
	# [title, colour] then rows of [text, colour, size]
	var head: Array = lines[0]
	var w := 340.0
	var h := 40.0
	for i in range(1, lines.size()):
		h += wrapped_h(String(lines[i][0]), w - 28, int(lines[i][2])) + 4.0
	var anchor: Rect2 = hit[0]
	var pos := HudTip.place(anchor, Vector2(w, h), sz)      # above if it fits, else beside; always on screen, never over the slot
	var a := clampf((H.hover_t - 0.25) / 0.12, 0.0, 1.0)
	var box := Rect2(pos, Vector2(w, h))
	H._rounded(box, Color(0.05, 0.06, 0.09, 0.95 * a), 12, Color(head[1], 0.6 * a), 2)
	H._text(pos + Vector2(14, 26), String(head[0]), 17, Color(head[1], a), H.big)
	var y := pos.y + 40
	for i in range(1, lines.size()):
		var ln: Array = lines[i]
		var fs := int(ln[2])
		var hh := wrapped_h(String(ln[0]), w - 28, fs)
		H.c.draw_multiline_string(H.body, Vector2(pos.x + 14, y + fs), String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 28, fs, -1, Color(ln[1], a))
		y += hh + 4.0

func wrapped_h(txt: String, w: float, fs: int) -> float:
	return H.body.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y

func secs(x: float) -> String:
	return ("%ds" % int(x)) if absf(x - round(x)) < 0.05 else ("%.1fs" % x)

## Hover text for an archetype's slots (and the kin's own ability on C, send/recall on G).
func arch_tip(id: String, p: Hunter) -> Array:
	var out: Array = []
	var k: Kin = p.kin
	match id:
		"kin_ab":
			if k == null or k.runner.def_of("k1") == null: return []
			var kd: AbilitySpec = k.runner.def_of("k1")
			out.append([kd.display_name, KinText.color(kd)])
			out.append(["%s's own ability  ·  it casts it by itself" % k.rec.get("name", "Boki"), H.MUTED, 12])
			out.append([KinText.ability(k.effective("k1")), H.INK, 14])
			out.append(["Cooldown %s%s" % [secs(kd.cooldown), ("  ·  ready in %s" % secs(k.runner.cd_left("k1"))) if not k.runner.is_ready("k1") else "  ·  ready"], H.MUTED, 13])
			return out
		"throw":
			if k == null: return []
			out.append(["Send / recall", Color("cfe8ff")])
			out.append(["%s  ·  tap: Sic %s at the cursor, or Call it back when it is away (it hits what it passes). Hold: Chase, Guard, Return or Follow. A downed Boki stays where it fell: run into it to bring it back." % [Settings.key_cap("throw"), k.rec.get("name", "your Boki")], H.INK, 13])
			return out
	var si := p.slot_info(id)
	var r_name := "Ultimate (%s)" % Settings.key_cap("hunter_ult")
	var slot_names := {"sec": "Right click", "k1": "Utility (E)", "r": r_name, "dash": "Dash"}
	var slot_name: String = slot_names[id]
	var key: String = {"sec": "secondary", "k1": "signature", "r": "hunter_ult", "dash": "dash"}[id]
	out.append([String(si["name"]), si["col"]])
	out.append(["%s %s  ·  %s  ·  %s" % [Arch.name_of(p.arch), slot_name, Settings.key_cap(key), p.rank_text({"sec": "sec", "k1": "k1", "r": "r", "dash": "dash"}[id])], H.MUTED, 12])
	out.append([String(si["desc"]), H.INK, 13])
	# what the next rank does, concretely (rank 2 when you're rank 1), then rank 3's special after it
	var sk: String = {"sec": "sec", "k1": "kin", "r": "ult", "dash": "dash"}[id]
	var nr := Arch.next_ranks(p.arch, sk, int(p.slot_lv.get(sk, 0)))
	for i in nr.size():
		out.append(["%s%s: %s" % ["Next  ·  " if i == 0 else "", String(nr[i][0]), String(nr[i][1])], Color(si["col"], 0.95 if i == 0 else 0.7), 12])
	if id == "r":
		out.append(["Unlocks at level %d, rank 2 at %d. " % [int(Hunter.ULT_AT[0]), int(Hunter.ULT_AT[1])], H.MUTED, 12])
	if id == "sec":
		var rd := p.ak.res_def()
		out.append(["Passive: %s" % String(p.ak.d["passive"]["desc"]), Color(Color(String(rd.get("col", "#ffffff"))), 0.9), 12])
	out.append(["Cooldown %s%s" % [secs(float(si["cd_max"])), ("  ·  ready in %s" % secs(float(si["cd"]))) if float(si["cd"]) > 0.0 else "  ·  ready"], H.MUTED, 13])
	return out

func tip_lines(id: String, p: Hunter) -> Array:
	var hc: Color = p.accent()
	var out: Array = []
	if id.begins_with("perk:"):
		var pd: Dictionary = Data.PERKS.get(id.substr(5), {})
		if not pd.is_empty():
			var n := p.perk_n(id.substr(5))
			out.append([String(pd["name"]) + ("  x%d" % n if n > 1 else ""), pd["col"]])
			out.append([String(pd["desc"]), H.INK])
			out.append(["Found this expedition. Gone when it ends.", H.MUTED])
		return out
	if id.begins_with("gslot:"):
		return GearPanel.tip(p, int(id.substr(6)))
	if p.ak and id in ["sec", "k1", "r", "dash", "kin_ab", "throw"]:
		return arch_tip(id, p)
	match id:
		"sec" when p.runner and p.runner.def_of("utility") != null:
			var u: AbilityDef = p.runner.def_of("utility")
			out.append([u.display_name, u.color])
			out.append(["Weapon utility (%s)  ·  %s" % [String(p.wpn.get("name", "")), Settings.key_cap("secondary")], H.MUTED, 12])
			out.append([u.desc, H.INK, 14])
			out.append(["Cooldown %s%s" % [secs(u.cooldown), ("  ·  ready in %s" % secs(p.runner.cd_left("utility"))) if not p.runner.is_ready("utility") else "  ·  ready"], H.MUTED, 13])
		"k1", "k2":
			var k: Kin = p.kin
			if k == null: return []
			var kd: AbilitySpec = k.runner.def_of(id)
			if kd == null: return []
			out.append([kd.display_name, KinText.color(kd)])
			out.append(["%s's ability  ·  %s" % [k.rec.get("name", "Boki"), "its own" if p.ak or id != "k1" else Settings.key_cap("signature")], H.MUTED, 12])
			out.append([KinText.ability(k.effective(id)), H.INK, 14])
			var where := "Your Boki casts it; while it rides with you, you do." if kd.from == "kin" else "Works on you wherever your Boki is."
			out.append(["Cooldown %s%s. %s" % [secs(kd.cooldown / maxf(0.1, k.runner.rate)), ("  ·  ready in %s" % secs(k.runner.cd_left(id))) if not k.runner.is_ready(id) else "  ·  ready", where], H.MUTED, 13])
			if id == "k1" and kd.cue != null:
				out.append(["Your Boki can also use it on its own (turn that on in Settings).", Color(KinText.color(kd), 0.85), 12])
			var ka: AbilitySpec = k.runner.def_of("k2")
			if id == "k1" and ka:
				out.append(["%s: %s. %s" % [ka.display_name, KinText.when(ka), KinText.ability(k.effective("k2"))], KinText.color(ka), 12])
		"r":
			var ud := KinMerge.def_for(p.kin) if p.kin else null
			if ud == null: return []
			var giant: bool = (p.kin as Kin).carry_style() == "mount"
			out.append([ud.display_name, H.GOLD])
			out.append(["Fusion  ·  %s  ·  %s" % [Settings.key_caps("ultimate"), "your mount grows giant" if giant else "you take its colour and power"], H.MUTED, 12])
			for ln in KinText.merge(ud, giant):
				out.append([String(ln), H.INK, 13])
			out.append(["Unlocks at level %d with a full meter. The bond fills as your Boki lands hits, as you hit what it marked, and on combos. Boki out? It comes back to you first. No Boki: a weak surge. Then %ss before it can go again." % [int(Hunter.ULT_AT[0]), KinText.n(KinParts.MERGE_SPENT_TIME)], H.GOLD, 12])
		"swap":
			var b: Kin = p.kin2
			if b == null: return []
			out.append(["Swap to %s" % b.rec.get("name", "your other Boki"), Data.KIN[b.species]["color"]])
			out.append(["Second Boki  ·  %s" % Settings.key_cap("swap_kin"), H.MUTED, 12])
			var names := []
			for sl in ["k1", "k2"]:
				var bd: AbilitySpec = b.runner.def_of(sl)
				if bd: names.append(bd.display_name)
			var bu := KinMerge.def_for(b)
			out.append(["Brings out %s: %s, and %s as its bond ultimate. The Boki you swap out rests and heals." % [Data.KIN[b.species]["name"], " and ".join(names), bu.display_name if bu else "its ultimate"], H.INK, 14])
		"kin":
			var k: Kin = p.kin
			if k == null: return []
			var ai := k.brain
			out.append([Data.kin_title(String(k.rec.get("name", "")), String(Data.KIN[k.species]["name"])), Data.KIN[k.species]["color"]])
			out.append(["Level %d  ·  %d / %d health  ·  trust %d" % [int(k.rec.get("level", 1)), int(ceil(k.hp)), int(k.max_hp), int(k.trust)], H.MUTED, 12])
			var traits := []
			if ai.aggression > 0.6: traits.append("aggressive: chases foes far")
			if ai.loyalty > 0.65: traits.append("loyal: stays by you and goes after whoever hurts you")
			if ai.caution > 0.55: traits.append("cautious: backs off when hurt")
			if traits.is_empty(): traits.append("steady: a bit of everything")
			out.append(["In a fight it's " + "; ".join(traits) + ".", H.INK, 14])
			if k.ks:
				out.append([KinText.carry(k.ks), KinRules.cat_color("sustain"), 13])
				var ob := KinText.owner_bonus(p.kin_bonus)
				if ob != "":
					out.append(["Owner bonus for the run: " + ob, H.GOLD, 13])
		"gear0", "gear1": out = GripHud.tip(p, int(id.substr(4)))
		"x": out = HunterUltTile.tip(p)
		"throw": return BokiHud.order_tip(H, p)
		"dash":
			var dd: AbilityDef = p.dodge_def
			out.append([dd.display_name if dd else "Dash", dd.color if dd else Color("bfe6ff")])
			out.append(["Dodge  ·  %s" % Settings.key_cap("dash"), H.MUTED, 12])
			out.append([dd.desc if dd else "A quick burst the way you're moving.", H.INK, 14])
			out.append(["%d of %d charges. One comes back every %s." % [int(floor(p.dashes)), int(p.max_dashes()), secs(p.dash_regen())], H.MUTED, 13])
		"util1", "util2", "util3", "util4": out = BeltHud.tip(p, int(id.substr(4)) - 1)
		"armor_level": out = ArmorHud.tip(p)
		"base":
			out.append(["Base to a teammate", Color("8fe3c8")])
			out.append(["Squads  ·  %s" % Settings.key_cap("base"), H.MUTED, 12])
			out.append(["A 3s channel to the teammate nearest your cursor. Stand still: moving, attacking or any damage interrupts it. You arrive weakened for 3s: half damage, and your crowd control, healing and shields are halved.", H.INK, 14])
			out.append(["Cooldown %ds%s" % [int(Hunter.BASE_CD), ("  ·  ready in %ds" % int(ceil(p.base_cd))) if p.base_cd > 0.0 else "  ·  ready"], H.MUTED, 13])
		"pack":
			var pack_tip := Backpacks.tip(p)
			out.append(pack_tip[0])
			out.append(["Open  ·  %s" % Settings.key_cap("inventory"), H.MUTED, 12])
			out.append(pack_tip[1])
		"weapon":
			var wp: Dictionary = p.wpn
			out.append([wp["name"], Color("e6dccb")])
			out.append(["Your signature weapon  ·  reloads by itself when empty", H.MUTED, 12])
			var ups := WeaponUps.summary(p)
			if ups != "":
				out.append([ups, H.GOOD, 13])
			var rate := 1.0 / maxf(0.01, float(wp["rate"]))
			out.append(["%.0f damage a shot  ·  %.1f shots a second  ·  about %d damage a second" % [float(wp["dmg"]), rate, int(float(wp["dmg"]) * rate)], H.INK, 14])
			out.append(["Magazine %d  ·  reload %s  ·  range %d tiles" % [int(wp["mag"]), secs(float(wp["reload"])), int(float(wp.get("range", 10.0)))], H.MUTED, 13])
			out.append(["It's the one weapon you carry; level-ups, chests and tunings on the ground make it stronger.", H.MUTED, 12])
		"vitals":
			out.append([Arch.label(p.arch), hc])
			out.append(["Speed %.1f  ·  %s" % [p.base_speed, String(p.cdat.get("desc", ""))], H.MUTED, 12])
			out.append(["Health %d / %d   ·   Armor %d / %d" % [int(ceil(p.hp)), int(p.max_hp), int(ceil(p.armor)), int(p.max_armor)], H.INK, 14])
			out.append(["Level %d  ·  %s" % [p.lvl, LevelGrowth.tip(p)], H.GOLD, 13])
			out.append(["Armor takes 20% off every hit until it wears out. Neither armor nor health comes back on its own: use armor kits and tonics.", H.MUTED, 13])
			if p.lives < 50:
				out.append(["Lives left: %d" % p.lives, Color("ff7a8a"), 13])
	var rk := p.rank_text(id)
	if rk != "" and not out.is_empty():
		out.append([rk, H.GOLD, 12])
	return out

## Point the cursor at a monster, a kin or another hunter to see what it is.
## A rival kin's kit in one or two lines: its ability names and what each does, so you learn the
## counters by looking (the kin's species always means the same kit).
## Read from its parts (KinText), coloured by effect category: damage, control, sustain, utility.
func kit_lines(lines: Array, k: Kin) -> void:
	if k == null or k.runner == null:
		return
	for slot in ["k1", "k2"]:
		var d: AbilitySpec = k.runner.def_of(slot)
		if d == null: continue
		var tag := "E" if slot == "k1" else "auto"
		lines.append(["%s  %s: %s" % [tag, d.display_name, KinText.ability(k.effective(slot))], KinText.color(d).lightened(0.2)])
	var ms := KinMerge.def_for(k)
	if ms:
		var ml: Array = KinText.merge(ms, k.carry_style() == "mount")
		var first := String(ml[0]) if not ml.is_empty() else ""
		lines.append(["%s  %s: %s" % [Settings.key_cap("ultimate"), ms.display_name, first], Color(H.GOLD, 0.95)])
	if k.ks:
		lines.append([KinText.carry(k.ks), Color(KinRules.cat_color("sustain"), 0.9)])

func draw_world_tip(sz: Vector2, p: Hunter) -> void:
	var mp: Vector2 = H.c.get_local_mouse_position()
	var cam: CamRig = H.m.cam
	# only once the cursor rests a moment and you aren't fighting: in a fight you aim at things all the
	# time and a card popped up over every target (and never while recording)
	if mp.distance_to(_wh_mp) > 6.0 or Input.is_action_pressed("fire") or Input.is_action_pressed("secondary"):
		_wh_still = 0.0
	_wh_mp = mp
	_wh_still += H.get_process_delta_time()
	var testing := "--hover-rival" in OS.get_cmdline_user_args() or "--hover" in OS.get_cmdline_user_args()
	if (Record.clean() or _wh_still < 0.4) and not testing:
		return
	if "--hover-rival" in OS.get_cmdline_user_args():
		# test hook: point at the nearest rival hunter (or their kin, with --hover-rival-kin)
		var nb: Ent = null
		var nd := 1e9
		for e0 in (H.m.kins if "--hover-rival-kin" in OS.get_cmdline_user_args() else H.m.hunters):
			if e0 != p and e0.team != p.team and not e0.dead and e0.visible and p.flat_dist(e0) < nd and not (e0 is Kin and (e0 as Kin).state == "shoulder"):
				nd = p.flat_dist(e0)
				nb = e0
		if nb and not cam.is_position_behind((nb as Node3D).position):
			mp = cam.unproject_position((nb as Node3D).position + Vector3(0, 0.7, 0))
	var best: Ent = null
	var bd := 46.0
	var cands: Array = []
	for mb in H.m.mobs:
		if not mb.dead and mb.visible: cands.append(mb)
	for k in H.m.kins:
		if not k.dead and k.visible and k.state != "shoulder": cands.append(k)
	for h in H.m.hunters:
		if h != p and not h.out and not h.extracted and not h.unseen and h.visible: cands.append(h)
	for e in cands:
		var ep: Vector3 = (e as Node3D).position + Vector3(0, 0.7, 0)
		if cam.is_position_behind(ep):
			continue
		var d := cam.unproject_position(ep).distance_to(mp)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var lines: Array = []
	if best is Mob:
		var mb: Mob = best
		var md: Dictionary = mb.md
		lines.append([String(md["name"]), Color(md["color"]).lightened(0.35)])
		lines.append(["Monster  ·  %d / %d health" % [int(ceil(mb.hp)), int(mb.max_hp)], H.MUTED])
		var how := {"lunge": "Lunges at whoever is closest.", "spit": "Spits from range: keep moving.", "slam": "Winds up a ground slam: step out of the circle.",
			"fuse": "Rolls in and blows up. Shoot it before it reaches you.", "volley": "Fires a spread of bolts down a line.", "none": "Runs from you. Tame it before it escapes."}
		if mb is Blight:
			# the Blight: what it does, and how strong it is right now
			var bl: Blight = mb
			lines[1] = ["The Blight  ·  %d / %d health  ·  %s" % [int(ceil(mb.hp)), int(round(mb.max_hp)), "stirring" if bl.lvl < 0.35 else ("hunting" if bl.lvl < 0.8 else "ravenous")], H.MUTED]
			how = {"lunge": "Hunts by noise and light. Fast, fragile, comes in packs later on.", "spit": "Sweeps a light. Stay in it and it shrieks, and the Blight nearby comes."}
		lines.append([String(how.get(String(md["attack"]), "Dangerous up close.")), H.INK])
		if md.get("stag", false):
			lines.append(["Staggerable: hit it with an ability while the purple ring shows.", Color(0.85, 0.6, 1.0)])
		lines.append(["Drops %d gem%s." % [int(md["gems"]), "" if int(md["gems"]) == 1 else "s"], H.GOLD])
	elif best is Kin:
		var k: Kin = best
		var sp: Dictionary = Data.KIN[k.species]
		var nm := String(k.rec.get("name", sp["name"]))
		lines.append([("%s (lost)" % nm if k.lost_from != "" else "Wild %s" % sp["name"]) if k.is_wild() else nm, sp["color"]])
		lines.append(["%s type  ·  level %d  ·  %d / %d health" % [String(sp["type"]).capitalize(), int(k.rec.get("level", 1)), int(ceil(k.hp)), int(k.max_hp)], H.MUTED])
		if k.is_wild():
			if k.state == "dazed":
				lines.append(["Knocked out. Hold %s next to it to scan it." % Settings.key_cap("interact"), H.GOLD])
			else:
				lines.append(["Knock its health down to knock it out, then hold %s beside it to scan it." % Settings.key_cap("interact"), H.INK])
			if k.rec.get("shimmer", false):
				lines.append(["A shimmering one. Rare.", H.INK])
			for mid in Mutations.of(k.rec):
				lines.append(["%s: %s (%s)" % [Mutations.name_of(mid), String(Mutations.info(mid).get("desc", "")), Mutations.perk_text(mid)], H.INK])
			if k.lost_from != "":
				lines.append(["Guarding where %s fell. Scan it and whoever gets out with it keeps it; its owner can pick it up if revived." % ("you" if k.lost_from == "you" else k.lost_from), H.GOLD if k.lost_from == "you" else H.MUTED])
		elif k.owner_h == p:
			var a1: AbilitySpec = k.runner.def_of("k1")
			var uses := ("it uses %s itself" if p.ak else Settings.key_cap("signature") + " uses %s") % (a1.display_name if a1 else "its ability")
			lines.append(["Yours. %s sends it out, %s." % [Settings.key_cap("throw"), uses], H.INK])
		elif k.lost_from == "you" and k.lost_uid != "":
			lines.append(["Your lost Boki! Held by %s. Take it back." % (k.owner_h.pname if k.owner_h else "a rival"), H.GOLD])
		else:
			lines.append(["%s's Boki." % (k.owner_h.pname if k.owner_h else "A rival hunter"), H.BAD])
			kit_lines(lines, k)
	elif best is Hunter:
		var h: Hunter = best
		var ally: bool = h.team == p.team
		lines.append([h.pname, H.GOOD if ally else Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]])
		lines.append(["%s  ·  %s  ·  %s" % [Arch.label(h.arch), String(h.wpn.get("name", "")), "teammate" if ally else "rival"], H.MUTED])
		lines.append(["Health %d / %d   ·   Armor %d / %d (%s)" % [int(ceil(h.hp)), int(h.max_hp), int(ceil(h.armor)), int(h.max_armor), String(Hunter.ARMOR_TIERS[h.armor_tier][0])], H.INK])
		if not ally:
			# know your opponent: their right click, dodge, glove and kin, so you can play around them
			var util: AbilityDef = h.runner.def_of("utility") if h.runner else null
			if util: lines.append(["%s: %s" % [Settings.key_cap("secondary"), util.display_name], Color(util.color).lightened(0.2)])
			if h.dodge_def: lines.append(["Dodge: %s" % h.dodge_def.display_name, Color("bfe6ff")])
			if not (h.gear[0] as Dictionary).is_empty() and Gear.ALL.has(String(h.gear[0]["id"])):
				lines.append(["Glove: %s" % String(Gear.ALL[String(h.gear[0]["id"])]["name"]), Gear.ALL[String(h.gear[0]["id"])]["col"]])
			if h.kin and not (h.kin as Kin).dead:
				lines.append(["Boki: " + Data.kin_title(String((h.kin as Kin).rec.get("name", "")), String(Data.KIN[(h.kin as Kin).species]["name"])), Data.KIN[(h.kin as Kin).species]["color"]])
				kit_lines(lines, h.kin)
		if h.downed:
			lines.append(["Down. %s" % ("Hold %s next to them to revive." % Settings.key_cap("interact") if ally else "Finish them before they're revived."), H.BAD if not ally else H.GOOD])
	var w := 300.0
	var h2 := 36.0
	for i in range(1, lines.size()):
		h2 += wrapped_h(String(lines[i][0]), w - 24, 13) + 3.0
	var pos := mp + Vector2(22, 18)
	if pos.x + w > sz.x - 8: pos.x = mp.x - w - 22
	if pos.y + h2 > sz.y - 160: pos.y = mp.y - h2 - 18
	var box := Rect2(pos, Vector2(w, h2))
	H._rounded(box, Color(0.05, 0.06, 0.09, 0.9), 10, Color(lines[0][1], 0.5), 2)
	H._text(pos + Vector2(12, 24), String(lines[0][0]), 16, lines[0][1], H.big)
	var y := pos.y + 34
	for i in range(1, lines.size()):
		var hh := wrapped_h(String(lines[i][0]), w - 24, 13)
		H.c.draw_multiline_string(H.body, Vector2(pos.x + 12, y + 13), String(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, -1, lines[i][1])
		y += hh + 3.0
