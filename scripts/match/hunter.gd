class_name Hunter
extends Ent
## A player or bot hunter: movement, weapon, dash, jump, ledge grab, class signature, downed state.

# Target feel (see sv/FEEL_NOTES.md): near-instant ground control, momentum that carries in
# the air and in the glider. Air, fall and glide-height tunables are in content/rules/hunter_move.json.
const H_GRAV := 14.7  # m/s^2 [game data] DefaultGravityZ -1470 uu/s^2, the same up and down
# ---- movement feel (movefeel, Oct 31 2026): every value and its source is in docs/MOVEMENT_FEEL.md,
# measured by --move-feel-check. Snappy first: input acts the step it arrives, falls hit the
# footage depth, the glider opens and steers at once and keeps the momentum you bring into it.
# m/s: [game data] JumpZVelocity is 7.5 (1.9m up); ours stops ~1.5m up so jump + mantle still tops
# out under four terraces (the wall kick's job) on our 0.8m terraces
const JUMP_V := 6.8
# one-step presses, cleared after each sim step
const PRESS_KEYS := [
	"dash",
	"jump",
	"sig",
	"util1",
	"util2",
	"util3",
	"util4",
	"util5",
	"util6",
	"ult",
	"sec",
	"gear1",
	"gear2",
	"skill",
	"swap"
]
# [input key, skill slot, feedback slot]: a press on a slot with no point is refused
const SLOT_GATES := [["dash", "dash", "dash"], ["sec", "sec", "sec"], ["sig", "kin", "k1"], ["ult", "ult", "r"]]
const AIR_ACCEL := 40.0  # a ledge rise steers crisply (a jump steers by Loco.air_step)
## The ledge, abyss, glide, drop, dive and landing numbers live in HunterFeel (tuning.json "feel", owner 11-08).
const EX_DASH_CD := 12.5  # the long dash: in the air, or with the short one on cooldown
const DASH_SPEED := 19.0  # m/s: the base dash (owner: 23 felt too fast); 19 x 0.19s = 3.6m
const DASH_TIME := 0.19  # s
const DASH_REGEN := 2.2
## Armor, as in Supervive: it takes its tier's share off every hit (ARMOR_TIERS) for as long as it
## has durability left; what gets through hurts your health and wears the durability down by the same
## amount. Neither comes back on its own: tonics heal and armor kits repair (the utility belt, 1 to 4).
const CONSUME_VULN := 1.2  # you take this much more damage while drinking, repairing or reviving a box

var pname := "Hunter"
var clan_tag := ""  # shown before the name on the nameplate (ClanInfo.tagged)
var cls := "medium"
var cdat: Dictionary = {}
var wid := "rifle"
var wpn: Dictionary = {}
var ctrl := "bot"  # local | bot | remote
var inp := {
	"move": Vector2.ZERO,
	"aim": Vector3.ZERO,
	"fire": false,
	"dash": false,
	"jump": false,
	"throw": false,
	"skill": false,
	"sig": false,
	"interact": false,
	"util1": false,
	"util2": false,
	"util3": false,
	"util4": false,
	"util5": false,
	"util6": false,
	"glide": false,
	"glide_press_only": false,
	"ult": false,
	"sec": false,
	"sec_hold": false,
	"crouch": false,
	"scout": false,
	"gear1": false,
	"gear2": false,
	"swap": false
}
var base_speed := 5.4
var ground_accel := HunterFeel.ground_accel  # per hunter (HunterMove)
var ammo := 12
var fire_cd := 0.0
var dash := DashState.new()  # charges and the long dash cooldown, the garden avatar's too
var dashes: float:
	get:
		return dash.charges
	set(v):
		dash.charges = v
var roll_dir := Vector2.ZERO
var inv_t := 0.0
var coyote := 0.0
var jump_buf := 0.0
var fly_t := 0.0
var mantle_cd := 0.0
var carry_v := 0.0  # m/s: how fast you were just going (MantleCarry, item 185b)
var carry_dir := Vector2.ZERO
var carry_mini := {}  # a mantle's held speed just after the lip (MantleCarry)
var grap_cd := 0.0
var grap: Dictionary = {}  # floating back up a ledge
var push_t := 0.0
var last_gy := 0.0  # ground height where you last stood
var pad: Dictionary = {}  # jump-pad flight along a fixed arc
var kb_t := -9.0
var sig_cd := 0.0
var cloak_t := 0.0
var haste_t := 0.0
var fortify_t := 0.0
var shield := 0.0
var shield_t := 0.0
var shield_kind := ""  # the material the shield sounds as (ShieldSfx); "" = the plain ward
var shield_src := ""  # an Icons id: who gave the shield (ShieldSrc), for your vitals' strip
var recoil := 0.0
var walk_ph := 0.0
var anim: HunterAnim = null  # the procedural animation for the model
var downed := false
var down_hp := 0.0
var revive := 0.0
var out := false
var gone := false  # dead for good: no box revive, no beacon (see Life)
var sick_t := 0.0  # resurrection sickness after a beacon revive: -25% damage
var stolen_carry := false  # carrying someone else's kin: it struggles, slowing you a little
var chase: Hunter = null  # whoever has your kin: you run faster toward them
var box_t := 0.0  # holding interact at a deathbox
var box_rev_at := -9.0  # last time we were channelling a deathbox revive (BoxRevive)
var hurt_at := -9.0  # last time a hit landed (channels like a box revive break on it)
var hit_k := 1.0  # how hard the last hit was (Oomph): scales the flinch
var hit_shake := 0.0  # the model's hit-shake left (Oomph.render_hit)
var hit_from := Vector2.ZERO  # which way the last hit pushed
var stagger_t := 0.0  # staggered by a big hit (Oomph)
var extracted := false
var extract_prog := 0.0
var dash_glide := DashGlide.new()  # an air dash's exit eases out, and Shift hands over to the glider
## What this hunter is holding interact for right now (an animation each, see HunterAnim._act_*):
## "" or one of HOLD_KINDS. Set every tick by whatever the hold works on; it lapses when not refreshed.
const HOLD_KINDS := [
	"scan", "revive", "chest", "dial", "console", "lever", "windup", "shrine", "beacon", "key", "loot", "rune"
]
var hold_kind := ""
var hold_until := 0.0


## Keep the hold animation going for a moment (the systems that run a hold call this every tick).
func set_hold(kind_name: String, dur := 0.15) -> void:
	hold_until = maxf(hold_until, m.time + dur) if kind_name == hold_kind else m.time + dur
	hold_kind = kind_name


func holding() -> String:
	return hold_kind if m.time < hold_until else ""


var chest_keys := 0  # chest keys carried: each opens one chest (KeyChest); they go in your deathbox
var kin: Ent = null  # the active kin: its abilities are on Q and V, its ultimate on R
var kin2: Ent = null  # the benched kin, swapped in with X
var swap_cd := 0.0
var merge_st: Dictionary = {}  # the merge (bond ultimate) while it runs: {def, t, T, giant, pulse, form, phase, kit, shell...} (KinMerge)
var merge_cd := 0.0  # the spent window after a merge ends
var merge_free := true  # the first time the ult slot opens this run, the bond meter fills
var kin_bonus: Dictionary = {}  # owner bonuses from your kin's stat points (KinLib.owner_bonus), applied for the run
var kin_hp_added := 0.0
var kin_shield := 0.0  # the small shield a kin's owner_shield points give: refills out of a fight
var kbuffs: Dictionary = {}  # short boosts from kin abilities: stat -> [amount, time left]
var air_jumps := 0  # extra jumps used since you left the ground (merge passives)
var air_dashed := false  # the merge's dodge in the air, used this airtime
var _kst: Dictionary = {}  # owner stats from your kin this step (carry passives + merge), see owner_stat
var gems := 0
var lost_gems := 0
var seeds := {}
var caught: Array = []  # kin records caught this match
var kills := 0
var knocks := 0
var dmg_done := 0.0
var belt: Array = UtilityBelt.empty()  # the utility belt on 1-4: four slots of {id, n, cd} (UtilityBelt)
var belt_free: Dictionary = {}  # issued charges, used first and never taken home
var tonics: int:  # (the belt's tonics and armor kits, for the code that counts them)
	get:
		return UtilityBelt.count(self, "tonic")
	set(v):
		UtilityBelt.set_count(self, "tonic", v)
