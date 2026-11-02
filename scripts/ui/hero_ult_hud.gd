class_name HeroUltHud
extends RefCounted
## The X slot on the archetype ability row (HUD._draw_arch_abilities): the hunter's own ultimate, its
## cooldown sweep and seconds, and a level tag ("Lv 6") until it unlocks. Merge keeps its own R slot.


## Draws the slot at x and returns the x after it (unchanged for a kit without an X ultimate).
static func slot(hud, p: Hunter, x: float, y: float, s: float, gap: float) -> float:
	if p.ak == null or p.ak.x_def().is_empty():
		return x
	var xd: Dictionary = p.ak.x_def()
	var col := Color(String(xd.get("col", "#ffffff")))
	var cd_left := float(p.ak.cd["x"])
	var cd_max := maxf(0.01, HeroUlt.cooldown(p))
	var locked := p.lvl < HeroUlt.unlock_level(p)
	var ready := not locked and cd_left <= 0.0
	var sweep := cd_left / cd_max if cd_left > 0.0 else 0.0
	var label := "Lv %d" % HeroUlt.unlock_level(p) if locked else ""
	var rect := Rect2(Vector2(x, y), Vector2(s, s))
	hud._ab_slot("x", rect, String(xd.get("icon", "burst")), Settings.key_cap("hunter_ult"), col, sweep, cd_left, ready,
		-1, 0, label)
	return x + s + gap
