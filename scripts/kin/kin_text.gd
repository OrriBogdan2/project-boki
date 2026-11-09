class_name KinText
extends RefCounted
## Short readable lines generated from a kin's parts, so a player who has never seen a kin can read
## what it does: "Hook: shot 8m, yanks → 8 damage, 18 damage over 3s, blight 4s, yank to the kin,
## stun 0.3s". Every number comes from the data; nothing here is written per kin. Colour means
## effect category (KinRules.CAT_COLORS). Phase 4 turns this into polished rules text.

static func n(f: float) -> String:
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(snappedf(f, 0.1))

static func pct(f: float) -> String:
	return "%d%%" % int(roundf(f * 100.0))

# ------------------------------------------------------------------ effects
static func effect(e: PartSpec, pw := 1.0) -> String:
	var p := e.params
	var t := ""
	match e.type:
		"damage":
			t = ("%s damage over %ss" % [n(float(p["amount"]) * pw), n(float(p["over"]))]) if float(p["over"]) > 0.0 else "%s damage" % n(float(p["amount"]) * pw)
		"slow": t = "slow %s %ss" % [pct(float(p["strength"])), n(float(p["duration"]))]
		"root": t = "root %ss" % n(float(p["duration"]))
		"stun": t = "stun %ss" % n(float(p["duration"]))
		"pull":
			var to := {"caster": "the kin", "owner": "its hunter", "center": "the middle"}[String(p["to"])] as String
			t = ("yank to %s" % to) if float(p["gap"]) > 0.0 else ("pull in" if String(p["to"]) == "center" else "pull to %s" % to)
		"push": t = "knock back"
		"lift": t = "knock up" if e.target == "foes" else ("lift you up" + (" and forward" if float(p["forward"]) > 0.0 else ""))
		"shield": t = "%s shield %ss" % [n(float(p["amount"]) * pw), n(float(p["duration"]))]
		"heal": t = ("heal %s over %ss" % [n(float(p["amount"]) * pw), n(float(p["over"]))]) if float(p["over"]) > 0.0 else "heal %s" % n(float(p["amount"]) * pw)
		"cleanse": t = "cleanse"
		"reflect": t = ("reflects shots" + ("" if is_equal_approx(float(p["power"]), 1.0) else " x%s" % n(float(p["power"])))) if e.target == "wall" else "mirror %ss" % n(float(p["duration"]))
		"mark":
			match String(p["mode"]):
				"reveal": t = "reveal %ss" % n(float(p["duration"]))
				"vulnerable": t = "+%s damage taken %ss" % [pct(minf(float(p["amount"]), KinRules.VULN_MAX)), n(float(p["duration"]))]
				"blight": t = "Anti-Heal %ss (heals %s less)" % [n(float(p["duration"])), pct(float(p["amount"]))]
		"buff":
			match String(p["stat"]):
				"crit": t = "your shots crit %ss" % n(float(p["duration"]))
				"dash_refill": t = "dodges refill"
				"glider_cool": t = "cools your glider"
				"move_speed": t = "+%s speed %ss" % [pct(float(p["amount"])), n(float(p["duration"]))]
				"guard": t = "-%s damage taken %ss" % [pct(float(p["amount"])), n(float(p["duration"]))]
				"damage": t = "+%s damage %ss" % [pct(float(p["amount"])), n(float(p["duration"]))]
				"fire_rate": t = "+%s fire rate %ss" % [pct(float(p["amount"])), n(float(p["duration"]))]
		"signature":
			match String(p["id"]):
				"swap": t = "swaps places with " + ("you" if String(p.get("who", "owner")) == "owner" else "the kin")
				"decoy": t = "leaves a decoy %ss" % n(float(p.get("duration", 1.8)))
				"bridge": t = "bridges the abyss %sm" % n(float(p.get("length", 8.0)))
	if e.target == "owner" and e.type in ["shield", "heal", "cleanse", "reflect"]:
		t += " on you"
	elif e.target == "allies":
		t += " on allies"
	elif e.target == "self" and e.type in ["shield", "heal", "cleanse", "reflect", "buff"]:
		t += " on itself"
	return t

static func effects(effs: Array, pw := 1.0) -> String:
	var out := PackedStringArray()
	for e in effs:
		var s := effect(e, pw)
		if s != "": out.append(s)
	return ", ".join(out)

