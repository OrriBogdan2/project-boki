class_name TellCue
extends RefCounted
## You hear where a rival's ability will land before it lands (DECISIONS 11-11: clarity first). A ground telegraph a
## rival Hunter shows everyone plays one short wind-up, tell_foe, at its centre when it starts: ArchKit.tele_circle
## and tele_lane, and AimKit areas with "all" (AimDraw.put, the first step an entry shows). Bigger areas play it
## lower and louder. Your own and your team's telegraphs play nothing, and ultimates are left to UltCue. It goes
## through Sfx.play, so its MIN_GAP, the stacking cap and the voice pool apply as to any sound.

const AREA_SMALL := 3.0     # m²: a telegraph this size or smaller plays highest and quietest (a 1 m circle)
const AREA_BIG := 40.0      # m²: this size or bigger plays lowest and loudest (a 3.6 m circle, a 13 x 3 m lane)
const DB_SMALL := -10.0     # dB at AREA_SMALL
const DB_BIG := -3.0        # dB at AREA_BIG: under the ult cues (-2), so an ultimate still reads bigger
const PITCH_SMALL := 1.15
const PITCH_BIG := 0.8
const SPAN_W := 1.0         # m: the width a span (a wall or a rift line) counts with
## AimKit kinds that mark where something lands; lines, Vs, dots and stars are aim marks, not areas.
const AREAS := ["circle", "lane", "cone", "arc_wall", "span", "swap"]

## A rival's telegraph covering `area` m² starts at `at`.
static func start(m: Node, h: Hunter, at: Vector3, area: float) -> void:
	if not rival(m, h):
		return
	var k := clampf(inverse_lerp(AREA_SMALL, AREA_BIG, area), 0.0, 1.0)
	m.sfx("tell_foe", at, lerpf(DB_SMALL, DB_BIG, k), lerpf(PITCH_SMALL, PITCH_BIG, k))

static func rival(m: Node, h: Hunter) -> bool:
	var me = m.get("player")
	return me != null and h != null and h.team != me.team

## AimDraw.put, the first step entry `e` under `id` shows. Ultimate telegraphs use ids "x..." and "ult..."
## (docs/AIMKIT.md), so those are skipped by id.
static func aim(m: Node, h: Hunter, id: String, e: Dictionary) -> void:
	if not e["all"] or id.begins_with("x") or id.begins_with("ult") or not (String(e["kind"]) in AREAS):
		return
	if not rival(m, h):
		return
	var y := float(e["y"])
	match String(e["kind"]):
		"circle":
			start(m, h, _v3(e["at"], y), PI * float(e["r"]) * float(e["r"]))
		"swap":
			start(m, h, _v3(e["b"], y), PI * float(e["r"]) * float(e["r"]))
		"span":
			start(m, h, _v3(e["at"], y), float(e["len"]) * SPAN_W)
		"lane":
			var len_l := float(e["len"])
			var mid: Vector2 = e["from"] + (e["dir"] as Vector2) * len_l * 0.5
			start(m, h, _v3(mid, y), len_l * float(e["width"]))
		"cone":
			var len_c := float(e["len"])
			var mid_c: Vector2 = e["from"] + (e["dir"] as Vector2) * len_c * 0.5
			start(m, h, _v3(mid_c, y), deg_to_rad(float(e["deg"])) * 0.5 * len_c * len_c)
		"arc_wall":
			var rad := float(e["radius"])
			var mid_w: Vector2 = e["center"] + (e["dir"] as Vector2) * rad
			start(m, h, _v3(mid_w, y), rad * deg_to_rad(float(e["deg"])) * float(e["thick"]))

static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
