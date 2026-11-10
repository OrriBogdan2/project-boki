extends RefCounted
## --tut-first-games-check: the first practice round of Shove, Seek and Volley (scripts/home/first_round.gd).
## For each game on a base with the full farm and three rested Boki:
##   1. the first press offers "Practice once?" with the one-line input hint instead of starting, and sets the flag
##   2. Skip (the button or Esc) leaves the save as it was without the offer, and the next press is a plain round
##   3. Practice runs a short round against a calm partner to a result card that explains joy, trust and gems
##   4. the offer never comes back; a save that has played the game already is not offered it
## Never touches the real save.

const DT := 0.1                  # s per step
const MAX_S := 90.0              # s a round may take at most
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building
const GAMES := {
	"shove": ["hshove", BaseShove.FIRST, "Press %s as the stump tips"],
	"seek": ["hseek", BaseSeek.FIRST, "Hide it where your Boki will look last"],
	"volley": ["hvolley", BaseVolley.FIRST, "Press %s to spike when it glows"],
}

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("TUTGAMES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		k["level"] = 5
		Care.ensure(k)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	rules["base_mode"] = true
	home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	for g in GAMES:
		_game(g)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("TUTGAMES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Everyone rested and out, with no memory of having played (a played save is never offered).
func _rest() -> void:
	for k in home.kins:
		k["rec"]["memory"].clear()
		k.erase("indoors")
		k["busy"] = false
		Care.change(k["rec"], "energy", 100.0)
		Care.change(k["rec"], "food", 100.0)

func _text(c: Control) -> String:
	var out := ""
	for l in c.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out

func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "menu"
	e.pressed = true
	return e

## Presses at the game's spot; seek needs the scent hidden after the pick-up.
func _press(g: String, game) -> void:
	game.use()
	if g == "seek" and game.state == BaseSeek.S.CARRY:
		home.ppos = home.kins[0]["pos"] + Vector3(7, 0, 0)
		game.use()

func _running(g: String, game) -> bool:
	return game.state == BaseSeek.S.HUNT if g == "seek" else game.run != null

## Plays the round out; true when a gold glow showed while it ran.
func _finish(g: String, game) -> bool:
	var glowed := false
	var t := 0.0
	while _running(g, game) and t < MAX_S:
		game.tick(DT)
		glowed = glowed or (g != "seek" and game.run != null and game.bar.glow)
		t += DT
	game.tick(float(Content.rules("base_" + g)["card_s"]) + 1.0)
	return glowed

## The partner you do not back is calmed: a flag on the seek and volley rounds, a weaker push in the shove.
func _calm(g: String, game) -> bool:
	if g == "seek":
		return game.hunt.calm >= 0
	if g == "volley":
		return game.run.calm >= 0
	var b: int = 1 - game.run.backed
	var recs: Array = game.run.recs
	var plain: float = BaseShove.push(recs[b], recs[1 - b]) / BaseShove.hold(recs[1 - b])
	return is_equal_approx(game.run.base[b], plain * float(BaseShove.rules()["calm"]))

func _card_text(game) -> String:
	return _text(game.card) if is_instance_valid(game.card) else ""

func _game(g: String) -> void:
	var game = home.get(GAMES[g][0])
	var flag: String = GAMES[g][1]
	var tip: String = GAMES[g][2] % Settings.key_cap("interact") if "%s" in GAMES[g][2] else GAMES[g][2]
	_rest()
	# 1. the first press offers instead of starting
	Save.d["tutorial"].erase(flag)
	var before: Dictionary = Save.d.duplicate(true)
	_press(g, game)
	var offer: Control = game.first.offer
	ok(is_instance_valid(offer) and not _running(g, game) and Save.d["tutorial"][flag],
			"%s: the first press offers, not starts" % g)
	var lines := _text(offer)
	ok(lines.contains("Practice once?") and lines.contains(tip), "%s: the offer and its one-line input" % g)
	ok(game.input(_esc()) and game.first.offer == null and not _running(g, game), "%s: Esc skips the offer" % g)
	# 2. skip leaves the save as without it, and the next press is a plain round
	var after: Dictionary = Save.d.duplicate(true)
	after["tutorial"].erase(flag)
	ok(after == before, "%s: skipping leaves the save as without the offer" % g)
	_press(g, game)
	ok(game.first.offer == null and _running(g, game) and not game.guide, "%s: after a skip it is a plain round" % g)
	_finish(g, game)
	ok(not _card_text(game).contains(FirstRound.RESULT.substr(0, 20)), "%s: a plain round's card has no explainer" % g)
	# 3. practice: a calm partner, a short round, the card explains
	_rest()
	Save.d["tutorial"].erase(flag)
	_press(g, game)
	game.first.answer(true)
	if g == "seek":
		home.ppos = home.kins[0]["pos"] + Vector3(7, 0, 0)
		game.use()
	ok(_running(g, game) and game.guide, "%s: Practice starts the guided round" % g)
	ok(_calm(g, game), "%s: against a calm partner" % g)
	var t := 0.0
	while _running(g, game) and t < MAX_S:
		game.tick(DT)
		t += DT
	var seen_card := _card_text(game)
	ok(not _running(g, game) and seen_card.contains("Joy and trust") and seen_card.contains("gems"),
			"%s: the round finished (%.1f s) and the card explains joy, trust and gems" % [g, t])
	if g != "seek":
		ok(game.guide == false, "%s: the guide ends with the round" % g)
	game.tick(float(Content.rules("base_" + g)["card_s"]) + 1.0)
	# 4. never again; a save that has played the game is not offered it
	_rest()
	_press(g, game)
	ok(game.first.offer == null and _running(g, game) and not game.guide, "%s: the offer never comes back" % g)
	_finish(g, game)
	_rest()
	Save.d["tutorial"].erase(flag)
	home.kins[0]["rec"]["memory"].append({"m": 0, "kind": g, "text": "played"})
	_press(g, game)
	ok(game.first.offer == null and _running(g, game), "%s: a save that has played it is not offered it" % g)
	_finish(g, game)
	home.kins[0]["rec"]["memory"].pop_back()