var armor_kits: int:
	get:
		return UtilityBelt.count(self, "armor_kit")
	set(v):
		UtilityBelt.set_count(self, "armor_kit", v)
var ai: Dictionary = {}
var muzzle_t := 0.0
var armor := 0.0
var max_armor := 50.0
var bloom := 0.0  # extra spread from moving, jumping and dashing
var crouch := false  # slower, steadier aim, and much harder to spot
var crouch_k := 0.0
var scout := false  # holding the far look (ScoutLook): further sight in a narrow cone, speed unchanged
var reveal_t := 0.0  # seen through bushes and around walls for a moment after firing or getting hit
var wall_touch_t := 0.0  # touching a wall in the air: a jump kicks off it
var wall_n := Vector2.ZERO
var slide_n := Vector2.ZERO  # out of the wall the last step's walk pressed into (HunterMove.along_wall)
var wall_moves := WallMoves.new()  # wall kick and wall bounce
var glide_lift := GlideLift.new()  # the abyss lift's spring and float, ledge catch timing
var abyss_sfx := AbyssSfx.new()  # whoosh, catch, strain and fall-out cues (everyone's, from synced state)
var glide_dive := GlideDive.new()  # the glider's plunge while crouch is held under it
var glider_snd := GliderSfx.new()  # its open, wind, dive, overheat and fold sounds
var abyss_snd := AbyssFallSfx.new()  # the abyss fall's wind, warning and lift (or others' cry)
var wslam_t := 0.0
var wallstun := 0.0  # how long the next wall slam stuns (Haymaker makes it longer)
var wallstun_at := -9.0  # s (match time) the hit that set wallstun landed (Displace.knocked keeps it)
var land_t := 0.0
var ghost_t := 0.0
var moves := HunterLoco.new(self)  # owns the locomotion state (Loco.S) and the data of the move it is in
var loco: Fsm = moves.fsm
## Views of the locomotion state; a write asks moves for the transition (HunterLoco).
var gliding: bool:
	get:
		return loco.state == Loco.S.GLIDING
	set(v):
		moves.set_glide(v)
var roll_t: float:  # s left of the dash or kit rush (negative: its overrun)
	get:
		return moves.dash_left
	set(v):
		moves.set_dash(v)
var knock_t: float:
	get:
		return moves.knock_left
	set(v):
		moves.knock_left = v
## The ledge rise (SUPERVIVE's ledge float): {lip, n (into the wall), t, max_t, at, face (start
## point), g0 (glide held when it began), downed, win (timing window opened)}. See _ledge_rise.
var lfloat: Dictionary:
	get:
		return moves.ledge
	set(v):
		moves.set_ledge(v)
var glide_fuel := 1.0  # shown as glider heat: 1 = cool, 0 = overheated
var shot_down := false  # knocked out of an overheated glide: stunned when you land
var below_lip := false  # dropped below the nearest island's edge, over the abyss
var wall_hit_v := Vector2.ZERO  # this step's speed into an island side that stopped you (for the ledge catch)
var lip_y := 0.0  # that edge's height: where your balloon floats
var heat_burn := 0.0
var in_current := false  # riding a wind road or an updraft: the glider doesn't heat up
var glide_max: float = HunterMove.glide_heat_s
var glide_cd := 0.0
var glide_k := 0.0  # how far the glider is unfolded, for the model
var auto_glide_held := true  # (glide held last frame: auto_glide ends on a fresh press, not a held key)
var auto_glide := false  # carried by a lair's escape updraft: the glider opens and stays open
# by itself until you land (hold glide yourself to take it back)
var wind_t := 0.0
var perk := ""  # (old single home perk; perks are now found in the run, see perks)
var perks: Array = []  # perks picked up this expedition, one entry per stack
var second_wind_at := -INF  # m.time Second Wind last refreshed the dash (DashReset.second_wind)
var ult_ready := false  # the hero ultimate is ready (UltGlow: read from the kit, or from the net)
var ult_glow := 0.0  # its glow on the body, 0..1 (UltGlow)
var ult := 0.0  # the bond meter, 0..1: R calls your kin's bond ultimate at 1
var crit_t := 0.0  # shots crit while this runs (Blink)
var phase_t := 0.0  # Light's Phase Step: shots pass through you while this runs
var dash_pass := {}  # a grammar dash or a kit dash: what it does to foes you pass through {hit, opts}
var abil_charge := {}  # holding a charge-up weapon ability (Rail Charge): {t}
var charge: Dictionary = {}  # Ram
var idle_fire := 99.0  # s since the last shot or ability; starts expired so a fresh spawn is not "in a fight"
var dropping := false  # gliding down from the sky at the start of a match
var drop_from := Vector2.INF  # where the drop started
var diving := false  # the skydive part of the drop, before the glider opens
var riding := false  # aboard the skyship, waiting to jump
var rocket: DropRocket = null  # riding the squad's rocket down (still `riding`); see DropRocket
var bless_t := 0.0
var wup_dmg := 1.0  # your signature weapon's damage from weapon upgrades (WeaponUps): kits scale their own hits by it
var welem := ""  # its element ("fire", "frost", ...) from a Brand upgrade: a rider on every hit (Loot.rider)
var el_n := 0  # attacks made with the element, for "every Nth hit" riders
var pack: Array = []  # the backpack: gear and valuables to carry home (Loot items)
var pack_cap := 6
var backpack := 0  # the backpack tier worn (Backpacks): 0 is the Pouch everyone has
var swap_hold := false
var dash_at := -9.0  # when the last dash started, for perfect dodges
var jump_at := -9.0  # when you last jumped off the ground (AirLimits: a move from before it is over)
var dodged := false  # F has to be let go between weapon swaps
var lives := 1  # comes back this many times minus one before it's really out
var arch := ""  # the archetype (docs/ARCHETYPES.md); "" = the old class kit (weapon RMB, class dodge)
var ak: ArchKit = null  # the archetype's kit at run time
var shot_range_k := 1.0  # the next shot's range multiplier (1 unless a kit sets it)
var shot_aim := ""  # the next shot's aim mode (AimMode.CURSOR / MAX); "" = the weapon's own
var draw_t := -1.0  # a bow being drawn: how long (-1: not drawing)
var spirit_t := 0.0  # Spirit Walk (PinSpirit): rocks, trees, barriers and terrain don't stop you while > 0
var nth_n := 0  # shots since the weapon's "every Nth" bonus


func init_hunter(
	match_node: Node, id: String, team_id: int, class_id: String, name_txt: String, control: String, kit := {}
) -> void:
	setup(match_node, id)
	kind = "hunter"
	team = team_id
	cls = class_id if Data.CLASSES.has(class_id) else "medium"
	cdat = Data.CLASSES[cls]
	# the archetype: asked for by the kit, else your saved one (you) or a random one of the class (bots)
	var ka := String(kit.get("arch", ""))
	if ka == "" and control == "local":
		ka = String(Save.d.get("arch", ""))
	if ka == "" and control == "remote":
		# a remote player's archetype comes with them; failing that, the one their weapon belongs to
		# (never a random pick, so nobody ever looks like an archetype they aren't)
		var wa := Arch.archetypes_of(String(kit.get("weapon", ""))).filter(func(x): return Arch.weight(x) == cls)
		ka = String(wa[0]) if not wa.is_empty() else Arch.default_for(cls)
	if ka == "" and control == "bot":
		ka = "?"
	if ka == "?":
		ka = Arch.pick_for(cls, "%s|%s" % [id, str(match_node.get("seed_val"))])
	arch = "" if ka == "none" else Arch.fix(ka, cls)
	wid = (
		Arch.weapon_for(arch, cls, String(kit.get("weapon", "")))
		if arch != ""
		else Data.weapon_for(cls, String(kit.get("weapon", "")))
	)
	wpn = Data.weapon_stats(wid)
	perk = ""
	pname = name_txt
	ctrl = control
	if control != "local":
		bot_look = PlayerLook.random()
	max_hp = cdat["hp"]
	hp = max_hp
	max_armor = float(ARMOR_TIERS[armor_tier][4])
	armor = max_armor
	# the belt issue and the equal pack size (Equal.pack_slots)
	UtilityBelt.issue(self)
	pack_cap = Equal.base_pack()
	glide_max = HunterMove.glide_heat_s * float(cdat.get("glide_cap", 1.0))
	runner = AbilityRunner.new(self)
	ak = ArchKit.make(self, arch) if arch != "" else null
	HunterMove.apply(self)
	if not CombatBus.ability_used.is_connected(_on_ability_used):
		CombatBus.ability_used.connect(_on_ability_used)
		CombatBus.kin_thrown.connect(_on_kin_thrown)
	dodge_def = Content.class_dodge(cls)
	_kit_from_weapon()
	dashes = max_dashes()
	ammo = wpn["mag"]
	Arch.apply_body(self)
	set_model(
		Models.hunter(
			cls,
			Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()],
			wid,
			"",
			Unmasked.mask_look() if ctrl == "local" else bot_look,
			arch
		)
	)


