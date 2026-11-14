class_name GardenMusic
extends RefCounted
## The music of the home (docs/AUDIO.md). In the garden the hub and each zone play their own track
## (garden_zones.json "music", the hub's by day and by night): a hop loads the zone and the music
## crossfades to its track over music_fade_s, and while a garden game is on the music ducks
## (music_duck_db). Off the garden the music follows the island you stand on, and home changes at night.
## A track picked in the music list (Sfx.music_lock) plays instead, and hold() gives a moment its own
## track for a while (a Boki evolving).

const LOOK_S := 0.5           # s between looks at where you are and what is on
const ISLAND_FADE_S := 2.5    # s: the crossfade as you cross a bridge off the garden
const HOLD_FADE_S := 1.0      # s: the crossfade into a held or picked track
const ISLANDS := ["orchard", "meadow", "summit"]   # islands with a theme of their own (World.island_id)

var h                         # the Home screen
var _look_t := 0.0
var _hold_t := 0.0

func _init(home) -> void:
	h = home

## The track of a garden zone, or of the hub by day or night.
static func zone_track(zone: String, night: bool) -> String:
	if zone == GardenZones.HUB:
		return String(GardenZones.rules()["hub_music"]["night" if night else "day"])
	return String(GardenZones.info(zone)["music"])

## The track of an island of the home off the garden.
static func island_track(isle: String, night: bool) -> String:
	if isle in ISLANDS:
		return isle
	return "home_night" if night else "home_day"

## `track` plays for `seconds` before the music follows you again.
func hold(track: String, seconds: float) -> void:
	_hold_t = seconds
	Sfx.play_music(track, HOLD_FADE_S)

## Looks again on the next tick (the music list let go of its track).
func retune() -> void:
	_look_t = 0.0

func tick(dt: float) -> void:
	_look_t -= dt
	_hold_t -= dt
	if _look_t > 0.0:
		return
	_look_t = LOOK_S
	if h.games.any(func(g): return g.playing()):
		Sfx.duck(LOOK_S * 2.0, float(GardenZones.rules()["music_duck_db"]))   # held while the game is on
	if _hold_t > 0.0:
		return
	var night := sin((h.day_t - 0.25) * TAU) < -0.15
	if Sfx.music_lock != "":
		Sfx.play_music(Sfx.music_lock, HOLD_FADE_S)
	elif GardenZones.here != "":
		var fade := float(GardenZones.rules()["music_fade_s"])
		Sfx.play_music(Soundtrack.track("base", zone_track(GardenZones.here, night)), fade)
	else:
		var isle := island_track(h.world.island_id(h.ppos.x, h.ppos.z), night)
		Sfx.play_music(Soundtrack.track("base", isle), ISLAND_FADE_S)      # (the Settings soundtrack can swap it)