# ------------------------------------------------------------------ deliveries and modifiers
static func delivery(d: PartSpec) -> String:
	var p := d.params
	var o := String(p.get("origin", ""))
	match d.type:
		"projectile": return ("hook %sm" if bool(p["rope"]) else "shot %sm") % n(float(p["range"]))
		"cone": return "%s° cone %sm" % [n(float(p["angle"])), n(float(p["radius"]))]
		"beam": return ("beam %sm" % n(float(p["range"]))) + (" (locks on)" if bool(p["seek"]) else "") + ((" for %ss" % n(float(p["duration"]))) if float(p["duration"]) > 0.0 else "")
		"burst":
			if float(p["radius"]) <= 0.01: return "on you" if o == "owner" else "on itself"
			return "burst %sm%s" % [n(float(p["radius"])), " around you" if o == "owner" else (" where it lands" if o == "here" else "")]
		"zone": return "zone %sm for %ss" % [n(float(p["radius"])), n(float(p["duration"]))]
		"trap": return ("%d traps" % int(p["count"])) if int(p["count"]) > 1 else "a trap"
		"wall": return "wall %sm, %s hp, %ss%s" % [n(float(p["length"])), n(float(p["hp"])), n(float(p["duration"])), " in front of you" if bool(p["follow"]) else ""]
		"aura": return "aura %sm for %ss" % [n(float(p["radius"])), n(float(p["duration"]))]
		"tether": return "tether %sm for %ss" % [n(float(p["length"])), n(float(p["duration"]))]
		"dash": return ("dash %sm" % n(float(p["distance"]))) + (" (you)" if o == "owner" else "")
		"leap": return ("leap %sm" % n(float(p["range"]))) + (" (you)" if o == "owner" else "")
		"blink": return ("blink %sm" % n(float(p["distance"]))) + (" (you)" if o == "owner" else "")
		"summon": return "%d %s%s for %ss" % [int(p["count"]), String(p["unit"]), "s" if int(p["count"]) > 1 else "", n(float(p["duration"]))]
	return d.type

static func modifier(md: PartSpec) -> String:
	var p := md.params
	match md.type:
		"bounce": return "bounces %d" % int(p["count"])
		"pierce": return "pierces %d" % int(p["count"])
		"chain": return "chains to %d more" % int(p["count"])
		"split": return "x%d" % int(p["count"])
		"delay": return "after %ss" % n(float(p["time"]))
		"linger": return "lingers %ss" % n(float(p["duration"]))
		"repeat": return ("echoes" if int(p["count"]) == 1 else "echoes x%d" % int(p["count"])) + " at %s" % pct(float(p["falloff"]))
		"return": return "comes back"
		"spike": return "spikes airborne +%s%s" % [pct(float(p["bonus"])), (", stun %ss" % n(float(p["stun"]))) if float(p["stun"]) > 0.0 else ""]
	return md.type

const EVENTS := {"on_hit": "on hit", "on_end": "at the end", "on_land": "on landing", "on_trigger": "when stepped on", "on_snap": "if it snaps"}

static func stage(st: StageSpec, pw := 1.0) -> String:
	var t := delivery(st.delivery)
	if not st.modifiers.is_empty():
		var ms := PackedStringArray()
		for md in st.modifiers: ms.append(modifier(md))
		t += " (%s)" % ", ".join(ms)
	var ef := effects(st.effects, pw)
	if ef != "":
		t += " → " + ef
	for ev in st.then:
		var subs := PackedStringArray()
		for sub in st.then[ev]: subs.append(stage(sub, pw))
		t += "; %s: %s" % [EVENTS.get(ev, ev), " + ".join(subs)]
	return t

## The whole ability in one line (without its name).
static func ability(ab: AbilitySpec, pw := 1.0) -> String:
	if ab == null:
		return ""
	var parts := PackedStringArray()
	for st in ab.stages: parts.append(stage(st, pw))
	var t := "; then ".join(parts)
	if ab.from == "owner":
		t += "  ·  works on you wherever your kin is"
	return t