## Switches the archetype mid-match (tests, practice). "" puts back the old class kit: the weapon's
## right click and the class dodge.
func set_arch(a: String) -> void:
	arch = "" if a == "" or a == "none" else Arch.fix(a, cls)
	Arch.apply_body(self)
	if ak:
		ak.teardown()
	ak = ArchKit.make(self, arch) if arch != "" else null
	HunterMove.apply(self)
	if arch != "" and not Arch.weapon_ok(arch, wid):
		equip(Arch.signature(arch))
	Arch.apply_body(self)
	_kit_from_weapon()


## Practice (the Arena and training): become another class and archetype on the spot. Health,
## speed, size, dash charges, the model and the kit change; your kin, level and slot ranks stay.
func reclass(c: String, a: String, w := "") -> void:
	if Data.CLASSES.has(c):
		cls = c
	cdat = Data.CLASSES[cls]
	if KinMerge.active(self):
		KinMerge.end(self, "broken")
	max_hp = float(cdat["hp"]) + kin_hp_added
	hp = max_hp
	LevelGrowth.reset(self)  # your levels' health comes along to the new class
	max_armor = float(ARMOR_TIERS[armor_tier][4])
	armor = max_armor
	glide_max = HunterMove.glide_heat_s * float(cdat.get("glide_cap", 1.0))
	dodge_def = Content.class_dodge(cls)
	arch = Arch.fix(a, cls)
	Arch.apply_body(self)
	if ak:
		ak.teardown()
	ak = ArchKit.make(self, arch)
	HunterMove.apply(self)
	wid = Arch.weapon_for(arch, cls, w)
	set_model(
		Models.hunter(
			cls,
			Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()],
			wid,
			"",
			Unmasked.mask_look() if ctrl == "local" else bot_look,
			arch
		)
	)
	anim = null
	equip(wid, -1, false)  # (Models.hunter just built this weapon, a 3D Warden's own model included)
	dashes = max_dashes()
	ex_cd = 0.0
	roll_t = 0.0
	stun_t = 0.0
	root_t = 0.0
	dash_buf = 0.0  # (a Shift press waiting in the old kit's buffer)


## Puts a weapon in hand with this run's weapon upgrades on it (WeaponUps). A hunter has one
## signature weapon (Arch.signature), so this is only called to build it, or when practice swaps archetype.
func equip(w: String, with_ammo := -1, rebuild := true) -> void:
	wid = w
	wpn = Data.weapon_stats(w)
	WeaponUps.apply(self)
	_kit_from_weapon()
	wbloom = 0.0
	warm_t = 0.0
	spin = 0.0
	spun_t = 0.0
	sus_n = 0
	mel_hold = 0.0
	strike_at_end = {}
	ammo = int(wpn["mag"]) if with_ammo < 0 else mini(with_ammo, int(wpn["mag"]))
	fire_cd = 0.25
	var gun: Node3D = model.find_child("Gun", true, false) if model and rebuild else null
	if gun:
		for ch in gun.get_children():
			if ch.name != "Muzzle":
				ch.queue_free()
		Models.gun_parts(
			gun,
			w,
			Models.toon(Color("4a4d5c")),
			Models.toon(Color("2b2a33")),
			Models.toon(Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()], true, 0.0)
		)


## Everything that slows your ground speed, multiplied (the bonuses add in HunterMove.speed_bonus): a
## slow, being downed, reloading, firing, drinking, crouching, the kit's own pace, a stolen kin carried,
## the Heartspark's weight.
func _move_mult() -> float:
	var k := slow_mult(0.65) * atk.fire_slow() * UtilityUse.channel_move(self) * KinDowned.carry_speed(self)
	if crouch:
		k *= HunterMove.sneak_speed
	if stolen_carry:
		k *= 0.92
	if ak:
		k *= ak.pace()
	if downed:
		k *= 0.4 * (Life.R["stomp_slow"] if get_meta("stomped", false) else 1.0)
	k *= 1.0 - float(get_meta("heart_slow", 0.0))  # carrying the Heartspark (Heart.carrier_slow)
	return k


## The colour that marks this hunter's effects (from their class).
func accent() -> Color:
	return cdat.get("color", Color.WHITE) if not cdat.is_empty() else Color.WHITE


func max_dashes() -> float:
	var n := DashState.base_charges(dodge_def, cdat)
	if ak and ak.single_dash():
		return 1.0
	return ak.dash_charges(n) if ak else n


func dash_regen() -> float:
	# each rank past the first recharges dashes faster; a kin's dodge_regen too (1 = instantly)
	var base := float(ak.dash_def().get("cd", 9.0)) if ak else DashState.base_regen(dodge_def)
	return (
		base
		* (ak.dash_k() if ak else 1.0 - 0.15 * float(maxi(0, int(slot_lv.get("dash", 1)) - 1)))
		* (1.0 - minf(0.9, owner_stat("dodge_regen") + gear_stat("dodge")))
	)


## Right click is always your weapon's ability, as left click is its attack.
func _kit_from_weapon() -> void:
	if runner == null:
		return
	var wd := Content.weapon(wid)
	if ak:
		wpn["sfx"] = String(ak.lmb_def().get("sfx", wpn["sfx"]))  # a Hunter's own shot over a shared gun's (Dredge)
		runner.set_slot("utility", null)  # right click is the archetype's
		return
	runner.set_slot("utility", Content.ability(wd.utility) if wd and wd.utility != "" else null)


# ------------------------------------------------------------------ your kin's stats on you
## Your kin with you on the Return order, settled in: its carry passives are on. A big Boki curls up on
## your back while you glide, and its passives are off for that time.
func kin_carry_on() -> bool:
	if kin == null or not (kin as Kin).carried() or (kin as Kin).owner_h != self:
		return false
	return not ((kin as Kin).carry_style() == "mount" and gliding)


## Riding the giant Fusion form right now (a Boki on the Return order guards at your side, never under you).
func mounted() -> bool:
	return kin_carry_on() and not (kin as Kin).giant.is_empty()


## An owner stat (KinParts.OWNER_STATS) from your kin: its carry passives while it rides with you,
## plus the merge's passives while merged, capped at the carry or merge maximum. Refreshed every step (_refresh_kin_stats).
func owner_stat(stat: String) -> float:
	return float(_kst.get(stat, 0.0))


func _refresh_kin_stats() -> void:
	var out_list := {}
	var k: Kin = kin
	if k and k.ks:
		if kin_carry_on():
			for ps in k.ks.carry_passives:
				out_list[ps["stat"]] = float(out_list.get(ps["stat"], 0.0)) + RunPayoff.amount(ps, k.carry_k)
	KinSteal.add_passives(self, out_list)  # stolen wisps at a share, clamped with the rest below
	if not merge_st.is_empty():
		for ps in KinMerge.passives(self):
			out_list[ps["stat"]] = float(out_list.get(ps["stat"], 0.0)) + float(ps["amount"])
		out_list["cooldown"] = float((merge_st.get("form", {}) as Dictionary).get("haste", 0.0))  # the form's faster ability cooldowns (MergeForm)
	for st in out_list:
		var row: Array = KinParts.OWNER_STATS[st]
		out_list[st] = clampf(float(out_list[st]), 0.0, float(row[3] if not merge_st.is_empty() else row[2]))
	_kst = out_list


## Owner bonuses from your kin's stat points, for the whole run (KinParts.STATS owner_*): max
## health now; armor, shield, regen and move speed are read where they act. Call when your kin changes.
func apply_kin_bonus() -> void:
	max_hp -= kin_hp_added
	hp = minf(hp, max_hp)
	kin_hp_added = 0.0
	var k: Kin = kin
	kin_bonus = KinLib.owner_bonus(k.ks, k.rec) if k and k.ks else {}
	kin_hp_added = float(kin_bonus.get("owner_max_hp", 0.0))
	max_hp += kin_hp_added
	hp = minf(max_hp, hp + kin_hp_added)
	kin_shield = float(kin_bonus.get("owner_shield", 0.0))


