class_name ShieldSrc
extends RefCounted
## Who gave a Hunter's timed shield (`Hunter.shield`), kept as an Icons id so your vitals' shield strip
## (ShieldStrip) can show it. The pool keeps the larger amount when two shields meet (docs/ABILITIES.md,
## Shields), so a grant names the pool only when it sets it at least as high as it was.

const HEAT := "cloak"  # Cinder: Heat Shield spin and the rank 3 pounce
const MOLTEN := "blaze_mantle"  # Tenzo: Molten Guard stacks
const TIDE := "wave"  # Gil: Tidal Wave landing
const SWAP := "swap"  # Void (Motley): the rank 3 swap's ally shield
const ITEM := "brightshield"  # an Effects "shield" (Shield cell, gear, abilities); also the fallback
const HEAL := "mend"  # an ally area's heal shield
const BOKI := "paw"  # a Boki move's shield, and the Boki owner shield (kin_shield)
const FUSE := "bond"  # a Fuse release's afterglow


## Gives `t` (a Hunter or a Kin) `amount` of shield, keeping the larger pool; a Hunter's pool takes `icon`
## as its source when this grant sets it.
static func give(t: Ent, amount: float, icon: String) -> void:
	var h := t as Hunter
	if h:
		if amount >= h.shield:
			h.shield_src = icon
		h.shield = maxf(h.shield, amount)
	elif t is Kin:
		(t as Kin).shield = maxf((t as Kin).shield, amount)
