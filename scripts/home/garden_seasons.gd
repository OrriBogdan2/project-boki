class_name GardenSeasons
extends RefCounted
## Garden seasons (content/rules/garden_seasons.json, GARDEN_MODERN.md 5 rank 9). Every couple of weeks one zone
## is in season, on the weekly-event clock (BaseRace.week_now). Its game plays the season twist, the snack patch
## grows the season snack, and that game's Crown adds the season keepsake. Lazy state: rec.keepsakes
## ({keepsake id: season number it was won in}), no migration.


static func rules() -> Dictionary:
	return Content.rules("garden_seasons")


## Seasons since 1970: one per `weeks` weeks of BaseRace's week number (default this week).
static func number(week := -1) -> int:
	return (week if week >= 0 else BaseRace.week_now()) / int(rules()["weeks"])


## The season on for a week number (default this week): a garden_seasons.json seasons entry.
static func season(week := -1) -> Dictionary:
	var list: Array = rules()["seasons"]
	return list[number(week) % list.size()]


## The season's twist when the season is for this game, else {}. Twists are looked up by id in base_race.json
## twists, then in the season-only twists.
static func twist(game: String, week := -1) -> Dictionary:
	var s := season(week)
	if String(s["game"]) != game:
		return {}
	for t in BaseRace.rules()["twists"] + rules()["twists"]:
		if t["id"] == s["twist"]:
			return t
	return {}


## The extra snack the patch grows right now (unix seconds).
static func snack(now: float) -> String:
	return String(season(BaseRace.week_now(now))["snack"])


## A Crown in `game`: in that game's season, the winner gets the season keepsake once. Returns its name or "".
static func keepsake(game: String, mine: Dictionary, now: float) -> String:
	var week := BaseRace.week_now(now)
	var s := season(week)
	if String(s["game"]) != game:
		return ""
	var k: Dictionary = s["keepsake"]
	var have: Dictionary = mine.get_or_add("keepsakes", {})
	if int(have.get(k["id"], -1)) == number(week):
		return ""
	have[k["id"]] = number(week)
	Save.remember(
		mine,
		"keepsake",
		"took the %s Crown in %s's season and kept the %s" % [GardenPrizes.game(game)["name"], s["name"], k["name"]],
		2.0
	)
	return String(k["name"])