func kin_pt(key: String) -> float:
	return float(kin_bonus.get(key, 0.0))


## A short boost from a kin ability (KinParts.BUFF_STATS).
func add_buff(stat: String, amount: float, dur: float) -> void:
	match stat:
		"crit":
			crit_t = maxf(crit_t, dur)
		"dash_refill":
			dashes = max_dashes()
		"glider_cool":
			glide_fuel = minf(1.0, glide_fuel + amount)
			shot_down = false
		"guard":
			guard_t = maxf(guard_t, dur)
			guard_k = amount
		_:
			var cur: Array = kbuffs.get(stat, [0.0, 0.0])
			kbuffs[stat] = [maxf(float(cur[0]), amount), maxf(float(cur[1]), dur)]


func buff(stat: String) -> float:
	var b: Array = kbuffs.get(stat, [0.0, 0.0])
	return float(b[0]) if float(b[1]) > 0.0 else 0.0


func mass() -> float:
	return float(cdat.get("mass", 1.0))


## A downed Hunter is a Wisp (decision 0019): shots and areas pass through it. Stomps, executes and revives
## reach it by their own rules (Life), not through here.
func hittable() -> bool:
	return not dead and not out and not extracted and not riding and not downed


func targetable() -> bool:
	return hittable() and cloak_t <= 0.0 and not dropping


func is_local() -> bool:
	return ctrl == "local"


## A cursor closer than this many body widths (2 r) says nothing about a way to face: aim_dir keeps the last good one.
const AIM_MIN_BODIES := 2.0
var aim_good := Vector2.ZERO  # the last aim direction taken from a cursor outside that circle


func aim_dir() -> Vector2:
	if ak and ak.aim_lock() != Vector2.ZERO:
		return ak.aim_lock()
	var d := Vector2(inp["aim"].x - pos.x, inp["aim"].z - pos.z)
	if d.length() > r * AIM_MIN_BODIES:
		aim_good = d.normalized()
	elif aim_good == Vector2.ZERO:
		aim_good = Vector2(sin(face), cos(face)) * -1.0
	return aim_good


# ------------------------------------------------------------------ damage
func _mitigate(dmg: float, by: Ent, opts: Dictionary) -> float:
	if (inv_t > 0.0 or dropping) and opts.get("src", "") != "fall":
		# dashing through an attack right as it lands: a perfect dodge
		if (
			not dropping
			and not dodged
			and m.time - dash_at < 0.22 * (ak.pd_k() if ak and ak.has_method("pd_k") else 1.0)
			and by != null
			and by.team != team
			and dmg >= 4.0
		):
			dodged = true
			dashes = minf(max_dashes(), dashes + 0.6)
			crit_t = maxf(crit_t, 1.5)
			m.on_perfect_dodge(self)
			if ak:
				ak.on_perfect_dodge()
		return 0.0
	if ctrl == "local" and Game.god:
		return 0.0
	reveal_t = maxf(reveal_t, 1.0)
	# (a hot glider or the tide never breaks a channel)
	hurt_at = hurt_at if opts.get("src", "") == "heat" else m.time
	if base_t > 0.0 and dmg > 0.0:
		BaseRecall.cancel(self, "you took damage", true)
	if opts.has("wallstun"):
		wallstun = float(opts["wallstun"])
		wallstun_at = m.time
	# Getting hit while gliding, as in Supervive: a hit does NOT knock you out of the air by itself
	# and you take normal damage. What it does is drain the glider at triple the usual rate. Only
	# when the glider runs dry are you spiked (stunned, plummeting, a 0.7s stun when you land; over
	# the abyss that's a fall). Monsters drain it but can't spike you.
	var spiked := false
	if gliding and not dropping and dmg > 0.0 and opts.get("src", "") not in ["fall", "burn", "heat", "zone"]:
		var was := glide_fuel
		glide_fuel = maxf(0.0, glide_fuel - dmg * HunterMove.hit_heat_per_dmg / float(cdat.get("glide_cap", 1.0)))
		hit_heat_t = 1.0
		if is_local() and m.hud and m.hud.has_method("glider_hit"):
			m.hud.glider_hit(was - glide_fuel)
		if opts.get("src", "") == "mob" or by is Mob:
			glide_fuel = maxf(glide_fuel, 0.02)  # monsters can't spike
		elif was <= 0.001 or glide_fuel <= 0.001:
			spiked = true
			GlideSpike.shoot_down(self)
			GlideSpike.credit(by)
	var d := dmg
	if ctrl == "local" and m.opts.get("tutorial", false):
		d *= 0.35
	d *= 1.0 - owner_stat("damage_reduction")
	if downed:
		return Life.wisp_hit(self, by, dmg, opts)
	var d_in := d
	d = MergeShell.absorb(self, d, opts, by)  # a merged form's shell takes the hit first (docs/decisions/0003)
	var shelled := false
	if d <= 0.0:
		if d_in <= 0.0:
			return 0.0
		shelled = true  # the shell took all of it: a token hit that skips the other defences but still counts
		d = 0.01
	if shield > 0.0 and not shelled:
		var a := minf(shield, d)
		shield -= a
		d -= a
		ShieldSfx.hit(self, a)
		SoakNumber.at(self, by, a, HudStyle.NUM_SHIELD)  # what the shield took, in its own look
		if shield <= 0.0:
			shield_kind = ""
		if d <= 0.0:
			flash_t = 0.06
			return 0.0
	if drink_t > 0.0 or kit_t > 0.0 or box_reviving():
		d *= CONSUME_VULN
		# drinking, repairing or reviving leaves you open: any real hit spills it (you keep the item)
		if d >= 1.0 and opts.get("src", "") != "heat":
			_interrupt_consume()
	if armor > 0.0 and not shelled and opts.get("src", "") not in ["fall", "burn", "heat", "zone"]:
		d *= 1.0 - float(ARMOR_TIERS[armor_tier][3])
		# your kin's armor stats make it wear more slowly
		armor = maxf(0.0, armor - d * (1.0 - minf(0.6, owner_stat("armor") + kin_pt("owner_armor"))))
		if armor <= 0.0:
			m.on_armor_break(self, by)
	if gliding and d > 0.0:
		m.fx.burst(pos + Vector3(0, 1.6, 0), Color("ffb070"), 6, 2.5, 0.3, 6.0)  # the glider takes the heat
	# only another hunter's damage (or their kin's) knocks you out of extracting, not monsters
	if extract_prog > 0.0 and d > 0.0 and by != null and not (by is Mob):
		var src: Ent = by
		if by is Kin and (by as Kin).owner_h:
			src = (by as Kin).owner_h
		if src is Hunter and src.team != team:
			extract_prog = 0.0
			if is_local() and m.hud:
				m.hud.toast("Extraction interrupted", Color("ff9a8a"))
	if kin_shield > 0.0 and d > 0.0 and not shelled and opts.get("src", "") not in ["fall", "heat"]:
		# your kin's owner shield soaks last; a fully soaked hit still counts as a hit (truces, interrupts)
		var ks0 := minf(kin_shield, d)
		kin_shield -= ks0
		SoakNumber.at(self, by, ks0, HudStyle.NUM_SHIELD)
		d = maxf(0.01, d - ks0)
		opts["soaked"] = ks0
	return d


func hit_y() -> float:
	return lip_y if below_lip else pos.y


## Over the abyss and below the lip of the nearest island? Ground level is the lowest land close by.
func update_lip() -> void:
	below_lip = false
	if grounded or downed or out or riding or dropping or not over_void():
		return
	var ref := INF
	for loc_r in [1.5, 3.0, 5.0, 7.5]:
		for i in 12:
			var a := TAU * i / 12.0
			var x: float = pos.x + cos(a) * loc_r
			var z: float = pos.z + sin(a) * loc_r
			if not m.world.is_void(x, z):
				ref = minf(ref, m.world.ground_at(x, z))
		if ref < INF:
			break
	if ref == INF:
		ref = last_gy
	lip_y = ref
	below_lip = pos.y < ref - 0.5


