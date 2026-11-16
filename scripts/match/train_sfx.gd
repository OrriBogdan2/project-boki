class_name TrainSfx
extends RefCounted
## The sky train's halt and ride sounds (set content/sfx/train.json, made by tools/gen_sfx_train.py).
## At every halt: the brakes as it eases in, the bell as it stands, the doors sliding open, the
## whistle SkyTrain.DEPART_LEAD seconds before it pulls out (time to run for it), the doors shutting
## just before it goes. While it moves: a quiet ride loop for you if you're riding it, otherwise a
## rumble at the car nearest you, heard within its reach only. Everything follows the train's match-
## clock schedule, so every game hears the same cues with no network traffic. The horn (something on
## the rails ahead) stays in SkyTrain.

const BRAKE_LEAD := 1.6        # s before it stands still that the brakes go on (the brake sound is 1.9 s)
const DOOR_OPEN_AFTER := 0.5   # s after it stops that the doors slide open
const DOOR_CLOSE_LEAD := 1.2   # s before it pulls out that the doors slide shut
const RIDE_GRACE := 0.5        # s off the deck (a jump) that still counts as riding, so the loop doesn't flicker
const RIDE_DB := -8.0          # dB: the ride loop sits under everything else, it lasts the whole ride
const RUMBLE_DB := -4.0        # dB at full speed; the distance falloff to its reach comes on top
const QUIET_K := 0.2           # the loops' level at a crawl, as a share of full speed's
const RIDE_KEY := "train_ride"
const RUMBLE_KEY := "train_rumble"

enum Stop { PULLED_IN, DOORS_OPEN, WHISTLED, DOORS_SHUT }

var train: SkyTrain = null
var stage := Stop.DOORS_OPEN   # the match starts with the train standing at its first halt
var stopped_at := 0.0          # match time it last stood still
var braking := false
var moved := false             # moving last tick
var rumble_reach := 0.0        # m: the rumble's reach from the set; past it the loop is stopped
var last := {}                 # cue -> match time it last played (--train-check reads it)

func setup(sky_train: SkyTrain) -> void:
	train = sky_train
	rumble_reach = float(Sfx.sound_reach.get(RUMBLE_KEY, 40.0))

func tick(moving: bool) -> void:
	var now := float(train.m.time)
	var head: Vector3 = (train.cur[0] as Transform3D).origin
	var mid: Vector3 = (head + (train.cur[train.cars_n - 1] as Transform3D).origin) * 0.5
	if moving:
		if not braking and train.speed_at(now + BRAKE_LEAD) < TrainHalts.STOPPED_V:
			braking = true
			_cue("train_brake", mid)
	else:
		if moved:
			stage = Stop.PULLED_IN
			stopped_at = now
			braking = false
			_cue("train_bell", mid)
		if stage == Stop.PULLED_IN and now - stopped_at >= DOOR_OPEN_AFTER:
			stage = Stop.DOORS_OPEN
			_cue("train_door_open", mid)
		if stage == Stop.DOORS_OPEN and train.depart_warned:
			stage = Stop.WHISTLED
			_cue("train_whistle", mid)
		if stage == Stop.WHISTLED and train.speed_at(now + DOOR_CLOSE_LEAD) > TrainHalts.STOPPED_V:
			stage = Stop.DOORS_SHUT
			_cue("train_door_close", mid)
	moved = moving
	_loops(moving, now)

func _cue(sname: String, at: Vector3) -> void:
	train.m.sfx(sname, at)
	last[sname] = float(train.m.time)

## Riding (you stood on a car within RIDE_GRACE): the ride loop, unpositioned. Otherwise, the train
## moving within the rumble's reach: the rumble at the nearest car. Both pitch and swell with speed.
func _loops(moving: bool, now: float) -> void:
	var pl = train.m.player
	var riding: bool = moving and pl != null and now - float(train.ride_t.get(pl, -INF)) < RIDE_GRACE
	var heat := clampf(train.head_v / train.speed, 0.0, 1.0)
	var lift := linear_to_db(maxf(heat, QUIET_K))
	var pitch := 0.85 + 0.3 * heat
	if riding:
		Sfx.loop_hold(RIDE_KEY, RIDE_KEY, null, RIDE_DB + lift, pitch)
	else:
		Sfx.loop_stop(RIDE_KEY)
	var near := Vector3.INF
	if moving and not riding:
		for k in train.cars_n:
			var p: Vector3 = (train.cur[k] as Transform3D).origin
			if _flat(p) < _flat(near):
				near = p
	if near != Vector3.INF and _flat(near) < rumble_reach:
		Sfx.loop_hold(RUMBLE_KEY, RUMBLE_KEY, near, RUMBLE_DB + lift, pitch)
	else:
		Sfx.loop_stop(RUMBLE_KEY)

## m from the listener on the ground plane (how Sfx measures its falloff).
func _flat(p: Vector3) -> float:
	return Vector2(p.x - Sfx.listener.x, p.z - Sfx.listener.z).length()
