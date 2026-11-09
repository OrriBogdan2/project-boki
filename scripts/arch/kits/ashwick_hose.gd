class_name AshwickHose
extends RefCounted
## Cinder's Torch Lance stream as a stream of fire, not a rigid cone (sheet gap 1): puffs of fire leave her hand
## every EMIT_DT along the aim and keep their own velocity, so sweeping the aim bends the stream behind
## it. Each puff widens from the narrow palm (w0) to a billowing end (w1) over its life (range / speed).
## Walls stop a puff where it meets them. The fire only hurts while the key is held; letting go snuffs
## the stream within SNUFF seconds (the source's fire stops at once). Simulated on the match step.

const EMIT_DT := 0.033          # s between puffs (about 30 a second)
const SNUFF := 0.08             # s the stream lingers after the key is let go
const INHERIT := 0.5            # share of Cinder's own velocity a puff carries
const DRAWN_FADE := 0.35        # share of a puff's life over which its drawn start joins the rules' stream

var puffs: Array = []           # {p, v, age, life, fy, seed}
var acc := 0.0
var emitted := 0                # (tests)

## Emits puffs for `dt` of firing from `nozzle` along `dir` (flat), then moves every puff.
func emit(nozzle: Vector3, dir: Vector2, carry: Vector3, feet_y: float, speed: float, reach: float, dt: float,
		drawn := Vector3.ZERO) -> void:
	acc += dt
	while acc >= EMIT_DT:
		acc -= EMIT_DT
		var v := Vector3(dir.x, 0.0, dir.y) * speed + Vector3(carry.x, 0.0, carry.z) * INHERIT
		var life := reach / speed
		puffs.append({"p": nozzle, "v": v, "age": acc, "life": life, "life0": life, "fy": feet_y, "seed": randf(),
			"drawn": drawn})
		emitted += 1

func snuff() -> void:
	acc = 0.0
	for pf in puffs:
		pf["life"] = minf(float(pf["life"]), float(pf["age"]) + SNUFF)
		pf["dead"] = true

func clear() -> void:
	puffs = []
	acc = 0.0

## Moves the puffs and stops them at walls (world.occupy at their feet height). Old ones go.
func step(world, dt: float) -> void:
	var keep: Array = []
	for pf in puffs:
		pf["age"] = float(pf["age"]) + dt
		if float(pf["age"]) >= float(pf["life"]):
			continue
		if not pf.get("wall", false):
			var np: Vector3 = (pf["p"] as Vector3) + (pf["v"] as Vector3) * dt
			if world.occupy(np.x, np.z, 0.12, float(pf["fy"]), false) != 0.0:
				pf["wall"] = true            # flattened on the wall: it billows there and dies sooner
				pf["life"] = minf(float(pf["life"]), float(pf["age"]) + 0.12)
			else:
				pf["p"] = np
		keep.append(pf)
	puffs = keep

## The puff's radius now: narrow at the nozzle, billowing at the far end.
static func radius(pf: Dictionary, w0: float, w1: float) -> float:
	var k := clampf(float(pf["age"]) / maxf(0.01, float(pf.get("life0", pf["life"]))), 0.0, 1.0)
	return lerpf(w0, w1, k) * 0.5

## Is this body inside the live stream (any puff overlapping it)? Returns the touching puff or {}.
func touching(f: Ent, w0: float, w1: float) -> Dictionary:
	for pf in puffs:
		if pf.get("dead", false):
			continue
		var p: Vector3 = pf["p"]
		if absf(f.pos.y + 0.9 - p.y) > 1.8:
			continue
		if Vector2(f.pos.x - p.x, f.pos.z - p.z).length() < radius(pf, w0, w1) + f.r:
			return pf
	return {}

## The look: [{p, age (0..1), r, seed}] for LDFx.flame.
func parts(w0: float, w1: float) -> Array:
	var out: Array = []
	for pf in puffs:
		var k := clampf(float(pf["age"]) / maxf(0.01, float(pf["life"])), 0.0, 1.0)
		# (drawn: the visible tip off the rules' nozzle, the camera's lean of the model; it fades down the stream)
		var off: Vector3 = pf.get("drawn", Vector3.ZERO) * (1.0 - smoothstep(0.0, DRAWN_FADE, k))
		var at: Vector3 = (pf["p"] as Vector3) + off
		out.append({"p": at, "age": k, "r": radius(pf, w0, w1) * 1.5 + 0.1, "seed": pf["seed"]})
	return out

## How far the farthest live puff is from `from` (tests: the stream's reach).
func reach_from(from: Vector3) -> float:
	var b := 0.0
	for pf in puffs:
		b = maxf(b, Vector2((pf["p"] as Vector3).x - from.x, (pf["p"] as Vector3).z - from.z).length())
	return b
