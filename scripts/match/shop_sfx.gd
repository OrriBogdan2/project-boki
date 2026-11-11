class_name ShopSfx
extends RefCounted
## The in-match shops' sounds (one family, tools/gen_sfx_shop.py, content/sfx/shop.json). Your own
## shop actions are UI sounds (no position): the panel opening and closing, a buy (coins and bell,
## bigger by price band) and a dull tick when a buy is refused. World sounds sit at a spot: the
## lantern bell when you come within reach of a vendor (once per arrival, NEAR_GAP apart per vendor)
## and someone else's buy at their position.
##
## For Shops / ShopPanel: ShopSfx.tick(m) every step, opened(), closed(), bought(m, h, paid), refused().

const NEAR_DB := -6.0     # dB: the nearby bell is a soft cue, under the panel's own sounds
const NEAR_GAP := 6.0     # s of match time before one vendor's bell can ring again for you
const OTHER_DB := -8.0    # dB: someone else's buy, heard at their spot
const BANDS := [40, 100]  # gems: a buy under 40 is the small sound, under 100 the middle one, else the big one

static func _st(m) -> Dictionary:
	if not m.has_meta("shop_sfx"):
		m.set_meta("shop_sfx", {"near": -1, "rung": {}})
	return m.get_meta("shop_sfx")

## Rings the vendor's bell when the player steps into its reach (not again while they stay, and not
## within NEAR_GAP of the last ring at that vendor).
static func tick(m) -> void:
	var st := _st(m)
	var h = m.player
	var at := -1
	var pos := Vector3.ZERO
	if h != null and not h.out and not h.downed:
		for v in Shops.list(m):
			if Shops.near(m, h, v):
				at = int(v["idx"])
				pos = v["pos"]
				break
	if at == int(st["near"]):
		return
	st["near"] = at
	var rung: Dictionary = st["rung"]
	if at < 0 or m.time - float(rung.get(at, -NEAR_GAP)) < NEAR_GAP:
		return
	rung[at] = m.time
	Sfx.play("shop_near", pos + Vector3(0, 2.7, 0), NEAR_DB, 0.03)

static func opened() -> void:
	Sfx.play("shop_open", null, 0.0, 0.03)

static func closed() -> void:
	Sfx.play("shop_close", null, 0.0, 0.03)

## A finished buy: yours as a UI sound, a bot's at its position.
static func bought(m, h, paid: int) -> void:
	if h == m.player:
		Sfx.play(buy_sound(paid), null, 0.0, 0.02)
	else:
		Sfx.play(buy_sound(paid), h.pos, OTHER_DB, 0.02)

## The buy sound for a price: small, middle or big (BANDS).
static func buy_sound(paid: int) -> String:
	if paid < BANDS[0]:
		return "shop_buy_s"
	return "shop_buy_m" if paid < BANDS[1] else "shop_buy_l"

## A buy click that didn't go through (not enough gems, sold out, still waiting on the host).
static func refused() -> void:
	Sfx.play("shop_broke", null, 0.0, 0.04)
