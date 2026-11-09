extends "res://tools/bjorn_launch_check.gd"
## Animation timing of Mossy (bulwark, source Oath), run from --bulwark-combo-check: each move's wind-up, hit and
## recovery are measured in game (s from the input, 60 Hz) and held to the hero sheet's footage frames
## (briefs/hero-ref/bjorn.md, 5 fps: one frame = 0.2 s) and the beats of its clips (tools/art1/breaker_anims.py).
## The before and after of each is the table in docs/heroes/bulwark.md. Prints AKTIME lines.

const FRAME := 0.2                  # s: one footage frame, the sheet's resolution
const ONE_FRAME_FADE := 0.05        # s: the most a one-frame pose may blend in over (the tree's usual 0.1 s smears it)
const ONE_FRAME_MOVES := ["bul_throw", "bul_smash", "bul_whirl", "bul_ult_slam"]

func anim_time() -> void:
	await _throw_times()
	await _swing_times()
	await _shift_times()
	await _mend_times()
	_clip_blends()

## The time of the n-th key of `move` in the footage-timed keys (KMovesPinBjorn).
func _key_t(move: String, n: int) -> float:
	return float(((KMovesPinBjorn.MOVES[move] as Dictionary)["keys"][n] as Array)[0])

## Steps until `done` is true or `limit` s pass; the s it took (-1 when it never did).
func _until(m: Match, done_when: Callable, limit := 1.0) -> float:
	var t := 0.0
	while t < limit:
		m.step(DT)
		t += DT
		if done_when.call():
			return t
	return -1.0

func _held(K: BulwarkKit, st: String) -> bool:
	return String(K.mace.get("st", "")) == st

## Sheet 0033-0036: cocked low for one frame, released overhand, planted at the cursor; recalled by a second tap.
func _throw_times() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	_ready_swing(m, P, T, home)
	K.mace = {}
	T.teleport(home + Vector3(6.0, 0, 0))
	fresh(T)
	press_at(P, T.pos)
	m.step(DT)
	P.inp["fire"] = false
	var left := _until(m, func(): return _held(K, "fly")) + DT
	var anim := K.anim_id
	var struck := _until(m, func(): return dmg(T) > 0.0)
	print("AKTIME throw: %s, hammer leaves the hand %.2f s after the press, hits %.2f s later" % [anim, left, struck])
	ok("bjorn time throw: the hammer leaves as the arm comes through (release key %.2f s)" % _key_t("bul_throw", 2),
		absf(left - _key_t("bul_throw", 2)) <= 2.0 * DT and anim == "bul_throw", "left at %.3f %s" % [left, anim])
	ok("bjorn time throw: it hits the dummy within a frame of leaving (sheet: out in 0.2-0.4 s)",
		struck > 0.0 and struck <= FRAME, "hit %.2f s after leaving" % struck)
	step(m, 0.6)
	P.fire_cd = 0.0
	press_at(P, T.pos)
	m.step(DT)
	P.inp["fire"] = false
	var caught := _until(m, func(): return K.mace.is_empty())
	print("AKTIME recall: %s, caught %.2f s after the press" % [K.anim_id, caught])
	ok("bjorn time recall: the catch lands inside the recall clip (0.48 s)", caught > 0.0 and caught <= 0.484,
		"caught %.2f" % caught)
	await done(m)

