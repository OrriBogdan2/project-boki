class_name ImpactWeight
extends RefCounted
## How heavy a hit lands (docs/DASHES_AND_ABILITY_FEEL.md §5.4): light (a poke), solid (a real hit) or
## heavy (an ult or a slam), each with a fixed hit-stop and shake (content/rules/impact_weight.json).
## A Hunter's ability hit takes its ability's tier from the rules; anything else (a Boki, a monster,
## the world) gets one from what the hit did. Feel applies the hit-stop, Shake the shake.

const TIERS := ["light", "solid", "heavy"]
## The kits' "ab" hit tags that name a Hunter slot; any other tag is its own ability key (a kit's rock, fan...).
const SLOT_OF_AB := {
	"primary": "lmb", "utility": "rmb", "dodge": "dash", "k1": "e", "signature": "e", "ult": "x", "ultimate": "x",
}
## Hit sources that are ticks or the world, never a weight.
const NO_WEIGHT_SRC := ["burn", "fall", "heat", "mob"]
const SOLID_HP_FRAC := 0.08    # a hit of this share of the target's max HP (or a CC) is solid when no rule names it
const SOLID_KB := 8.0          # m/s of knockback that makes a hit solid when no rule names it

const RULES_PATH := "res://content/rules/impact_weight.json"
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))

## The ability key a hit belongs to: a known slot tag mapped, any other tag kept, an untagged shot is the LMB.
static func ability_of(o: Dictionary) -> String:
	var ab := String(o.get("ab", ""))
	if ab == "":
		return "lmb" if String(o.get("src", "")) in ["shot", "boom"] or o.get("melee", false) else ""
	return String(SLOT_OF_AB.get(ab, ab))

## The tier a Hunter's ability is set to ("" when the rules don't name it).
static func of_ability(arch: String, ability: String) -> String:
	return String((rules["hunters"] as Dictionary).get(arch, {}).get(ability, ""))

## The tier of one hit ("" = no hit-stop or shake: a tick, a slow-only touch, a world hit).
static func of_hit(by: Ent, target: Ent, d: float, o: Dictionary) -> String:
	if String(o.get("src", "")) in NO_WEIGHT_SRC or o.get("tick", false):
		return ""
	if o.get("bonded", false) or o.get("merge_start", false) or String(o.get("src", "")) == "wall":
		return "heavy"
	var cc := float(o.get("stun", 0.0)) > 0.0 or float(o.get("root", 0.0)) > 0.0 or float(o.get("lift", 0.0)) > 0.0
	var kb: Vector2 = o.get("kb") if o.get("kb", null) is Vector2 else Vector2.ZERO
	var big: bool = cc or d >= maxf(1.0, target.max_hp) * SOLID_HP_FRAC or kb.length() >= SOLID_KB
	big = big or o.get("reflected", false)
	if not big and (d <= 0.0 or float(o.get("slow", 0.0)) > 0.0):
		return ""      # a slow-only touch or a zone tick that slows
	var w := of_ability((by as Hunter).arch, ability_of(o)) if by is Hunter else ""
	if w == "":
		w = "solid" if big else "light"
	if o.get("payoff", false) or o.get("spiked", false) or o.get("exploit", false):
		w = TIERS[mini(TIERS.find(w) + 1, TIERS.size() - 1)]
	return w

## The tier's fixed hit-stop, seconds.
static func hold_s(w: String) -> float:
	return float(rules["tiers"][w]["hitstop_ms"]) / 1000.0 if w != "" else 0.0

## Does the attacker of a melee hit hold too?
static func holds_attacker(w: String) -> bool:
	return w != "" and bool(rules["tiers"][w]["attacker"])

## The tier's shake power on the struck player's camera (Shake.incoming_big's 0-1).
static func shake(w: String) -> float:
	return float(rules["tiers"][w]["shake"]) if w != "" else 0.0

static func cap(key: String) -> float:
	return float(rules["cap"][key])