## Where shots hit you, drawn so everyone can track it in a top-down view. Your body is the target
## while you stand or hop (a hop still counts as standing on your terrace). Below an island's lip
## a balloon on a string floats at ground level above you: that's what everyone aims at. High in
## the air over land, a ring on a faint string hangs under you at the height shots catch you. The
## ring is always your real hit circle (radius r + Match.HIT_SLACK) on the plane you're hit as if
## standing on (Match.shot_stance_y), and the balloon is that circle's size too, at shot height.
## Enemies' markers are red, allies' their team colour, yours faint. A hit through a marker flashes
## it. The balloon glows purple once your glider is overheated, when the next hit spikes you.
const MARKER_BALL_Y := 0.95  # balloon centre above the stance: where a level shot flies
const MARKER_FLASH := 0.3
const MARKER_ALLY_A := 0.5  # an ally's marker is half see-through, since you never shoot at it
var balloon: Node3D  # the hit marker: Ring, Ball, Knot, Aura, String
var mk_ring: MeshInstance3D
var mk_ball: MeshInstance3D
var mk_knot: MeshInstance3D
var mk_aura_n: MeshInstance3D
var mk_str: MeshInstance3D
var mk_kind := ""
var mk_col := Color(0, 0, 0, 0)
var mk_flash := 0.0
var mk_flashing := false
static var mk_quad: PlaneMesh
static var _mk_mats := {}  # shared materials, by colour: {"ring", "ball", "knot"}
static var mk_aura: ShaderMaterial
static var mk_string: ShaderMaterial


## The radius of the circle shots hit you in (a bullet touching it connects).
func hit_radius() -> float:
	return r + Match.HIT_SLACK


## Which marker shows where shots hit you: "balloon" (below a lip), "ring" (high over land), or ""
## when your body itself is the target.
func hit_marker() -> String:
	return HunterMarker.hit_marker(self)


## A shot connected: if it hit you through your marker, the marker flashes.
func marker_hit() -> void:
	HunterMarker.marker_hit(self)


static func _marker_mats(c: Color) -> Dictionary:
	if _mk_mats.has(c):
		return _mk_mats[c]
	var d := {}
	if c == Color.WHITE:  # the flash
		d["ring"] = SideRings.mat(Color(1, 1, 1, 1), 0.3)
		d["ball"] = Models.toon(Color(1.0, 0.97, 0.9), true, 1.0)
		d["knot"] = d["ball"]
	else:
		d["ring"] = SideRings.mat(c, 0.2)
		d["ball"] = Models.toon(Color(c, 1.0), c.a > 0.75, 0.35 if c.a > 0.75 else 0.1)
		d["knot"] = Models.toon(Color(c, 1.0).darkened(0.3), false)
	_mk_mats[c] = d
	return d


## The marker's colour as the local player sees it.
func _marker_col() -> Color:
	return HunterMarker._marker_col(self)


func _build_marker() -> void:
	HunterMarker._build_marker(self)


## Builds the hit-marker balloon hidden, with its materials, under the loading screen (Match.warm_up): built
## lazily, its first showing in a fight compiled its shaders mid-frame (item 94's repeatable hitch).
func warm_marker() -> void:
	HunterMarker.warm_marker(self)


func _render_balloon(delta: float) -> void:
	HunterMarker._render_balloon(self, delta)


## Knockback is a clean, predictable shove: a knock replaces the flight you were in (Displace.knock_speed: a
## second knock takes over from the first, a pull or a reel), you slide for a fixed moment without control,
## and it never pops you into the air unless the attack says so. knock_t (HunterLoco.knock_left) is how long it lasts.
var launched_at := -9.0  # when a hard shove or a launch last hit you (Capture.controlled: it interrupts a rescue or a scan)
var knock_steer := 0.3  # how much WASD bends a knockback (the attack decides: 0.3 to 0.5)


func impulse(kbv: Vector2, lift := -1.0) -> void:
	if fortify_t > 0.0:
		return
	var k := kbv * (1.0 - owner_stat("knockback_resist"))
	var s := k.length() / mass()
	if s >= Capture.HARD_KNOCK or lift / mass() >= 3.0:
		launched_at = m.time
	if s < 0.05:
		if lift > 0.0:  # (only a lift above 0 leaves the ground: a 0 riding a slow or a shove is no launch)
			# a straight-up lift (a slam's crater, an eruption) with no sideways push
			vel.y = maxf(vel.y, minf(9.0, lift / mass()))
			grounded = false
		return
	if s > 4.0:
		kb_t = m.time
	var hv := Displace.knock_speed(Vector2(vel.x, vel.z), k / k.length(), s)
	vel.x = hv.x
	vel.z = hv.y
	if s >= Displace.KNOCK_MIN:
		knock_t = clampf(0.1 + s * 0.02, 0.12, 0.35)
		HunterMove.cut_air_dash(self)
		if m is Match:
			(m as Match).displace.knocked(self)
	if lift > 0.0:
		vel.y = maxf(vel.y, minf(9.0, lift / mass()))
		grounded = false


func _on_zero(by: Ent, opts: Dictionary) -> void:
	if remote or downed:
		return
	m.knock(self, by, opts)


# ------------------------------------------------------------------ actions
func do_jump() -> void:
	HunterAir.do_jump(self)


## Feathering [est] (SUPERVIVE players tap the glider on and off instead of holding it): opening and
## closing are instant with no penalty for quick toggles; only the ground cools the glider ([footage]
## "it only really cools on the ground"); after a close you fall like any jump (Loco.air_step: the glide's
## extra over run speed bleeds off), so skilled taps (short lifts out of the abyss, coasting the gaps) cover
## more ground per heat than holding. Numbers in docs/MOVEMENT_FEEL.md; measured by --move-feel-check (feather_*).
var glide_off_t := 9.0  # seconds since the glider closed in the air (9 = long ago / on the ground)
var lift_t := 0.0  # seconds of the current abyss lift (feathering taps stay in the cheap part)


## The glider's vertical speed this step below an island's lip over the abyss, `depth` metres under
## it: it pulls you up harder and faster the deeper you are (HunterFeel.abyss_lift*), then brakes into the last
## HunterFeel.abyss_brake_dist so you arrive at ground level (let go just before to carry the climb up as height).
## Shared by Hunter (matches, the --training ground) and Home (the farm).
static func abyss_lift_vy(vy: float, depth: float, dt: float, k := 1.0) -> float:
	if depth > HunterFeel.abyss_brake_dist:
		var acc := (HunterFeel.abyss_lift + HunterFeel.abyss_lift_per_m * depth) * k
		var top := (
			minf(HunterFeel.abyss_lift_max + HunterFeel.abyss_lift_max_per_m * depth, HunterFeel.abyss_lift_cap) * k
		)
		# a fall is caught at once (the canopy bites), then the climb builds
		if vy < 0.0:
			vy = move_toward(vy, 0.0, (acc + Loco.glide_catch) * dt)
		return minf(vy + acc * dt, maxf(top, vy))
	return move_toward(
		vy, maxf(depth * HunterFeel.abyss_brake_gain, HunterFeel.abyss_lip_vy), HunterFeel.abyss_brake * dt
	)


## Real keys only open the glider with a fresh press in the air (a second Space, or the glide button). Opening uses
## the press up, so a fold (heal, dash, a knock) stays shut until a new press; release or landing clears it too.
var glide_armed := false
var glide_btn_held := false


func can_glide() -> bool:
	return HunterGlide.can_glide(self)


## Item 4: a fresh glide press at any moment of an air Shift dash ends the dash that frame (no minimum time) and
## the glide takes over at the dash's own velocity, no reset, no snap: Loco.glide_step's drag and this hunter's
## glide_carry cap tame it. A kit's rush or special movement (move_kind other than "dash") is not cancelled, unless
## the kit lets go of its own flight on the press (ArchKit.glide_cancel: Rock Hop's launch_to). The dash's own
## wind-down (glide_cd a kit set at its start, or left by the dash before in a chain) goes with it.
## A press just after the dash (DashGlide.fresh) counts as one in it, past the kit's wind-down (decision 0061).
func _dash_into_glide() -> bool:
	return HunterGlide._dash_into_glide(self)


func _open_glider() -> void:
	HunterGlide._open_glider(self)


var boost_fx_t := 0.0  # the boost trail lasts while you're well above cruise speed (render)


## The glider's open/close sound for this hunter's glider skin (quieter, and positional, for everyone else).
func glider_sfx(which: String) -> void:
	HunterGlide.glider_sfx(self, which)