## The colour of an ability: its first stage that has effects (KinRules.CAT_ORDER).
static func color(ab: AbilitySpec) -> Color:
	if ab == null:
		return Color.WHITE
	for st in ab.all_stages():
		if not st.effects.is_empty():
			return KinRules.effects_color(st.effects)
	return KinRules.cat_color("sustain" if not ab.stages.is_empty() and ab.stages[0].delivery.type == "wall" else "utility")

## A HUD icon from the shape of the ability (Icons ids).
static func icon(ab: AbilitySpec) -> String:
	if ab == null or ab.stages.is_empty():
		return "bond"
	var st: StageSpec = ab.stages[0]
	var types := ab.effect_types()
	match st.delivery.type:
		"projectile":
			if types.has("signature"): return "swap"
			return "hook" if bool(st.delivery.params["rope"]) else "fireball"
		"cone": return "wave"
		"beam": return "chain"
		"burst":
			if types.has("lift"): return "updraft"
			if types.has("reflect"): return "brightshield"
			if types.has("mark"): return "scanner"
			return "burst"
		"zone": return "snare"
		"trap": return "trap"
		"wall": return "wall"
		"aura": return "pulse"
		"tether": return "tether"
		"dash": return "dash"
		"leap": return "slam"
		"blink": return "blink"
	return "burst"

const CUES := {"foe_in_range": "when a foe is in reach", "foes_clumped": "when foes bunch up", "owner_hurt": "when you're hurt",
	"owner_falling": "when you fall into the abyss", "owner_fighting": "in a fight", "owner_under_fire": "when you're shot at"}
const TRIGGERS := {"auto": "", "on_throw": "when thrown into a foe", "on_hit": "every few of its hits", "on_recall": "when recalled",
	"on_bond_full": "when the bond meter fills", "on_low_hp": "when health runs low"}

## When an auto ability goes off, in words.
static func when(ab: AbilitySpec) -> String:
	if ab == null or ab.trigger == null:
		return ""
	if ab.trigger.type == "auto":
		return "On its own " + String(CUES.get(ab.cue.type if ab.cue else "", "when it sees the chance"))
	return "On its own " + String(TRIGGERS.get(ab.trigger.type, ab.trigger.type))

# ------------------------------------------------------------------ owner stats, carry, merge
static func owner_stat(stat: String, v: float) -> String:
	match stat:
		"move_speed": return "+%s move speed" % pct(v)
		"extra_jumps": return "double jump"
		"air_dashes": return "a dodge in the air"
		"glide": return "+%s glide" % pct(v)
		"dodge_charges": return "+%d dodge charge" % int(v)
		"dodge_regen": return "dodges come back instantly" if v >= 0.99 else "dodges recharge %s faster" % pct(v)
		"armor": return "armor wears %s slower" % pct(v)
		"damage_reduction": return "-%s damage taken" % pct(v)
		"knockback_resist": return "half knockback" if is_equal_approx(v, 0.5) else "-%s knockback" % pct(v)
		"regen": return "%s hp/s regen" % n(v)
		"damage": return "+%s damage" % pct(v)
		"fire_rate": return "+%s fire rate" % pct(v)
		"reload": return "%s faster reload" % pct(v)
		"reveal_radius": return "reveals rivals within %sm" % n(v)
		"cooldown": return "abilities recharge %s faster" % pct(v)
	return stat

static func passives(list: Array, k := 1.0) -> String:
	var out := PackedStringArray()
	for ps in list:
		var v := float(ps["amount"])
		if not String(ps["stat"]) in ["extra_jumps", "air_dashes", "dodge_charges", "dodge_regen"]: v *= k
		out.append(owner_stat(String(ps["stat"]), v))
	return ", ".join(out)

static func on_shot(os: Dictionary) -> String:
	if os.is_empty():
		return ""
	var out := PackedStringArray()
	for e in os.get("effects", []): out.append(effect(e))
	if float(os.get("splash", 0.0)) > 0.0: out.append("splash %sm" % n(float(os["splash"])))
	if int(os.get("chain", 0)) > 0: out.append("arc to %d more" % int(os["chain"]))
	return "your shots: " + ", ".join(out)

const CARRY_NAMES := {"shoulder": "Return: rides your shoulder", "perch": "Return: perches on your pack", "mount": "Return: you ride it"}

