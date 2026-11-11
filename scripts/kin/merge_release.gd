class_name MergeRelease
extends RefCounted
## Ending a merge on purpose: the second press of the merge key fires the form's ultimate (MergeKit), and when
## the form lets go the hunter gets a short afterglow (faster, with a small shield) while the Boki lands beside
## you pumped for a short rest (Kin.land_pumped). A merge that just times out has none of this.
## Numbers: content/rules/merge_forms.json `release_rest_s` and `afterglow`.

const SPARK_EVERY := 0.4          # s: between sparkles on a hunter with the afterglow

static func rules() -> Dictionary:
	return MergeForm.data().get("afterglow", {})

## Seconds the Boki rests after a release.
static func rest_s() -> float:
	return float(MergeForm.data().get("release_rest_s", 6.0))

## The Boki's rest after a merge that ran out of time (no release): longer than after a release.
static func timeout_rest_s() -> float:
	return float(MergeForm.data().get("timeout_rest_s", 10.0))

## The hunter's side of a release: the speed and the shield, with a flash and a sound.
static func afterglow(h: Hunter) -> void:
	var r := rules()
	var secs := float(r.get("secs", 3.0))
	h.add_buff("move_speed", float(r.get("move_speed", 0.15)), secs)
	h.shield = maxf(h.shield, h.max_hp * float(r.get("shield_frac", 0.08)))
	h.shield_t = maxf(h.shield_t, secs)
	h.set_meta("afterglow_t", secs)
	var col := Color("ffd84a")
	h.m.fx.ring(h.pos, 2.4, col, 0.45)
	h.m.fx.burst(h.pos + Vector3(0, 1.1, 0), col, 20, 4.0)
	if h.is_local():
		h.m.fx.word(h.pos + Vector3(0, 2.6, 0), "AFTERGLOW", col, true)

## Every step: counts the afterglow down and sparkles while it lasts.
static func tick(h: Hunter, dt: float) -> void:
	var t := float(h.get_meta("afterglow_t", 0.0))
	if t <= 0.0:
		return
	var left := maxf(0.0, t - dt)
	h.set_meta("afterglow_t", left)
	if fmod(t, SPARK_EVERY) < fmod(left + dt, SPARK_EVERY) - 0.0001 or left == 0.0:
		h.m.fx.burst(h.pos + Vector3(0, 0.9, 0), Color("ffd84a"), 4, 2.0)
