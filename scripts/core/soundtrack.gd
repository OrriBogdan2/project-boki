class_name Soundtrack
extends RefCounted
## Which music plays where (content/music/soundtracks.json, Settings > Audio > Music). A place (the
## main menu, the garden, an expedition's calm / fight / last moments, a boss, a run that got out,
## training) plays its track from the picked soundtrack style, unless a track was picked by hand for
## that place. With Shuffle on, each scene rolls a random style when it starts and keeps it until the
## scene changes, so one expedition stays in one style. The first score ("isles") keeps each place's
## own music: track() hands the caller's own choice back (the garden's islands and nights, the
## expedition's layered stems).

const PATH := "res://content/music/soundtracks.json"
const OWN_STYLE := "isles"
const MATCH_PLACES := ["calm", "tense", "final", "boss"]
const SCREENS := ["menu", "victory"]     # places a screen sets once; a new pick replays them at once
## place -> the setting holding its hand-picked track ("" = the style's)
const HAND_PICK := {"menu": "track_menu", "base": "track_base", "calm": "track_calm", "tense": "track_tense",
	"final": "track_final", "boss": "track_boss", "victory": "track_victory", "training": "track_training"}

static var _data := {}
static var _scene := ""        # the scene Shuffle last rolled for
static var _rolled := ""       # and the style it rolled
static var _last := ["", "", ""]   # the last screen place asked for, its own track, what it got

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data

static func styles() -> Dictionary:
	return data().get("styles", {})

static func places() -> Array:
	return data().get("places", [])

## The track to play in `place` (a music id for Sfx.play_music). `own` is what the place played before
## soundtracks could be picked; it comes back whenever the pick is the first score's track there.
static func track(place: String, own: String) -> String:
	var id := picked(place)
	var out := own if id == _track_of(OWN_STYLE, place) else id
	if place in SCREENS:
		_last = [place, own, out]
	return out

## The track the settings pick for `place`: a hand pick, else the style's.
static func picked(place: String) -> String:
	var hand := String(Settings.get_v(HAND_PICK[place]))
	if hand != "" and ResourceLoader.exists("res://audio/music_%s.ogg" % hand):
		return hand
	return _track_of(style_for(place), place)

## The style `place` plays from: the picked one, or with Shuffle on, this scene's roll.
static func style_for(place: String) -> String:
	var style := String(Settings.get_v("soundtrack"))
	if bool(Settings.get_v("music_shuffle")):
		var scene := _scene_of(place)
		if scene != _scene:
			_scene = scene
			var ids := styles().keys()
			_rolled = String(ids[randi() % ids.size()])
		style = _rolled
	return style if styles().has(style) else String(data().get("default", OWN_STYLE))

## True while every expedition place plays the first score: the match runs its layered stems (MusicDir).
static func layered() -> bool:
	for p in MATCH_PLACES:
		if picked(p) != _track_of(OWN_STYLE, p):
			return false
	return true

## The picker's choices for one place: the soundtrack's own, then each style's track there.
static func options(place: String) -> Array:
	var out := [["", "From the soundtrack"]]
	for sid in styles():
		var t: Array = styles()[sid]["tracks"][place]
		out.append([String(t[0]), "%s (%s)" % [t[1], styles()[sid]["name"]]])
	return out

## A pick changed in the settings: the menu or results screen behind them switches now, if its track is
## still the one playing. The garden and an expedition's single tracks follow by themselves.
static func replay() -> void:
	if _last[0] != "" and Sfx.music_name == _last[2]:
		Sfx.play_music(track(_last[0], _last[1]))

static func _track_of(style: String, place: String) -> String:
	return String(styles().get(style, {}).get("tracks", {}).get(place, [""])[0])

static func _scene_of(place: String) -> String:
	for p in places():
		if p["id"] == place:
			return String(p["scene"])
	return place