## How it's carried and what that gives you: "You ride it (Anchor): -15% damage taken, half knockback".
static func carry(ks: KinSpec) -> String:
	if ks == null:
		return ""
	var bits := PackedStringArray()
	if not ks.carry_passives.is_empty(): bits.append(passives(ks.carry_passives))
	var os := on_shot(ks.carry_on_shot)
	if os != "": bits.append(os)
	var t := "%s%s" % [CARRY_NAMES.get(ks.carry_style, ks.carry_style), (" (%s)" % ks.carry_name) if ks.carry_name != "" else ""]
	if not bits.is_empty(): t += ": " + "; ".join(bits)
	match ks.carry_style:
		"mount": t += ". It curls up on your back while you glide; you can't glide riding it"
		"perch": t += ". Thrown, it dives on the spot from above"
	return t

## What you lose while it is out beside you: "Off you: no -15% damage taken" ("" if its carry gives nothing).
static func carry_off(ks: KinSpec) -> String:
	if ks == null:
		return ""
	var bits := PackedStringArray()
	if not ks.carry_passives.is_empty(): bits.append("no " + passives(ks.carry_passives).replace(", ", ", no "))
	var os := on_shot(ks.carry_on_shot)
	if os != "": bits.append("no " + os)
	return ("Off you: " + "; ".join(bits)) if not bits.is_empty() else ""

const OWNER_POINTS := {"owner_max_hp": "+%s max health", "owner_armor": "armor wears %s slower", "owner_shield": "%s shield that refills out of a fight",
	"owner_regen": "+%s hp/s regen", "owner_move_speed": "+%s move speed"}

## The owner bonuses from its stat points: "+8 max health, +3% move speed".
static func owner_bonus(bonus: Dictionary) -> String:
	var out := PackedStringArray()
	for key in KinParts.STATS:
		if not bonus.has(key): continue
		var v := float(bonus[key])
		var vs := pct(v) if key in ["owner_armor", "owner_move_speed"] else n(v)
		out.append(String(OWNER_POINTS.get(key, key + " %s")) % vs)
	return ", ".join(out)

## The class dodge's kin rider: "Venom Trail: what you dodge through takes 3 damage, ...".
static func rider(ks: KinSpec) -> String:
	if ks == null or ks.dodge_rider.is_empty():
		return ""
	var r: Dictionary = ks.dodge_rider
	var bits := PackedStringArray()
	if String(r.get("as", "dash")) == "blink": bits.append("on the ground your dodge is a blink: there in an instant")
	if not (r.get("on_pass", []) as Array).is_empty(): bits.append("what you dodge through: " + effects(r["on_pass"]))
	for st in r.get("on_start", []): bits.append("where you start: " + stage(st))
	for st in r.get("on_end", []): bits.append("where you stop: " + stage(st))
	for md in r.get("modifiers", []):
		if (md as PartSpec).type == "repeat": bits.append("a beat later it dodges again at %s" % pct(float(md.params["falloff"])))
	return "; ".join(bits)

## A merge in a few lines: [what it gives, what its shots do, what it does over time].
static func merge(ms: MergeSpec, giant := false) -> Array:
	if ms == null:
		return []
	var fd: Dictionary = Content.merge_form(ms.id)
	if not fd.is_empty():
		return form_lines(ms, fd)
	var out: Array = []
	var head := "%ss: %s" % [n(ms.duration), passives(ms.passives)]
	if giant: head = "Your mount grows huge for " + head
	else: head = "Fuses onto you for " + head
	out.append(head)
	var os := on_shot(ms.on_shot)
	if os != "": out.append(os.substr(0, 1).to_upper() + os.substr(1))
	for st in ms.on_start: out.append("As it starts: " + stage(st))
	for pl in ms.pulses: out.append("Every %ss: %s" % [n(float(pl["every"])), stage(pl["stage"])])
	var fdash: Dictionary = MergeForm.data()["fallback"]["dash"]
	out.append("%s, %s: your dash leaves your Boki type's trail (its rider on what you pass), then %ss of haste."
		% [Settings.key_cap("dash"), String(fdash["name"]), n(float(fdash["haste_s"]))])
	out.append("%s again: a basic burst that ends the Fusion." % Settings.key_cap("ultimate"))
	for slot in ms.merged:
		var pt: Dictionary = ms.merged[slot]
		var bits := PackedStringArray()
		for k in pt.get("scale", {}): bits.append("%s x%s" % [k, n(float(pt["scale"][k]))])
		for mp in pt.get("add_modifiers", []): bits.append(modifier(mp))
		out.append("Fused %s: %s" % ["E" if slot == "active" else "auto ability", ", ".join(bits)])
	return out

