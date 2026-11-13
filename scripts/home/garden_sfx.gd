class_name GardenSfx
extends RefCounted
## The sounds of the garden minigames (the Dash, Stump Shove, Seek, Spark Volley, Tumble, Echo Steps, the Show
## Ring and the Relay Cup; docs/AUDIO.md). Every cue goes through cue(), which plays it through Sfx at the Boki,
## quiet under the garden ambience, and counts it in `heard` so the checks can assert each cue fires once per event.

const DB := -6.0                      # dB: the garden sounds sit under the Boki voices
const BEAT_S := 0.45                  # s between the three countdown beats
const GO_S := BEAT_S * 2.0            # s from the first beat to "go"
const SULK_DELAY := 0.7               # s after the win fanfare until the loser huffs
const SNIFF_NEAR := 12.0              # m from the scent where the sniffing loop is at its highest
const PUSH_DELAY := 0.25              # s after a Tumble clash until the loser's paws scuff back
const REVEAL_S := 1.2                 # s of the Show Ring's card reveal before the crowd answers
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
	home.get_tree().create_timer(GO_S).timeout.connect(beat.bind("garden_go"))

## The crowd of Boki answering a timing press: "great", "good" or "miss".
static func crowd(grade: String, pos) -> void:
	cue("garden_cheer_" + GRADE[grade], pos)

## The winner's fanfare and, a beat later, the loser's huff; each in its own size.
static func result(home, res: Dictionary) -> void:
	fanfare(home, home._kin_entry(res["win"]), home._kin_entry(res["lose"]))

## result() for two entries that need not be yours ({rec, pos}: a visitor, a rival team's runner).
static func fanfare(home, win: Dictionary, lose: Dictionary) -> void:
	cue("garden_win_" + _size(win["rec"]), win["pos"])
	var huff := func(): cue("garden_sulk_" + _size(lose["rec"]), lose["pos"])
	home.get_tree().create_timer(SULK_DELAY).timeout.connect(huff)

## Tumble: the exchange lands with the move that decided it, then the loser scuffs back unless it was dead level.
static func clash(home, move: String, pos, pushed: bool) -> void:
	cue("tumble_clash_" + move, pos)
	if pushed:
		home.get_tree().create_timer(PUSH_DELAY).timeout.connect(func(): cue("tumble_push", pos))

## The Show Ring: the judges flip their cards, then the crowd answers.
static func reveal(home, pos) -> void:
	cue("show_reveal", pos)
	home.get_tree().create_timer(REVEAL_S).timeout.connect(func(): cue("show_crowd", pos))

static func _size(rec: Dictionary) -> String:
	return SIZE[Unique.size_tag(rec)]

## Seek: the sniffing loop at the hunter nearest the scent, higher as it closes in. Call every frame of the hunt.
static func sniff(pos, metres_off: float) -> void:
	if not Sfx.loop_on("seek_sniff"):
		heard["garden_sniff"] = int(heard.get("garden_sniff", 0)) + 1
	Sfx.loop_hold("seek_sniff", "garden_sniff", pos, DB, 0.9 + 0.3 * clampf(1.0 - metres_off / SNIFF_NEAR, 0.0, 1.0))

static func sniff_stop() -> void:
	Sfx.loop_stop("seek_sniff")
