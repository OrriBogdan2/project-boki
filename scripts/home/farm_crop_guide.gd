class_name FarmCropGuide
extends RefCounted
## The tutorial's first crop: it ripens fast (options.crop_stage_s per growth stage) and the patch
## shows a growth bar with a countdown, so waiting is never a dead end.

## Seconds one growth stage takes: the tutorial's first crop is quick, everything else keeps `normal`.
static func stage_time(normal: float) -> float:
	if FarmTutorial.active() and not FarmTutorial.did("crop"):
		return minf(normal, float(FarmTutorial.option("crop_stage_s")))
	return normal

## The first growing, watered plot: {plot, left (s), frac (0..1)}; {} when nothing is growing.
static func growing() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var i := -1
	for d in Save.d["plots"]:
		i += 1
		if String(d["crop"]) == "":
			continue
		var grow := int(Data.CROPS[String(d["crop"])]["grow"])
		var stage := int(d["stage"])
		if stage >= grow:
			continue
		var per := stage_time(Data.WATER_TIME)
		var wt := float(d.get("wt", 0.0))
		var into := clampf(now - wt, 0.0, per) if wt > 0.0 else 0.0
		var left := float(grow - stage) * per - into
		return {"plot": i, "left": left, "frac": 1.0 - left / (float(grow) * per)}
	return {}

## "▰▰▰▱▱ 12s" for the patch label and the hint.
static func bar_text(g: Dictionary) -> String:
	var n := int(round(clampf(float(g["frac"]), 0.0, 1.0) * 6.0))
	return "%s%s %ds" % ["▰".repeat(n), "▱".repeat(6 - n), int(ceil(float(g["left"])))]