## A merge with a form (content/merge_forms): what you become, its shell, what it adds to your own abilities, its ultimate (the same for everyone).
static func form_lines(ms: MergeSpec, fd: Dictionary) -> Array:
	var f := MergeForm.kit_form(ms.id)
	var out: Array = []
	out.append("You become %s for %ss. A shell (%s hp, from the lightest Hunter to the sturdiest) takes damage first; if it breaks, the Fusion ends." % [fd["name"], n(ms.duration), "/".join([n(MergeShell.size_for("light", f)), n(MergeShell.size_for("medium", f)), n(MergeShell.size_for("heavy", f))])])
	var a: Dictionary = fd["aug"]
	out.append("You keep your own abilities and they get stronger:")
	out.append("Left click, %s: %s" % [a["lmb"]["name"], a["lmb"]["desc"]])
	out.append("Right click, %s: %s" % [a["rmb"]["name"], a["rmb"]["desc"]])
	out.append("E, %s: %s" % [a["e"]["name"], a["e"]["desc"]])
	out.append("Shift, %s: %s" % [a["dash"]["name"], a["dash"]["desc"]])
	out.append("%s again, %s: %s It ends the Fusion with a burst of speed and a shield, and your Boki rests %ss. Ready %ss in." % [Settings.key_cap("ultimate"), fd["r"]["name"], fd["r"]["desc"], n(float(MergeForm.data()["release_rest_s"])), n(float(MergeForm.data()["ult_lock_s"]))])
	out.append("Your Boki's own ability is off while fused. Your Boki is part of you until it ends.")
	return out

## The aiming shape shown while E is held (Match._update_indicators): [kind, reach, size(, "front")].
static func aim(ab: AbilitySpec) -> Array:
	if ab == null or ab.stages.is_empty():
		return ["self", 0.0, 1.2]
	var st: StageSpec = ab.stages[0]
	var p := st.delivery.params
	var reach := ab.cast_range if ab.cast_range > 0.0 else 8.0
	var o := String(p.get("origin", ""))
	match st.delivery.type:
		"projectile":
			var rad := 0.0
			for sub in st.then.get("on_end", []): rad = maxf(rad, float((sub as StageSpec).delivery.params.get("radius", 0.0)))
			if rad > 0.0 and not bool(p["rope"]) and not st.then.has("on_hit"):
				return ["area", float(p["range"]), rad]
			var sp := st.modifier("split")
			return ["line", float(p["range"]), maxf(0.5, float(p["size"]) * 2.5) * (1.0 + (float(sp.params["count"]) * 0.3 if sp else 0.0))]
		"cone": return ["cone", float(p["radius"]), cos(deg_to_rad(float(p["angle"])) * 0.5)]
		"beam": return ["line", float(p["range"]), float(p["width"]) * 2.0]
		"dash": return ["line", float(p["distance"]), float(p["width"]) * 2.0]
		"blink": return ["line", float(p["distance"]), 0.7]
		"tether": return ["line", float(p["length"]), 0.5]
		"leap":
			var lr := 2.0
			for ev in st.then:
				for sub in st.then[ev]: lr = maxf(lr, float((sub as StageSpec).delivery.params.get("radius", 0.0)))
			return ["area", minf(reach, float(p["range"])), lr]
		"wall":
			if o in ["owner", "caster"]:
				return ["wall", maxf(0.6, float(p["offset"])), float(p["length"]), "front"]
			return ["wall", reach, float(p["length"])]
		"zone", "trap", "summon":
			var r := float(p.get("radius", 2.0)) + (float(p.get("spread", 0.0)) if int(p.get("count", 1)) > 1 else 0.0)
			return ["area", reach, r]
		"burst":
			if o == "aim": return ["area", reach, float(p["radius"])]
			return ["self", 0.0, maxf(1.2, minf(float(p["radius"]), 8.0))]
		"aura": return ["self", 0.0, float(p["radius"])]
	return ["self", 0.0, 1.2]
