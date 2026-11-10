class_name GardenSfx
extends RefCounted
## The sounds of the four garden minigames (the Dash, Stump Shove, Seek, Spark Volley; docs/AUDIO.md).
## Every cue goes through cue(), which plays it at the Boki, quiet under the garden ambience, and counts it
## in `heard` so the minigame checks can assert each cue fires once per event.

const DB := -6.0                      # dB: the garden sounds sit under the Boki voices
const BEAT_S := 0.45                  # s between the three countdown beats
const SULK_DELAY := 0.7               # s after the win fanfare until the loser huffs
const SNIFF_NEAR := 12.0              # m from the scent where the sniffing loop is at its highest
const GRADE := {"great": "perfect", "good": "good", "miss": "miss"}
const SIZE := {"XS": "small", "S": "small", "M": "medium", "L": "large", "XL": "large"}

static var heard := {}                # cue name -> times played, for the checks

static func cue(sname: String, pos, pitch := 1.0) -> void:
	heard[sname] = int(heard.get(sname, 0)) + 1
	Sfx.play(sname, pos, DB, 0.04, pitch)

## Three beats as a game starts: tick, tick, go.
static func countdown(home, pos) -> void:
	cue("garden_count", pos)
	var beat := func(sname: String): cue(sname, pos)
	home.get_tree().create_timer(BEAT_S).timeout.connect(beat.bind("garden_count"))
	home.get_tree().create_timer(BEAT_S * 2.0).timeout.connect(beat.bind("garden_go"))

## The crowd of Boki answering a timing press: "great", "good" or "miss".
static func crowd(grade: String, pos) -> void:
	cue("garden_cheer_" + GRADE[grade], pos)

## The winner's fanfare and, a beat later, the loser's huff; each in its own size.
static func result(home, res: Dictionary) -> void:
	var win: Dictionary = home._kin_entry(res["win"])
	var lose: Dictionary = home._kin_entry(res["lose"])
	cue("garden_win_" + _size(res["win"]), win["pos"])
	var huff := func(): cue("garden_sulk_" + _size(res["lose"]), lose["pos"])
	home.get_tree().create_timer(SULK_DELAY).timeout.connect(huff)

static func _size(rec: Dictionary) -> String:
	return SIZE[Unique.size_tag(rec)]

## Seek: the sniffing loop at the hunter nearest the scent, higher as it closes in. Call every frame of the hunt.
static func sniff(pos, metres_off: float) -> void:
	if not Sfx.loop_on("seek_sniff"):
		heard["garden_sniff"] = int(heard.get("garden_sniff", 0)) + 1
	Sfx.loop_hold("seek_sniff", "garden_sniff", pos, DB, 0.9 + 0.3 * clampf(1.0 - metres_off / SNIFF_NEAR, 0.0, 1.0))

static func sniff_stop() -> void:
	Sfx.loop_stop("seek_sniff")