## Shift, as in Supervive: the long dash (its own cooldown) in the air or with no short one ready.
var ex_cd: float:
	get:
		return dash.ex_cd
	set(v):
		dash.ex_cd = v
var used := {}  # slot -> times you pressed it and it went off (the tutorial reads this)
var hit_heat_t := 0.0  # a moment after being hit while gliding, the glider heats twice as fast
var ex_next := false
var dash_is_ex := false
## Movement chains (Supervive): Shift during a glove rush cancels it into the dash; during a dash
## or a ledge climb it's buffered and fires the moment that ends; off a jump pad (after the first
## beat of the launch) it breaks the pad flight into a dash. Jump out of a ground dash keeps half
## its speed. Dash in the air and keep holding glide and the glider opens again as the dash ends.
## B: base to a teammate (BaseRecall: the channel, its cancels and the arrival; BaseWheel: the hold-B pick).
var base_t := 0.0  # s left on the channel (0: not basing)
var base_to: Hunter = null  # the teammate you will appear beside
var base_cd := 0.0
var base_tele: Node3D = null  # the filling circle under that teammate, for everyone to see
var weak_t := 0.0
var dash_buf := 0.0
var air_peak := 0.0  # the highest point of this time in the air (for skyfall landings)
const SKYFALL_H := 8.0  # drop at least this far, fast, onto rivals and you land a skyfall


## Height pays off: come down hard from 8m+ (not gliding gently, not the opening drop) and the
## landing slams everyone close: damage that grows with the height and a pop into the air.
func _skyfall(drop: float, fall_v: float) -> void:
	HunterGlide._skyfall(self, drop, fall_v)


var move_kind := "dash"  # what the current roll is: "dash" (Shift) or "rush" (an ability or glove)
var roll_falls := false  # this ground dash ran off a ledge: it falls as it goes (HunterMove.dash_off_ledge)
const DASH_KEEP := 0.5  # s: a press inside a dash this short waits for its end (a longer lock drops it)


func do_dash() -> void:
	HunterDash.do_dash(self)


## The theme of the kin you brought ("venom", "lunar"...). Cosmetic only: it tints, never rules.
func kin_element() -> String:
	if kin == null or (kin as Kin).dead:
		return ""
	return String(Data.KIN.get((kin as Kin).species, {}).get("type", ""))


var roll_speed := DASH_SPEED
var dash_rest := Vector2.ZERO  # metres: the dash's own last moment, riding on the step that hands it over
var wedged_t := 0.0


## World.occupy, with the sky train in it: on a car's deck you walk freely (the deck is your floor,
## whatever the ground far below or a bridge overhead is doing), the engine is a wall, and walking
## off a car only takes you onto ground about level with the deck (a pier at a stop): the edge of a
## car over the abyss holds you like any island edge. Dashes, knockback and jumps go over it.
func _occ(x: float, z: float, guard: bool) -> float:
	return HunterDash._occ(self, x, z, guard)


## True only when there's no direction at all you could step: really stuck, not just walking into a wall.
func _boxed_in() -> bool:
	return HunterDash._boxed_in(self)


var shove := {}  # the heavy charge: who it already hit, and how hard it shoves


func dash_with(e: Dictionary) -> void:
	HunterDash.dash_with(self, e)


## A grammar dash you perform (or a kit's dash that hits): what you dash through gets its effects.
func _pass_along(dt: float) -> void:
	HunterDash._pass_along(self, dt)


func _shove_along(dt: float) -> void:
	HunterDash._shove_along(self, dt)


## The weapon (HunterAttack: the attack key, guns, bows, melee, reloads) and the state it builds up
## while you fire (Supervive-style), which the animation, HUD and kits read.
var atk := HunterAttack.new(self)
var shot_n := 0
var safe_pos := Vector3.INF  # the last solid ground you stood on, well away from any edge
var wbloom := 0.0  # extra spread in degrees from firing; recovers once you stop
var warm_t := 0.0  # sniper wind-up left; the shot goes when it runs out
var spin := 0.0  # minigun spin, 0 to 1; it only fires fully spun
var spun_t := 0.0  # how long the minigun has been firing (it tightens up)
var sus_n := 0  # rounds in the current string of fire
var mel_hold := 0.0  # how long the attack key has been held with a sword
var strike_at_end := {}  # a charged lunge's hit, which lands where the lunge ends
var combo_i := 0
var swing_at := -9.0
var swing_t := 0.0  # for the swing animation, counts down
var swing_n := 0


func use_signature() -> void:
	use_kin_ability("k1")


## Is a kin with you and able to fight? (The bond meter only fills while one is.)
func has_kin_ready() -> bool:
	return kin != null and (kin as Kin).ready_to_fight()


func _ground_aim() -> Vector3:
	var a: Vector3 = inp["aim"]
	var g: float = m.world.ground_at(a.x, a.z)
	return Vector3(a.x, g if g > World.VOID + 1.0 else pos.y, a.z)


## Rail Charge and the like: hold the button and it grows; let go (or hold past full) and it fires.
func _tick_charge(dt: float) -> void:
	var ud: AbilityDef = runner.def_of("utility") if runner else null
	if ud == null or ud.charge.is_empty() or downed or stun_t > 0.0 or out:
		abil_charge = {}
		return
	abil_charge["t"] = float(abil_charge["t"]) + dt
	var full := float(ud.charge.get("time", 1.0))
	var k := clampf(float(abil_charge["t"]) / full, 0.0, 1.0)
	if not unseen:
		AbilityFx.charging(m, self, k, ud.color, clampf((float(abil_charge["t"]) - dt) / full, 0.0, 1.0))
	if not inp.get("sec_hold", false) or float(abil_charge["t"]) >= full + 0.6:
		abil_charge = {}
		if runner.use("utility", {"level": ability_level("sec"), "charge": maxf(k, float(ud.charge.get("min", 0.0)))}):
			used["utility"] = int(used.get("utility", 0)) + 1
			_ab_feedback("sec", "cast")
			if k >= 1.0:
				m.fx.flash(pos + Vector3(0, 1.0, 0), ud.color, 0.6, 0.08)


## How far along a held charge is, 0..1 (-1 when not charging).
func charge_frac() -> float:
	var ud: AbilityDef = runner.def_of("utility") if runner else null
	if abil_charge.is_empty() or ud == null or ud.charge.is_empty():
		return -1.0
	return clampf(float(abil_charge["t"]) / float(ud.charge.get("time", 1.0)), 0.0, 1.0)


## The rank of one of your ability slots this run (slot_lv, 1..3; the ult 1..2). Ranks raise an
## ability's numbers: +15% damage, its "per_level" numbers (range, duration, radius...) and a shorter
## cooldown. Any slot name works: "sec"/"utility" (RMB), "dash"/"dodge" (Shift), "gear"/"gear0" (Q),
## "kin"/"k1" (E), "ult"/"r" (R).
const SLOT_ALIAS := {
	"utility": "sec", "dodge": "dash", "gear0": "gear", "q": "gear", "k1": "kin", "e": "kin", "r": "ult"
}


func ability_level(slot: String) -> int:
	return HunterKit.ability_level(self, slot)


## The rank line on an ability's hover panel ("" for things that don't rank).
func rank_text(slot: String) -> String:
	return HunterKit.rank_text(self, slot)


## Cooldown multiplier for a slot's rank: 10% shorter per rank past the first.
func rank_cd_k(slot: String) -> float:
	return HunterKit.rank_cd_k(self, slot)


## What the HUD needs to draw one ability slot: name, short name, icon, colour, one-line desc,
## cooldown left and total, charges. slot: "sec" | "dash" | "gear" | "k1" | "r".
func slot_info(slot: String) -> Dictionary:
	return HunterKit.slot_info(self, slot)


## Q and V: your active kin's abilities, aimed at the cursor.
func use_kin_ability(slot: String) -> void:
	HunterKit.use_kin_ability(self, slot)


## C (with an archetype): your Boki's own ability, cast from wherever the Boki is (KinCommand.cast_c).
## On your shoulder it is cast through you; out in the field it casts where it stands.
func use_boki_c() -> void:
	HunterKit.use_boki_c(self)


## R: the Merge (KinMerge.press): a full bond meter merges you with your Boki, with the Boki out it
## leaps back and merges, with none able to fight it is a weak surge.
func use_ultimate() -> void:
	HunterKit.use_ultimate(self)