## Sheet 0146-0149: the sweep in one frame, the impact the frame after, about 0.4 s of recovery.
func _swing_times() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	_ready_swing(m, P, T, home)
	T.teleport(home + Vector3(1.8, 0, 0))
	fresh(T)
	var tap := float(K.lmb_def()["tap"])
	var wound := _until(m, func(): return _wind_up(P, T, K))
	step(m, 0.4, press_at.bind(P, T.pos))
	P.inp["fire"] = false
	var landed := _until(m, func(): return dmg(T) > 0.0, 0.3)
	var recover := P.fire_cd + landed
	print("AKTIME swing: wind-up pose %.2f s after the press (tap %.2f), blow %.2f s after the release, free %.2f s" %
		[wound, tap, landed, recover])
	ok("bjorn time swing: the wind-up pose starts when the press turns into a hold (%.2f s)" % tap,
		absf(wound - tap) <= 3.0 * DT, "at %.3f" % wound)
	ok("bjorn time swing: the blow lands within a frame of the release, the clip's impact pose %.2f s in" %
			_key_t("bul_smash", 1),
		landed > 0.0 and landed <= FRAME and K.anim_id == "bul_smash", "blow %.2f anim %s" % [landed, K.anim_id])
	ok("bjorn time swing: the next action comes ~0.6 s on (sweep + ~0.4 s of recovery)",
		recover >= 0.5 and recover <= 0.7, "free in %.2f" % recover)
	await done(m)

func _wind_up(P: Hunter, T: Hunter, K: BulwarkKit) -> bool:
	press_at(P, T.pos)
	return K.anim_id == "bul_smash_wind"

## Sheet 0369-0372: a dash of 0.15-0.2 s, ONE spin of 0.15-0.2 s on arrival, ~0.4 s of recovery.
func _shift_times() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	_ready_swing(m, P, T, home)
	T.teleport(home + Vector3(3.2, 0, 0))
	fresh(T)
	var spins0 := K.spins
	P.inp["dash"] = true
	press_at(P, T.pos)
	m.step(DT)
	P.inp["dash"] = false
	var spun := _until(m, func(): return K.spins > spins0) + DT
	var spin_len := _key_t("bul_whirl", 3) - _key_t("bul_whirl", 1)
	var recover := _key_t("bul_whirl", 5) - _key_t("bul_whirl", 3)
	step(m, 0.1)
	print("AKTIME 360 Smash: spin hit %.2f s after the press, spin %.2f s, recovery %.2f s" % [spun, spin_len, recover])
	ok("bjorn time 360 Smash: one spin hit as the dash arrives, inside the clip's spin (%.2f-%.2f s)" %
			[_key_t("bul_whirl", 1), _key_t("bul_whirl", 3)],
		K.spins == spins0 + 1 and spun >= _key_t("bul_whirl", 1) and spun <= _key_t("bul_whirl", 3),
		"spin at %.3f" % spun)
	ok("bjorn time 360 Smash: the spin is 0.15-0.2 s, the recovery ~0.4 s (sheet)",
		spin_len >= 0.15 and spin_len <= 0.2 and absf(recover - 0.4) <= 0.05,
		"spin %.2f recovery %.2f" % [spin_len, recover])
	await done(m)

## Sheet 0412-0421: the hammer comes down, the column shows about a second on.
func _mend_times() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	_ready_swing(m, P, T, home)
	K.cd["e"] = 0.0
	K.cast_e()
	var anim := K.anim_id
	var opened := _until(m, func(): return not K.mend.is_empty() and float(K.mend["zone"]) >= 0.0, 2.0) + DT
	var delay := float(K.e_def()["delay"])
	print("AKTIME Mending Ground: %s, the zone opens %.2f s after the cast" % [anim, opened])
	ok("bjorn time Mending Ground: the hammer is down (%.2f s) before the column lands (%.1f s)" %
			[_key_t("bul_mend", 2), delay],
		anim == "bul_mend" and absf(opened - delay) <= 3.0 * DT and _key_t("bul_mend", 2) < opened,
		"zone at %.3f anim %s" % [opened, anim])
	await done(m)

## One-frame poses must not be smeared by the clip tree's 0.1 s crossfade.
func _clip_blends() -> void:
	var kmoves: Dictionary = WardenClips.data("breaker")["kmoves"]
	for mv in ONE_FRAME_MOVES:
		var fade := float((kmoves[mv] as Dictionary).get("fade", WardenClips.FADE))
		ok("bjorn time %s: the clip blends in within %.2f s" % [mv, ONE_FRAME_FADE], fade <= ONE_FRAME_FADE,
			"fade %.2f" % fade)
