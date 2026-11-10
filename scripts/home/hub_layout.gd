class_name HubLayout
extends RefCounted
## The garden's hub (briefs/design/GARDEN.md 10.1, docs/decisions/0022-garden-zones.md): a small fixed
## island you arrive on, with the Waystone in the middle (HubWaystone) and the expedition portal. It
## is shown through Home's visit path: island() is the snapshot Home reads instead of your save, so
## nothing on it is saved and no farm system runs there. Nobody lives in the hub: only your partner
## comes along. (The house, the nest corner, the stall and the Burrow door move here in a later step.)

const SEED := 7310        # the hub's island shape: the same for everyone
const SCALE := 0.55       # fs_shape scale: the smallest farm-start island, about 20 m across

## The snapshot Home shows for the hub (the keys a visited island has, see Social.clean_island).
static func island() -> Dictionary:
	var L := HomeLayout.fresh()
	L["seed"] = SEED
	L["fs"] = 1
	L["sk"] = SCALE
	var ak := Save.active_kin()
	return {"hub": true, "name": "", "layout": L, "plots": [], "roster": [ak] if not ak.is_empty() else [],
		"active": String(Save.d.get("active", ""))}

static func is_hub(d: Dictionary) -> bool:
	return bool(d.get("hub", false))
