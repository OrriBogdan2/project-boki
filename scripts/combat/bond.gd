class_name Bond
## The bond meter: fighting together fills it. Your hits, your kin's hits, combos and knockouts all
## add to it (numbers in content/rules/bond.json). When it's full, R calls your active kin's
## Merge (the bond meter, `ult`, 0..1 on the hunter). Your Boki's hits mark a foe for a few seconds, and your
## own hits on a marked foe fill the meter faster.

static func rules() -> Dictionary:
	return Content.rules("bond")

static func add(h: Hunter, amount: float) -> void:
	if h == null or h.out or amount <= 0.0:
		return
	# IVS: the active kin's Bond IV fills the meter up to 10% faster (Care.iv_mult)
	if h.kin is Kin: amount *= Care.iv_mult((h.kin as Kin).rec, "bond")
	KinBond.add(h, amount * (1.3 if h.perk_n("overcharge") > 0 else 1.0), KinBond.FIGHT)

## Connected to CombatBus.hit_landed by the match.
static func on_hit(attacker: Node, target: Node, amount: float, _tags: Array) -> void:
	if attacker == null or not is_instance_valid(attacker) or target == null:
		return
	var rl := rules()
	var h: Hunter = null
	var rate := 0.0
	if attacker is Hunter:
		h = attacker
		rate = float(rl.get("per_player_dmg", 0.003))
		rate *= marked_k(h, target)
	elif attacker is Kin and (attacker as Kin).owner_h:
		h = (attacker as Kin).owner_h
		rate = float(rl.get("per_kin_dmg", 0.005))
	if h == null or target.team == h.team or not (target is Ent):
		return
	if attacker is Kin:
		(attacker as Kin).marked[(target as Ent).nid] = h.m.time + float(rl.get("mark_s", 4.0))
	if bool(rl.get("kin_required", true)) and not h.has_kin_ready():
		return
	if target is Mob:
		rate *= float(rl.get("mob_factor", 0.6))     # fighting other hunters fills it faster than farming monsters
	var add_v := minf(amount * rate, float(rl.get("max_per_hit", 0.06)))
	if attacker is Kin and target.hp <= 0.0:
		add_v += float(rl.get("kin_ko", 0.1))
	add(h, add_v)

## How much faster your hit on `target` fills the meter: the bond rate times marked_factor while your
## Boki has hit it in the last mark_s seconds.
static func marked_k(h: Hunter, target: Node) -> float:
	var k: Kin = h.kin
	if k == null or not is_instance_valid(k) or not (target is Ent):
		return 1.0
	return float(rules().get("marked_factor", 2.0)) if float(k.marked.get((target as Ent).nid, 0.0)) > h.m.time else 1.0

static func passive(h: Hunter, dt: float) -> void:
	if h.has_kin_ready():
		add(h, float(rules().get("passive_per_sec", 0.003)) * dt)
