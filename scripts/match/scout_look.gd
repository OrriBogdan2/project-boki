class_name ScoutLook
extends RefCounted
## The held far look (Settings "Look ahead", C by default). While it is held the camera eases out toward the
## cursor as far as the screen has room for (CamRig.scout_to, scout_k) and you see SIGHT_MUL further inside a
## narrow cone along your aim (Match.sees; the lit wedge in shaders/vis.gdshaderinc). Walking speed is unchanged.
## Release eases the view back. Numbers: content/rules/camera.json "scout" (CamRig.SCOUT).

const BIT := 1 << 25          # hunter flags (Match._flags): holding the far look, so teammates share its sight online

## The 1/s rate that covers 90% of the way in `secs` (CamRig eases scout_k with it).
static func rate(secs: float) -> float:
	return log(10.0) / maxf(0.01, secs)

## The cosine of the cone's half-angle: a direction whose dot with the aim is at least this is inside it.
static func cone_cos() -> float:
	return cos(deg_to_rad(float(CamRig.SCOUT["cone_deg"]) * 0.5))

## How much further `h` sees toward the flat unit direction `to`: sight_mul inside the cone while held, else 1.
static func sight_mul(h: Hunter, to: Vector2) -> float:
	if h.scout and to.dot(h.aim_dir()) >= cone_cos():
		return float(CamRig.SCOUT["sight_mul"])
	return 1.0

## vis_scout for the sight shader: x the extra share of range in the cone (eased with the camera), y cone_cos.
static func shader_arg(k: float) -> Vector2:
	return Vector2((float(CamRig.SCOUT["sight_mul"]) - 1.0) * k, cone_cos())
