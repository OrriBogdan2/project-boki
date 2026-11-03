class_name MantleLook
extends RefCounted
## The Mantle look (docs/decisions/0011-mantle-look.md): in a match a Bearer looks like their
## class's original Warden (gender, folk, face, hair and the class's palette: the 80%), nudged by
## the player's own person (PlayerLook: the 20%). At home, with no Mantle on, the player is their own
## person. Data in, model params out: Models.hunter builds from the params. Every range lives in
## content/rules/mantle_look.json. Hitboxes and hurtboxes never read any of this.

const RULES_PATH := "res://content/rules/mantle_look.json"
const FALLBACK_WARDEN := "gunslinger"

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {"sliders": {}, "tint": {}, "wardens": {}}
	return _rules

## A Hunter's original Warden, ready for apply(): the picks as indexes, the palette as colours, and
## the clamp and tint ranges with the Warden's own overrides folded in.
static func warden(arch: String) -> Dictionary:
	var all: Dictionary = rules()["wardens"]
	var w: Dictionary = all.get(arch, all.get(FALLBACK_WARDEN, {}))
	var folk_ids := Models.RACES.map(func(r): return String(r["id"]))
	var race := maxi(0, folk_ids.find(String(w.get("race", "human"))))
	var clamps := {}
	for k in rules()["sliders"]:
		clamps[k] = float(w.get("clamp", {}).get(k, rules()["sliders"][k]["clamp"]))
	var tints := {}
	for k in rules()["tint"]:
		var spec: Dictionary = (rules()["tint"][k] as Dictionary).duplicate()
		spec.merge(w.get("tint", {}).get(k, {}), true)
		tints[k] = spec
	return {"gender": String(w.get("gender", "male")), "race": race,
		"face": maxi(0, Models.LOOK_FACES.find(String(w.get("face", "")))),
		"hair": maxi(0, Models.hair_styles(race).find(String(w.get("hair", "")))),
		"detail": maxi(0, Models.LOOK_DETAILS.find(String(w.get("detail", "None")))),
		"skin": Color(String(w.get("skin", "f1c9a0"))), "hair_col": Color(String(w.get("hair_col", "2b2124"))),
		"eyes": Color(String(w.get("eyes", "4a3a2a"))), "outfit": Color(String(w.get("outfit", "9ee2a0"))),
		"clamp": clamps, "tint": tints}

## The model params for a Bearer of this Warden. The Warden gives the gender, folk, face, hair style
## and markings; each of the player's sliders moves its factor at most the Warden's clamp either
## way; each colour pick tints the Warden's colour within its tint range. warden_base comes from
## warden(), player_look from PlayerLook.clean().
static func apply(warden_base: Dictionary, player_look: Dictionary) -> Dictionary:
	var sliders: Dictionary = player_look["sliders"]
	var tints: Dictionary = warden_base["tint"]
	var out := {"own": false, "race": warden_base["race"], "gender": 0 if warden_base["gender"] == "female" else 1,
		"face": warden_base["face"], "hair": warden_base["hair"], "detail": warden_base["detail"],
		"glider": String(player_look.get("glider", "classic")),
		"skin_col": tint(warden_base["skin"], _pick_col(player_look, "skin"), tints["skin"]),
		"hair_col": tint(warden_base["hair_col"], _pick_col(player_look, "hair_col"), tints["hair"]),
		"eye_col": tint(warden_base["eyes"], _pick_col(player_look, "eyes"), tints["eyes"]),
		"outfit_col": tint(warden_base["outfit"], _pick_col(player_look, "outfit"), tints["outfit"])}
	for k in warden_base["clamp"]:
		out[k] = factor(float(sliders.get(k, PlayerLook.NEUTRAL)), float(warden_base["clamp"][k]))
	return out

## The player's own person (at home, no Mantle on): their own picks and colours, and the sliders at
## own_k times the Mantle's range.
static func own(player_look: Dictionary) -> Dictionary:
	var out := {"own": true, "glider": String(player_look.get("glider", "classic"))}
	for k in ["race", "gender", "face", "hair", "detail"]:
		out[k] = int(player_look[k])
	out["skin_col"] = _pick_col(player_look, "skin")
	out["hair_col"] = _pick_col(player_look, "hair_col")
	out["eye_col"] = _pick_col(player_look, "eyes")
	out["outfit_col"] = _pick_col(player_look, "outfit")
	var sliders: Dictionary = player_look["sliders"]
	for k in rules()["sliders"]:
		var reach := float(rules()["sliders"][k]["clamp"]) * float(rules()["own_k"])
		out[k] = factor(float(sliders.get(k, PlayerLook.NEUTRAL)), reach)
	return out

## What Models.hunter builds from: the look it was handed, as the player's own person (a look from
## at_home()) or as a Bearer of arch.
static func params(arch: String, appearance: Dictionary) -> Dictionary:
	var lk := PlayerLook.clean(appearance)
	if appearance.get("own", false):
		return own(lk)
	return apply(warden(arch), lk)

## The look, asked for as the player's own person (home, the farm's buildings, the town).
static func at_home(look: Dictionary) -> Dictionary:
	var out := look.duplicate(true)
	out["own"] = true
	return out

## A slider (0..1, 0.5 neutral) as a model factor: 1 -/+ reach at the ends.
static func factor(slider: float, reach: float) -> float:
	return 1.0 + (clampf(slider, 0.0, 1.0) - PlayerLook.NEUTRAL) * 2.0 * reach

## base pulled toward pick by spec "pull" in HSV, each channel moved at most spec "hue" / "sat" /
## "val". A grey pick has no hue to give, so its hue pull fades with its saturation.
static func tint(base: Color, pick: Color, spec: Dictionary) -> Color:
	var pull := float(spec.get("pull", 0.0))
	var hue_w := clampf(pick.s * 4.0, 0.0, 1.0)
	var dh := wrapf(pick.h - base.h, -0.5, 0.5) * pull * hue_w
	var ds := (pick.s - base.s) * pull
	var dv := (pick.v - base.v) * pull
	var h := base.h + clampf(dh, -float(spec.get("hue", 0.0)), float(spec.get("hue", 0.0)))
	var s := base.s + clampf(ds, -float(spec.get("sat", 0.0)), float(spec.get("sat", 0.0)))
	var v := base.v + clampf(dv, -float(spec.get("val", 0.0)), float(spec.get("val", 0.0)))
	return Color.from_hsv(fposmod(h, 1.0), clampf(s, 0.0, 1.0), clampf(v, 0.0, 1.0))

static func _pick_col(lk: Dictionary, key: String) -> Color:
	var list: Array = PlayerLook.pick_list(key) if key != "outfit" else Models.OUTFIT_COLS
	return list[clampi(int(lk.get(key, 0)), 0, list.size() - 1)]