## Tells the HUD a button press landed ("cast": the slot pops) or didn't ("deny": PressDeny's red pulse
## and tick), so a press on cooldown never just silently does nothing.
func _ab_feedback(slot: String, kind_name: String) -> void:
	HunterKit._ab_feedback(self, slot, kind_name)


## X: swap which of your two kin is out. The benched one rests in your satchel.
func swap_kin(force := false) -> void:
	HunterKit.swap_kin(self, force)


## Riders your kin puts on every shot or swing (KinSpec carry.on_shot while it rides with you, the
## merge's on_shot while merged): damage over time, slow, push, marks, splash and arcs. Never stun or root.
func _kin_riders(extra: Dictionary) -> void:
	HunterKit._kin_riders(self, extra)


func heal(n: float) -> void:
	if downed or out:
		return
	if remote:
		m.net_event(["heal", nid, n])
		m.fx.healed(self, minf(n, max_hp - hp))  # its own game heals it; the heal shows here now
		return
	if blight_t > 0.0:
		n *= 1.0 - blight_k  # blighted: healing barely takes
	var before := hp
	hp = minf(max_hp, hp + n)
	m.fx.healed(self, hp - before)


## Drinking a tonic and repairing with an armor kit take a moment: you slow down, lower your gun and
## are open to hits (CONSUME_VULN). Dashing, getting stunned or going down spills it (you keep the item).
## The belt and what each item does: UtilityBelt, UtilityUse.
var drink_t := 0.0
var drink_id := "tonic"  # which belt drink is being drunk, and how long it takes (UtilityUse, the item's "time")
var drink_len := 1.0
var kit_t := 0.0
var beat_id := ""  # the instant belt item whose body beat is playing (UtilityPose)
var beat_t := 0.0
var kit_len := 1.6  # how long the armor kit takes (its "time"; both lengths are set when a use starts)
var vuln_fx_t := 0.0  # paces the pulsing "vulnerable" tell while drinking or repairing
var finish_t := 0.0  # holding interact over a downed enemy (until the stomp commits)
var stomp: Dictionary = {}  # committed stomp on an enemy wisp: {o, t, hits} (see Life)


## Channelling a deathbox revive right now (Match._update_interact keeps box_rev_at fresh).
func box_reviving() -> bool:
	return m.time - box_rev_at < 0.12 and not downed and not out


func launch_to(target: Vector3, t: float) -> void:
	HunterAir.launch_to(self, target, t)


# ------------------------------------------------------------------ simulation
func sim(dt: float) -> void:
	HunterSim.sim(self, dt)


func pad_launch(to: Vector3) -> void:
	HunterAir.pad_launch(self, to)


func _pad_fly(dt: float) -> void:
	HunterAir._pad_fly(self, dt)


## Where a mantle has you at progress k (0..1): up the face with an ease-out (a quick pull that
## slows near the top), then over the lip with a small hop and an ease-in-out onto the top. The
## height never drops below the lip while you're over the cliff, so you can't sink into it.
func _mantle_point(k: float) -> Vector3:
	return HunterLedge._mantle_point(self, k)


## True while you're rising up a ledge (or in a scripted pad mantle).
func mantling() -> bool:
	return HunterLedge.mantling(self)


## How far through the climbing part of a mantle you are (0 when not mantling), for the animation.
func mantle_k() -> float:
	return HunterLedge.mantle_k(self)


## Lost to the abyss: over the void a few metres below the lowest island lip around you (see
## World.abyss_floor), so a fall is over quickly instead of dropping a long way under the islands.
## A glider that still has heat gets a little more room to lift you back out. Over solid ground nobody is
## lost, however deep under it (_unclip puts them back on it).
func _in_abyss() -> bool:
	if grounded or not over_void():
		return false
	return pos.y < -40.0 or pos.y < abyss_kill_y()


## (movefeel) The point of no return under you: below this you're lost to the abyss. World.ABYSS_DEPTH
## (6m, shared with monsters and the home island) plus HunterFeel.abyss_extra for hunters, so there's real room to
## recover with the glider, an updraft or a ledge float; a glider with heat left gets HunterFeel.abyss_glide_room
## more. The HUD's abyss danger reads this (AbyssFx.danger).
func abyss_kill_y() -> float:
	var fl: float = m.world.abyss_floor(pos.x, pos.z, last_gy) - HunterFeel.abyss_extra
	if gliding and glide_fuel > 0.001:
		fl -= HunterFeel.abyss_glide_room
	return fl


## Islands are solid all the way down: if anything (a pull, a drag, a shove) has left you inside an
## island's column below its top, you're put back beside it, or on top when the top is in reach.
func _unclip() -> void:
	HunterAir._unclip(self)


## Falling with the canopy folded: the opening skydive, or the glider's dive.
func plunging() -> bool:
	return diving or glide_dive.on


## The skydive ends: the glider snaps open and the fall slows right down.
func _deploy() -> void:
	if not diving:
		return
	diving = false
	glide_k = 0.0
	# (movefeel) the canopy bites: your fall checks hard (HunterFeel.deploy_pop), then settles to the drop's sink
	vel.y = maxf(vel.y, HunterFeel.deploy_pop)
	m.sfx("glide", pos, -2.0)
	glider_sfx("open")


## Using a heal in the air: the glider folds (it can't be held while you drink; a fresh glide press
## opens it after a beat and spills what's left). The opening drop never gets here (AirLimits).
func _fold_for_action() -> void:
	if gliding and not dropping:
		gliding = false
		glide_cd = maxf(glide_cd, 0.4)
		glider_sfx("close")


## Knocked out of a drink, a repair or a box revive: it spills (nothing is used up) and everyone sees it.
func _interrupt_consume() -> void:
	if drink_t <= 0.0 and kit_t <= 0.0 and not box_reviving():
		return
	if drink_t > 0.0 or kit_t > 0.0:
		UtilityUse.spill(self)
	else:
		m.fx.burst(pos + Vector3(0, 1.3, 0), Color("ff7a4a"), 10, 3.0, 0.35, 8.0)
		m.sfx("crit", pos, -4.0, 0.7)
	BoxRevive.cancel(self)


## Hold jump while falling to open the glider. It folds when you land, let go, dash, are stunned or spiked.
var air_t := 0.0  # time since you left the ground


func _update_glide(dt: float) -> void:
	HunterGlide._update_glide(self, dt)


# Ledge float: touch the side of any ground above you while you're still alive and you float
# back up onto it, the way Supervive does it. Walking into a step up a few terraces high does
# the same after a short push. Getting launched hard still carries you past the edge.
func _try_ledge_grab(dt: float) -> void:
	HunterLedge._try_ledge_grab(self, dt)


## (ledge rise) One step of rising up a ledge: sets vel.y and returns true while it lasts. Your
## horizontal speed is the ordinary air steering (_physics): keys and momentum work the whole way,
## and the wall itself (World.occupy) is all that holds you to the face while you push into it.
## Over the top you pop up a little toward your keys. Moving off the face, a fresh glide press, a stun or a
## knock end it. A press in the rise goes by its mantle row (DashFlow); a jump flings you (_ledge_fling).
const LRISE_PUSH := MantleCarry.APPROACH_DOT  # home.gd's ledge rise reads this (keys this far into the wall)


func _ledge_rise(dt: float, mv: Vector2) -> bool:
	return HunterLedge._ledge_rise(self, dt, mv)


func teleport(p: Vector3) -> void:
	super(p)
	MantleCarry.forget(self)
	slide_n = Vector2.ZERO  # (the wall the last step pressed is not here)


## A jump during a ledge rise: in the window near the top, a strong fling (higher, faster, a whoosh);
## earlier, a weaker one. Either way toward the keys you hold (or up and onto the ledge with none).
func _ledge_fling() -> void:
	HunterLedge._ledge_fling(self)


## Floating up the side: rise to the lip, drift onto it, then a small hop onto the top.
func _grapple(dt: float) -> void:
	HunterLedge._grapple(self, dt)


# ------------------------------------------------------------------ visuals
var bot_look: Dictionary = {}  # how a bot hunter looks (random)
var runner: AbilityRunner  # weapon utility now; kin abilities later
var dodge_def: AbilityDef  # the class's dodge
var stats := {}  # this match's counts for challenges (the local player's)
var gear: Array = Gear.empty_slots()  # four slots of found gear (Gear.SLOTS): {id, rar}
var gear_cd: Array = [0.0, 0.0, 0.0, 0.0]

