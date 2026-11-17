class_name Clutter
extends RefCounted
## How much purely visual ground clutter the world builder keeps, per quality preset. "small" is short
## grass, flowers, pebbles and the knee-high undergrowth and patches; "bush" is the tall grass you hide
## in, which is cover, so it keeps more (a thinner clump still reads as a clump). Trees, boulders,
## pillars and cliff rocks are never thinned: they are the map's shapes and cover.
## Thinning happens after placement, so the map and everything else drawn from its random seed stay
## the same; only some batch instances are dropped, with a fixed pattern per map.

## Share of instances kept (0-1), by preset. Ultra keeps everything; High and Medium keep enough
## that ground reads as lush at match zoom; Low and Very Low keep a sprinkle.
const KEEP := {
	"very_low": {"small": 0.08, "bush": 0.5},
	"low": {"small": 0.2, "bush": 0.6},
	"medium": {"small": 0.4, "bush": 0.8},
	"high": {"small": 0.6, "bush": 1.0},
	"ultra": {"small": 1.0, "bush": 1.0},
}

## The share of a scatter class ("small", "bush" or "big") kept at the current preset.
static func keep(cls: String) -> float:
	var row: Dictionary = KEEP.get(Settings.quality(), KEEP["low"])
	return float(row.get(cls, 1.0))

## The items (any array) with about `share` of them kept, by a fixed pattern from seed_i.
static func thin(items: Array, share: float, seed_i: int) -> Array:
	if share >= 0.999:
		return items
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	return items.filter(func(_it): return r.randf() < share)
