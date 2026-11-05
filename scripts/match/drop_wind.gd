class_name DropWind
extends Node
## The drop's wind: two looped layers of our own synthesis (tools/gen_drop_sfx.py), a
## low body and a high tearing edge. It builds from a breath at the jump with how long and how fast you
## have been falling, drops away the instant the glider catches, and is gone when you land.

static var BUILD_S: float = DropData.rules["look"]["wind_build_s"]
const SILENT_DB := -44.0
const LOW_DB := Vector2(-30.0, -13.0)      # the body: a breath .. full
const HIGH_DB := Vector2(-40.0, -15.0)     # the edge: a breath .. a full dive
const GLIDE_LOW_DB := -27.0                # under the open glider: a breeze
const GLIDE_HIGH_DB := -38.0
const RATE := 5.0                          # 1/s, the fade toward the wanted level
const CATCH_RATE := 22.0                   # 1/s, the fade at the snap: it has to feel cut

var low: AudioStreamPlayer
var high: AudioStreamPlayer
var built := 0.0                   # 0..1 how far the wind has built this fall
var low_db := SILENT_DB            # (read by the checks)
var high_db := SILENT_DB

func _ready() -> void:
	low = _layer("res://audio/drop_wind_low.wav")
	high = _layer("res://audio/drop_wind_high.wav")

func _layer(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	var st := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = int(st.get_length() * st.mix_rate)
	p.stream = st
	p.volume_db = SILENT_DB
	add_child(p)
	return p

## Per frame. stage: 0 not in the air, 1 falling (speed 0..1), 2 under the glider.
func tick(stage: int, speed: float, delta: float) -> void:
	if stage == 1:
		built = minf(1.0, built + delta / BUILD_S)
	var k := built * built * (3.0 - 2.0 * built) * lerpf(0.72, 1.0, speed)
	var want_low := SILENT_DB
	var want_high := SILENT_DB
	if stage == 1:
		want_low = lerpf(LOW_DB.x, LOW_DB.y, k)
		want_high = lerpf(HIGH_DB.x, HIGH_DB.y, k * speed)
	elif stage == 2:
		want_low = GLIDE_LOW_DB
		want_high = GLIDE_HIGH_DB
	var rate := RATE if stage == 1 else CATCH_RATE
	var e := 1.0 - exp(-rate * delta)
	low_db = lerpf(low_db, want_low, e)
	high_db = lerpf(high_db, want_high, e)
	if stage == 0:
		built = 0.0
	_apply(low, low_db, lerpf(0.82, 1.08, k))
	_apply(high, high_db, lerpf(0.8, 1.15, k * speed))

func _apply(p: AudioStreamPlayer, db: float, pitch: float) -> void:
	var on := db > SILENT_DB + 1.0
	if on != p.playing:
		if on:
			p.play(randf() * 3.0)
		else:
			p.stop()
	p.volume_db = db
	p.pitch_scale = pitch
