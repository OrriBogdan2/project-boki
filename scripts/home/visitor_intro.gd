class_name VisitorIntro
extends RefCounted
## The first wild visitor on a save (GardenVisitor): your partner runs to it and looks back at you (the base
## tutorial's lead, BaseTutLead: "your Boki physically leads"), and one tip says who it is and what to do.
## Once per save (Save.d["tutorial"]["visitor_intro"]), skipped while a game runs or a tutorial step is up.
## The lead lasts until you walk up to the visitor or lead_s runs out (Save.d["visitor"]["lead"] = end, unix s).
## Tuning and the tip text: content/rules/garden_visitor.json "intro".

const TIP_COL := Color("f3e6c8")      # the hub hints' colour

static func rules() -> Dictionary:
	return GardenVisitor.rules()["intro"]

## `r` has just arrived in `h`'s zone: the first one on this save starts the lead and shows its tip.
static func start(h, r: Dictionary, now: float) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	if seen.get("visitor_intro", false) or FarmTutorial.current() != "" or not Settings.get_v("tips") or Record.clean():
		return
	if h.kins.any(func(k): return k.get("busy", false)):
		return      # a game is running
	seen["visitor_intro"] = true
	Save.d["visitor"]["lead"] = now + float(rules()["lead_s"])
	var text := String(rules()["text"]).replace("{interact}", Settings.key_cap("interact"))
	text = text.replace("{name}", String(Data.KIN[String(r["species"])]["name"]))
	text = text.replace("{zone}", String(GardenZones.info(String(Save.d["visitor"]["zone"])).get("name", "")))
	text = text.replace("{food}", Care.food_name(String(r["likes"]["food"])))
	MsgLane.of(h.root_ui).push(text, TIP_COL, MsgLane.NORMAL, float(rules()["tip_s"]))

## Where your partner `k` leads now: the visitor's spot, or INF when no lead is on (BaseTutLead.target).
static func lead_at(h, k: Dictionary) -> Vector3:
	var st: Dictionary = Save.d.get("visitor", {})
	if not st.has("lead") or k["rec"] != Save.active_kin() or FarmTutorial.current() != "":
		return Vector3.INF
	var wild: Dictionary = h._kin_entry(st["rec"])
	if not wild.is_empty():
		var at: Vector3 = wild["pos"]
		var away := Vector2(h.ppos.x - at.x, h.ppos.z - at.z).length() >= float(rules()["near_m"])
		if away and Time.get_unix_time_from_system() <= float(st["lead"]):
			return at
	st.erase("lead")
	return Vector3.INF
