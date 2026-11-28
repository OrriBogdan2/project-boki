class_name HunterFeel
extends RefCounted
## The match hunter's movement and feel numbers, in the one tuning file the owner asked for on 11-08:
## the "feel" section of content/rules/tuning.json, read once at load. Its "notes" give each key's unit and source.

static var _t: Dictionary = _load()
static var spirit_climb: float = _t["spirit_climb"]
static var ground_accel: float = _t["ground_accel"]
static var air_decel: float = _t["air_decel"]
static var air_overspeed: float = _t["air_overspeed"]
static var glide_grav: float = _t["glide_grav"]
static var glide_engage: float = _t["glide_engage"]
## The abyss lift [wiki: "a rapid upward impulse to ground level, then a rapid deceleration"], scaled
## by how deep you are; in the owner's words, "pull you up faster based on how low in the abyss you are": a gentle
## lift just under the lip, a hard surge from deep down. See Hunter.abyss_lift_vy.
static var abyss_lift: float = _t["abyss_lift"]
static var abyss_lift_per_m: float = _t["abyss_lift_per_m"]
static var abyss_lift_max: float = _t["abyss_lift_max"]
static var abyss_lift_max_per_m: float = _t["abyss_lift_max_per_m"]
static var abyss_lift_cap: float = _t["abyss_lift_cap"]
static var abyss_brake_dist: float = _t["abyss_brake_dist"]
static var abyss_brake: float = _t["abyss_brake"]
static var abyss_lip_vy: float = _t["abyss_lip_vy"]
static var abyss_brake_gain: float = _t["abyss_brake_gain"]
static var mantle_reach: float = _t["mantle_reach"]
static var tall_climb_extra: float = _t["tall_climb_extra"]
static var mantle_reach_abyss: float = _t["mantle_reach_abyss"]
static var wall_catch_reach: float = _t["wall_catch_reach"]
static var abyss_glide_room: float = _t["abyss_glide_room"]
static var ledge_reach: float = _t["ledge_reach"]
static var float_speed: float = _t["float_speed"]
static var glide_fall: float = _t["glide_fall"]
## The opening drop, battle-royale style: a fast skydive you steer freely, then the glider opens by
## itself near the ground (or earlier on jump) for a slower, floatier last stretch.
static var dive_fall: float = _t["dive_fall"]
static var dive_speed: float = _t["dive_speed"]
static var drop_fall: float = _t["drop_fall"]
static var drop_speed: float = _t["drop_speed"]
static var dive_vy_rate: float = _t["dive_vy_rate"]
static var drop_vy_rate: float = _t["drop_vy_rate"]
static var deploy_pop: float = _t["deploy_pop"]
static var deploy_h: float = _t["deploy_h"]
static var feather_keep: float = _t["feather_keep"]
static var feather_min: float = _t["feather_min"]
static var feather_tap: float = _t["feather_tap"]
static var lrise_speed: float = _t["lrise_speed"]
static var lrise_min: float = _t["lrise_min"]
static var lrise_pop: float = _t["lrise_pop"]
static var lrise_off: float = _t["lrise_off"]
static var lrise_window: float = _t["lrise_window"]
static var fling_early_height: float = _t["fling_early_height"]
static var abyss_extra: float = _t["abyss_extra"]

static func _load() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(Loco.PATH))
	return (d as Dictionary)["feel"] if d is Dictionary else {}