# ---- run levels: like Supervive, you start each run at level 1 with one skill point and every
# ability locked. XP comes from knocks and lair bosses, never from time or from damage; each level gives a
# point to unlock or strengthen an ability. The ultimate opens at level 6 (rank 2 at 9, rank 3 at 10).
const XP_TO := [0.0, 70.0, 170.0, 300.0, 460.0, 650.0, 870.0, 1120.0, 1400.0, 1710.0]  # total XP to reach level i+1
const SLOTS := ["sec", "dash", "kin", "ult"]  # the hero's own abilities; gloves never rank (Gloves)
const SLOT_MAX := {"sec": 3, "dash": 3, "kin": 3, "ult": 3}
const ULT_AT := [6, 9, 10]  # run level each R rank opens at (0022)
var lvl := 1
var xp := 0.0
var skill_pts := 1
var level_ups := 0  # how many times this run the local level-up moment played (tests)
var slot_lv := {"sec": 0, "dash": 0, "kin": 0, "ult": 0}


func gain_xp(x: float) -> void:
	HunterProgress.gain_xp(self, x)


func xp_frac() -> float:
	return HunterProgress.xp_frac(self)


func can_level(slot: String) -> bool:
	return HunterProgress.can_level(self, slot)


func level_slot(slot: String) -> bool:
	return HunterProgress.level_slot(self, slot)


## Bots (and anyone skipping the choice) spend points in a sensible order.
func _bot_spend() -> void:
	HunterProgress._bot_spend(self)


## Everything open at rank 1, for practice modes.
func unlock_all() -> void:
	HunterProgress.unlock_all(self)


## Every ability key pressed this step: a locked one takes a point if you have one (HunterProgress._gate).
func gate_ranks() -> void:
	HunterProgress.gate_ranks(self)


## Armor evolves through a run, like Supervive's: damage you deal to rival hunters fills it (monsters
## count a third), and a knock adds a big chunk. Each tier blocks more and may hold more durability
## (the new durability arrives full). Tier colour shows on everyone's armor bar, so you can read how
## fed a rival is. Rows: [name, colour, xp to reach, damage reduction, durability] (ArmorRules).
static var ARMOR_TIERS: Array = ArmorRules.tiers()
const ARMOR_KNOCK_XP := 140.0
var armor_xp := 0.0
var armor_tier := 0
var dmg_taken := 0.0
var downs := 0  # times knocked this match
var deaths := 0
var revives := 0  # teammates you picked up


## Adds armor progress; returns the new tier if it went up, else -1.
func armor_gain(xp_amount: float) -> int:
	return HunterGear.armor_gain(self, xp_amount)


## How far into the current tier (0..1), for the HUD.
func armor_frac() -> float:
	return HunterGear.armor_frac(self)


func armor_col() -> Color:
	return HunterGear.armor_col(self)


func refresh_gear() -> void:
	HunterGear.refresh_gear(self)


func gear_stat(k: String) -> float:
	return HunterGear.gear_stat(self, k)


var worn_sums := {}  # stat key -> what the worn gear and the perks add, summed once a step
var worn_t := -1.0  # Match.time the sums above are from (gear_stat is asked ~14 times a step)


## Ground speed while you ride your mount (its carry.mount speed), as a share of your own.
func mount_speed() -> float:
	return HunterGear.mount_speed(self)


func _took(d: float, _by: Ent) -> void:
	DashReset.second_wind(self, hp + d)


## How many stacks of a perk you've picked up this run.
func perk_n(id: String) -> int:
	return HunterProgress.perk_n(self, id)


## Can this perk still be offered to you (a free perk slot, not at its stack limit)?
func perk_open(id: String) -> bool:
	return HunterProgress.perk_open(self, id)


## Takes a perk for the rest of the expedition. Stats that are worked out once (health, glider,
## armor) are updated on the spot.
func add_perk(id: String) -> void:
	HunterProgress.add_perk(self, id)


func add_stat(k: String, n := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n


var unseen := false  # hidden from the local player (in a bush, or behind a wall)

var drawn_y := INF  # m: where StepSmooth draws the body (INF until it first draws)
## The sniper's aiming laser while it winds up, and the minigun's barrels spinning.
var laser: MeshInstance3D


func _render_weapon_fx(delta: float) -> void:
	var on := warm_t > 0.0 and visible and not unseen
	if on and laser == null:
		laser = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.04, 1.0)
		laser.mesh = bm
		laser.material_override = Models.glow_mat(Color(wpn["color"], 0.7))
		laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		laser.top_level = true
		add_child(laser)
	if laser:
		laser.visible = on
		if on:
			var k := 1.0 - warm_t / maxf(0.01, float(wpn.get("warmup", 0.6)))
			var d := aim_dir()
			var y := position.y + 0.95 * float(cdat["scale"])
			var ln := float(wpn["range"])
			var a := Vector3(position.x + d.x * 0.6, y, position.z + d.y * 0.6)
			laser.global_transform = Transform3D(
				Basis.looking_at(Vector3(d.x, 0, d.y), Vector3.UP), a + Vector3(d.x, 0, d.y) * ln * 0.5
			)
			laser.scale = Vector3(lerpf(2.5, 0.6, k), lerpf(2.5, 0.6, k), ln)
			(laser.material_override as ShaderMaterial).set_shader_parameter(
				"color", Color(wpn["color"], lerpf(0.25, 0.9, k))
			)
	if spin > 0.0 and model:
		var br: Node3D = model.find_child("Barrels", true, false)
		if br:
			br.rotation.z += delta * spin * 40.0


## For the animation: when this hunter last cast an ability (or threw its kin), and which.
var cast_at := -9.0
var cast_slot := ""


func _on_ability_used(caster: Node, _id: String, slot: String) -> void:
	if caster == self:
		MergeAugment.on_used(self, slot)  # a merge form's add-ons on RMB, E and Shift
		if m:
			HostileCue.on_used(self, slot)  # a rival's E or R sounds like a threat
	if caster == self and slot != "dodge" and slot != "primary" and m:
		cast_at = m.time
		cast_slot = "ult" if slot in ["ult", "ultimate"] else slot
	if slot in ["k1", "k2"] and kin is Kin and (caster == kin or caster == self) and is_local() and m:
		BokiChatter.say(m, kin, "ability")  # its own ability, used by it or through you


func _on_kin_thrown(_k: Node, owner_node: Node) -> void:
	if owner_node == self and m:
		cast_at = m.time
		cast_slot = "throw"


## The state HunterAnim poses the model from (one dictionary, refilled every frame).
var anim_s := {}
var anim_dt := 0.0
var anim_n := 0
const DODGE_ANIM := {"light": "phase", "medium": "roll", "heavy": "charge"}


## How far up the face a ledge rise has you (0 at the start, 1 at the lip), -1 when not rising: the animation's progress.
func _rise_k() -> float:
	return HunterRender._rise_k(self)


func _anim_state(stretch: float) -> void:
	HunterRender._anim_state(self, stretch)


## (movefeel) Hunters are drawn a little larger in a match so they read on screen (owner: SUPERVIVE's
## heroes "feel more important"), times the camera style's hunter_scale. Visual only: the hitbox (r),
## the TeamRing hit circle under your feet, shot heights and the balloon marker are unchanged.
const VIS_SCALE := 1.12
var vis_k := 1.0  # the scale fit_scale last put on this model


func set_model(n: Node3D) -> void:
	super.set_model(n)
	HunterRender.after_model(self, n)


## Puts VIS_SCALE x the camera's hunter_scale on the model (again when the Settings camera changes).
func fit_scale() -> void:
	HunterRender.fit_scale(self)


## (movefeel) Where to draw this hunter between simulation steps. Everyone else is interpolated
## (drawn up to one step in the past, which is smooth); the local player is drawn at the present
## instead, extrapolated by the fraction of a step since the last one, so a key press shows on the
## very next frame and the camera never trails the sim. A teleport (a big jump between steps) snaps.
const LOCAL_RENDER_LEAD := true


func render_pos(alpha: float) -> Vector3:
	return HunterRender.render_pos(self, alpha)


func render(delta: float, alpha: float) -> void:
	super.render(delta, alpha)
	HunterRender.after_render(self, delta, alpha)
