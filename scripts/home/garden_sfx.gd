class_name GardenSfx
extends RefCounted
## The sounds of the garden minigames (the Dash, Stump Shove, Seek, Spark Volley, Tumble, Echo Steps, the Show
## Ring and the Relay Cup) and of the shaping items (docs/AUDIO.md). Every cue goes through cue(), which plays it
## through Sfx at the Boki, quiet under the garden ambience, and counts it in `heard` so the checks can assert each
## cue fires once per event.
## Ring and the Relay Cup), its cup rounds, wild visitors and seasons (docs/AUDIO.md). Every cue goes through
## cue(), which plays it through Sfx at the Boki, quiet under the garden ambience, and counts it in `heard` so the
## checks can assert each cue fires once per event.

const DB := -6.0                      # dB: the garden sounds sit under the Boki voices
const BEAT_S := 0.45                  # s between the three countdown beats
const GO_S := BEAT_S * 2.0            # s from the first beat to "go"
const SULK_DELAY := 0.7               # s after the win fanfare until the loser huffs
const SNIFF_NEAR := 12.0              # m from the scent where the sniffing loop is at its highest
const PUSH_DELAY := 0.25              # s after a Tumble clash until the loser's paws scuff back
const REVEAL_S := 1.2                 # s of the Show Ring's card reveal before the crowd answers
const GRADE := {"great": "perfect", "good": "good", "miss": "miss"}
const SIZE := {"XS": "small", "S": "small", "M": "medium", "L": "large", "XL": "large"}
const PIP_S := 0.35                   # s after a path token's cue until its pip clicks into the meter
const TICK_S := 0.6                   # s between the soft ticks while a held item's preview card is up
## A fed shaping item's effect kind (garden_items.json) -> its family's cue; Stayleaf and Rinse Melon have their own.
const ITEM := {"stat": "garden_item_bite", "stat_all": "garden_item_bite", "xp": "garden_item_bite",
		"token": "garden_item_token", "stay": "garden_item_lock", "sweet": "garden_item_snack",
		"rinse": "garden_item_wash", "aura": "garden_item_aura", "loose": "garden_item_unwind",
		"trait": "garden_item_nudge", "twin": "garden_item_nudge", "down": "garden_item_nudge"}
const CUPS := ["garden_cup_sprout", "garden_cup_bloom", "garden_cup_crown"]      # by cup round, garden_prizes.json

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

## A cup round won (garden_prizes.json cup rounds, by name): its fanfare, bigger each step up to the Crown.
static func cup(round_name: String) -> void:
	var rounds: Array = GardenPrizes.rules()["cup"]["rounds"]
	cue(CUPS[rounds.map(func(r): return r["name"]).find(round_name)], null)

## A Home opening in `zone` ("" the start zone, GardenZones.here before it opens is `from`): when that is a
## new zone and the one in season (GardenSeasons), its short sting.
static func zone_in(zone: String, from: String) -> void:
	if not FarmUnlocks.base_mode() or zone == GardenZones.HUB or _zone(zone) == _zone(from):
		return
	if String(GardenSeasons.season()["zone"]) == _zone(zone):
		cue("garden_season", null)

static func _zone(id: String) -> String:
	return id if id != "" else GardenZones.start()

static func _size(rec: Dictionary) -> String:
	return SIZE[Unique.size_tag(rec)]

## A shaping item given to a Boki at pos: its family's cue, and for a path token its pip clicking into the meter
## a beat later.
static func item(home, pos, id: String) -> void:
	var kind := String(GardenItems.item(id)["effect"]["kind"])
	cue(ITEM[kind], pos)
	if kind == "token":
		home.get_tree().create_timer(PIP_S).timeout.connect(func(): cue("garden_item_pip", pos))

## One soft tick of a held item's preview card (ItemHold plays one every TICK_S); a UI sound, not at the Boki.
static func card_tick() -> void:
	cue("garden_item_tick", null)

## Seek: the sniffing loop at the hunter nearest the scent, higher as it closes in. Call every frame of the hunt.
static func sniff(pos, metres_off: float) -> void:
	if not Sfx.loop_on("seek_sniff"):
		heard["garden_sniff"] = int(heard.get("garden_sniff", 0)) + 1
	Sfx.loop_hold("seek_sniff", "garden_sniff", pos, DB, 0.9 + 0.3 * clampf(1.0 - metres_off / SNIFF_NEAR, 0.0, 1.0))

static func sniff_stop() -> void:
	Sfx.loop_stop("seek_sniff")
