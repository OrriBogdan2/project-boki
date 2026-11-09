class_name Hunter
extends Ent
## A player or bot hunter: movement, weapon, dash, jump, ledge grab, class signature, downed state.

# Supervive feel (see docs/SUPERVIVE_FEEL.md): near-instant ground control, momentum that carries in
# the air and in the glider. Air, fall and glide-height tunables are in content/rules/hunter_move.json.
const H_GRAV := 14.7             # m/s^2 [game data] DefaultGravityZ -1470 uu/s^2, the same up and down
# ---- movement feel (movefeel, Oct 31 2026): every value and its source is in docs/MOVEMENT_FEEL.md,
# measured by --move-feel-check. Snappy first: input acts the step it arrives, falls hit the
# footage depth, the glider opens and steers at once and keeps the momentum you bring into it.
const GLIDE_CATCH := 60.0        # the canopy brakes a terminal fall to its sink rate in ~0.13s (was 16: ~0.45s, sluggish)
# m/s: [game data] JumpZVelocity is 7.5 (1.9m up); ours stops ~1.5m up so jump + mantle still tops
# out under four terraces (the wall kick's job) on our 0.8m terraces
const JUMP_V := 6.8
const JUMP_BUFFER := 0.12        # a jump pressed this long before you land goes off as you land (FeelConfig)
const GROUND_ACCEL := 90.0       # [spec] near-instant: top speed in ~0.055s (was 70)
const GROUND_SHED := 110.0       # m/s^2, no keys: speed over a run (kit step, knock) sheds this fast
const GROUND_OVERSPEED := 30.0   # how fast dash or pad speed bleeds off on the ground
const AIR_ACCEL := 40.0          # a ledge rise steers crisply (a jump steers by HunterMove.air_steer)
const AIR_DECEL := 9.0           # let go on a ledge rise and you mostly stop
const AIR_OVERSPEED := 3.0       # but momentum above run speed (a dash, a pad) still carries
const GLIDE_ACCEL := 16.25       # [game data] GlideTargetXYForce 162,500 / UE's 100 kg: a force, so steering has inertia
const GLIDE_DECEL := 1.4         # let go of the keys and the glider drifts on, a long soft coast
const GLIDE_OVERSPEED := 1.1     # extra glide momentum bleeds off slowly: a dash into a glide carries for seconds
const GLIDE_TURN := 420.0        # deg/s the glider turns at cruise speed (90 degrees in ~0.2s); wider arcs when fast
const GLIDE_TURN_FAST := 0.45    # ...down to this share of GLIDE_TURN at the boost cap
const GLIDE_BRAKE := 36.0        # steering more than GLIDE_BRAKE_DEG against your heading brakes this hard
const GLIDE_BRAKE_DEG := 115.0
const GLIDE_GRAV := 14.0
const GLIDE_ENGAGE := 0.1        # hold Space this long in the air before the glider opens (a tap is a jump); was 0.15
                                 # (the dedicated glide button, Mouse 5, opens it at once)
## The abyss lift [wiki: "a rapid upward impulse to ground level, then a rapid deceleration"], scaled
## by how deep you are (owner: "pull you up faster based on how low in the abyss you are"): a gentle
## lift just under the lip, a hard surge from deep down. See abyss_lift_vy (the match and home both use it).
const ABYSS_LIFT := 22.0         # [est] upward pull (m/s^2) just under the lip...
const ABYSS_LIFT_PER_M := 7.0    # [est] ...plus this per metre deeper (10m down: 92 m/s^2)
const ABYSS_LIFT_MAX := 5.0      # [est] fastest climb just under the lip...
const ABYSS_LIFT_MAX_PER_M := 1.1  # [est] ...plus this per metre deeper (12m down: ~18 m/s; item 63: ~30% under the old ~25)
const ABYSS_LIFT_CAP := 18.2     # item 63: the deepest climb is 30% softer than the old 26
const ABYSS_BRAKE_DIST := 2.5    # ...that brakes near ground level (let go just before to keep the height)
const ABYSS_BRAKE := 60.0
const ABYSS_LIP_VY := 4.5        # [est] m/s still rising as the lift reaches the lip: it bounces up past it
const ABYSS_BRAKE_GAIN := 3.5    # (movefeel) rise speed per metre left in the brake zone (was 2: the last metre crawled)
const MANTLE_REACH := 1.5        # near a jump's apex, ledges this far above you pop you up
const TALL_CLIMB_EXTRA := 0.9     # m: Archer and Juggernaut also climb double-high ledges ([game data] bCanWallJump)
const MANTLE_REACH_ABYSS := 4.5  # below an island's lip over the abyss, its side catches you this far down (movefeel: was 3.5)
                                 # (a bit past the normal ledge reach); deeper you slide down the face
const WALL_CATCH_REACH := 0.75   # (movefeel) over the abyss below a lip, a wall this far from your side catches you (elsewhere 0.4)
const ABYSS_GLIDE_ROOM := 1.5    # a glider with heat left (lifting you out) gets this much more room
const MANTLE_RISE := 14.0        # [footage] a deep mantle returns to the top in ~0.8s
const EX_DASH_CD := 12.5         # the long dash: in the air, or with the short one on cooldown
const SPIKE_STUN := 0.7         # [wiki] stun when a spiked glider hits the ground (docs/EXPEDITION_SPEC.md)
const SPIKE_DMG := 8.0
const DASH_SPEED := 19.0      # m/s: the base dash (owner: 23 felt too fast); 19 x 0.19s = 3.6m
const DASH_TIME := 0.19       # s
const DASH_REGEN := 2.2
const LEDGE_REACH := 2.8
const LEDGE_CD := 0.45
const FLOAT_SPEED := 12.0
const GLIDE_FALL := 1.7
const GLIDE_SPEED := 5.0       # [game data] MaxGlide 500 uu/s (item 163: "too fast and controllable"; was 6.5)
const GLIDE_TIME := 9.0        # (owner: "lasts too long, not punishing enough") was 14s of level glide before the heat ring turns hot
const GLIDE_DRAG := 1.6         # speed lost per second while gliding (more when going fast)
const GLIDE_MAX := 15.0
# The opening drop, battle-royale style: a fast skydive you steer freely, then the glider opens by
# itself near the ground (or earlier on jump) for a slower, floatier last stretch.
const DIVE_FALL := 13.0        # [est] a punchy skydive (was 11)
const DIVE_SPEED := 14.0       # m/s, top flat speed in the dive (DropFeel)
const DROP_FALL := 4.2
const DROP_SPEED := 8.0        # m/s, top flat speed under the open glider
const DIVE_VY_RATE := 7.0      # the dive reaches its fall speed in ~0.3s (was 4)
const DROP_VY_RATE := 9.0      # the canopy settles to its sink in ~0.2s after it opens (was 4)
const DEPLOY_POP := -1.6       # the canopy catching: your fall checks to this, then settles to DROP_FALL
const DEPLOY_H := 8.0         # the glider opens by itself this high above the ground
## Armor, as in Supervive: it takes a flat share off every hit (ARMOR_DR) for as long as it has
## durability left; what gets through hurts your health and wears the durability down by the same
## amount. Neither comes back on its own: tonics heal and armor kits repair (the utility belt, 1 to 4).
const ARMOR_DR := 0.2
const ARMOR_DUR := 2.2        # durability as a multiple of max health
const ARMOR_WAIT := 4.0
const CONSUME_VULN := 1.2     # you take this much more damage while drinking, repairing or reviving a box

var pname := "Hunter"
var cls := "medium"
var cdat: Dictionary = {}
var wid := "rifle"
var wpn: Dictionary = {}
var ctrl := "bot"             # local | bot | remote
var inp := {"move": Vector2.ZERO, "aim": Vector3.ZERO, "fire": false, "dash": false, "jump": false,
	"throw": false, "skill": false, "sig": false, "interact": false, "util1": false, "util2": false, "util3": false, "util4": false, "glide": false, "ult": false,
	"sec": false, "sec_hold": false, "crouch": false, "gear1": false, "gear2": false, "swap": false}
var base_speed := 5.4
var ground_accel := GROUND_ACCEL     # per hunter (HunterMove)
var ammo := 12
var reload_t := 0.0
var fire_cd := 0.0
var dashes := 2.0
var roll_t := 0.0
var roll_dir := Vector2.ZERO
var inv_t := 0.0
var coyote := 0.0
var jump_buf := 0.0
var fly_t := 0.0
var mantle_cd := 0.0
var carry_v := 0.0             # m/s: how fast you were just going (MantleCarry, item 185b)
var carry_dir := Vector2.ZERO
var carry_mini := {}           # a mantle's held speed just after the lip (MantleCarry)
## The ledge rise (SUPERVIVE's ledge float): {lip, n (into the wall), t, max_t, at, face (start
## point), g0 (glide held when it began), downed, win (timing window opened)}. See _ledge_rise.
var lfloat := {}
var grap_cd := 0.0
var grap: Dictionary = {}       # floating back up a ledge
var push_t := 0.0
var last_gy := 0.0             # ground height where you last stood
var pad: Dictionary = {}        # jump-pad flight along a fixed arc
var kb_t := -9.0
var sig_cd := 0.0
var cloak_t := 0.0
var haste_t := 0.0
var fortify_t := 0.0
var shield := 0.0
var shield_t := 0.0
var recoil := 0.0
var walk_ph := 0.0
var anim: HunterAnim = null     # the procedural animation for the model
var downed := false
var down_hp := 0.0
var revive := 0.0
var out := false
var gone := false              # dead for good: no box revive, no beacon (see Life)
var sick_t := 0.0              # resurrection sickness after a beacon revive: -25% damage
var stolen_carry := false      # carrying someone else's kin: it struggles, slowing you a little
var chase: Hunter = null       # whoever has your kin: you run faster toward them
var box_t := 0.0               # holding interact at a deathbox
var box_rev_at := -9.0         # last time we were channelling a deathbox revive (BoxRevive)
var hurt_at := -9.0            # last time a hit landed (channels like a box revive break on it)
var hit_k := 1.0               # how hard the last hit was (Oomph): scales the flinch
var hit_shake := 0.0           # the model's hit-shake left (Oomph.render_hit)
var hit_from := Vector2.ZERO   # which way the last hit pushed
var stagger_t := 0.0           # staggered by a big hit (Oomph)
var extracted := false
var extract_prog := 0.0
## What this hunter is holding interact for right now (an animation each, see HunterAnim._act_*):
## "" or one of HOLD_KINDS. Set every tick by whatever the hold works on; it lapses when not refreshed.
const HOLD_KINDS := ["scan", "revive", "chest", "dial", "console", "lever", "windup", "shrine", "beacon", "key", "loot", "rune"]
var hold_kind := ""
var hold_until := 0.0

## Keep the hold animation going for a moment (the systems that run a hold call this every tick).
func set_hold(kind: String, dur := 0.15) -> void:
	hold_until = maxf(hold_until, m.time + dur) if kind == hold_kind else m.time + dur
	hold_kind = kind

func holding() -> String:
	return hold_kind if m.time < hold_until else ""
var rift_keys := 0               # Rift Keys carried: each opens a rift hatch once (see Exits); they go in your deathbox
var chest_keys := 0              # chest keys carried: each opens one chest (KeyChest); they go in your deathbox
var kin: Ent = null             # the active kin: its abilities are on Q and V, its ultimate on R
var kin2: Ent = null            # the benched kin, swapped in with X
var swap_cd := 0.0
var merge_st: Dictionary = {}   # the merge (bond ultimate) while it runs: {def, t, T, giant, pulse, form, phase, kit, shell...} (KinMerge)
var merge_cd := 0.0             # the spent window after a merge ends
var merge_free := true          # the first time the ult slot opens this run, the bond meter fills
var kin_bonus: Dictionary = {}  # owner bonuses from your kin's stat points (KinLib.owner_bonus), applied for the run
var kin_hp_added := 0.0
var kin_shield := 0.0           # the small shield a kin's owner_shield points give: refills out of a fight
var kbuffs: Dictionary = {}     # short boosts from kin abilities: stat -> [amount, time left]
var air_jumps := 0              # extra jumps used since you left the ground (merge passives)
var air_dashed := false         # the merge's dodge in the air, used this airtime
var _kst: Dictionary = {}       # owner stats from your kin this step (carry passives + merge), see owner_stat
var gems := 0
var lost_gems := 0
var seeds := {}
var caught: Array = []        # kin records caught this match
var kills := 0
var knocks := 0
var dmg_done := 0.0
var belt: Array = UtilityBelt.empty()    # the utility belt on 1-4: four slots of {id, n, cd} (UtilityBelt)
var belt_free: Dictionary = {}                # issued charges, used first and never taken home
var tonics: int:                              # (the belt's tonics and armor kits, for the code that counts them)
	get: return UtilityBelt.count(self, "tonic")
	set(v): UtilityBelt.set_count(self, "tonic", v)
var armor_kits: int:
	get: return UtilityBelt.count(self, "armor_kit")
	set(v): UtilityBelt.set_count(self, "armor_kit", v)
var ai: Dictionary = {}
var muzzle_t := 0.0
var regen_wait := 0.0
var armor := 0.0
var max_armor := 50.0
var armor_wait := 0.0
var bloom := 0.0              # extra spread from moving, jumping and dashing
var crouch := false           # slower, steadier aim, and much harder to spot
var crouch_k := 0.0
var reveal_t := 0.0           # seen through bushes and around walls for a moment after firing or getting hit
var wall_touch_t := 0.0       # touching a wall in the air: a jump kicks off it
var wall_n := Vector2.ZERO
var wall_moves := WallMoves.new()      # wall kick and wall bounce
var glide_lift := GlideLift.new()      # the abyss lift's spring and float, ledge catch timing
var glide_dive := GlideDive.new()      # the glider's plunge while crouch is held under it
var wslam_t := 0.0
var wallstun := 0.0           # how long the next wall slam stuns (Haymaker makes it longer)
var land_t := 0.0
var ghost_t := 0.0
var step_t := 0.0
var gliding := false
var glide_fuel := 1.0          # shown as glider heat: 1 = cool, 0 = overheated
var shot_down := false         # knocked out of an overheated glide: stunned when you land
var below_lip := false         # dropped below the nearest island's edge, over the abyss
var wall_hit_v := Vector2.ZERO  # this step's speed into an island side that stopped you (for the ledge catch)
var lip_y := 0.0               # that edge's height: where your balloon floats
var heat_burn := 0.0
var in_current := false        # riding a wind road or an updraft: the glider doesn't heat up
var glide_max := GLIDE_TIME
var glide_cd := 0.0
var glide_k := 0.0             # how far the glider is unfolded, for the model
var _auto_glide_held := true   # (glide held last frame: auto_glide ends on a fresh press, not a held key)
var auto_glide := false        # carried by a lair's escape updraft: the glider opens and stays open
                               # by itself until you land (hold glide yourself to take it back)
var wind_t := 0.0
var perk := ""                  # (old single home perk; perks are now found in the run, see perks)
var perks: Array = []           # perks picked up this expedition, one entry per stack
var ult := 0.0                # the bond meter, 0..1: R calls your kin's bond ultimate at 1
var crit_t := 0.0             # shots crit while this runs (Blink)
var phase_t := 0.0            # Light's Phase Step: shots pass through you while this runs
var dash_pass := {}           # a grammar dash or a kit dash: what it does to foes you pass through {hit, opts}
var abil_charge := {}         # holding a charge-up weapon ability (Rail Charge): {t}
var charge: Dictionary = {}   # Ram
var idle_fire := 0.0
var dropping := false         # gliding down from the sky at the start of a match
var drop_from := Vector2.INF  # where the drop started
var diving := false           # the skydive part of the drop, before the glider opens
var riding := false           # aboard the skyship, waiting to jump
var drop_follow: Hunter = null  # gliding down in formation behind this squad's drop leader (see DropSquad)
var drop_slot := 0            # which slot of the formation
var drop_solo := false        # broke away from the squad's drop
var bless_t := 0.0
var wup_dmg := 1.0            # your signature weapon's damage from weapon upgrades (WeaponUps): kits scale their own hits by it
var welem := ""               # its element ("fire", "frost", ...) from a Brand upgrade: a rider on every hit (Loot.rider)
var el_n := 0                 # attacks made with the element, for "every Nth hit" riders
var pack: Array = []          # the backpack: gear and valuables to carry home (Loot items)
var pack_cap := 6
var backpack := 0              # the backpack tier worn (Backpacks): 0 is the Pouch everyone has
var swap_hold := false
var dash_at := -9.0           # when the last dash started, for perfect dodges
var jump_at := -9.0           # when you last jumped off the ground (AirLimits: a move from before it is over)
var launch_at := -1.0         # when the skyship launch started (DropLaunch), -1 once it is over
var dodged := false        # F has to be let go between weapon swaps
var lives := 1                # comes back this many times minus one before it's really out
var arch := ""                # the archetype (docs/ARCHETYPES.md); "" = the old class kit (weapon RMB, class dodge)
var ak: ArchKit = null        # the archetype's kit at run time
var shot_range_k := 1.0       # the next shot's range (an idle gun's first ember: +40%)
var shot_aim := ""            # the next shot's aim mode (AimMode.CURSOR / MAX); "" = the weapon's own
var draw_t := -1.0            # a bow being drawn: how long (-1: not drawing)
var spirit_t := 0.0           # Spirit Walk (PinSpirit): rocks, trees and barriers don't stop you while > 0
var nth_n := 0                # shots since the weapon's "every Nth" bonus


func init_hunter(match_node: Node, id: String, team_id: int, class_id: String, name_txt: String, control: String, kit := {}) -> void:
	setup(match_node, id)
	kind = "hunter"
	team = team_id
	cls = class_id if Data.CLASSES.has(class_id) else "medium"
	cdat = Data.CLASSES[cls]
	# the archetype: asked for by the kit, else your saved one (you) or a random one of the class (bots)
	var ka := String(kit.get("arch", ""))
	if ka == "" and control == "local": ka = String(Save.d.get("arch", ""))
	if ka == "" and control == "remote":
		# a remote player's archetype comes with them; failing that, the one their weapon belongs to
		# (never a random pick, so nobody ever looks like an archetype they aren't)
		var wa := Arch.archetypes_of(String(kit.get("weapon", ""))).filter(func(x): return Arch.weight(x) == cls)
		ka = String(wa[0]) if not wa.is_empty() else Arch.default_for(cls)
	if ka == "" and control == "bot": ka = "?"
	if ka == "?": ka = Arch.pick_for(cls, "%s|%s" % [id, str(match_node.get("seed_val"))])
	arch = "" if ka == "none" else Arch.fix(ka, cls)
	wid = Arch.weapon_for(arch, cls, String(kit.get("weapon", ""))) if arch != "" else Data.weapon_for(cls, String(kit.get("weapon", "")))
	wpn = Data.weapon_stats(wid)
	perk = ""
	pname = name_txt
	ctrl = control
	if control != "local":
		bot_look = PlayerLook.random()
	max_hp = cdat["hp"]; hp = max_hp
	max_armor = round(max_hp * ARMOR_DUR); armor = max_armor; base_armor = max_armor
	# the belt issue and the equal pack size (Equal.pack_slots)
	UtilityBelt.issue(self)
	pack_cap = Equal.base_pack()
	glide_max = GLIDE_TIME * float(cdat.get("glide_cap", 1.0))
	base_speed = cdat["speed"]
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
	r = Arch.hit_r(arch, cdat)
	set_model(Models.hunter(cls, Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()], wid, "", Unmasked.mask_look() if ctrl == "local" else bot_look, arch))

## Switches the archetype mid-match (tests, practice). "" puts back the old class kit: the weapon's
## right click and the class dodge.
func set_arch(a: String) -> void:
	arch = "" if a == "" or a == "none" else Arch.fix(a, cls)
	r = Arch.hit_r(arch, cdat)
	if ak: ak.teardown()
	ak = ArchKit.make(self, arch) if arch != "" else null
	HunterMove.apply(self)
	if arch != "" and not Arch.weapon_ok(arch, wid):
		equip(Arch.signature(arch))
	r = Arch.hit_r(arch, cdat)
	_kit_from_weapon()

## Practice (the Arena and training): become another class and archetype on the spot. Health,
## speed, size, dash charges, the model and the kit change; your kin, level and slot ranks stay.
func reclass(c: String, a: String, w := "") -> void:
	if Data.CLASSES.has(c):
		cls = c
	cdat = Data.CLASSES[cls]
	if KinMerge.active(self): KinMerge.end(self, "broken")
	max_hp = float(cdat["hp"]) + kin_hp_added; hp = max_hp
	LevelGrowth.reset(self)      # your levels' health comes along to the new class
	max_armor = round(float(cdat["hp"]) * ARMOR_DUR); armor = max_armor; base_armor = max_armor
	glide_max = GLIDE_TIME * float(cdat.get("glide_cap", 1.0))
	base_speed = cdat["speed"]
	dodge_def = Content.class_dodge(cls)
	arch = Arch.fix(a, cls)
	r = Arch.hit_r(arch, cdat)
	if ak: ak.teardown()
	ak = ArchKit.make(self, arch)
	HunterMove.apply(self)
	wid = Arch.weapon_for(arch, cls, w)
	set_model(Models.hunter(cls, Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()], wid, "", Unmasked.mask_look() if ctrl == "local" else bot_look, arch))
	anim = null
	equip(wid, -1, false)      # (Models.hunter just built this weapon, a 3D Warden's own model included)
	dashes = max_dashes(); ex_cd = 0.0
	roll_t = 0.0; stun_t = 0.0; root_t = 0.0

## Puts a weapon in hand with this run's weapon upgrades on it (WeaponUps). A hunter has one
## signature weapon (Arch.signature), so this is only called to build it, or when practice swaps archetype.
func equip(w: String, with_ammo := -1, rebuild := true) -> void:
	wid = w
	wpn = Data.weapon_stats(w)
	WeaponUps.apply(self)
	_kit_from_weapon()
	wbloom = 0.0; warm_t = 0.0; spin = 0.0; spun_t = 0.0; sus_n = 0; mel_hold = 0.0; strike_at_end = {}
	ammo = int(wpn["mag"]) if with_ammo < 0 else mini(with_ammo, int(wpn["mag"])); reload_t = 0.0; fire_cd = 0.25
	if ammo <= 0 and not remote: start_reload()
	var gun: Node3D = model.find_child("Gun", true, false) if model and rebuild else null
	if gun:
		for ch in gun.get_children():
			if ch.name != "Muzzle":
				ch.queue_free()
		Models.gun_parts(gun, w, Models.toon(Color("4a4d5c")), Models.toon(Color("2b2a33")), Models.toon(Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()], true, 0.0))

## Chasing down whoever took your kin: 18% faster heading their way. Carrying a stolen kin: 8% slower.
func _chase_mod(mv: Vector2) -> float:
	var k := 0.92 if stolen_carry else 1.0
	# the archetype kit's own pace (a Lance charging, Avalanche, a raised tower shield) and short
	# move-speed boosts (a Sigil): kept here so the movement code itself stays untouched
	k *= (ak.pace() if ak else 1.0) * (1.0 + buff("move_speed"))
	if Hex.active(self): k *= Hex.SPEED_K      # a hexed critter scurries
	if chase and not chase.out and not chase.extracted and mv.length() > 0.1 and mv.normalized().dot(dir_to(chase)) > 0.5:
		k *= 1.18
	return k

## The colour that marks this hunter's effects (from their class).
func accent() -> Color:
	return cdat.get("color", Color.WHITE) if not cdat.is_empty() else Color.WHITE

func max_dashes() -> float:
	var base := float(dodge_def.charges) if dodge_def else float(cdat["dashes"])
	return base + float(perk_n("secondwind")) + (ak.extra_dashes() if ak else 0.0)

func dash_regen() -> float:
	# each rank past the first recharges dashes faster; a kin's dodge_regen too (1 = instantly)
	var base := float(ak.dash_def().get("cd", 9.0)) if ak else (dodge_def.cooldown if dodge_def else DASH_REGEN)
	return base * (1.0 - 0.15 * float(maxi(0, int(slot_lv.get("dash", 1)) - 1))) * (1.0 - minf(0.9, owner_stat("dodge_regen") + gear_stat("dodge")))

## Right click is always your weapon's ability, as left click is its attack.
func _kit_from_weapon() -> void:
	if runner == null:
		return
	var wd := Content.weapon(wid)
	if ak:
		runner.set_slot("utility", null)      # right click is the archetype's
		return
	runner.set_slot("utility", Content.ability(wd.utility) if wd and wd.utility != "" else null)

# ------------------------------------------------------------------ your kin's stats on you
## Your kin riding with you, settled in: its carry passives are on. A mount curls up on your back
## while you glide (you can't glide riding it), and its passives are off for that time.
func kin_carry_on() -> bool:
	if kin == null or not (kin as Kin).carried():
		return false
	return not ((kin as Kin).carry_style() == "mount" and gliding)

## Riding your mount right now (on the ground or jumping, not gliding).
func mounted() -> bool:
	return kin_carry_on() and (kin as Kin).carry_style() == "mount"

## An owner stat (KinParts.OWNER_STATS) from your kin: its carry passives while it rides with you,
## plus the merge's passives while merged, capped at the carry or merge maximum. Refreshed every step (_refresh_kin_stats).
func owner_stat(stat: String) -> float:
	return float(_kst.get(stat, 0.0))

func _refresh_kin_stats() -> void:
	var out := {}
	var k: Kin = kin
	if k and k.ks:
		if kin_carry_on():
			for ps in k.ks.carry_passives:
				out[ps["stat"]] = float(out.get(ps["stat"], 0.0)) + float(ps["amount"])
	if not merge_st.is_empty():
		for ps in KinMerge.passives(self):
			out[ps["stat"]] = float(out.get(ps["stat"], 0.0)) + float(ps["amount"])
		out["cooldown"] = float((merge_st.get("form", {}) as Dictionary).get("haste", 0.0))      # the form's faster ability cooldowns (MergeForm)
	for st in out:
		var row: Array = KinParts.OWNER_STATS[st]
		out[st] = clampf(float(out[st]), 0.0, float(row[3] if not merge_st.is_empty() else row[2]))
	_kst = out

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
		"crit": crit_t = maxf(crit_t, dur)
		"dash_refill": dashes = max_dashes()
		"glider_cool":
			glide_fuel = minf(1.0, glide_fuel + amount)
			shot_down = false
		"guard":
			guard_t = maxf(guard_t, dur); guard_k = amount
		_:
			var cur: Array = kbuffs.get(stat, [0.0, 0.0])
			kbuffs[stat] = [maxf(float(cur[0]), amount), maxf(float(cur[1]), dur)]

func buff(stat: String) -> float:
	var b: Array = kbuffs.get(stat, [0.0, 0.0])
	return float(b[0]) if float(b[1]) > 0.0 else 0.0

func mass() -> float:
	return float(cdat.get("mass", 1.0))

func hittable() -> bool:
	return not dead and not out and not extracted and not riding

func cc_proof() -> bool:
	return ak != null and ak.cc_proof()

func targetable() -> bool:
	return hittable() and not downed and cloak_t <= 0.0 and not dropping

func is_local() -> bool:
	return ctrl == "local"

func aim_dir() -> Vector2:
	if ak and ak.aim_lock() != Vector2.ZERO:
		return ak.aim_lock()
	var d := Vector2(inp["aim"].x - pos.x, inp["aim"].z - pos.z)
	return d.normalized() if d.length() > 0.05 else Vector2(sin(face), cos(face)) * -1.0

# ------------------------------------------------------------------ damage
func _mitigate(dmg: float, by: Ent, opts: Dictionary) -> float:
	if (inv_t > 0.0 or dropping) and opts.get("src", "") != "fall":
		# dashing through an attack right as it lands: a perfect dodge
		if not dropping and not dodged and m.time - dash_at < 0.22 * (ak.pd_k() if ak and ak.has_method("pd_k") else 1.0) and by != null and by.team != team and dmg >= 4.0:
			dodged = true
			dashes = minf(max_dashes(), dashes + 0.6)
			crit_t = maxf(crit_t, 1.5)
			m.on_perfect_dodge(self)
			if ak: ak.on_perfect_dodge()
		return 0.0
	if ctrl == "local" and Game.god:
		return 0.0
	reveal_t = maxf(reveal_t, 1.0)
	hurt_at = m.time
	if base_t > 0.0 and dmg > 0.0:
		cancel_base("you took damage")
	if opts.has("wallstun"):
		wallstun = float(opts["wallstun"])
	# Getting hit while gliding, as in Supervive: a hit does NOT knock you out of the air by itself
	# and you take normal damage. What it does is drain the glider at triple the usual rate. Only
	# when the glider runs dry are you spiked (stunned, plummeting, a 0.7s stun when you land; over
	# the abyss that's a fall). Monsters drain it but can't spike you.
	var spiked := false
	if gliding and not dropping and dmg > 0.0 and opts.get("src", "") not in ["fall", "burn", "heat"]:
		var was := glide_fuel
		# a knock's worth of damage (250 of 1,050) would burn 30% of the glider; hits drain it 3x
		glide_fuel = maxf(0.0, glide_fuel - 3.0 * dmg * (0.30 / 34.5) / float(cdat.get("glide_cap", 1.0)))
		hit_heat_t = 1.0
		if is_local() and m.hud and m.hud.has_method("glider_hit"):
			m.hud.glider_hit(was - glide_fuel)
		if opts.get("src", "") == "mob" or by is Mob:
			glide_fuel = maxf(glide_fuel, 0.02)      # monsters can't spike
		elif was <= 0.001 or glide_fuel <= 0.001:
			spiked = true
			_shot_down()
			# spiking someone cools your own glider
			if by is Hunter and (by as Hunter).gliding: (by as Hunter).glide_fuel = minf(1.0, (by as Hunter).glide_fuel + 0.5)
			if by is Hunter: (by as Hunter).add_stat("spikes")
			elif by is Kin and (by as Kin).owner_h: (by as Kin).owner_h.add_stat("spikes")
	var d := dmg
	if ctrl == "local" and m.opts.get("tutorial", false):
		d *= 0.35
	d *= 1.0 - owner_stat("damage_reduction")
	if downed:
		# a wisp can't be shot: it's lost to stomps, an execute, or bleeding out
		return 0.0
	var d_in := d
	d = MergeShell.absorb(self, d, opts)         # a merged form's shell takes the hit first (docs/decisions/0003)
	var shelled := false
	if d <= 0.0:
		if d_in <= 0.0:
			return 0.0
		shelled = true          # the shell took all of it: a token hit that skips the other defences but still counts
		d = 0.01
	if shield > 0.0 and not shelled:
		var a := minf(shield, d)
		shield -= a; d -= a
		if d <= 0.0:
			flash_t = 0.06
			m.fx.number(pos + Vector3(0, 1.6, 0), a, Color("cfe8ff"), false)
			return 0.0
	regen_wait = 5.0
	armor_wait = ARMOR_WAIT
	if drink_t > 0.0 or kit_t > 0.0 or box_reviving():
		d *= CONSUME_VULN
		# drinking, repairing or reviving leaves you open: any real hit spills it (you keep the item)
		if d >= 1.0 and opts.get("src", "") != "heat":
			_interrupt_consume()
	if armor > 0.0 and not shelled and opts.get("src", "") not in ["fall", "burn", "heat"]:
		d *= 1.0 - ARMOR_DR
		# your kin's armor stats make it wear more slowly
		armor = maxf(0.0, armor - d * (1.0 - minf(0.6, owner_stat("armor") + kin_pt("owner_armor"))))
		if armor <= 0.0:
			m.on_armor_break(self, by)
	if gliding and d > 0.0:
		m.fx.burst(pos + Vector3(0, 1.6, 0), Color("ffb070"), 6, 2.5, 0.3, 6.0)    # the glider takes the heat
	# only another hunter's damage (or their kin's) knocks you out of extracting, not monsters
	if extract_prog > 0.0 and d > 0.0 and by != null and not (by is Mob):
		var src: Ent = by
		if by is Kin and (by as Kin).owner_h: src = (by as Kin).owner_h
		if src is Hunter and src.team != team:
			extract_prog = 0.0
			if is_local() and m.hud: m.hud.toast("Extraction interrupted", Color("ff9a8a"))
	if kin_shield > 0.0 and d > 0.0 and not shelled and opts.get("src", "") not in ["fall", "heat"]:
		# your kin's owner shield soaks last; a fully soaked hit still counts as a hit (truces, interrupts)
		var ks0 := minf(kin_shield, d)
		kin_shield -= ks0
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
	for r in [1.5, 3.0, 5.0, 7.5]:
		for i in 12:
			var a := TAU * i / 12.0
			var x: float = pos.x + cos(a) * r; var z: float = pos.z + sin(a) * r
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
const MARKER_BALL_Y := 0.95       # balloon centre above the stance: where a level shot flies
const MARKER_FLASH := 0.3
const MARKER_FOE := Color("ff4a3a")
# always cool blue, so an ally never reads like a foe (team 0 is orange); half see-through, since you
# never shoot at it (at full strength it lit a bright blue hoop under every squadmate's hop)
const MARKER_ALLY := Color(0.31, 0.85, 1.0, 0.5)
var balloon: Node3D               # the hit marker: Ring, Ball, Knot, Aura, String
var _mk_ring: MeshInstance3D
var _mk_ball: MeshInstance3D
var _mk_knot: MeshInstance3D
var _mk_aura_n: MeshInstance3D
var _mk_str: MeshInstance3D
var _mk_kind := ""
var _mk_col := Color(0, 0, 0, 0)
var _mk_flash := 0.0
var _mk_flashing := false
static var _mk_quad: PlaneMesh
static var _mk_mats := {}         # shared materials, by colour: {"ring", "ball", "knot"}
static var _mk_aura: ShaderMaterial
static var _mk_string: ShaderMaterial

## The radius of the circle shots hit you in (a bullet touching it connects).
func hit_radius() -> float:
	return r + Match.HIT_SLACK

## Which marker shows where shots hit you: "balloon" (below a lip), "ring" (high over land), or ""
## when your body itself is the target.
func hit_marker() -> String:
	if not hittable():
		return ""
	if below_lip:
		return "balloon"
	if not grounded or remote:      # (a remote hunter's grounded flag isn't sent; its height is)
		var g := ground()
		if g > World.VOID + 1.0 and pos.y - g > Match.HOP_STAND:
			return "ring"
	return ""

## A shot connected: if it hit you through your marker, the marker flashes.
func marker_hit() -> void:
	if hit_marker() != "":
		_mk_flash = MARKER_FLASH

static func _marker_mats(c: Color) -> Dictionary:
	if _mk_mats.has(c):
		return _mk_mats[c]
	var d := {}
	if c == Color.WHITE:      # the flash
		d["ring"] = Models.ring_mat(Color(1, 1, 1, 1), 0.3)
		d["ball"] = Models.toon(Color(1.0, 0.97, 0.9), true, 1.0)
		d["knot"] = d["ball"]
	else:
		d["ring"] = Models.ring_mat(c, 0.2)
		d["ball"] = Models.toon(Color(c, 1.0), c.a > 0.75, 0.35 if c.a > 0.75 else 0.1)
		d["knot"] = Models.toon(Color(c, 1.0).darkened(0.3), false)
	_mk_mats[c] = d
	return d

## The marker's colour as the local player sees it.
func _marker_col() -> Color:
	var lp: Ent = m.local_player()
	var tc: Color = Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()]
	if lp == self:
		return Color(tc.lerp(Color.WHITE, 0.45), 0.45)       # your own: faint
	if lp and lp.team != team:
		return MARKER_FOE                                    # an enemy
	if lp:
		return MARKER_ALLY                                   # an ally
	return tc                                            # watching: team colours

func _build_marker() -> void:
	if _mk_quad == null:
		_mk_quad = Models.flat_quad(2.0)       # unit-radius ring, scaled to the hit radius
		_mk_aura = Models.glow_mat(Color(0.75, 0.35, 1.0, 0.4))
		_mk_string = Models.toon(Color(0.95, 0.95, 0.95), false)
	balloon = Node3D.new()
	balloon.top_level = true
	add_child(balloon)
	_mk_ring = Models.part(balloon, _mk_quad, null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ring")
	_mk_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mk_ball = Models.part(balloon, Models.sphere(1.0), null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ball")
	_mk_knot = Models.part(balloon, Models.cyl(0.03, 0.06, 0.1), null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Knot")
	_mk_aura_n = Models.part(balloon, Models.sphere(1.0), _mk_aura, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Aura")
	_mk_aura_n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mk_str = Models.part(balloon, Models.cyl(0.012, 0.012, 1.0, 4), _mk_string, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "String")
	_mk_str.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Builds the hit-marker balloon hidden, with its materials, under the loading screen (Match.warm_up): built
## lazily, its first showing in a fight compiled its shaders mid-frame (item 94's repeatable hitch).
func warm_marker() -> void:
	if balloon == null:
		_build_marker()
	var mats := _marker_mats(_marker_col())
	_mk_ring.material_override = mats["ring"]
	_mk_ball.material_override = mats["ball"]
	_mk_knot.material_override = mats["knot"]
	balloon.visible = false

func _render_balloon(delta: float) -> void:
	_mk_flash = maxf(0.0, _mk_flash - delta)
	var kind := hit_marker() if visible and model and model.visible else ""
	if kind == "":
		if balloon: balloon.visible = false
		_mk_kind = ""
		return
	if balloon == null:
		_build_marker()
	balloon.visible = true
	var ring := _mk_ring; var ball := _mk_ball; var knot := _mk_knot; var aura := _mk_aura_n; var string := _mk_str
	var hot := gliding and glide_fuel <= 0.001
	var col := _marker_col()
	if kind == "ring" and hot:
		col = Color(0.75, 0.35, 1.0, col.a)      # overheated: one more hit spikes you
	var flashing := _mk_flash > 0.0
	if col != _mk_col or flashing != _mk_flashing or kind != _mk_kind:
		var mats := _marker_mats(Color.WHITE if flashing else col)
		ring.material_override = mats["ring"]
		ball.material_override = mats["ball"]
		knot.material_override = mats["knot"]
		_mk_col = col; _mk_flashing = flashing; _mk_kind = kind
	var hr := hit_radius()
	var pop := 1.0 + 0.3 * (_mk_flash / MARKER_FLASH)
	# the stance follows the drawn body (sim heights, offset onto the interpolated position)
	var stance: float = m.shot_stance_y(self)
	var at := Vector3(position.x, stance if kind == "balloon" else position.y - (pos.y - stance), position.z)
	balloon.global_position = at
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3.ONE * hr * pop
	ball.visible = kind == "balloon"
	knot.visible = ball.visible
	aura.visible = ball.visible and hot
	if kind == "balloon":
		var bob := sin(m.time * 3.0) * 0.06
		var c := Vector3(0, MARKER_BALL_Y + bob, 0)
		ball.position = c
		ball.scale = Vector3(hr, hr * 1.15, hr) * pop
		knot.position = c - Vector3(0, hr * 1.15 + 0.03, 0)
		aura.position = c
		aura.scale = Vector3.ONE * hr * 1.45 * (1.0 + 0.08 * sin(m.time * 9.0))
		# the string runs down from the knot to the hunter hanging below
		var bot_y := knot.position.y - 0.05
		var len := maxf(0.1, at.y + bot_y - (position.y + 1.6))
		string.position = Vector3(0, bot_y - len * 0.5, 0)
		string.scale = Vector3(1, len, 1)
	else:
		# a faint tether from the feet down to the ring
		var len := maxf(0.05, position.y + 0.1 - at.y)
		string.position = Vector3(0, len * 0.5, 0)
		string.scale = Vector3(1, len, 1)

func _shot_down() -> void:
	gliding = false
	glide_cd = 2.5
	shot_down = true
	stun_t = maxf(stun_t, 0.35)
	vel = Vector3(vel.x * 0.3, minf(vel.y, -6.0), vel.z * 0.3)
	m.fx.burst(pos + Vector3(0, 1.8, 0), Color("ff9a5a"), 14, 3.0, 0.45, 6.0, 0.8)
	m.sfx("knock", pos, -2.0, 1.3)
	if ctrl == "local" and m.hud:
		m.hud.toast_small("GLIDER SHOT DOWN", Color("ff9a5a"))

## Knockback is a clean, predictable shove: it sets your speed along its direction (it doesn't
## stack with whatever you were doing), you slide for a fixed moment without control, and it never
## pops you into the air unless the attack says so.
var knock_t := 0.0
var launched_at := -9.0        # when a hard shove or a launch last hit you (Capture.controlled: it interrupts a rescue or a scan)
var knock_steer := 0.3         # how much WASD bends a knockback (the attack decides: 0.3 to 0.5)
func impulse(kbv: Vector2, lift := -1.0) -> void:
	if fortify_t > 0.0:
		return
	var k := kbv * (1.0 - owner_stat("knockback_resist"))
	var s := k.length() / mass()
	if s >= Capture.HARD_KNOCK or (lift >= 0.0 and lift / mass() >= 3.0):
		launched_at = m.time
	if s < 0.05:
		if lift >= 0.0:
			# a straight-up lift (a slam's crater, an eruption) with no sideways push
			vel.y = maxf(vel.y, minf(9.0, lift / mass()))
			grounded = false
		return
	if s > 4.0:
		kb_t = m.time
	var dir := k / k.length()
	var hv := Vector2(vel.x, vel.z)
	var along := hv.dot(dir)
	hv += dir * (maxf(along, s) - along)
	vel.x = hv.x; vel.z = hv.y
	if s > 2.5:
		knock_t = clampf(0.1 + s * 0.02, 0.12, 0.35)
	if lift >= 0.0:
		vel.y = maxf(vel.y, minf(9.0, lift / mass()))
		grounded = false

func _on_zero(by: Ent, opts: Dictionary) -> void:
	if remote or downed:
		return
	m.knock(self, by, opts)

# ------------------------------------------------------------------ actions
func do_jump() -> void:
	if downed or stun_t > 0.0 or grap.size() > 0 or out or KitStatus.grounded(self) or (ak and ak.cast_locked()):
		return
	KinFollow.on_jump(self)         # riding a mount: you come off it into the jump
	if not lfloat.is_empty():
		_ledge_fling()
		return
	if dropping and diving:
		_deploy()
		return
	if pad.size() > 0:
		# press jump mid-flight off a jump pad and the glider opens, keeping the launch's speed
		if not pad.get("ledge", false) and float(pad["t"]) > 0.12 and can_glide():
			pad = {}
			vel.y = minf(vel.y, 2.0)
			_open_glider()
		return
	if roll_t > 0.0 and grounded and move_kind == "dash":
		# jump out of a dash: the dash ends and you keep about half its speed into the jump
		var keep := roll_dir * roll_speed * DASH_JUMP_CARRY
		roll_t = 0.0
		vel.x = keep.x; vel.z = keep.y
		glide_handoff(roll_dir, roll_speed)         # (movefeel) dash, jump, glide carries the dash
	if grounded or coyote > 0.0:
		vel.y = JUMP_V * (float((kin as Kin).ks.mount.get("jump", 1.0)) if mounted() else 1.0)
		jump_at = m.time
		grounded = false
		coyote = 0.0
		m.sfx("jump", pos, -6.0)
		m.fx.dust(pos, 2)                   # (movefeel) a little kick of dust off the ground
		return
	if air_jumps < int(owner_stat("extra_jumps")) and not gliding:
		# a merge's double jump
		air_jumps += 1
		vel.y = JUMP_V
		m.fx.dust(pos, 4)
		m.sfx("jump", pos, -4.0, 1.2)
		return
	if wall_moves.try_kick(self):
		return
	# already in the air: a second press opens the glider straight away, rising or falling,
	# unless you're about to land, where it buffers a jump instead
	var lead := JUMP_BUFFER + 0.02     # "about to land": the ground is this many seconds of falling away
	var fall_left := maxf(0.9, (0.5 * H_GRAV * lead - vel.y) * lead)
	var near_ground := vel.y < 0.0 and pos.y - ground() < fall_left and not over_void()
	if not gliding and can_glide() and not near_ground:
		_open_glider()
		return
	jump_buf = JUMP_BUFFER

## A glider sinks at one steady rate, whatever your speed, so every glide reads the same.
const GLIDE_SINK := 1.4       # (movefeel) floatier: [spec] says 2-4 m/s eyeball, [est] 2.2 felt like falling; was 2.2
static func glide_fall(_speed: float) -> float:
	return GLIDE_SINK

## Momentum-preserving acceleration (the Supervive feel): under the wanted speed, move toward it;
## over it (a dash, a pad, a knockback) bleed the extra off slowly while still steering. With no keys:
## speed over `run` sheds at `shed`, then `friction` (a share of the speed per second) and a constant `decel`
## brake the walk, as UE does.
static func accel2(cur: Vector2, wish: Vector2, accel: float, decel: float, over_decel: float, dt: float) -> Vector2:
	var mx := wish.length()
	if mx < 0.001:
		return cur.move_toward(Vector2.ZERO, decel * dt)
	var cs := cur.length()
	if cs > mx:
		var wd := wish / mx
		# steering back against your momentum brakes it properly
		var against := maxf(0.0, -(cur / cs).dot(wd))
		var ns := maxf(cs - (over_decel + accel * against) * dt, mx)
		var turn := clampf(accel * dt / cs, 0.0, 1.0)
		var d := (cur / cs).lerp(wd, turn)
		if d.length_squared() < 0.0001: d = wd
		return d.normalized() * ns
	return cur.move_toward(wish, accel * dt)

## (movefeel) Glider steering, SUPERVIVE-style: at cruise speed the glider turns where you point
## almost at once (GLIDE_TURN deg/s) and gets up to speed quickly; speed you bring in above cruise
## (a dash, a pad, a ring) is kept and bleeds off slowly, turning in wider arcs the faster you go so
## the momentum reads. Steering hard against your heading brakes (GLIDE_BRAKE). Letting go drifts.
## wish is the wanted velocity (keys x cruise speed), gs the cruise speed.
static func glide_steer(hv: Vector2, wish: Vector2, gs: float, dt: float) -> Vector2:
	var s := hv.length()
	var ws := wish.length()
	if ws < 0.05:
		# let go: drift on; anything above cruise bleeds a little faster
		return hv.move_toward(Vector2.ZERO, (GLIDE_DECEL + (GLIDE_OVERSPEED if s > gs else 0.0)) * dt)
	if s <= gs + 0.05:
		# at or under cruise, the glide force pulls you toward where you steer: turns and reversals take time
		# (item 163, SUPERVIVE's GlideTargetXYForce), never a snap
		return hv.move_toward(wish, GLIDE_ACCEL * dt)
	var d := hv / s
	var wd := wish / ws
	var ang := d.angle_to(wd)
	if absf(ang) > deg_to_rad(GLIDE_BRAKE_DEG):
		# pulling back against your heading: brake hard, then build up the other way
		return hv.move_toward(wish, GLIDE_BRAKE * dt)
	var fast := clampf((s - gs) / maxf(0.1, GLIDE_MAX - gs), 0.0, 1.0)
	var rate := deg_to_rad(GLIDE_TURN) * lerpf(1.0, GLIDE_TURN_FAST, fast)
	d = d.rotated(clampf(ang, -rate * dt, rate * dt))
	if s < ws:
		s = minf(ws, s + GLIDE_ACCEL * dt)
	else:
		s = maxf(ws, s - GLIDE_OVERSPEED * dt)
	return d * s

## Feathering [est] (SUPERVIVE players tap the glider on and off instead of holding it): opening and
## closing are instant with no penalty for quick toggles; only the ground cools the glider ([footage]
## "it only really cools on the ground"); for FEATHER_KEEP after a close you keep its speed and steering, so
## skilled taps (short lifts out of the abyss, coasting the gaps) cover more ground per heat than
## holding. Numbers in docs/MOVEMENT_FEEL.md; measured by --move-feel-check (feather_*).
const FEATHER_KEEP := 0.6      # [est] seconds after closing the glider that its speed and steering carry
const FEATHER_MIN := 0.05      # [est] the glider reopens with this much heat room left (was 0.15)
const FEATHER_TAP := 0.3       # [est] an abyss lift's first this-many seconds are its quick impulse...
const FEATHER_TAP_HEAT := 1.0  # [est] ...heating like a level glide; held past it, the full 4x
var glide_off_t := 9.0         # seconds since the glider closed in the air (9 = long ago / on the ground)
var lift_t := 0.0              # seconds of the current abyss lift (feathering taps stay in the cheap part)

## The glider's vertical speed this step below an island's lip over the abyss, `depth` metres under
## it: it pulls you up harder and faster the deeper you are (ABYSS_LIFT*), then brakes into the last
## ABYSS_BRAKE_DIST so you arrive at ground level (let go just before to carry the climb up as height).
## Shared by Hunter (matches, the --training ground) and Home (the farm).
static func abyss_lift_vy(vy: float, depth: float, dt: float, k := 1.0) -> float:
	if depth > ABYSS_BRAKE_DIST:
		var acc := (ABYSS_LIFT + ABYSS_LIFT_PER_M * depth) * k
		var top := minf(ABYSS_LIFT_MAX + ABYSS_LIFT_MAX_PER_M * depth, ABYSS_LIFT_CAP) * k
		# a fall is caught at once (the canopy bites), then the climb builds
		if vy < 0.0:
			vy = move_toward(vy, 0.0, (acc + GLIDE_CATCH) * dt)
		return minf(vy + acc * dt, maxf(top, vy))
	return move_toward(vy, maxf(depth * ABYSS_BRAKE_GAIN, ABYSS_LIP_VY), ABYSS_BRAKE * dt)

func can_glide() -> bool:
	return not grounded and roll_t <= 0.0 and fly_t <= 0.0 and glide_cd <= 0.0 and not downed and stun_t <= 0.0 \
		and m.time - kb_t > 0.4 and not dropping and charge.is_empty() and not KitStatus.grounded(self) and not shot_down \
		and not (ak != null and ak.no_glide()) and not AirLimits.glide_locked(self)

func _open_glider() -> void:
	gliding = true
	grounded = false
	# unfolding catches the air: a slow start gets carried up to cruising speed
	var hv := Vector2(vel.x, vel.z)
	if hv.length() < GLIDE_SPEED and not dropping:
		# half the gap up front, the rest comes from the glide's own acceleration: no speed snap
		var mvv: Vector2 = inp.get("move", Vector2.ZERO)
		var dirv := mvv.normalized() if mvv.length() > 0.1 else (hv.normalized() if hv.length() > 0.3 else aim_dir())
		hv = hv.lerp(dirv * GLIDE_SPEED, 0.5)
		vel.x = hv.x; vel.z = hv.y
	_glider_sfx("open")
	_take_glide_handoff()
	glide_lift.open_kick(self)

# ---------------------------------------------------------------- dash -> glide momentum (movefeel)
## [wiki] "Gliding right after a lateral Impulse in the same direction keeps some momentum and
## increases glide speed" (dashes, relics, consumables, terrain). Anything that throws you sideways
## calls glide_handoff() as it ends (the Shift dash does, and a jump out of a dash; an archetype's
## own dash can call it too). If the glider opens within GLIDE_HANDOFF_WINDOW, heading the same way,
## it starts at GLIDE_HANDOFF_KEEP of the burst's speed (up to GLIDE_BOOST_MAX) and keeps it: the
## glide's slow over-speed bleed (GLIDE_OVERSPEED) does the rest. Owner-side only (inputs and
## physics run on the owning machine; the result reaches others through the usual Net state).
const GLIDE_HANDOFF_WINDOW := 0.3   # [est] "right after": open the glider within this long
const GLIDE_HANDOFF_KEEP := 0.75    # [est] an air dash opens the glider at this share of its speed, up to the cap below
const GLIDE_HANDOFF_MIN := 3.0      # a burst slower than a walk hands nothing over
const GLIDE_BOOST_MAX := 14.0       # [est] the most a handoff can start you at (GLIDE_MAX is 15)
var boost_fx_t := 0.0               # the boost trail lasts while you're well above cruise speed (render)
const GLIDE_HANDOFF_DOT := 0.3      # "in the same direction": the glide's heading within ~70 degrees
var _handoff := {}                  # {dir: Vector2, speed: float, at: float} the last lateral burst

## Call as a lateral burst (dash, rush, blink with speed...) ends: dir is where it went, speed how fast.
func glide_handoff(dir: Vector2, speed: float) -> void:
	if dir.length() < 0.01 or speed <= GLIDE_HANDOFF_MIN:
		return
	_handoff = {"dir": dir.normalized(), "speed": speed, "at": m.time}
	# (already gliding, e.g. a dash that leaves the glider open: _update_glide spends it this step)

## An air dash a kit cut short itself (it zeroed roll_t, as a Slipstep or a landing does) hands its last
## burst to the glider the way the timed-out class dash does, so every kit's air dash carries into a glide.
var _last_burst := {}               # {dir: Vector2, speed: float} the roll's last step

func _hand_off_ended_dash() -> void:
	if roll_t > 0.0 or _last_burst.is_empty():
		return
	if not grounded:
		glide_handoff(_last_burst["dir"], _last_burst["speed"])
	_last_burst = {}

## The glider just opened (or is open): spend a fresh handoff on a speed burst along its heading.
func _take_glide_handoff() -> void:
	if _handoff.is_empty() or dropping:
		return
	var h := _handoff
	_handoff = {}
	if m.time - float(h["at"]) > GLIDE_HANDOFF_WINDOW + 0.001:
		return
	var dir: Vector2 = h["dir"]
	var hv := Vector2(vel.x, vel.z)
	var mvv: Vector2 = inp.get("move", Vector2.ZERO)
	var heading := mvv.normalized() if mvv.length() > 0.1 else (hv.normalized() if hv.length() > 0.3 else dir)
	if heading.dot(dir) < GLIDE_HANDOFF_DOT:
		return
	var boost := minf(float(h["speed"]) * GLIDE_HANDOFF_KEEP, GLIDE_BOOST_MAX * (1.0 + gear_stat("glide_speed")))
	if boost <= hv.length():
		return
	# the burst's own line, bent a little toward where you're steering
	var bd := dir.lerp(heading, 0.35).normalized()
	vel.x = bd.x * boost; vel.z = bd.y * boost
	_glide_boost_fx()

## Reads as a boost: a loud whoosh, a trail that stays while you're fast (see render), and for you a brief
## camera pull-back.
func _glide_boost_fx() -> void:
	m.sfx("whoosh", pos, -1.0 if is_local() else -9.0, 1.2)
	m.sfx("glide", pos, -6.0 if is_local() else -14.0, 1.6)
	boost_fx_t = 1.6
	if is_local() and m.cam:
		m.cam.pull_back(0.12)

## The glider's open/close sound for this hunter's glider skin (quieter, and positional, for everyone else).
func _glider_sfx(which: String) -> void:
	var skin := "classic"
	if model and model.has_node("Rig/Torso/Glider"):
		skin = String(model.get_node("Rig/Torso/Glider").get_meta("skin", "classic"))
	var vol := (-3.0 if is_local() else -9.0) if which == "open" else (-8.0 if is_local() else -14.0)
	Sfx.play_stream(Gliders.sound(skin, which), pos, vol)

## The class's dodge (Shift), as described by its ability data: a dash, plus anything else in its
## effect list (the heavy class's charge shoves people).
## Shift, as in Supervive: a short dash, and a long one (its own, longer cooldown) when you're in
## the air or the short one is still recharging.
var ex_cd := 0.0
var used := {}                  # slot -> times you pressed it and it went off (the tutorial reads this)
var hit_heat_t := 0.0           # a moment after being hit while gliding, the glider heats twice as fast
var ex_next := false
var dash_is_ex := false
## Movement chains (Supervive): Shift during a glove rush cancels it into the dash; during a dash
## or a ledge climb it's buffered and fires the moment that ends; off a jump pad (after the first
## beat of the launch) it breaks the pad flight into a dash. Jump out of a ground dash keeps half
## its speed. Dash in the air and keep holding glide and the glider opens again as the dash ends.
## B: base to a teammate (Supervive's recall-to-ally). A 3s channel where you stand still and can't
## attack; moving, attacking or taking any damage cancels it. Everyone sees the channel ring on you
## and a marker on the teammate. You arrive beside them weakened for 3s: half damage, and the crowd
## control, healing and shields you apply are halved.
const BASE_TIME := 3.0
const BASE_CD := 40.0
const WEAK_TIME := 3.0
var base_t := 0.0
var base_to: Hunter = null
var base_cd := 0.0
var weak_t := 0.0
var dash_buf := 0.0

func start_base(to: Hunter) -> void:
	if to == null:
		if is_local() and m.hud: m.hud.toast_small("No teammate to base to", Color("a2a8bb"))
		_ab_feedback("base", "deny")
		return
	if base_cd > 0.0 or downed or out or dropping or riding or not grounded or base_t > 0.0:
		_ab_feedback("base", "deny")
		return
	base_t = BASE_TIME
	base_to = to
	_ab_feedback("base", "cast")
	m.sfx("portal", pos, -6.0, 1.2)
	if is_local() and m.hud: m.hud.toast_small("Basing  ·  hold still", Color("8fe3c8"))

func cancel_base(why := "") -> void:
	if base_t <= 0.0:
		return
	base_t = 0.0
	base_to = null
	base_cd = 4.0          # a short lockout after an interrupted channel
	m.sfx("warn", pos, -10.0, 0.8)
	if is_local() and m.hud and why != "": m.hud.toast_small("Base interrupted: " + why, Color("ff9a8a"))

func _tick_base(dt: float) -> void:
	if base_t <= 0.0:
		return
	var o := base_to
	if o == null or not is_instance_valid(o) or o.out or o.downed or o.extracted or downed or out:
		cancel_base("your teammate can't take you")
		return
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	if mv.length() > 0.2 or inp.get("fire", false) or inp["dash"] or inp["jump"] or inp["sig"] or inp["sec"] or inp["ult"] or inp.get("gear1", false) or inp.get("gear2", false) or inp.get("throw", false):
		cancel_base("you moved")
		return
	base_t -= dt
	if base_t <= 0.0:
		base_t = 0.0
		base_to = null
		var at := o.pos
		for i in 12:
			var a := TAU * i / 12.0
			var q := o.pos + Vector3(cos(a) * 1.3, 0, sin(a) * 1.3)
			if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z) and absf(m.world.ground_at(q.x, q.z) - o.pos.y) < 0.6:
				at = Vector3(q.x, m.world.ground_at(q.x, q.z), q.z); break
		m.fx.ring(pos, 1.6, Color("8fe3c8"), 0.4)
		teleport(at)
		vel = Vector3.ZERO
		weak_t = WEAK_TIME
		base_cd = BASE_CD
		m.fx.ring(at, 1.8, Color("8fe3c8"), 0.45)
		m.sfx("portal", at, -2.0, 1.5)
		if is_local() and m.hud: m.hud.toast_small("Weakened 3s", Color("ffb36a"))
var air_peak := 0.0              # the highest point of this time in the air (for skyfall landings)
const SKYFALL_H := 8.0           # drop at least this far, fast, onto rivals and you land a skyfall

## Height pays off: come down hard from 8m+ (not gliding gently, not the opening drop) and the
## landing slams everyone close: damage that grows with the height and a pop into the air.
func _skyfall(drop: float, fall_v: float) -> void:
	if drop < SKYFALL_H or fall_v > -6.0 or dropping or downed or remote:
		return
	var k := clampf((drop - SKYFALL_H) / 16.0, 0.0, 1.0)
	var any := false
	for f in m.foes_of(team):
		if flat_dist(f) < 2.4 + f.r and absf(f.pos.y - pos.y) < 2.0:
			any = true
	m.fx.dust(pos, 10)
	if not any:
		return
	Abil._blast(self, pos, 2.4, 10.0 + 16.0 * k, 7.0, Color("ffd27a"), 7.0, "skyfall")
	m.fx.word(pos + Vector3(0, 2.2, 0), "SKYFALL", Color("ffd27a"), true)
	add_stat("skyfalls")
var move_kind := "dash"          # what the current roll is: "dash" (Shift) or "rush" (an ability or glove)
const DASH_BUFFER := 0.18
const DASH_JUMP_CARRY := 0.55

func do_dash() -> void:
	if downed or stun_t > 0.0 or root_t > 0.0 or out or Hex.active(self):
		return
	if KitStatus.grounded(self) and not DredgeKit.reeling(self):
		# Grounded (a Thief's Bola): no dash, jump or glide (a reeling Dredge still barges)
		_ab_feedback("dash", "deny")
		return
	if roll_t > 0.0 and move_kind == "rush":
		roll_t = 0.0            # a glove/ability rush cancels straight into the dash
	elif pad.size() > 0 and not pad.get("ledge", false) and float(pad.get("t", 0.0)) > 0.12:
		pad = {}                # break out of a jump pad's flight
	elif roll_t > 0.0 or grap.size() > 0 or pad.size() > 0:
		dash_buf = DASH_BUFFER  # pressed a hair early: fire it as soon as this movement ends
		return
	var use_ex := not grounded or dashes < 1.0
	if not grounded and dashes >= 1.0 and not air_dashed and int(owner_stat("air_dashes")) > 0:
		use_ex = false           # a merge's dodge in the air: a normal dodge, once per airtime
		air_dashed = true
	if m.blight:
		m.blight.noise(pos, "dash", self)     # a dash is loud enough for the Blight nearby
	if ak:
		# the archetype's dash shape: it spends its own charge (or the long air dash) itself
		ak.dash_press_at = m.time      # its moves from here are the dash's (AirLimits)
		ak.on_dash(use_ex)
		return
	if use_ex:
		if ex_cd > 0.0:
			_ab_feedback("dash", "deny")
			return
		ex_cd = float(cdat.get("ex_cd", EX_DASH_CD))
		ex_next = true
		gliding = false
	else:
		dashes -= 1.0
	var effs: Array = dodge_def.effects if dodge_def else [{"type": "dash", "speed": DASH_SPEED, "time": DASH_TIME, "invuln": 0.14}]
	Effects.run(effs, self, {"slot": "dodge", "ability": dodge_def.id if dodge_def else "dash", "level": ability_level("dash")})
	CombatBus.ability_used.emit(self, dodge_def.id if dodge_def else "dash", "dodge")

## The theme of the kin you brought ("venom", "lunar"...). Cosmetic only: it tints, never rules.
func kin_element() -> String:
	if kin == null or (kin as Kin).dead:
		return ""
	return String(Data.KIN.get((kin as Kin).species, {}).get("type", ""))

var roll_speed := DASH_SPEED
var wedged_t := 0.0

## World.occupy, with the sky train in it: on a car's deck you walk freely (the deck is your floor,
## whatever the ground far below or a bridge overhead is doing), the engine is a wall, and walking
## off a car only takes you onto ground about level with the deck (a pier at a stop): the edge of a
## car over the abyss holds you like any island edge. Dashes, knockback and jumps go over it.
func _occ(x: float, z: float, guard: bool) -> float:
	var st: SkyTrain = m.skytrain
	if st == null:
		return m.world.occupy(x, z, r, pos.y, guard, spirit_t > 0.0)
	var sw := st.solid_at(x, z, pos.y, r)
	if sw > 0.0:
		return sw
	if st.walk_deck(Vector3(x, pos.y, z), r) > World.VOID + 1.0:
		return 0.0
	if not st.on_deck(pos):
		return m.world.occupy(x, z, r, pos.y, guard)
	var b: float = m.world.occupy(x, z, r, pos.y, false)
	if b == 0.0 and guard:
		var g: float = m.world.ground_at(x, z)
		if g <= World.VOID + 1.0 or g < pos.y - 0.9:
			return -1.0
	return b

## True only when there's no direction at all you could step: really stuck, not just walking into a wall.
func _boxed_in() -> bool:
	for i in 8:
		var a := TAU * i / 8.0
		if _occ(pos.x + cos(a) * 0.2, pos.z + sin(a) * 0.2, false) == 0.0:
			return false
	return true
var shove := {}                # the heavy charge: who it already hit, and how hard it shoves

func dash_with(e: Dictionary) -> void:
	var d: Vector2 = inp["move"]
	if d.length() < 0.1 or (is_local() and Settings.get_v("dash_to_cursor")):
		d = aim_dir()      # standing still, or the "Dash toward the cursor" setting
	if e.has("dir") and (e["dir"] as Vector2).length() > 0.01:
		d = e["dir"]
	roll_dir = d.normalized()
	roll_speed = float(e.get("speed", DASH_SPEED))
	roll_t = float(e.get("time", DASH_TIME))
	move_kind = String(e.get("kind", "dash"))
	dash_is_ex = ex_next
	if ex_next:
		# the long dash: the class's own distance and time (light 7m, medium 6m, heavy 5m)
		ex_next = false
		roll_t = float(cdat.get("ex_time", roll_t * 1.45))
		roll_speed = float(cdat.get("ex_dist", roll_speed * roll_t)) / roll_t
		vel.y = maxf(vel.y, 0.0)
	inv_t = maxf(inv_t, float(e.get("invuln", 0.14)))
	shove = {"hit": {}, "kb": float(e.get("shove_kb", 9.0)), "dmg": float(e.get("shove_dmg", 0.0)), "ws": float(e.get("wallstun", 0.0))} if e.get("shove", false) else {}
	if float(e.get("phase", 0.0)) > 0.0:
		# Light: for the whole step shots fly straight through you
		phase_t = maxf(phase_t, roll_t + float(e["phase"]) * 0.3)
		inv_t = maxf(inv_t, roll_t + 0.02)
	if float(e.get("reload", 0.0)) > 0.0 and not wpn.get("melee", false):
		# Medium: the roll slips rounds into the magazine
		var mag := int(wpn["mag"])
		ammo = mini(mag, ammo + int(ceil(mag * float(e["reload"]))))
		if ammo >= mag: reload_t = 0.0
	match String(e.get("trail", "")):
		"ghost":
			for i in 3:
				m.later(roll_t * float(i) / 3.0, func():
					if is_instance_valid(self) and m: m.fx.ghost(position, face, Color("d8c8ff"), float(cdat["scale"])))
		"roll":
			m.fx.dust(pos, 6)
		"dust":
			m.fx.dust(pos, 10)
	if not shove.is_empty():
		fortify_t = maxf(fortify_t, roll_t + 0.1)     # nothing knocks you back mid-charge
	dash_at = m.time
	dodged = false
	fly_t = 0.0
	if wpn.get("bloom_dash_reset", false): wbloom = 0.0
	m.sfx(HeroSfx.of(self, "dash", "dash"), pos, -4.0, 0.8 if not shove.is_empty() else 1.0)
	if not (ak and ak.own_dash_trail()):
		m.fx.dash_trail(self)          # the shared puff and ring; a kit with its own trail draws no ring

## A grammar dash you perform (or a kit's dash that hits): what you dash through gets its effects.
func _pass_along() -> void:
	for f in m.foes_of(team):
		if dash_pass.is_empty(): return
		if dash_pass["hit"].has(f.get_instance_id()) or flat_dist(f) > r + f.r + float(dash_pass.get("w", 0.8)) * 0.5 or absf(f.pos.y - pos.y) > 1.4:
			continue
		dash_pass["hit"][f.get_instance_id()] = true
		if dash_pass.get("kx") is Callable:
			(dash_pass["kx"] as Callable).call(f)
			continue
		var o := {"src": "abil", "ab": "dodge", "tags": ["dodge"]}
		var po: Dictionary = dash_pass["opts"]
		for k in ["burn", "slow", "blight", "stun", "root"]:
			if po.has(k): o[k] = float(po[k])
		f.hurt(maxf(0.1, float(po.get("dmg", 0.0))) * m.dmg_mult(self), self, o)
		m.fx.burst(f.pos + Vector3(0, 0.8, 0), Color(String(po.get("color", "#a6ff3a"))), 8, 3.0, 0.3)

func _shove_along() -> void:
	for f in m.foes_of(team):
		if shove.is_empty(): return
		if shove["hit"].has(f.nid) or flat_dist(f) > r + f.r + 0.35 or absf(f.pos.y - pos.y) > 1.4:
			continue
		shove["hit"][f.nid] = true
		var side := Vector2(f.pos.x - pos.x, f.pos.z - pos.z).normalized()
		var push := (roll_dir * 0.7 + side * 0.5).normalized() * float(shove["kb"])
		var so := {"kb": push, "lift": 2.5, "src": "abil", "ab": "dodge", "tags": ["dodge"]}
		if float(shove.get("ws", 0.0)) > 0.0: so["wallstun"] = float(shove["ws"])
		f.hurt(maxf(0.1, float(shove["dmg"])) * m.dmg_mult(self), self, so)

func can_fire() -> bool:
	if Hex.active(self) or Capture.active(self):
		return false
	if ak and not ak.can_shoot():
		return false
	if ak and roll_t > 0.0 and ak.fires_in_dash() and not (drink_t > 0.0 or reload_t > 0.0 or downed or stun_t > 0.0):
		return true          # shooting from a held slide
	return not (drink_t > 0.0 or reload_t > 0.0 or roll_t > 0.0 or downed or out or stun_t > 0.0 or grap.size() > 0 or gliding or charge.size() > 0)

const SWAY := [0.0, 0.6, -0.4, 1.0, -0.8, 0.3, -1.0, 0.5]
var shot_n := 0
var safe_pos := Vector3.INF    # the last solid ground you stood on, well away from any edge

## Weapon state that builds up while you fire (Supervive-style): per-shot bloom, a sniper's
## wind-up, a minigun's spin, a rifle's sustained-fire falloff, and a sword's charge.
var wbloom := 0.0              # extra spread in degrees from firing; recovers once you stop
var warm_t := 0.0              # sniper wind-up left; the shot goes when it runs out
var spin := 0.0                # minigun spin, 0 to 1; it only fires fully spun
var spun_t := 0.0              # how long the minigun has been firing (it tightens up)
var sus_n := 0                 # rounds in the current string of fire
var mel_hold := 0.0            # how long the attack key has been held with a sword
var fire_was := false
var swing_buf := 0.0           # a tap that came in mid-swing, played as soon as the swing ends
var lunge_n := 0               # lunges in a row; each one in a short window goes 25% less far
var lunge_at := -9.0
var strike_at_end := {}        # a charged lunge's hit, which lands where the lunge ends

## Called every frame with the attack key's state; decides what that means for this weapon.
func trigger(dt: float) -> void:
	var held: bool = inp["fire"]
	if ak and ak.lmb_override(held, dt):
		return          # the archetype runs this weapon's attack itself (the Bulwark's mace: throw / smash)
	if wpn.get("melee", false):
		swing_buf = maxf(0.0, swing_buf - dt)
		if swing_buf > 0.0 and fire_cd <= 0.0 and can_fire():
			swing_buf = 0.0
			fire()
		if ctrl != "local" or not wpn.has("charge_time"):
			if held: fire()
			return
		# tap for the combo, hold to charge
		var ct := float(wpn["charge_time"])
		var pressed := held and not fire_was
		fire_was = held
		if held:
			if not can_fire() or fire_cd > 0.0:
				if pressed: swing_buf = 0.3     # tapped mid-swing: it plays when this one ends
				return
			mel_hold += dt
			if mel_hold >= ct + 0.35:
				# held well past full: it goes off by itself, and keeps charging the next one
				_charged_attack()
		else:
			if mel_hold >= ct and can_fire():
				_charged_attack()
			elif mel_hold > 0.0:
				if fire_cd > 0.0: swing_buf = 0.3
				else: fire()
			mel_hold = 0.0
		return
	if wpn.has("draw"):
		_trigger_bow(held, dt)
		return
	if wpn.has("spin_up"):
		if held and can_fire() and ammo > 0:
			spin = minf(1.0, spin + dt / float(wpn["spin_up"]))
			if spin >= 1.0:
				spun_t += dt
				fire()
		else:
			spin = maxf(0.0, spin - dt / 0.5)
			spun_t = 0.0
			if held and ammo <= 0: start_reload()
		return
	if held:
		fire()

## A bow: hold to draw, let go to loose. Only the button coming up looses a player's arrow: a cooldown
## never looses it, and a stun or glide cancels the draw with no shot (a dash too, unless its DashFlow hold
## row keeps it). A bot lets go by itself.
func _trigger_bow(held: bool, dt: float) -> void:
	if draw_t >= 0.0 and not can_fire() and ak and ak.flow.pauses_hold("lmb"):
		if held:
			draw_t += dt * ak.draw_rate()      # a dash whose row keeps the draw: it charges on through it,
		return          # and a release in it looses when it ends
	var can_draw: bool = can_fire() and ammo > 0
	if draw_t >= 0.0 and not held:
		_loose()
		return
	if draw_t >= 0.0 and not can_draw:
		draw_t = -1.0
		return
	if held and can_draw and (draw_t >= 0.0 or fire_cd <= 0.0):
		_draw_step(dt)
	elif held and ammo <= 0:
		start_reload()

func _draw_step(dt: float) -> void:
	var top := float((wpn["draw"][-1] as Array)[0])
	if draw_t < 0.0:
		draw_t = 0.0
		m.sfx("charge", pos, -12.0 if is_local() else -16.0, 1.6)
	draw_t += dt * (ak.draw_rate() if ak else 1.0)
	if ctrl == "bot" and draw_t >= top + 0.05:
		_loose()

## Looses a drawn arrow: the draw stage reached sets damage, range and speed.
func _loose() -> void:
	var t := draw_t
	draw_t = -1.0
	if not can_fire() or ammo <= 0:
		return
	var stages: Array = wpn.get("draw", [])
	var dmg := float(wpn.get("draw_early", 15.0)); var rng := float(wpn["range"]); var spd := float(wpn["speed"])
	for stg in stages:
		if t >= float(stg[0]):
			dmg = float(stg[1]); rng = float(stg[2]); spd = float(stg[3])
	if ak and ak.has_method("draw_bonus"):
		dmg *= float(ak.draw_bonus(t))       # the kit's stage rules (Hem: the perfect window, overdraw, where it lands)
	var keep := wpn
	wpn = wpn.duplicate()
	wpn["dmg"] = dmg * wup_dmg; wpn["range"] = rng; wpn["speed"] = spd
	_release()
	wpn = keep
	if t >= float((stages[-1] as Array)[0]) if not stages.is_empty() else false:
		m.fx.flash(pos + Vector3(aim_dir().x * 0.7, 1.0, aim_dir().y * 0.7), keep["color"], 0.5, 0.06)

func charge_k() -> float:
	if not wpn.get("melee", false) or not wpn.has("charge_time") or mel_hold <= 0.12:
		return 0.0
	return clampf(mel_hold / float(wpn["charge_time"]), 0.0, 1.0)

func _fire_slow() -> float:
	if draw_t >= 0.0:
		return float(wpn.get("draw_slow", 0.7))
	var firing: bool = fire_cd > 0.0 or warm_t > 0.0 or (spin > 0.0 and inp["fire"]) or charge_k() > 0.0
	if not firing:
		return 1.0
	return float(wpn.get("fire_slow", 1.0 if wpn.get("melee", false) else 0.8))

func fire() -> void:
	if not can_fire() or fire_cd > 0.0 or warm_t > 0.0:
		return
	if wpn.get("melee", false):
		_swing()
		return
	if ammo <= 0:
		start_reload()
		return
	if cloak_t > 0.0:
		cloak_t = 0.0
		m.sfx("cloak", pos, -8.0)
	idle_fire = 0.0
	reveal_t = maxf(reveal_t, 1.2)
	if float(wpn.get("warmup", 0.0)) > 0.0:
		# the sniper winds up with its laser showing, then fires
		warm_t = float(wpn["warmup"])
		fire_cd = 0.0
		m.sfx("charge", pos, -6.0 if is_local() else -12.0, 1.3)
		return
	_release()

## The round actually leaving the gun (straight away, or once a wind-up ends).
func _release() -> void:
	var rate: float = wpn["rate"] * (1.0 - minf(0.5, owner_stat("fire_rate") + buff("fire_rate")))
	fire_cd = rate
	idle_fire = 0.0
	ammo -= 1
	recoil = 1.0
	muzzle_t = 0.05
	burst_left = int(wpn.get("burst", 1)) - 1
	burst_t = float(wpn.get("burst_gap", 0.07))
	_emit_shot()
	Oomph.on_fire(self)
	if ammo <= 0 and burst_left <= 0:
		start_reload()

func _tick_weapon(dt: float) -> void:
	if warm_t > 0.0:
		warm_t -= dt
		if not can_fire() or ammo <= 0:
			warm_t = 0.0
		elif warm_t <= 0.0:
			warm_t = 0.0
			_release()
	# per-shot bloom recovers once you've stopped firing for a beat
	if wbloom > 0.0 and idle_fire > float(wpn["rate"]) + 0.2:
		wbloom = maxf(0.0, wbloom - float(wpn.get("bloom_recover", 20.0)) * dt)
	if idle_fire > 0.35 or reload_t > 0.0:
		sus_n = 0
	if not strike_at_end.is_empty():
		if roll_t > 0.0 and not downed and stun_t <= 0.0:
			# the lunge curves to follow your aim
			roll_dir = roll_dir.slerp(aim_dir(), minf(1.0, dt * 6.0)).normalized()
		else:
			var st: Dictionary = strike_at_end
			strike_at_end = {}
			if not downed and stun_t <= 0.0:
				_strike(float(st["dmg"]), float(st["reach"]), float(st["arc"]), float(st["kb"]), st)

## Burst weapons fire the rest of their burst on a short timer (see sim).
var burst_left := 0
var burst_t := 0.0
func _tick_burst(dt: float) -> void:
	if burst_left <= 0:
		return
	burst_t -= dt
	if burst_t > 0.0:
		return
	if ammo <= 0 or not can_fire():
		burst_left = 0
		return
	burst_left -= 1
	burst_t = float(wpn.get("burst_gap", 0.07))
	ammo -= 1
	recoil = 1.0
	muzzle_t = 0.05
	_emit_shot()
	Oomph.on_fire(self)
	if ammo <= 0 and burst_left <= 0:
		start_reload()

## Melee: a wedge in front of you, a short step into it, and a combo whose last hit lands hardest.
## Swing again within the combo window to keep it going. Hold to charge a heavier attack instead.
var combo_i := 0
var swing_at := -9.0
var swing_t := 0.0             # for the swing animation, counts down
var swing_n := 0
func _swing() -> void:
	var cd: Array = wpn.get("combo_dmg", [])
	var cn: int = cd.size() if cd.size() > 0 else (wpn.get("combo", [1.0]) as Array).size()
	if m.time - swing_at > float(wpn["rate"]) + float(wpn.get("combo_reset", 0.6)):
		combo_i = 0
	var step := combo_i % cn
	var dmg: float = float(cd[step]) if cd.size() > 0 else float(wpn["dmg"]) * float((wpn.get("combo", [1.0]) as Array)[step])
	var last: bool = step == cn - 1
	combo_i += 1
	swing_at = m.time
	fire_cd = float(wpn["rate"]) * (1.35 if last else 1.0)
	# a basic swing never moves you: you keep walking control (fire_slow), and gap-closers live on
	# right click (and in a deliberate held charge where a weapon has one)
	_strike(dmg, float(wpn["range"]), float(wpn.get("arc", 100.0)), float(wpn["kb"]) * (1.5 if last else 1.0), {"heavy": last})

## A step forward with the swing. Lunges close together get 25% shorter each time.
func _lunge(dist: float) -> void:
	if dist <= 0.0 or not grounded:
		return
	if m.time - lunge_at > 1.2:
		lunge_n = 0
	var k := pow(0.75, lunge_n)
	lunge_n += 1
	lunge_at = m.time
	# the speed that covers about dist before ground friction takes it back (it bleeds off slower
	# while you're holding a direction)
	var d2 := aim_dir()
	var moving := (inp["move"] as Vector2).length() > 0.1
	var want := sqrt(2.0 * (GROUND_OVERSPEED if moving else GROUND_SHED) * dist * k + (base_speed * base_speed if moving else 0.0))
	var hv := Vector2(vel.x, vel.z)
	var along := hv.dot(d2)
	hv += d2 * (maxf(along, want) - along)
	vel.x = hv.x; vel.z = hv.y

func _charged_attack() -> void:
	mel_hold = 0.0
	combo_i = 0
	swing_at = m.time
	fire_cd = float(wpn["rate"]) * 1.8
	var st := {"dmg": float(wpn.get("charged_dmg", float(wpn["dmg"]) * 2.5)), "reach": float(wpn.get("charged_reach", float(wpn["range"]) * (0.85 if wpn.has("charged_lunge") else 1.0))),
		"arc": float(wpn.get("charged_arc", float(wpn.get("arc", 100.0)) * (0.5 if wpn.has("charged_lunge") else 1.0))), "kb": float(wpn.get("charged_kb", float(wpn["kb"]) * 2.0)),
		"stun": float(wpn.get("charged_stun", 0.0)), "heavy": true, "charged": true}
	if wpn.has("charged_lunge"):
		# a lunging stab: you travel, and the hit lands where the lunge ends (charged lunges don't decay)
		var t := 0.2
		roll_dir = aim_dir()
		roll_t = t
		roll_speed = float(wpn["charged_lunge"]) / t
		dash_is_ex = false
		shove = {}
		strike_at_end = st
		m.fx.dash_trail(self)
		m.sfx("dash", pos, -4.0, 0.7)
	else:
		_strike(float(st["dmg"]), float(st["reach"]), float(st["arc"]), float(st["kb"]), st)

func _strike(dmg: float, reach: float, arc_deg: float, kb: float, o := {}) -> void:
	idle_fire = 0.0
	reveal_t = maxf(reveal_t, 1.2)
	if cloak_t > 0.0:
		cloak_t = 0.0
	swing_t = 0.18
	swing_n += 1
	var dir := aim_dir()
	var heavy: bool = o.get("heavy", false)
	var arc := deg_to_rad(arc_deg)
	var a0 := atan2(dir.y, dir.x)
	var y := pos.y + 0.95 * float(cdat["scale"])
	var extra := {"kb": kb, "swing": "%s_%d" % [nid, swing_n], "melee": true, "kbi": float(wpn.get("kb_influence", 0.3))}
	if wpn.has("tip_bonus"):
		extra["tip"] = [reach * 0.7, float(wpn["tip_bonus"])]
	if float(o.get("stun", 0.0)) > 0.0: extra["stun"] = float(o["stun"])
	if crit_t > 0.0: extra["crit"] = true
	_kin_riders(extra)
	Loot.rider(self, extra, dmg * m.dmg_mult(self))
	# the swing is a fan of very short, invisible strikes, so walls and terraces block it like shots
	var rays := 9 if arc_deg > 130.0 else 7
	for i in rays:
		var aa := a0 - arc * 0.5 + arc * float(i) / float(rays - 1)
		var st := Vector3(pos.x + cos(aa) * 0.25, y, pos.z + sin(aa) * 0.25)
		m.spawn_shot(self, st, Vector2(cos(aa), sin(aa)) * 40.0, dmg * m.dmg_mult(self), maxf(0.02, (reach - 0.25) / 40.0), 0.22, wpn["color"], extra)
	m.fx.slash(Vector3(pos.x, y - 0.15, pos.z), a0, arc, reach, wpn["color"], heavy)
	Oomph.on_fire(self, true)
	m.sfx(wpn["sfx"], pos, -4.0 if not o.get("charged", false) else 0.0, (0.8 if heavy else 1.15) + randf() * 0.1)

func _emit_shot() -> void:
	var dir := aim_dir()
	# no dice rolls: every shot goes where you aim. Fast guns sway in a fixed, learnable pattern,
	# wider as per-shot bloom builds up
	shot_n += 1
	var spread: float = float(wpn["spread"])
	var rng_add := 0.0
	if wpn.has("tighten_from_deg"):
		var tk := clampf(spun_t / float(wpn.get("tighten_time", 1.5)), 0.0, 1.0)
		spread = deg_to_rad(lerpf(float(wpn["tighten_from_deg"]), rad_to_deg(float(wpn["spread"])), tk))
		rng_add = float(wpn.get("spun_range", 0.0)) * tk
	var pel := int(wpn.get("pellets", 1))
	if pel <= 1:
		spread += deg_to_rad(wbloom)
	var a: float = atan2(dir.y, dir.x) + spread * 0.45 * float(SWAY[shot_n % SWAY.size()])
	var shot_y := pos.y + 0.95 * float(cdat["scale"])
	var start := Vector3(pos.x + cos(a) * 0.6, shot_y, pos.z + sin(a) * 0.6)
	var spd: float = wpn["speed"]
	if has_meta("zero_spread_t") and m.time < float(get_meta("zero_spread_t")):
		spread = 0.0            # a Thief's SMG right after a Shadow Step
		a = atan2(dir.y, dir.x)
	var rng: float = (float(wpn["range"]) + rng_add) * shot_range_k
	shot_range_k = 1.0
	var life: float = rng / spd
	var dmg: float = float(wpn["dmg"]) * m.dmg_mult(self)
	if wpn.has("nth"):
		nth_n += 1
		if nth_n % int(wpn["nth"][0]) == 0: dmg *= 1.0 + float(wpn["nth"][1])
	if wpn.has("sustain_loss"):
		dmg *= 1.0 - float(wpn["sustain_loss"]) * minf(1.0, float(sus_n) / float(wpn.get("sustain_rounds", 10)))
	sus_n += 1
	var extra := {"kb": wpn["kb"], "tracer": float(wpn.get("tracer", 1.0))}
	extra.merge(wpn.get("shot_x", {}), true)      # a weapon's own shot rules (Tether Lantern: through terrain)
	if wpn.has("decel"):
		# slugs slow down and stop at the weapon's range: v^2 = 2 a d
		extra["decel"] = float(wpn["decel"])
		spd = sqrt(2.0 * float(wpn["decel"]) * rng)
		life = spd / float(wpn["decel"]) + 0.05
	if wpn.has("close_mult"):
		extra["near"] = [float(wpn["close_mult"]), rng * 0.5]
	if wpn.has("far_mult"):
		extra["farf"] = [rng * float(wpn.get("far_start", 0.6)), float(wpn["far_mult"]), rng]
	if AimMode.take(self) == AimMode.CURSOR:
		life = AimMode.dist(self, rng) / spd      # lands at the cursor, clamped to range (scripts/match/aim/aim_mode.gd)
	if wpn.get("pierce", false):      # through everyone in line (Sparkle's bolts)
		extra["pierce"] = true
		extra["hitset"] = {}
	if wpn.has("boom"):
		extra["boom"] = wpn["boom"]; extra["boom_kb"] = wpn["boom_kb"]
	if crit_t > 0.0:
		extra["crit"] = true
	Loot.rider(self, extra, dmg)
	_kin_riders(extra)
	if pel > 1:
		# a shotgun throws the same fixed fan every time, wider with each shot in a row. However
		# few slugs land, the first one on a target still does a good share of the whole volley
		var fan: float = deg_to_rad(float(wpn.get("fan_deg", 23.0)) + wbloom) if wpn.has("fan_deg") else float(wpn.get("fan", 0.4))
		extra["pg"] = "%s_%d" % [nid, shot_n]
		extra["pn"] = pel
		extra["pf"] = float(wpn.get("pellet_floor", 1.0 / pel))
		for i in pel:
			var pa := a - fan * 0.5 + fan * float(i) / float(pel - 1)
			m.spawn_shot(self, Vector3(pos.x + cos(pa) * 0.6, shot_y, pos.z + sin(pa) * 0.6), Vector2(cos(pa), sin(pa)) * spd, dmg, life, wpn["size"], wpn["color"], extra)
	else:
		m.spawn_shot(self, start, Vector2(cos(a), sin(a)) * spd, dmg, life, wpn["size"], wpn["color"], extra)
	if wpn.has("bloom_deg"):
		wbloom = minf(float(wpn.get("bloom_max_deg", 6.0)), wbloom + float(wpn["bloom_deg"]))
	m.sfx(wpn["sfx"], pos, -2.0 if is_local() else -6.0)
	Juice.shot(self, start, Vector2(cos(a), sin(a)))

func start_reload() -> void:
	if reload_t > 0.0 or ammo >= int(wpn["mag"]) or downed or wpn.get("melee", false) or not wpn.has("reload"):
		return
	reload_t = float(wpn["reload"]) * (1.0 - owner_stat("reload") - gear_stat("reload")) * (0.7 if perk_n("quickhands") > 0 else 1.0)
	m.sfx("reload", pos, -8.0)

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
			if k >= 1.0: m.fx.flash(pos + Vector3(0, 1.0, 0), ud.color, 0.6, 0.08)

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
const SLOT_ALIAS := {"utility": "sec", "dodge": "dash", "gear0": "gear", "q": "gear", "k1": "kin", "e": "kin", "r": "ult"}
func ability_level(slot: String) -> int:
	var s := String(SLOT_ALIAS.get(slot, slot))
	return maxi(1, int(slot_lv.get(s, 1)))

## The rank line on an ability's hover panel ("" for things that don't rank).
func rank_text(slot: String) -> String:
	var s := String({"sec": "sec", "k1": "kin", "dash": "dash", "r": "ult"}.get(slot, ""))
	if s == "":
		return ""
	var lv := int(slot_lv.get(s, 0))
	var mx := int(SLOT_MAX[s])
	var per := "+30% duration, +15% damage" if s == "ult" else ("15% faster recharge" if s == "dash" else "+15% damage, 10% shorter cooldown, longer/bigger effects")
	if lv <= 0:
		return "Locked  ·  a skill point unlocks it"
	if ak and lv < mx:
		# an archetype slot: the next rank's concrete change (rank 2 when you're rank 1)
		var nr := Arch.next_ranks(arch, s, lv)
		if not nr.is_empty(): per = String(nr[0][1])
	return "Rank %d / %d%s" % [lv, mx, ("  ·  next rank: " + per) if lv < mx else "  ·  max rank"]

## Cooldown multiplier for a slot's rank: 10% shorter per rank past the first.
func rank_cd_k(slot: String) -> float:
	return 1.0 - 0.1 * float(ability_level(slot) - 1)

## What the HUD needs to draw one ability slot: name, short name, icon, colour, one-line desc,
## cooldown left and total, charges. slot: "sec" | "dash" | "gear" | "k1" | "r".
func slot_info(slot: String) -> Dictionary:
	var mki := MergeKit.slot_info(self, slot)
	if not mki.is_empty():
		return mki                       # merged: the form's slots
	if ak and (slot in ["sec", "utility", "k1", "e", "kin", "dash", "dodge", "x"] or KinCommand.class_ults()):
		return ak.slot_info(slot)
	var out := {"name": "", "short": "", "icon": "", "col": Color.WHITE, "desc": "", "cd": 0.0, "cd_max": 0.0, "charges": 0, "max_charges": 0, "verb": "", "ready": false, "level": ability_level(slot)}
	match slot:
		"sec", "utility":
			var d: AbilityDef = runner.def_of("utility") if runner else null
			if d == null: return out
			out.merge({"name": d.display_name, "short": d.short, "icon": d.icon, "col": d.color, "desc": d.desc, "cd": runner.cd_left("utility"),
				"cd_max": runner.cd_max("utility"), "charges": runner.charges("utility"), "max_charges": d.charges, "verb": d.verb, "ready": runner.is_ready("utility"), "charge": charge_frac()}, true)
		"dash", "dodge":
			var d: AbilityDef = dodge_def
			var dmax := max_dashes()
			out.merge({"name": d.display_name if d else "Dash", "short": (d.short if d else "Dash"), "icon": d.icon if d else "dash", "col": d.color if d else Color("bfe6ff"),
				"desc": d.desc if d else "",
				"cd": (1.0 - fposmod(dashes, 1.0)) * dash_regen() if dashes < dmax - 0.001 else 0.0, "cd_max": dash_regen(), "charges": int(floor(dashes)), "max_charges": int(dmax),
				"verb": d.verb if d else "dash", "ready": dashes >= 1.0}, true)
		"gear", "gear0", "q", "gear1", "v":
			var gi := 1 if slot in ["gear1", "v"] else 0      # glove 1 (Q) or glove 2 (V); gloves never rank (Gloves)
			var g: Dictionary = gear[gi]
			if g.is_empty() or not Gear.ALL.has(String(g["id"])): return out
			var gd: Dictionary = Gear.ALL[String(g["id"])]
			out.merge({"name": String(gd["name"]), "short": String(gd.get("short", gd["name"])), "icon": Gear.icon_of(String(g["id"])), "col": gd["col"], "desc": Gear.desc_of(String(g["id"]), int(g["rar"])),
				"cd": float(gear_cd[gi]), "cd_max": Gear.cd_of(String(g["id"]), int(g["rar"])), "charges": 1 if float(gear_cd[gi]) <= 0.0 else 0, "max_charges": 1, "verb": String(gd.get("verb", "")), "ready": float(gear_cd[gi]) <= 0.0 and Gear.active(String(g["id"]))}, true)
		"k1", "e":
			var k: Kin = kin
			if k == null or k.runner == null: return out
			var d: AbilitySpec = k.runner.def_of("k1")
			if d == null: return out
			out.merge({"name": d.display_name, "short": d.short, "icon": KinText.icon(d), "col": KinText.color(d), "desc": KinText.ability(k.effective("k1")), "cd": k.runner.cd_left("k1"), "cd_max": k.runner.cd_max("k1"),
				"charges": k.runner.charges("k1"), "max_charges": d.charges, "verb": d.stages[0].delivery.type, "element": d.theme, "ready": k.runner.is_ready("k1") and k.ready_to_fight()}, true)
		"r", "ult":
			var k := kin as Kin
			var u := KinMerge.def_for(k) if k and KinMerge.boki_with_you(self) else null
			var f := MergeForm.for_boki(k) if u else MergeForm.surge_form()
			var txt: String = " ".join(KinText.merge(u, k.carry_style() == "mount")) if u else String(MergeForm.data()["surge"]["flavor"])
			out.merge({"name": "Fusion", "short": "Fusion", "icon": "bond", "col": f["glow"], "desc": txt, "form": f, "bond": ult,
				"plan": KinMerge.plan(self), "cd": merge_cd, "cd_max": maxf(KinParts.MERGE_SPENT_TIME, MergeRelease.rest_s()) if kin != null and kin.resting() else KinParts.MERGE_SPENT_TIME, "charges": 1 if ult >= 1.0 else 0, "max_charges": 1,
				"ready": KinMerge.plan(self) in ["merge", "leap", "surge"]}, true)
	return out

## Q and V: your active kin's abilities, aimed at the cursor.
func use_kin_ability(slot: String) -> void:
	var k: Kin = kin
	if k == null or downed or dropping or riding:
		return
	if not k.ready_to_fight():
		_ab_feedback(slot, "deny")
		if is_local() and m.hud:
			m.hud.toast("%s is resting%s" % [k.rec.get("name", "Your Boki"), ("  ·  %s swaps in %s" % [Settings.key_cap("swap_kin"), (kin2 as Kin).rec.get("name", "your other Boki")]) if kin2 and (kin2 as Kin).hp > 0.0 else ""], Color("a2a8bb"))
		return
	if k.use_ability(slot, _ground_aim()) or k.pend_slot == slot:
		used[slot] = int(used.get(slot, 0)) + 1
		_ab_feedback(slot, "cast")
		if is_local():
			# tie the button to what happened: a flash line from you to the kin doing it, if it's away
			var kc := KinText.color(k.runner.def_of(slot))
			if k.flat_dist(self) > 2.5 and k.state != "shoulder":
				m.fx.bolt(pos + Vector3(0, 1.2, 0), k.pos + Vector3(0, 0.6, 0), Color(kc, 0.8))
			m.fx.ring(k.pos, 1.3, kc, 0.3)
	else:
		_ab_feedback(slot, "deny")

## C (with an archetype): your Boki's own ability, cast from wherever the Boki is (KinCommand.cast_c).
## On your shoulder it is cast through you; out in the field it casts where it stands.
func use_boki_c() -> void:
	if KinCommand.cast_c(self):
		if is_local() and m.sfx: m.sfx("skill", null, -10.0, 1.3)
		return
	_ab_feedback("k1", "deny")
	var why := KinCommand.c_deny_text(self)
	if why != "" and is_local() and m.hud: m.hud.toast_small(why, Color("ffb0a0"))

## R: the Merge (KinMerge.press): a full bond meter merges you with your Boki, with the Boki out it
## leaps back and merges, with none able to fight it is a weak surge.
func use_ultimate() -> void:
	if KinMerge.press(self):
		_ab_feedback("r", "cast")
		return
	_ab_feedback("r", "deny")
	var why := KinMerge.deny_text(self)
	if why != "" and is_local() and m.hud:
		m.hud.toast_small(why, Color("a2a8bb"))

## Tells the HUD a button press landed ("cast": the slot pops) or didn't ("deny": it shakes red
## with a soft buzz), so a press on cooldown never just silently does nothing.
func _ab_feedback(slot: String, kind: String) -> void:
	if not is_local() or m.hud == null or not m.hud.has_method("ability_feedback"):
		return
	m.hud.ability_feedback(slot, kind)
	if kind == "deny":
		m.sfx("warn", null, -16.0, 1.6)
	else:
		m.sfx("skill", null, -9.0, 1.15)

## X: swap which of your two kin is out. The benched one rests in your satchel.
func swap_kin(force := false) -> void:
	if kin2 == null or riding or out or (not force and (swap_cd > 0.0 or downed)):
		return
	var a: Kin = kin
	var b: Kin = kin2
	if b.dead or KinLoss.guarding(b) or (a and (a.state == "fused" or KinLoss.guarding(a))):
		return
	if a: a.bench()
	b.unbench()
	kin = b
	kin2 = a
	swap_cd = float(Content.rules("kin_ai").get("swap_cooldown", 3.0))
	m.on_kin_swap(self, b, a)

## Riders your kin puts on every shot or swing (KinSpec carry.on_shot while it rides with you, the
## merge's on_shot while merged): damage over time, slow, push, marks, splash and arcs. Never stun or root.
func _kin_riders(extra: Dictionary) -> void:
	var lists: Array = []
	var k: Kin = kin
	if k and k.ks and kin_carry_on() and not k.ks.carry_on_shot.is_empty():
		lists.append([k.ks.carry_on_shot, 1.0])
	var mo := KinMerge.on_shot(self)
	if not mo.is_empty():
		lists.append([mo, 1.0])
	MergeAugment.lmb(self, extra)          # a merge form's rider on this attack (docs/decisions/0004)
	for pair in lists:
		var os: Dictionary = pair[0]
		var kk: float = pair[1]
		for e in os.get("effects", []):
			var pr: Dictionary = (e as PartSpec).params
			match (e as PartSpec).type:
				"damage":
					if float(pr["over"]) > 0.0:
						extra["burn"] = maxf(float(extra.get("burn", 0.0)), float(pr["amount"]) * kk / float(pr["over"]))
						extra["burn_for"] = float(pr["over"])
					else:
						extra["ride_dmg"] = maxf(float(extra.get("ride_dmg", 0.0)), float(pr["amount"]) * kk)
				"slow":
					extra["slow"] = maxf(float(extra.get("slow", 0.0)), float(pr["duration"]))
					extra["slow_k"] = maxf(float(extra.get("slow_k", 0.0)), float(pr["strength"]))
					extra["dr"] = true
				"push":
					extra["kb"] = float(extra.get("kb", 0.0)) + float(pr["strength"]) * kk * 0.25
				"mark":
					extra["mark"] = [String(pr["mode"]), float(pr["duration"]), float(pr["amount"])]
		if float(os.get("splash", 0.0)) > 0.0 and not extra.has("boom"):
			extra["boom"] = float(os["splash"]); extra["boom_kb"] = 4.0; extra["boom_small"] = true
		if int(os.get("chain", 0)) > 0 and not extra.has("kx"):
			extra["fx_hit"] = [{"type": "chain", "count": int(os["chain"]), "first": 5.0, "dmg": float(wpn["dmg"]) * 0.5, "color": KinRules.cat_color("damage").to_html(false), "skip_here": true}]
			extra["fx_ctx"] = {"slot": "ult", "ability": "merge"}

func heal(n: float) -> void:
	if downed or out:
		return
	if remote:
		m.net_event(["heal", nid, n])
		return
	if blight_t > 0.0:
		n *= 1.0 - blight_k   # blighted: healing barely takes
	var before := hp
	hp = minf(max_hp, hp + n)
	if hp - before > 1.0:
		m.fx.number(pos + Vector3(0, 1.6, 0), hp - before, Color("8ff0a0"), false, "+")

## Drinking a tonic and repairing with an armor kit take a moment: you slow down, lower your gun and
## are open to hits (CONSUME_VULN). Dashing, getting stunned or going down spills it (you keep the item).
## The belt and what each item does: UtilityBelt, UtilityUse.
const DRINK_TIME := 1.1
const KIT_TIME := 1.6
var drink_t := 0.0
var kit_t := 0.0
var vuln_fx_t := 0.0            # paces the pulsing "vulnerable" tell while drinking or repairing
var finish_t := 0.0             # holding interact over a downed enemy (until the stomp commits)
var stomp: Dictionary = {}      # committed stomp on an enemy wisp: {o, t, hits} (see Life)

## Channelling a deathbox revive right now (Match._update_interact keeps box_rev_at fresh).
func box_reviving() -> bool:
	return m.time - box_rev_at < 0.12 and not downed and not out

func launch_to(target: Vector3, t: float) -> void:
	if target.y > pos.y + World.STEP and not m.world.is_void(target.x, target.z):
		# (movefeel) up onto higher ground (a grapple onto a ledge, a leap up a cliff): the move was
		# aimed there, so it's a sure arc that clears the lip (a pad flight) instead of a thrown
		# body that can clip the cliff's edge now that ledges no longer grab you on their own
		var d := Vector2(target.x - pos.x, target.z - pos.z).length()
		pad = {"from": pos, "to": target, "t": 0.0, "dur": maxf(0.12, t), "h": 0.6 + 0.12 * d}
		vel = Vector3((target.x - pos.x) / maxf(0.12, t), 0.0, (target.z - pos.z) / maxf(0.12, t))
		grounded = false
		fly_t = 0.0
		roll_t = 0.0
		return
	vel.x = (target.x - pos.x) / t
	vel.z = (target.z - pos.z) / t
	vel.y = (target.y - pos.y) / t + 0.5 * H_GRAV * t
	grounded = false
	fly_t = t + 0.3
	roll_t = 0.0

# ------------------------------------------------------------------ simulation
func sim(dt: float) -> void:
	Hex.tick(self, dt)
	prev = pos
	if out or extracted:
		if not merge_st.is_empty():
			KinMerge.end(self, "broken")      # (eliminated or extracted mid-merge: the form goes with you)
		return
	if riding:
		# aboard the skyship: you go where it goes until you jump
		if remote:
			net_follow(dt)
		else:
			pos = m.ship_pos_of(m.ship_of(self)) + Vector3(0, -1.2, 0)
			prev = pos
			vel = Vector3.ZERO
			if ctrl == "local" and inp["jump"]:
				m.ship_jump(self)
			for k in ["jump", "dash", "sig", "util1", "util2", "util3", "util4", "ult", "fire", "skill", "swap"]:
				inp[k] = false
		return
	tick_status(dt)
	if grounded:
		air_peak = pos.y
	for k in ["base_cd", "weak_t", "dash_buf", "hit_heat_t", "ex_cd", "reveal_t", "inv_t", "fire_cd", "coyote", "jump_buf", "mantle_cd", "grap_cd", "sig_cd", "cloak_t", "haste_t", "fortify_t", "recoil", "muzzle_t", "regen_wait", "land_t", "glide_cd", "bless_t", "crit_t", "sick_t", "phase_t"]:
		set(k, maxf(0.0, get(k) - dt))
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0: shield = 0.0
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			ammo = wpn["mag"]
	if dashes < max_dashes():
		dashes = minf(max_dashes(), dashes + dt / dash_regen())
	_refresh_kin_stats()
	var regen := owner_stat("regen") + kin_pt("owner_regen")
	if regen > 0.0 and not downed and hp < max_hp:
		hp = minf(max_hp, hp + regen * dt * (1.0 - blight_k if blight_t > 0.0 else 1.0))
	if kin_pt("owner_shield") > 0.0 and regen_wait <= 0.0 and kin_shield < kin_pt("owner_shield"):
		kin_shield = minf(kin_pt("owner_shield"), kin_shield + kin_pt("owner_shield") * 0.5 * dt)
	if owner_stat("dodge_regen") >= 0.99:
		dashes = max_dashes()
	for bk in kbuffs.keys():
		kbuffs[bk][1] = float(kbuffs[bk][1]) - dt
		if float(kbuffs[bk][1]) <= 0.0: kbuffs.erase(bk)
	if grounded:
		air_jumps = 0
		air_dashed = false
	armor_wait = maxf(0.0, armor_wait - dt)
	# shots spread more while you move, jump or have just dashed, and settle when you stand still
	if not remote:
		crouch = bool(inp.get("crouch", false)) and grounded and not downed and roll_t <= 0.0 and not gliding and not dropping and not riding and charge.is_empty()
	var want_bloom := -0.3 if crouch else 0.0
	if not grounded: want_bloom = 1.0
	elif Vector2(vel.x, vel.z).length() > 1.5 and not crouch: want_bloom = 0.45
	if roll_t > 0.0: want_bloom = 1.4
	bloom = lerpf(bloom, want_bloom, 1.0 - exp(-(10.0 if want_bloom > bloom else 4.0) * dt))
	if remote:
		net_follow(dt)
		return
	if not downed and not dropping:
		Bond.passive(self, dt)
	swap_cd = maxf(0.0, swap_cd - dt)
	KinMerge.tick(self, dt)
	# reload by itself once you stop shooting for a moment
	idle_fire += dt
	if idle_fire > 1.3 and ammo < int(wpn["mag"]) and reload_t <= 0.0 and not inp["fire"]:
		start_reload()
	if downed:
		# your other kin comes out of the satchel to pick you up if the active one can't
		if kin and (kin as Kin).state == "downed" and kin2 and (kin2 as Kin).hp > 0.0:
			swap_kin(true)
		# a wisp doesn't bleed out: it's lost to enemy stomps, a finish, or more damage
		if down_hp <= 0.0:
			m.eliminate(self, last_hit_by, "finished")
			return
	# bringing a teammate back at their deathbox: no attacks, and moving breaks it
	if box_reviving():
		BoxRevive.guard_inputs(self)
	# mid-stomp you're committed: none of your own buttons do anything until it ends
	if not stomp.is_empty():
		for kk in ["dash", "jump", "sig", "skill", "sec", "ult", "swap", "util1", "util2", "util3", "util4",
				"gear1", "gear2", "fire", "throw", "kin_ab"]:
			inp[kk] = false
		inp["move"] = Vector2.ZERO
	# inputs
	AirLimits.gate_drop(self)        # the opening drop: steering only (item 162)
	KinDowned.commit(self)           # carrying your Boki: Shift or interact puts it down; no jump, glide or firing
	MergeAugment.route(self)         # merging: nothing fires mid-transformation; merged in a form, C is off
	if ak: ak.gate_inputs()          # a kit's lock-out (Cinder's Flue Flight: only E)
	# gloves need no point: Gloves
	for gk in [["dash", "dash", "dash"], ["sec", "sec", "sec"], ["sig", "kin", "k1"], ["ult", "ult", "r"]]:
		_gate(gk[0], gk[1], gk[2])
	if not downed and not dropping and not out:
		gain_xp(dt * 1.2)       # a slow trickle, so a careful run still levels
	_tick_base(dt)
	if base_t > 0.0:
		inp["fire"] = false        # channeling: no attacks while you base
	if ak: ak.flow.route(dt)       # presses during a dash: fire, held to its end, or cancel it (DashFlow)
	if inp["dash"]: do_dash()
	if dash_buf > 0.0 and roll_t <= 0.0 and grap.is_empty() and pad.is_empty() and not inp["dash"]:
		dash_buf = 0.0
		do_dash()
	if inp["jump"]: do_jump()
	if runner:
		runner.rate = 1.0 + gear_stat("cdr")
		runner.tick(dt)
	var cdr := gear_stat("cdr")
	if cdr > 0.0:
		sig_cd = maxf(0.0, sig_cd - dt * cdr)
	for gi in 2:
		gear_cd[gi] = maxf(0.0, float(gear_cd[gi]) - dt)
		if inp.get("gear%d" % (gi + 1), false):
			if Hex.active(self) or (ak and ak.cast_locked()):
				_ab_feedback("gear%d" % gi, "deny")
			elif (gear[gi] as Dictionary).is_empty() or float(gear_cd[gi]) > 0.0 or not Gear.active(String(gear[gi].get("id", ""))):
				_ab_feedback("gear%d" % gi, "deny")
			else:
				m.use_gear(self, gi)
	if ak:
		# the archetype's kit: E utility, right click with its variants, R ultimate; the kin's own
		# ability is on its own key (C: cast from where the Boki is)
		ak.tick(dt)
		if inp["sig"]: ak.use_e()
		if inp["sec"]: ak.press_rmb()
		if inp.get("kin_ab", false) and not Hex.active(self) and not ak.cast_locked(): use_boki_c()
	elif inp["sig"]: use_kin_ability("k1")
	if inp.get("kin_ab", false) and ak == null: use_kin_ability("k1")
	# (a kin's second ability and mid-fight kin swaps are retired from the kit; bots don't press them)
	if inp["sec"] and runner and runner.has_slot("utility") and ak == null:
		var ud: AbilityDef = runner.def_of("utility")
		if not ud.charge.is_empty() and runner.is_ready("utility") and abil_charge.is_empty():
			abil_charge = {"t": 0.0}       # a charge-up: it fires when you let go
			m.sfx("rail", pos, -14.0, 0.6)
			m.sfx("ab_charge", pos, -6.0 if is_local() else -13.0)
		elif ud.charge.is_empty() and runner.use("utility", {"level": ability_level("sec")}):
			used["utility"] = int(used.get("utility", 0)) + 1
			_ab_feedback("sec", "cast")
		elif abil_charge.is_empty():
			_ab_feedback("sec", "deny")
	if not abil_charge.is_empty():
		_tick_charge(dt)
	for ui in UtilityBelt.SLOTS:
		if inp[UtilityBelt.KEYS[ui]]: UtilityBelt.press(self, ui)
	UtilityBelt.tick(self, dt)
	_tick_burst(dt)
	_tick_weapon(dt)
	swing_t = maxf(0.0, swing_t - dt)
	if inp["ult"]:
		if ak and KinCommand.class_ults(): ak.use_r()
		else: use_ultimate()
	trigger(dt)
	inp["kin_ab"] = false
	for k in ["dash", "jump", "sig", "util1", "util2", "util3", "util4", "ult", "sec", "gear1", "gear2", "skill", "swap"]:
		inp[k] = false
	_physics(dt)
	var ad := aim_dir()
	var want := atan2(-ad.x, -ad.y)
	if roll_t > 0.0 and not (ak and ak.aims_in_dash()):
		want = atan2(-roll_dir.x, -roll_dir.y)
	if not (ak and ak.face_locked()):
		face = lerp_angle(face, want, minf(1.0, dt * 20.0))

func pad_launch(to: Vector3) -> void:
	var d := Vector2(to.x - pos.x, to.z - pos.z).length()
	pad = {"from": pos, "to": to, "t": 0.0, "dur": clampf(d / 12.0, 0.7, 1.5), "h": maxf(pos.y, to.y) - pos.y + 2.5 + d * 0.12}
	roll_t = 0.0
	grap = {}
	grounded = false

func _pad_fly(dt: float) -> void:
	pad["t"] += dt
	var k := clampf(pad["t"] / pad["dur"], 0.0, 1.0)
	var a: Vector3 = pad["from"]; var b: Vector3 = pad["to"]
	var np: Vector3
	if pad.has("face"):
		np = _mantle_point(k)
	else:
		var y := lerpf(a.y, b.y, k) + 4.0 * float(pad["h"]) * k * (1.0 - k)
		np = Vector3(lerpf(a.x, b.x, k), y, lerpf(a.z, b.z, k))
	vel = (np - pos) / maxf(dt, 0.0001)
	pos = np
	if k >= 1.0:
		pos = b
		var ledge: bool = pad.get("ledge", false)
		var hvel := Vector2(vel.x, vel.z)
		if ledge and hvel.length() > 0.01:
			# out of a mantle you keep running in the same direction, no stop
			hvel = hvel.normalized() * float(pad.get("carry", base_speed))
		vel = Vector3(hvel.x, 0.0, hvel.y).limit_length(base_speed * 1.3)
		grounded = true
		pad = {}
		squash = 0.12 if ledge else 0.3
		m.fx.dust(pos, 3 if ledge else 8)
		m.sfx("land", pos, -12.0 if ledge else -8.0)

## Where a mantle has you at progress k (0..1): up the face with an ease-out (a quick pull that
## slows near the top), then over the lip with a small hop and an ease-in-out onto the top. The
## height never drops below the lip while you're over the cliff, so you can't sink into it.
func _mantle_point(k: float) -> Vector3:
	var a: Vector3 = pad["from"]; var f: Vector3 = pad["face"]; var b: Vector3 = pad["to"]
	var lip: float = pad["lip"]
	var sp: float = pad["split"]
	if k < sp:
		var u := k / maxf(0.001, sp)
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var hz := clampf(u * 3.0, 0.0, 1.0)          # snap against the wall in the first third
		return Vector3(lerpf(a.x, f.x, hz), lerpf(a.y, lip, e), lerpf(a.z, f.z, hz))
	var u2 := (k - sp) / maxf(0.001, 1.0 - sp)
	var e2 := u2 * u2 * (3.0 - 2.0 * u2)
	return Vector3(lerpf(f.x, b.x, e2), lerpf(lip, b.y, e2) + 0.22 * sin(u2 * PI), lerpf(f.z, b.z, e2))

## True while you're rising up a ledge (or in a scripted pad mantle).
func mantling() -> bool:
	return not lfloat.is_empty() or (not pad.is_empty() and pad.has("face"))

## How far through the climbing part of a mantle you are (0 when not mantling), for the animation.
func mantle_k() -> float:
	if not lfloat.is_empty():
		return 1.0
	if pad.is_empty() or not pad.has("face"):
		return 0.0
	var k := clampf(float(pad["t"]) / float(pad["dur"]), 0.0, 1.0)
	return 1.0 if k < float(pad["split"]) + 0.15 else 0.0

func _physics(dt: float) -> void:
	if pad.size() > 0:
		_pad_fly(dt)
		return
	if grap.size() > 0:
		_grapple(dt)
		return
	var mv: Vector2 = inp["move"] if stun_t <= 0.0 and root_t <= 0.0 else Vector2.ZERO
	var spd := base_speed * (1.35 if haste_t > 0.0 else 1.0) * (0.4 * (Life.R["stomp_slow"] if get_meta("stomped", false) else 1.0) if downed else 1.0) * slow_mult(0.65) * (0.88 if reload_t > 0.0 else 1.0) * _fire_slow() * (0.45 if drink_t > 0.0 or kit_t > 0.0 else 1.0) * (0.55 if crouch else 1.0) * (1.0 + gear_stat("speed")) * (_mount_speed() if mounted() and grounded else 1.0) * _chase_mod(mv)
	spd *= KinDowned.carry_speed(self)
	var hv := Vector2(vel.x, vel.z)
	var cur := hv.length()
	_hand_off_ended_dash()
	if roll_t > 0.0:
		roll_t -= dt
		hv = roll_dir * roll_speed
		_last_burst = {"dir": roll_dir, "speed": roll_speed}
		if not shove.is_empty():
			_shove_along()
		if not dash_pass.is_empty():
			_pass_along()
		if roll_t <= 0.0:
			hv = HunterMove.dash_exit(roll_dir * roll_speed, spd)     # no hard stop: the run carries on
			glide_handoff(roll_dir, roll_speed)     # (movefeel) open the glider now and it keeps the burst
			_last_burst = {}
	elif fly_t > 0.0:
		fly_t -= dt
	elif knock_t > 0.0:
		knock_t -= dt
		hv = hv.move_toward(Vector2.ZERO, 6.0 * dt)
		# directional influence: hold a key to bend the knockback, never to cancel it
		if mv.length() > 0.1:
			var spd0 := hv.length()
			hv = (hv + mv * spd0 * knock_steer * 4.0 * dt).limit_length(spd0)
	elif gliding:
		# the glider keeps the speed you bring into it (a dash or a pad into a glide carries) and
		# drifts on when you let go of the keys
		var gs := (GLIDE_SPEED * 0.5 if glide_fuel <= 0.001 else GLIDE_SPEED) * (1.0 + gear_stat("glide_speed"))
		gs += glide_lift.swoop
		hv = glide_dive.steer(hv, mv * gs, gs, dt) if glide_dive.on else glide_steer(hv, mv * gs, gs, dt)
		if dropping:
			# the drop goes where you point and stops when you let go: no fixed heading to circle on
			gs = DIVE_SPEED if diving else DROP_SPEED
			if not DropLaunch.locked(self):
				hv = DropFeel.steer(Vector2(vel.x, vel.z), mv, diving, dt)     # (the launch flies its arc)
			if drop_follow != null and m.skydrop:
				hv = m.skydrop.follow_hv(self, gs)     # in formation: the leader steers
		# wind roads carry you along (either way), updrafts lift you
		in_current = false
		if not dropping:
			var wd: Dictionary = m.world.wind_at(pos)
			if not wd.is_empty():
				in_current = true
				var wdir: Vector3 = wd["dir"]
				var w2 := Vector2(wdir.x, wdir.z).normalized()
				if hv.dot(w2) < 0.0: w2 = -w2
				hv = hv.lerp(w2 * 14.0, 1.0 - exp(-2.5 * dt))
				vel.y = lerpf(vel.y, clampf((float(wd["y"]) - pos.y) * 2.5, -3.0, 6.0), 1.0 - exp(-4.0 * dt))
			var up: Dictionary = m.world.updraft_at(pos)
			if not up.is_empty():
				in_current = true
				vel.y = move_toward(vel.y, 9.0, 45.0 * dt)     # (movefeel) grabs you harder (was 30: 0.33s to climb)
	else:
		# near-instant on the ground (and in a kit's hover); a jump keeps its run-up
		if grounded or (ak != null and ak.hovering()):
			var grip: float = m.ground_grip(pos)     # ice in a frost region: you skid instead of stopping
			if (mv * spd).length() >= 0.001:
				hv = accel2(hv, mv * spd, ground_accel * grip, 0.0, GROUND_OVERSPEED * grip, dt)
			else:
				hv = HunterMove.brake(hv, spd, grip, dt)
		elif glide_off_t < FEATHER_KEEP and not dropping:
			# (feathering) just after letting go of the glider you keep its speed and steering
			var gsf := GLIDE_SPEED * (1.0 + gear_stat("glide_speed"))
			hv = glide_steer(hv, mv * gsf, gsf, dt)
		elif not lfloat.is_empty():
			hv = accel2(hv, mv * spd, AIR_ACCEL, AIR_DECEL, AIR_OVERSPEED, dt)
		else:
			hv = HunterMove.air_steer(self, hv, mv * spd, dt)     # [game data] low air control: a jump keeps its run-up
	hv = MantleCarry.step(self, hv, dt)
	vel.x = hv.x; vel.z = hv.y
	update_lip()
	wall_moves.carry(self, mv, dt)
	_update_glide(dt)
	if not lfloat.is_empty() and _ledge_rise(dt, mv):
		pass   # rising up a ledge's face (sets vel.y; your keys steer as in any jump)
	elif gliding and in_current:
		pass   # the current sets the height
	elif gliding and not dropping and below_lip:      # overheated: still lifts, at half strength, while it burns
		# below ground level over the abyss the glider lifts you hard, then brakes near the top.
		# Let go just before ground level to carry the lift up as height (feathering)
		vel.y = abyss_lift_vy(vel.y, lip_y - pos.y, dt, 1.0 if glide_fuel > 0.001 else 0.5)
		glide_lift.hang_t = GlideLift.HANG_T
	elif gliding:
		var sink := (DIVE_FALL if diving else DROP_FALL) if dropping else (5.0 if glide_fuel <= 0.001 else glide_fall(Vector2(vel.x, vel.z).length()))
		if dropping:
			vel.y = DropFeel.fall_vy(vel.y, sink, DIVE_VY_RATE if diving else DROP_VY_RATE, pos.y - ground(), dt)
			if drop_follow != null and m.skydrop:
				vel.y = m.skydrop.follow_vy(self)
		elif glide_dive.on:
			vel.y = glide_dive.fall_vy(vel.y, dt)
		else:
			sink = glide_lift.sink(self, sink)     # high over the ground: pulled down, the drop becomes speed
			if vel.y < -sink:
				vel.y = move_toward(vel.y, -sink, GLIDE_CATCH * dt)    # the canopy catches you over a beat
			else:
				vel.y = maxf(vel.y - GLIDE_GRAV * glide_lift.gravity_scale() * dt, -sink)
			# [footage] over the abyss a glider holds at island level instead of sinking below it,
			# so you can cross until the heat runs out
			if over_void() and glide_fuel > 0.001 and vel.y < 0.0 and pos.y + vel.y * dt < lip_y:
				vel.y = minf(0.0, (lip_y - pos.y) / dt)
	elif MergeKit.rising(self):
		vel.y = MergeKit.rise_vy(self)      # the ultimate's climb (Thunderhead)
	elif roll_t > 0.0 and not grounded and not dropping:
		vel.y = ak.dash_vy(dt) if ak else 0.0          # an air dash holds your height (a skate sinks)
	elif not grounded:
		vel.y = maxf(vel.y - H_GRAV * dt, -HunterMove.fall_cap(self))
	# a person walks straight off an island's edge and falls (then the glider and the abyss rules
	# take over); only bots keep an edge guard, so walking can't carry one into the abyss by accident
	var guard := ctrl == "bot" and grounded and roll_t <= 0.0 and hv.length() <= spd * 1.25
	# horizontal with walls; mantle onto ledges you run or fall into
	var x0 := pos.x; var z0 := pos.z
	var pre_v := Vector2(vel.x, vel.z)
	wall_hit_v = Vector2.ZERO
	var step_up := 0.0
	# rocks and trees: slide round them. Where you're heading is pushed straight out of any blocker
	# it overlaps, and the part of your speed going into it is dropped (no bounce, no catch on a
	# corner); the axis moves below then only meet terrain, edges and walls.
	StoneStand.mover = self         # (rocks: only their caster climbs them)
	var tgt := Vector2(pos.x + vel.x * dt, pos.z + vel.z * dt)
	var po: Vector2 = tgt if spirit_t > 0.0 else m.world.push_out_blocks(tgt.x, tgt.y, r, pos.y)
	var block_n := Vector2.ZERO     # out of the rock you met this step (its face's normal)
	var rock_b := 0.0               # ...and its top, standing in for occupy()'s answer below
	if po.distance_squared_to(tgt) > 1e-10:
		block_n = (po - tgt).normalized()
		rock_b = m.world.ground_at(tgt.x - block_n.x * r * 0.7, tgt.y - block_n.y * r * 0.7) + World.BLOCK_H
		var hvb := Vector2(vel.x, vel.z)
		var into := hvb.dot(block_n)
		if into < 0.0:
			hvb -= block_n * into
			vel.x = hvb.x; vel.z = hvb.y
		tgt = po
	var nx := tgt.x
	var b1: float = _occ(nx, pos.z, guard)
	if b1 == 0.0: pos.x = nx
	elif grounded and b1 > 0.0 and b1 - pos.y <= World.LEVEL + 0.05: step_up = b1
	elif b1 > 0.0 or b1 == -1.0: vel.x = 0.0 if b1 == -1.0 else vel.x * -0.1
	var nz := tgt.y
	var b2: float = _occ(pos.x, nz, guard)
	if b2 == 0.0: pos.z = nz
	elif grounded and b2 > 0.0 and b2 - pos.y <= World.LEVEL + 0.05: step_up = maxf(step_up, b2)
	elif b2 > 0.0 or b2 == -1.0: vel.z = 0.0 if b2 == -1.0 else vel.z * -0.1
	if step_up > 0.0 and mv.length() > 0.3:
		# walking into a single terrace steps you up it smoothly, no hop
		step_vis -= step_up - pos.y
		pos.y = step_up
		prev.y = pos.y
		var fw := mv.normalized() * spd * dt
		if _occ(pos.x + fw.x, pos.z + fw.y, guard) == 0.0:
			pos.x += fw.x; pos.z += fw.y
	elif step_up == 0.0 and (b1 > 0.0 or b2 > 0.0) and hv.length() > 1.0:
		# caught on a corner: slip sideways around it rather than sticking
		var moved := Vector2(pos.x - x0, pos.z - z0).length()
		var want := hv.length() * dt
		if moved < want * 0.35:
			var dn := hv.normalized()
			# (try first the side that leads away from what stopped you, never round toward it)
			var wn := -Vector2(pre_v.x if b1 > 0.0 else 0.0, pre_v.y if b2 > 0.0 else 0.0)
			var sides := [Vector2(-dn.y, dn.x), Vector2(dn.y, -dn.x)]
			if wn.dot(sides[1]) > wn.dot(sides[0]): sides.reverse()
			for side in sides:
				var tx: float = pos.x + (side.x * 0.8 + dn.x * 0.4) * want
				var tz: float = pos.z + (side.y * 0.8 + dn.y * 0.4) * want
				if _occ(tx, tz, guard) == 0.0:
					pos.x = tx; pos.z = tz
					break
	# a safety net: pushing to move for a second without going anywhere means something has us
	# wedged, so step out to the nearest open ground
	if grounded and mv.length() > 0.3 and stun_t <= 0.0 and root_t <= 0.0 and not remote and grap.is_empty():
		if Vector2(pos.x - x0, pos.z - z0).length() < 0.004 and _boxed_in():
			wedged_t += dt
			if wedged_t > 0.9:
				wedged_t = 0.0
				var free: Vector3 = m.world.free_spot_near(pos, [], 1.0, r, 2.5)
				if free.distance_to(pos) > 0.05 and absf(free.y - pos.y) < 1.0:
					pos = Vector3(free.x, free.y, free.z)
					m.fx.dust(pos, 4)
		else:
			wedged_t = 0.0
	var blk := maxf(maxf(b1, b2), rock_b)
	# (a rock you slid along counts as a wall you hit, with the part of your speed that went into it)
	var rock_v := block_n * minf(0.0, pre_v.dot(block_n)) if rock_b > 0.0 else Vector2.ZERO
	if b1 > 0.0 or b2 > 0.0:
		wall_hit_v = Vector2(pre_v.x if b1 > 0.0 else 0.0, pre_v.y if b2 > 0.0 else 0.0)
	elif rock_v.length() > 0.01:
		wall_hit_v = rock_v
	if (b1 > 0.0 or b2 > 0.0 or rock_v.length() > 0.01) and blk > pos.y + 0.6:
		# against a wall: in the air you can kick off it; knocked into it hard, you're stunned
		if not grounded:
			wall_touch_t = 0.2
			wall_n = Vector2(-signf(pre_v.x) if b1 > 0.0 else 0.0, -signf(pre_v.y) if b2 > 0.0 else 0.0).normalized() if (b1 > 0.0 or b2 > 0.0) else block_n
			wall_moves.hit(self, pre_v, blk)
		if m.time - kb_t < 0.6 and pre_v.length() > 8.0 and wslam_t <= 0.0 and not remote:
			wslam_t = 1.2
			var st := maxf(0.9, wallstun)
			wallstun = 0.0
			stun_t = maxf(stun_t, st)
			m.on_wall_slam(self)
			hurt(10.0, last_hit_by, {"src": "wall"})
	if grounded:
		wall_moves.land()
		glide_lift.hang_t = 0.0
	wall_touch_t = maxf(0.0, wall_touch_t - dt)
	wslam_t = maxf(0.0, wslam_t - dt)
	# rocks, trees and walls are walls: no hop onto them (item 151; their tops were never ground, so a hop left
	# you inside the clump). Terrain ledges are the ledge rise's (_ledge_rise).
	StoneStand.climb(self, maxf(b1, b2))      # the caster walking into her own rock rises onto it
	StoneStand.mover = null
	var g := ground()
	if grounded and g < pos.y - 0.05:
		grounded = false
		vel.y = minf(vel.y, 0.0)
		coyote = 0.12
	if not grounded:
		var fv := vel.y
		pos.y += vel.y * dt
		air_peak = maxf(air_peak, pos.y)
		if g > World.VOID + 1.0 and vel.y <= 0.0 and pos.y <= g and pos.y > g - 1.25:
			pos.y = g
			vel.y = 0.0
			grounded = true
			fly_t = 0.0
			_skyfall(air_peak - g, fv)
			air_peak = g
			if gliding:
				gliding = false
				m.fx.dust(pos, 5)
			var was_drop := dropping     # (movefeel) the drop's own landing has its feedback (Match.on_drop_landed)
			if dropping:
				dropping = false
				diving = false
				m.on_drop_landed(self)
			if shot_down:
				# spiked onto the ground [wiki]: a 0.7s stun and a little extra damage
				shot_down = false
				stun_t = maxf(stun_t, SPIKE_STUN)
				hurt(SPIKE_DMG, last_hit_by, {"src": "fall"})
				m.fx.dust(pos, 12)
				m.fx.ring(pos + Vector3(0, 0.05, 0), 1.6, Color(1.0, 0.6, 0.4, 0.6), 0.3)
			if fv < -11.0 or cur > spd * 1.3:
				m.fx.dust(pos, 6)
				squash = 0.15
				land_t = 0.2
				m.sfx("land", pos, -10.0)
			elif fv < -4.0 and not was_drop:
				# (movefeel) every real landing reads: a brief squash by how fast you came down, a puff
				# and a soft thud; no lockout, you keep moving the same step
				squash = maxf(squash, clampf(-fv / 60.0, 0.07, 0.16))
				m.fx.dust(pos, 2 if fv > -8.0 else 4)
				m.sfx("land", pos, (-16.0 if fv > -8.0 else -12.0) + (0.0 if is_local() else -6.0))
			if fv < -17.0:
				# a long drop lands hard: a thud, a puff of dust and a short stagger
				m.fx.dust(pos, 12)
				squash = 0.25
				land_t = 0.32
			if jump_buf > 0.0:
				jump_buf = 0.0
				vel.y = JUMP_V
				grounded = false
	else:
		pos.y = g
	if grounded:
		last_gy = pos.y
		if int(m.time * 10.0) != int((m.time - dt) * 10.0) and not dropping:
			var w: World = m.world
			if not (w.is_void(pos.x + 1.4, pos.z) or w.is_void(pos.x - 1.4, pos.z) or w.is_void(pos.x, pos.z + 1.4) or w.is_void(pos.x, pos.z - 1.4)):
				safe_pos = pos
	_unclip()
	_try_ledge_grab(dt)
	if _in_abyss():
		fall_out()

## Lost to the abyss: over the void a few metres below the lowest island lip around you (see
## World.abyss_floor), so a fall is over quickly instead of dropping a long way under the islands.
## A glider that still has heat gets a little more room to lift you back out.
func _in_abyss() -> bool:
	if pos.y < -40.0:
		return true
	if grounded or not over_void():
		return false
	return pos.y < abyss_kill_y()

## (movefeel) The point of no return under you: below this you're lost to the abyss. World.ABYSS_DEPTH
## (6m, shared with monsters and the home island) plus ABYSS_EXTRA for hunters, so there's real room to
## recover with the glider, an updraft or a ledge float; a glider with heat left gets ABYSS_GLIDE_ROOM
## more. The HUD's abyss danger reads this (AbyssFx.danger).
const ABYSS_EXTRA := 11.5         # [game data] AbyssHeight: lost 17.5m under ground level (with World.ABYSS_DEPTH)
func abyss_kill_y() -> float:
	var fl: float = m.world.abyss_floor(pos.x, pos.z, last_gy) - ABYSS_EXTRA
	if gliding and glide_fuel > 0.001:
		fl -= ABYSS_GLIDE_ROOM
	return fl

## Islands are solid all the way down: if anything (a pull, a drag, a shove) has left you inside an
## island's column below its top, you're put back beside it, or on top when the top is in reach.
func _unclip() -> void:
	if grounded or pad.size() > 0 or grap.size() > 0:
		return
	var w: World = m.world
	var g: float = w.ground_at(pos.x, pos.z)
	if g <= World.VOID + 1.0 or pos.y > g - 1.25 or ground() != g:
		return
	if g - pos.y <= MANTLE_REACH_ABYSS and not w.is_block(pos.x, pos.z):
		pos.y = g
		vel.y = 0.0
		grounded = true
		return
	for rad in [0.5, 0.8, 1.2, 1.7, 2.4, 3.2, 4.5]:
		for i in 16:
			var a := TAU * i / 16.0
			var x: float = pos.x + cos(a) * rad; var z: float = pos.z + sin(a) * rad
			if w.is_void(x, z) and w.occupy(x, z, r, pos.y, false) == 0.0:
				pos.x = x; pos.z = z
				vel.x = 0.0; vel.z = 0.0
				return
	if safe_pos != Vector3.INF:
		teleport(safe_pos)
		vel = Vector3.ZERO

## Falling with the canopy folded: the opening skydive, or the glider's dive.
func plunging() -> bool:
	return diving or glide_dive.on

## The skydive ends: the glider snaps open and the fall slows right down.
func _deploy() -> void:
	if not diving:
		return
	diving = false
	glide_k = 0.0
	# (movefeel) the canopy bites: your fall checks hard (DEPLOY_POP), then settles to the drop's sink
	vel.y = maxf(vel.y, DEPLOY_POP)
	m.sfx("glide", pos, -2.0)
	_glider_sfx("open")

## Using a heal in the air: the glider folds (it can't be held while you drink; holding glide again
## opens it after a beat and spills what's left). The opening drop never gets here (AirLimits).
func _fold_for_action() -> void:
	if gliding and not dropping:
		gliding = false
		glide_cd = maxf(glide_cd, 0.4)
		_glider_sfx("close")

## Knocked out of a drink, a repair or a box revive: it spills (nothing is used up) and everyone sees it.
func _interrupt_consume() -> void:
	if drink_t <= 0.0 and kit_t <= 0.0 and not box_reviving():
		return
	drink_t = 0.0
	kit_t = 0.0
	BoxRevive.cancel(self)
	m.fx.word(pos + Vector3(0, 2.3, 0), "INTERRUPTED", Color("ff8a5a"))
	m.fx.burst(pos + Vector3(0, 1.3, 0), Color("ff7a4a"), 10, 3.0, 0.35, 8.0)
	m.sfx("crit", pos, -4.0, 0.7)

## Hold jump while falling to open the glider. It folds when you land, run out, dash, or get hit.
var air_t := 0.0                # time since you left the ground
func _update_glide(dt: float) -> void:
	air_t = 0.0 if grounded else air_t + dt
	glide_lift.tick(self, dt)
	DropLaunch.tick(self)            # the squad launch over: break off, the glider opens (item 163)
	glide_dive.tick(self, dt)
	if dropping:
		# the opening drop: the glider stays open until you land, or until you sink below the islands
		gliding = not grounded
		if diving:
			var void_below: bool = m.world.is_void(pos.x, pos.z)
			var above: float = pos.y - (World.VOID if void_below else m.world.ground_at(pos.x, pos.z))
			if (not void_below and above < DEPLOY_H) or (void_below and pos.y < 7.0) or (drop_follow != null and not drop_follow.diving):
				_deploy()
		if pos.y < -1.5:
			dropping = false
			diving = false
			glide_fuel = 1.0
		return
	if grounded:
		glide_fuel = minf(1.0, glide_fuel + dt / 1.2)
		glide_off_t = 9.0
	elif not gliding:
		glide_off_t += dt
	if grounded:
		shot_down = false
	# a player takes the glider back with a fresh press of glide; a bot's own glide input (it holds
	# glide over the void to recover) must not fold the glider it's being carried on
	var glide_press: bool = inp.get("glide", false) and not _auto_glide_held and ctrl != "bot"
	_auto_glide_held = inp.get("glide", false)
	if auto_glide and (glide_press or downed or out or (grounded and air_t <= 0.0 and vel.y <= 0.0)):
		auto_glide = false
	# an overheated glider scorches you while it stays open
	if gliding and not dropping and glide_fuel <= 0.001 and not downed:
		heat_burn += dt * max_hp * 0.035      # an overheated glider burns ~3.5% of your health a second (was a token 4/s)
		if heat_burn >= 20.0:                  # (in ~20-damage ticks, ~2 a second: not a stream of numbers)
			heat_burn -= 20.0
			hurt(20.0, null, {"src": "heat"})
	# an overheated glider stays open (slow and sinking) until you land or get hit again
	var can: bool = (lfloat.is_empty() or (bool(inp.get("glide", false)) and not bool(lfloat.get("g0", true)))) and not grounded and roll_t <= 0.0 and fly_t <= 0.0 and glide_cd <= 0.0 and not downed and stun_t <= 0.0 \
		and m.time - kb_t > 0.4 and pad.is_empty() and not shot_down
	var want: bool = inp.get("glide", false) or auto_glide
	if gliding and not _handoff.is_empty() and want and can:
		_take_glide_handoff()       # (movefeel) a burst that ended with the glider still open
	if gliding:
		if not want or not can:
			gliding = false
			glide_off_t = 0.0 if want == false and can else 9.0     # (feathering) a let-go, not a knock
			_glider_sfx("close")
		elif not in_current:
			# heat builds faster while the glider is lifting you out of the abyss
			# [footage] ~1s of lift burns a quarter; (feathering) a short tap's impulse costs less
			var lifting := below_lip and lip_y - pos.y > 0.3 and vel.y > 0.0
			lift_t = lift_t + dt if lifting else 0.0
			var hk := ((FEATHER_TAP_HEAT if lift_t <= FEATHER_TAP else 4.0) if lifting else 1.0) * (2.0 if hit_heat_t > 0.0 else 1.0)
			glide_fuel = maxf(0.0, glide_fuel - dt * hk / (glide_max * (1.0 + gear_stat("heat"))))
		if not dropping:
			stats["glide_t"] = float(stats.get("glide_t", 0.0)) + dt
	elif want and can and air_t >= (0.0 if inp.get("glide_btn", false) else GLIDE_ENGAGE) \
			and not AirLimits.glide_locked(self):
		# hold Space in the air and the glider opens a beat after you leave the ground (the glide
		# button opens it at once: there's no tap-to-jump to tell apart)
		gliding = true
		_take_glide_handoff()
		if below_lip:
			m.sfx("glide", pos, -2.0, 1.4)
			add_stat("feathers")
		_glider_sfx("open")
		glide_lift.open_kick(self)

# Ledge float: touch the side of any ground above you while you're still alive and you float
# back up onto it, the way Supervive does it. Walking into a step up a few terraces high does
# the same after a short push. Getting launched hard still carries you past the edge.
func _try_ledge_grab(dt: float) -> void:
	if not lfloat.is_empty() or grap.size() > 0 or pad.size() > 0 or fly_t > 0.0 or charge.size() > 0 or dropping or shot_down or pos.y < last_gy - 14.0 \
			or stun_t > 0.0 or root_t > 0.0 or Hex.active(self):
		push_t = 0.0
		return
	var w: World = m.world
	var mv: Vector2 = inp["move"]
	var reach := 0.0
	var max_rise := MANTLE_REACH + (TALL_CLIMB_EXTRA if HunterMove.climbs_tall(self) else 0.0)
	if grounded:
		# as in Supervive, walking into a wall doesn't climb it: jump, and you mantle at the top.
		# Bots still lean their way up so their paths work.
		if mv.length() < 0.5 or grap_cd > 0.0 or ctrl == "local":
			push_t = 0.0
			return
		var probe := Vector2(pos.x, pos.z) + mv.normalized() * (r + 0.35)
		var g2 := w.ground_at(probe.x, probe.y)
		if w.is_block(probe.x, probe.y) or g2 <= pos.y + World.STEP or g2 - pos.y > World.LEVEL * 2.0 + 0.05:
			push_t = 0.0
			return
		push_t += dt
		if push_t < 0.08:
			return
		reach = r + 0.6
		max_rise = World.LEVEL * 2.0 + 0.1
	else:
		push_t = 0.0
		# a hard launch carries you a moment before you can catch anything
		if grap_cd > 0.0 or (m.time - kb_t < 0.3 and Vector2(vel.x, vel.z).length() > 8.0):
			return
		# no magnet: you have to be below the edge, right up against the cliff, and pushing into it
		# (or, over the abyss, thrown into its side: the shove counts as the push)
		if mv.length() < 0.3:
			var shoved := over_void() or gliding or glide_off_t < FEATHER_KEEP     # thrown or glided into the face
			if shoved and wall_hit_v.length() >= 2.0:
				mv = wall_hit_v.normalized()
			elif carry_v >= MantleCarry.PUSH_SPEED:
				mv = MantleCarry.heading(self, mv)       # flying in with momentum is a push (item 185b)
			else:
				return
		reach = r + 0.4
	var void_here := over_void()
	if not grounded and mv.length() > 0.3:
		# a smooth sheer cliff right in front of you has nothing to hold, and its neighbours don't
		# catch you through it either (the deep abyss reach would otherwise reach round its corner)
		var fr := Vector2(pos.x, pos.z) + mv.normalized() * (r + 0.3)
		var fi := Vector2i(int(floor(fr.x)), int(floor(fr.y)))
		if w.inb(fi.x, fi.y) and w.sheer.has(w.idx(fi.x, fi.y)) and w.ground_at(fr.x, fr.y) > pos.y + World.STEP:
			return
	if not grounded and void_here and last_gy - pos.y > 0.3:
		max_rise = MANTLE_REACH_ABYSS      # deep in the abyss, any island wall you touch springs you back up
		# (movefeel) and a wall a short step away catches you too: falling at full speed just off a
		# face while steering along it used to slip past (wall-hug check: 15 of 40 at 3m down)
		reach = r + WALL_CATCH_REACH
		var sr := r + WALL_CATCH_REACH + 0.6
		for sz in range(int(floor(pos.z - sr)), int(floor(pos.z + sr)) + 1):
			for sx in range(int(floor(pos.x - sr)), int(floor(pos.x + sr)) + 1):
				if w.inb(sx, sz) and w.sheer.has(w.idx(sx, sz)):
					reach = r + 0.4      # a smooth sheer cliff nearby: only the usual reach
	var best := {}; var bd := 1e9
	for z in range(int(floor(pos.z - reach)), int(floor(pos.z + reach)) + 1):
		for x in range(int(floor(pos.x - reach)), int(floor(pos.x + reach)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			# a smooth sheer cliff (authored maps) has nothing to hold: you can't catch it from the air
			if not grounded and w.sheer.has(w.idx(x, z)):
				continue
			var gz := w.level[w.idx(x, z)] * World.LEVEL
			var dz := gz - pos.y
			if dz < (0.05 if not grounded and over_void() else World.STEP + 0.05) or dz > max_rise:
				continue
			var ex := clampf(pos.x, x + 0.06, x + 0.94); var ez := clampf(pos.z, z + 0.06, z + 0.94)
			var d := Vector2(ex - pos.x, ez - pos.z).length()
			var toward := Vector2(ex - pos.x, ez - pos.z)
			if grounded and toward.dot(mv) <= 0.0:
				continue
			# (movefeel) over the abyss below a lip, steering mostly along a wall still counts as pushing
			# into it (up to ~78 degrees off straight in): SUPERVIVE rarely lets a wall-hugger sink under
			# an island. Elsewhere the ledge rise wants keys or momentum into it, up to ~60 degrees off (MantleCarry)
			if not grounded and toward.length() > 0.01:
				if void_here and last_gy - pos.y > 0.3:
					if toward.normalized().dot(mv.normalized()) < 0.2:
						continue
				elif not MantleCarry.pushing(self, toward, mv):
					continue
			if not grounded and not void_here:
				# off the void, only a wall you're heading into and that rises above where you last stood:
				# hopping down a terrace must not float you back up it
				# and one that shares an edge with your tile: the tile ahead along a wall isn't the wall you press
				if absi(x - int(floor(pos.x))) + absi(z - int(floor(pos.z))) > 1:
					continue
				var stepping_back := gz <= last_gy + World.STEP and not GlideLift.airborne_long(self)
				if stepping_back or (toward.dot(mv) <= 0.0 and toward.dot(Vector2(vel.x, vel.z)) <= 0.0):
					continue
			if d < bd and d < reach:
				bd = d
				best = {"x": x, "z": z, "gz": gz, "ex": ex, "ez": ez}
	if best.is_empty():
		return
	# (ledge rise) no snap and no fixed path: you gain upward momentum and float up the face while
	# your own keys and momentum carry you sideways (see _ledge_rise)
	var dir_in := Vector2(float(best["ex"]) - pos.x, float(best["ez"]) - pos.z)
	if dir_in.length() < 0.01:
		dir_in = mv
	lfloat = {"lip": float(best["gz"]), "n": dir_in.normalized(), "t": 0.0, "g0": bool(inp.get("glide", false)),
		"shove": (inp["move"] as Vector2).length() < 0.3,     # thrown into the side with no keys: it carries you over
		"kb0": kb_t,                                          # (a fresh knock ends the rise; the one that threw you here doesn't)
		"at": Vector2(pos.x, pos.z), "downed": downed, "win": false, "tile": Vector2i(int(best["x"]), int(best["z"])),
		"v_in": carry_v,                                      # the speed you came in with comes over the top (item 185b)
		"max_t": clampf((float(best["gz"]) - pos.y) / LRISE_SPEED, 0.1, 0.9) * (1.35 if downed else 1.0) + 0.3}
	vel.y = maxf(vel.y, LRISE_MIN)
	grounded = false
	grap = {}
	grap_cd = LEDGE_CD
	push_t = 0.0
	gliding = false
	roll_t = 0.0
	m.sfx("grab", pos, -8.0, 1.2)
	m.on_ledge_grab(self)

## (ledge rise) One step of rising up a ledge: sets vel.y and returns true while it lasts. Your
## horizontal speed is the ordinary air steering (_physics): keys and momentum work the whole way,
## and the wall itself (World.occupy) is all that holds you to the face while you push into it.
## Over the top you pop up a little toward wherever you're holding. Moving off the face, a dash, a
## fresh glide press, a stun or a knock end it. A jump during the rise flings you (_ledge_fling).
const LRISE_PUSH := MantleCarry.APPROACH_DOT     # home.gd's ledge rise reads this (keys this far into the wall)
const LRISE_SPEED := 14.0      # [footage] a deep mantle returns to the top in ~0.8s (was MANTLE_RISE)
const LRISE_MIN := 4.0         # never slower than this near the top
const LRISE_POP := 2.6         # [est] up speed as you clear the lip with no jump (a ~0.25m pop)
const LRISE_OFF := 0.9         # moved this far out from the face: you've let go
const LRISE_WINDOW := 0.6      # [est] the fling window: the last this-many metres below the top (~0.12s)
const FLING_HEIGHT := 0.9     # [est] a fling timed in the window peaks this high over the top...
const FLING_SPEED := 7.5       # [est] ...going this fast toward your keys (run speed is ~5)
const FLING_EARLY_HEIGHT := 0.2  # [est] a jump before the window: only just over the top, at run speed
func _ledge_rise(dt: float, mv: Vector2) -> bool:
	var lf := lfloat
	lf["t"] = float(lf["t"]) + dt
	var n: Vector2 = lf["n"]
	var glide_now: bool = inp.get("glide", false)
	if not glide_now:
		lf["g0"] = false
	var off := (Vector2(pos.x, pos.z) - (lf["at"] as Vector2)).dot(-n) > LRISE_OFF
	# (a teleport; or you've slid along past the end of the face, so there's nothing beside you to rise up)
	var drift := Vector2(pos.x, pos.z).distance_to(lf.get("last", Vector2(pos.x, pos.z))) > 1.5 or not _face_near(float(lf["lip"]))
	lf["last"] = Vector2(pos.x, pos.z)
	if off or drift or gliding or downed != bool(lf["downed"]) or out or roll_t > 0.0 or stun_t > 0.0 or kb_t > float(lf.get("kb0", kb_t)) \
			or fly_t > 0.0 or grounded or dropping or float(lf["t"]) > float(lf["max_t"]) or (glide_now and not bool(lf["g0"])):
		lfloat = {}
		return false
	var lip := maxf(float(lf["lip"]), m.world.ground_at(pos.x + n.x * (r + 0.3), pos.z + n.y * (r + 0.3)))     # (props raise the top)
	var left := lip + 0.12 - pos.y
	if left <= 0.0:
		# over the lip: a small pop, carried toward your keys
		lfloat = {}
		vel.y = LRISE_POP
		var hv := Vector2(vel.x, vel.z)
		if mv.length() > 0.3:
			var d := mv.normalized()
			var along := hv.dot(d)
			if along < base_speed * 0.9:
				hv += d * (base_speed * 0.9 - along)
		# keys still leaning into the ledge (or a shove that threw you at it): enough speed onto the top
		# to land on it, on top of whatever your keys asked for
		if (mv.length() > 0.3 and mv.normalized().dot(n) > 0.15) or (bool(lf.get("shove", false)) and mv.length() <= 0.3):
			var short := HunterMove.mantle_launch(base_speed) - hv.dot(n)
			if short > 0.0:
				hv += n * short
		hv = MantleCarry.exit(self, hv, n, mv, float(lf.get("v_in", 0.0)))
		vel.x = hv.x; vel.z = hv.y
		mantle_cd = 0.3
		return true
	if not bool(lf["win"]) and left <= LRISE_WINDOW:
		# the fling window opens: a tick and a quick ring, so the timing reads
		lf["win"] = true
		if is_local():
			m.sfx("click", pos, -8.0, 1.6)
			m.fx.ring(pos + Vector3(0, 0.1, 0), 0.9, Color(1, 1, 1, 0.8), 0.18)
	vel.y = clampf(left * 14.0, LRISE_MIN, LRISE_SPEED) * (0.75 if downed else 1.0)
	return true

## Is there ground at the ledge's height within reach of your side (the face you're rising up)?
func _face_near(lip: float) -> bool:
	var w: World = m.world
	var rr := r + WALL_CATCH_REACH + 0.2
	for z in range(int(floor(pos.z - rr)), int(floor(pos.z + rr)) + 1):
		for x in range(int(floor(pos.x - rr)), int(floor(pos.x + rr)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			if absf(w.level[w.idx(x, z)] * World.LEVEL - lip) > 0.05:
				continue
			var ex := clampf(pos.x, x, x + 1.0); var ez := clampf(pos.z, z, z + 1.0)
			if Vector2(ex - pos.x, ez - pos.z).length() <= rr:
				return true
	return false

func teleport(p: Vector3) -> void:
	super(p)
	MantleCarry.forget(self)

## A jump during a ledge rise: in the window near the top, a strong fling (higher, faster, a whoosh);
## earlier, a weaker one. Either way toward the keys you hold (or up and onto the ledge with none).
func _ledge_fling() -> void:
	var lf := lfloat
	lfloat = {}
	var mvv: Vector2 = inp.get("move", Vector2.ZERO)
	var d: Vector2 = mvv.normalized() if mvv.length() > 0.3 else (lf["n"] as Vector2)
	var hv := Vector2(vel.x, vel.z)
	var timed: bool = lf.get("win", false)
	var spd := FLING_SPEED if timed else base_speed
	var along := hv.dot(d)
	if along < spd:
		hv += d * (spd - along)
	vel.x = hv.x; vel.z = hv.y
	# up speed to peak FLING_HEIGHT (or FLING_EARLY_HEIGHT) over the top from wherever you are on the face
	var left := maxf(0.0, float(lf["lip"]) + 0.12 - pos.y)
	vel.y = sqrt(2.0 * H_GRAV * (left + (FLING_HEIGHT if timed else FLING_EARLY_HEIGHT)))
	mantle_cd = 0.3
	air_t = 0.0        # (held Space opens the glider a beat later, as after any jump)
	stats["flings"] = int(stats.get("flings", 0)) + (1 if timed else 0)
	m.sfx("jump", pos, -6.0)
	if timed:
		m.sfx("whoosh", pos, -6.0 if is_local() else -12.0, 1.3)
		m.fx.ghost(position, face, Color("e6f6ff"), float(cdat["scale"]))

## Floating up the side: rise to the lip, drift onto it, then a small hop onto the top.
func _grapple(dt: float) -> void:
	grap["t"] += dt
	var tz: float = grap["gz"] + 0.5
	var rise := clampf(tz - pos.y, -FLOAT_SPEED * dt, FLOAT_SPEED * dt)
	pos.y += rise
	var hd := Vector2(grap["ex"] - pos.x, grap["ez"] - pos.z)
	var hs := 11.0 * dt
	if hd.length() <= hs: pos.x = grap["ex"]; pos.z = grap["ez"]
	else:
		var hn := hd.normalized() * hs
		pos.x += hn.x; pos.z += hn.y
	vel = Vector3.ZERO
	grounded = false
	grap["fx"] -= dt
	if grap["fx"] <= 0.0:
		grap["fx"] = 0.07
		m.fx.burst(pos + Vector3(0, 0.6, 0), Color("cfeaff"), 2, 1.2, 0.35, 0.0)
	if (absf(tz - pos.y) < 0.02 and hd.length() < 0.05) or grap["t"] > 2.0:
		pos = Vector3(grap["ex"], maxf(pos.y, tz), grap["ez"])
		var land: Vector3 = grap["land"]
		grap = {}
		pad = {"from": pos, "to": land, "t": 0.0, "dur": 0.22, "h": 0.4, "ledge": true}

# ------------------------------------------------------------------ visuals
var bot_look: Dictionary = {}  # how a bot hunter looks (random)
var runner: AbilityRunner     # weapon utility now; kin abilities later
var dodge_def: AbilityDef     # the class's dodge
var stats := {}                # this match's counts for challenges (the local player's)
var gear: Array = Gear.empty_slots()     # four slots of found gear (Gear.SLOTS): {id, rar}
var gear_cd: Array = [0.0, 0.0, 0.0, 0.0]

# ---- run levels: like Supervive, you start each run at level 1 with one skill point and every
# ability locked. XP comes from fighting (damage, knocks) and a slow trickle; each level gives a
# point to unlock or strengthen an ability. The ultimate opens at level 6 (rank 2 at 9).
const XP_TO := [0.0, 70.0, 170.0, 300.0, 460.0, 650.0, 870.0, 1120.0, 1400.0, 1710.0]   # total XP to reach level i+1
const SLOTS := ["sec", "dash", "kin", "ult"]                  # the hero's own abilities; gloves never rank (Gloves)
const SLOT_MAX := {"sec": 3, "dash": 3, "kin": 3, "ult": 2}
const ULT_AT := [6, 9]
var lvl := 1
var xp := 0.0
var skill_pts := 1
var level_ups := 0          # how many times this run the local level-up moment played (tests)
var slot_lv := {"sec": 0, "dash": 0, "kin": 0, "ult": 0}

func gain_xp(x: float) -> void:
	if lvl >= XP_TO.size() or x <= 0.0:
		return
	if m and m.rolling:
		x = m.rolling.scale_xp(self, x)      # catch-up XP below the session's median level (Rolling.xp_mult)
	xp += x
	while lvl < XP_TO.size() and xp >= float(XP_TO[lvl]):
		lvl += 1
		skill_pts += 1
		var wstep := {}
		if lvl % 2 == 0 and m and not remote:
			wstep = WeaponPath.on_level(self, lvl)      # every other level: the next step of this hero's fixed weapon path
		if m and not remote: LevelGrowth.apply(self)      # every level: a little more health and ability power, quietly
		# a gold ring pulse on the hunter that everyone nearby sees
		if m and m.fx and visible and not unseen:
			m.fx.ring(pos, 2.0, Color("ffd27a"), 0.4)
			m.fx.burst(pos + Vector3(0, 1.2, 0), Color("ffd27a"), 12, 2.5, 0.5, -2.0)
		if is_local() and m and m.hud:
			m.hud.level_up(lvl, wstep)
			# the level-up chime: its own rising bell run over a warm swell (tools/gen_sfx_ui.py)
			m.sfx("level_up", null, -2.0, 1.0)
			if kin is Kin: BokiChatter.say(m, kin, "level_up")
			level_ups += 1
	if not is_local():
		_bot_spend()

func xp_frac() -> float:
	if lvl >= XP_TO.size():
		return 1.0
	var a := float(XP_TO[lvl - 1]); var b := float(XP_TO[lvl])
	return clampf((xp - a) / (b - a), 0.0, 1.0)

func can_level(slot: String) -> bool:
	if skill_pts <= 0 or not SLOT_MAX.has(slot) or int(slot_lv.get(slot, 0)) >= int(SLOT_MAX[slot]):
		return false
	if slot == "ult":
		return lvl >= int(ULT_AT[mini(int(slot_lv["ult"]), ULT_AT.size() - 1)])
	return true

func level_slot(slot: String) -> bool:
	if not can_level(slot):
		return false
	slot_lv[slot] = int(slot_lv[slot]) + 1
	skill_pts -= 1
	if slot == "ult" and merge_free and kin != null:
		# the merge unlocks with a full bond meter, once a run
		merge_free = false
		ult = 1.0
		if m and m.has_method("on_bond_ready"): m.on_bond_ready(self)
	if is_local() and m and m.hud:
		m.hud.ability_feedback({"sec": "sec", "dash": "dash", "kin": "k1", "ult": "r"}[slot], "cast")
		m.sfx("unlock", null, -8.0, 1.0 + 0.1 * float(slot_lv[slot]))
	return true

## Bots (and anyone skipping the choice) spend points in a sensible order.
func _bot_spend() -> void:
	var order := ["sec", "dash", "kin", "sec", "kin", "dash", "sec", "kin", "dash"]
	if ak:
		# the archetype's recommended order (ARCHETYPES §6), which skips the R until it opens (and
		# any "gear" left in it: gloves don't rank)
		order = (ak.d.get("order", []) as Array).filter(func(x): return x != "ult" and SLOT_MAX.has(x)) + ["kin", "dash", "sec"]
	while skill_pts > 0:
		if can_level("ult"):
			level_slot("ult"); continue
		var done := false
		# follow the order as a list of ranks (sec 1, dash 1, kin 1, gear 1, sec 2, ...), so every slot
		# opens early: the kin's abilities are locked until its slot has a point (KinRules slot locks)
		var want := {}
		for s in order:
			want[s] = int(want.get(s, 0)) + 1
			if int(slot_lv[s]) < int(want[s]) and int(slot_lv[s]) < int(SLOT_MAX[s]) and can_level(s):
				level_slot(s); done = true; break
		if not done: break

## Everything open at rank 1, for practice modes.
func unlock_all() -> void:
	for s in SLOTS:
		slot_lv[s] = maxi(int(slot_lv[s]), 1)
	skill_pts = 0

## Pressing a locked ability: spend a point on it if you have one, otherwise say it's locked.
func _gate(key: String, slot: String, fb: String) -> void:
	if not inp.get(key, false) or int(slot_lv[slot]) > 0:
		return
	inp[key] = false
	if key == "dash": dash_buf = 0.0
	if is_local() and level_slot(slot):
		return
	_ab_feedback(fb, "deny")
	if is_local() and m.hud:
		if slot == "ult" and skill_pts > 0:
			m.hud.toast("Ultimate unlocks at level %d" % int(ULT_AT[0]), Color("a2a8bb"))
		else:
			m.hud.toast("Locked  ·  earn a skill point to unlock it", Color("a2a8bb"))

var base_armor := 50.0
## Armor evolves through a run, like Supervive's: damage you deal to rival hunters fills it (monsters
## count a third), and a knock adds a big chunk. Each tier adds plates on top of the base, and the new
## plates arrive full. Tier colour shows on everyone's armor bar, so you can read how fed a rival is.
const ARMOR_TIERS := [["Common", Color("dfe9f7"), 0.0], ["Uncommon", Color("7fe08a"), 220.0], ["Rare", Color("5fb6ff"), 560.0],
	["Epic", Color("c27cff"), 1000.0], ["Legendary", Color("ffbf3a"), 1600.0]]
const ARMOR_TIER_BONUS := 0.15     # of base armor per tier above Common
const ARMOR_KNOCK_XP := 140.0
var armor_xp := 0.0
var armor_tier := 0
var dmg_taken := 0.0
var downs := 0                # times knocked this match
var deaths := 0
var revives := 0              # teammates you picked up

## Adds armor progress; returns the new tier if it went up, else -1.
func armor_gain(xp: float) -> int:
	armor_xp += xp
	var up := -1
	while armor_tier < ARMOR_TIERS.size() - 1 and armor_xp >= float(ARMOR_TIERS[armor_tier + 1][2]):
		armor_tier += 1
		up = armor_tier
	if up >= 0:
		var old := max_armor
		refresh_gear()
		armor = minf(max_armor, armor + maxf(0.0, max_armor - old))
	return up

## How far into the current tier (0..1), for the HUD.
func armor_frac() -> float:
	if armor_tier >= ARMOR_TIERS.size() - 1:
		return 1.0
	var a := float(ARMOR_TIERS[armor_tier][2]); var b := float(ARMOR_TIERS[armor_tier + 1][2])
	return clampf((armor_xp - a) / (b - a), 0.0, 1.0)

func armor_col() -> Color:
	return ARMOR_TIERS[armor_tier][1]

func refresh_gear() -> void:
	max_armor = round(base_armor * (1.0 + ARMOR_TIER_BONUS * float(armor_tier))) + gear_stat("armor")
	armor = minf(armor, max_armor)
	Gear.apply_worn(self)

func gear_stat(k: String) -> float:
	var t := 0.0
	for g in gear:
		if not g.is_empty():
			t += float(Gear.ALL[g["id"]]["stats"].get(k, 0.0)) * Gear.mult(int(g["rar"]))
	for pk in perks:
		t += float((Data.PERKS.get(pk, {}).get("stats", {}) as Dictionary).get(k, 0.0))
	if kin != null and is_instance_valid(kin) and (k == "armor" or k == "sight"):
		t += Mutations.owner_stat((kin as Kin).rec, k)      # a Crystal or Glowing kin helps its hunter
	# your kin: its owner bonus points, carry passives, the merge and short ability buffs
	match k:
		"speed": t += owner_stat("move_speed") + kin_pt("owner_move_speed") + buff("move_speed")
		"dmg": t = KinMerge.cap_damage(self, t, owner_stat("damage") + buff("damage"))
		"heat", "glide_speed": t += owner_stat("glide")
		"cdr": t += owner_stat("cooldown")
	return t

## Ground speed while you ride your mount (its carry.mount speed).
func _mount_speed() -> float:
	var k: Kin = kin
	return float(k.ks.mount.get("speed", 1.0)) if k and k.ks else 1.0

## How many stacks of a perk you've picked up this run.
func perk_n(id: String) -> int:
	return perks.count(id)

## Can this perk still be offered to you (not at its stack limit)?
func perk_open(id: String) -> bool:
	return perk_n(id) < int(Data.PERKS.get(id, {}).get("max", 1)) and WeaponUps.fits(self, id)

## Takes a perk for the rest of the expedition. Stats that are worked out once (health, glider,
## dash charges, armor) are updated on the spot.
func add_perk(id: String) -> void:
	if not Data.PERKS.has(id) or not perk_open(id):
		return
	perks.append(id)
	match id:
		"toughskin":
			max_hp += 15.0; hp = minf(max_hp, hp + 15.0)
		"featherfall":
			glide_max *= 1.6
		"secondwind":
			dashes = minf(max_dashes(), dashes + 1.0)
	if (Data.PERKS[id] as Dictionary).has("wup"):
		WeaponUps.apply(self)
	refresh_gear()

func add_stat(k: String, n := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n
var unseen := false           # hidden from the local player (in a bush, or behind a wall)

var step_vis := 0.0            # eases the model up a terrace you just stepped onto
## The sniper's aiming laser while it winds up, and the minigun's barrels spinning.
var laser: MeshInstance3D
func _render_weapon_fx(delta: float) -> void:
	var on := warm_t > 0.0 and visible and not unseen
	if on and laser == null:
		laser = MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.04, 1.0)
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
			laser.global_transform = Transform3D(Basis.looking_at(Vector3(d.x, 0, d.y), Vector3.UP), a + Vector3(d.x, 0, d.y) * ln * 0.5)
			laser.scale = Vector3(lerpf(2.5, 0.6, k), lerpf(2.5, 0.6, k), ln)
			(laser.material_override as ShaderMaterial).set_shader_parameter("color", Color(wpn["color"], lerpf(0.25, 0.9, k)))
	if spin > 0.0 and model:
		var br: Node3D = model.find_child("Barrels", true, false)
		if br: br.rotation.z += delta * spin * 40.0

## For the animation: when this hunter last cast an ability (or threw its kin), and which.
var cast_at := -9.0
var cast_slot := ""
func _on_ability_used(caster: Node, _id: String, slot: String) -> void:
	if caster == self:
		MergeAugment.on_used(self, slot)          # a merge form's add-ons on RMB, E and Shift
	if caster == self and slot != "dodge" and slot != "primary" and m:
		cast_at = m.time
		cast_slot = "ult" if slot in ["ult", "ultimate"] else slot
	if slot in ["k1", "k2"] and kin is Kin and (caster == kin or caster == self) and is_local() and m:
		BokiChatter.say(m, kin, "ability")      # its own ability, used by it or through you

func _on_kin_thrown(_k: Node, owner: Node) -> void:
	if owner == self and m:
		cast_at = m.time
		cast_slot = "throw"

## The state HunterAnim poses the model from (one dictionary, refilled every frame).
var anim_s := {}
var _anim_dt := 0.0
var _anim_n := 0
const DODGE_ANIM := {"light": "phase", "medium": "roll", "heavy": "charge"}

## The dodge pose HunterAnim plays. Claire's skate has its own, so the light-dash lean does not stack
## on the skate move's lean and tip her over.
func _dash_anim_kind() -> String:
	if not strike_at_end.is_empty():
		return "lunge"
	if move_kind == "rinkrun":
		return "skate"
	if move_kind == "rush":
		return "rush"
	var own := ak.dodge_anim() if ak else ""      # the kit's own (Slipstep's slide)
	return own if own != "" else String(DODGE_ANIM.get(cls, "roll"))

func _anim_state(stretch: float) -> void:
	var s := anim_s
	s["vel"] = vel; s["face"] = face
	s["grounded"] = grounded and pad.is_empty()
	s["gliding"] = gliding and not plunging()
	s["diving"] = plunging()
	s["rolling"] = roll_t > 0.0
	s["dash_dir"] = roll_dir
	s["dash_kind"] = _dash_anim_kind()
	s["crouch"] = crouch_k
	s["downed"] = false      # downed shows as a Wisp (HunterWisp)
	s["dead"] = out
	s["dead_t"] = m.time - float(get_meta("died_at", m.time)) if out else 0.0
	s["ledge"] = grap.size() > 0
	var mk := -1.0
	if pad.has("face"):
		mk = clampf(float(pad["t"]) / maxf(0.01, float(pad["dur"])), 0.0, 1.0)
	s["mantle"] = mk
	s["stomp"] = (fmod(float(stomp["t"]), Life.R["stomp_cycle"]) / Life.R["stomp_cycle"]) if not stomp.is_empty() else -1.0
	s["reload"] = (1.0 - reload_t / maxf(0.1, float(wpn["reload"]))) if reload_t > 0.0 and not wpn.get("melee", false) else -1.0
	s["drink"] = (1.0 - drink_t / DRINK_TIME) if drink_t > 0.0 else -1.0
	s["recoil"] = recoil
	s["flash"] = clampf(flash_t / 0.12, 0.0, 1.0)
	s["fired"] = idle_fire
	s["wid"] = wid
	s["swing_n"] = swing_n
	var cd: Array = wpn.get("combo_dmg", [])
	var cn: int = maxi(1, cd.size() if cd.size() > 0 else (wpn.get("combo", [1.0]) as Array).size())
	s["combo"] = -1 if combo_i == 0 else (combo_i - 1) % cn
	s["charge"] = clampf((mel_hold - 0.15) / maxf(0.1, float(wpn.get("charge_time", 1.0))), 0.0, 1.0) if mel_hold > 0.15 else 0.0
	s["cast"] = m.time - cast_at
	s["cast_slot"] = cast_slot
	if ak and ak.anim_id != "":
		s["kmove"] = ak.anim_id                # the kit's own full-body move (HunterAnim.KMOVES)
		s["kmove_t"] = m.time - ak.anim_at
	if ak and ak.face_locked(): s["statue"] = true       # frozen: no idle sway, glance or fidget
	MergeKit.anim_state(self, s)
	KinDowned.anim_state(self, s)
	s["hit_t"] = m.time - hurt_at
	s["hit_k"] = hit_k
	if last_hit_by and is_instance_valid(last_hit_by):
		s["hit_dir"] = Vector2(pos.x - last_hit_by.pos.x, pos.z - last_hit_by.pos.z)
	s["stun"] = stun_t > 0.0
	s["base"] = (1.0 - base_t / BASE_TIME) if base_t > 0.0 else -1.0
	s["squash"] = squash
	s["stretch"] = stretch
	s["kin_on_shoulder"] = kin != null and (kin as Kin).state == "shoulder"
	# reviving a teammate: standing on their wisp
	var rv := false
	if grounded and not downed:
		for o in m.hunters:
			if o != self and o.downed and o.team == team and self in (o.get_meta("revivers", []) as Array):
				rv = true
				break
	s["reviving"] = rv or box_reviving()
	s["act"] = holding()
	# an emote bubble over us
	var em := ""
	var et := 99.0
	if m.truce:
		for e in m.truce.shown:
			if e["h"] == self:
				em = String(e["id"]); et = float(e["t"])
	s["dead"] = out
	s["dead_t"] = m.time - float(get_meta("died_at", m.time)) if out else 0.0
	s["emote"] = em
	s["emote_t"] = et
	if not grounded and not gliding and not downed:
		s["air_h"] = clampf(pos.y - m.world.ground_at(pos.x, pos.z), 0.0, 30.0)
	else:
		s.erase("air_h")

## (movefeel) Hunters are drawn a little larger in a match so they read on screen (owner: SUPERVIVE's
## heroes "feel more important"). Visual only: the hitbox (r), the TeamRing hit circle under your
## feet, shot heights and the balloon marker are unchanged.
const VIS_SCALE := 1.12
func set_model(n: Node3D) -> void:
	super.set_model(n)
	if n == null:
		return
	n.scale *= VIS_SCALE
	var ring := n.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.scale /= VIS_SCALE

## (movefeel) Where to draw this hunter between simulation steps. Everyone else is interpolated
## (drawn up to one step in the past, which is smooth); the local player is drawn at the present
## instead, extrapolated by the fraction of a step since the last one, so a key press shows on the
## very next frame and the camera never trails the sim. A teleport (a big jump between steps) snaps.
const LOCAL_RENDER_LEAD := true
func render_pos(alpha: float) -> Vector3:
	if not LOCAL_RENDER_LEAD or not is_local() or freeze_t > 0.0 or remote:
		return prev.lerp(pos, alpha)
	var stp := pos - prev
	if stp.length() > 1.5:
		return pos
	return pos + stp * alpha

func render(delta: float, alpha: float) -> void:
	super.render(delta, alpha)
	if LOCAL_RENDER_LEAD and is_local() and freeze_t <= 0.0 and not remote:
		position = render_pos(alpha)
	if absf(step_vis) > 0.001:
		position.y += step_vis
		step_vis = lerpf(step_vis, 0.0, 1.0 - exp(-16.0 * delta))
	visible = (not out or WardenClips.dying(self)) and not extracted and not riding and not unseen
	if not model:
		return
	HunterWisp.tick(self, delta)
	if m.cam: model.basis = m.cam.char_basis(face, model.scale)     # leaned toward the camera (CamRig.char_lean)
	else: model.rotation.y = face
	if out and has_meta("fling"):
		# hit by the sky train: the body is flung tumbling through the air for a moment, then gone
		var fl: Dictionary = get_meta("fling")
		var ft: float = m.time - float(fl["t"])
		if ft < 1.2:
			var v0: Vector3 = fl["v"]
			visible = true
			position = (fl["from"] as Vector3) + v0 * ft + Vector3(0, -0.5 * H_GRAV * 0.45 * ft * ft, 0)
			model.rotation = Vector3(ft * 9.0, face + ft * float(fl["spin"]) * 6.0, ft * 4.0 * float(fl["spin"]))
			return
		remove_meta("fling")
		model.rotation = Vector3(0, face, 0)
		if m.cam: model.basis = m.cam.char_basis(face, model.scale)
	# riding a mount: you sit up on its back
	var ride := (kin as Kin).ride_height() if mounted() and not downed else 0.0
	model.position.y = lerpf(model.position.y, ride, minf(1.0, delta * 12.0))
	if remote:
		update_lip()
	_render_weapon_fx(delta)
	DropReticle.tick(self, delta)
	var rig: Node3D = model.get_node("Rig")
	var torso: Node3D = rig.get_node("Torso")
	if anim == null or anim.model != model:
		anim = HunterAnim.new(model)
	var hv := Vector2(vel.x, vel.z)
	var spd := hv.length()
	crouch_k = move_toward(crouch_k, 1.0 if crouch else 0.0, delta * 8.0)
	var stretch := 0.0
	if roll_t > 0.0:
		stretch = 0.25 if anim.dash_kind != "roll" else 0.0
	elif not gliding and not grounded and pad.is_empty():
		stretch = clampf(vel.y / 30.0, -0.1, 0.18)
	# hunters you can't see right now (hidden by sight or off screen) pose less often; the animation
	# catches up in one bigger step (its springs sub-step) when they show again
	_anim_dt += delta
	_anim_n += 1
	var every := 1
	if not is_local() and m.cam:
		if unseen or not visible: every = 6
		elif not m.cam.on_screen(position): every = 3
	var posed := _anim_n % every == 0
	if posed:
		_anim_state(stretch)
		anim.update(_anim_dt, anim_s)
		_anim_dt = 0.0
	if posed and anim.stepped and not downed and not crouch:
		Sfx.step(pos, -14.0 if is_local() else -20.0)
	if posed and anim.slammed and not downed:
		# a heavy coming down hard: a ring of dust where they land
		m.fx.dust(pos, 12)
	var tc: Color = Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()]
	if roll_t > 0.0:
		ghost_t -= delta
		if ghost_t <= 0.0 and model.visible and not (ak and ak.own_dash_trail()):
			ghost_t = 0.028
			if ak == null or not ak.dash_afterimage():
				m.fx.ghost(position, face, tc, float(cdat["scale"]))
	elif gliding:
		wind_t -= delta
		# (movefeel) carrying a dash's momentum: a dense streak trail and afterimages until it bleeds off
		var boosted := boost_fx_t > 0.0 and spd > GLIDE_SPEED * 1.25 and not dropping
		boost_fx_t = maxf(0.0, boost_fx_t - delta) if boosted else 0.0
		if wind_t <= 0.0:
			wind_t = 0.035 if boosted else 0.09
			m.fx.burst(pos + Vector3(randf_range(-0.8, 0.8), 1.9, randf_range(-0.4, 0.4)), Color(1, 1, 1, 0.8 if boosted else 0.5), 4 if boosted else 2, 1.0, 0.45, -1.0, 0.9 if boosted else 0.7, Vector3(-vel.x, 0, -vel.z).normalized(), 20.0)
			if boosted:
				m.fx.ghost(position, face, Color(0.85, 0.95, 1.0), float(cdat["scale"]))
	# little puffs of dust while running, and a kick of dust when you turn hard
	if grounded and spd > 4.0 and not downed and KMovesStone.gait(arch) >= 0.5:      # (no feet, no steps: Motley)
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.32
			m.fx.dust(pos, 2)
			Juice.footstep(self)
	# (the rig's squash, the skydive and lying downed are posed by HunterAnim)
	glide_k = move_toward(glide_k, 1.0 if gliding and not plunging() else 0.0, delta * (7.0 if gliding else 9.0))
	var gl: Node3D = torso.get_node("Glider")
	gl.visible = glide_k > 0.02
	if gl.visible:
		var gk := glide_k - 1.0
		var ek := 1.0 + 2.7 * gk * gk * gk + 1.7 * gk * gk      # pops open with a little overshoot
		gl.scale = Vector3(ek * (1.0 + sin(m.time * 9.0) * 0.02), ek, ek)
		gl.rotation.x = 0.35 * ek - 0.1
	var halo := torso.get_node_or_null("Halo")
	if halo:
		halo.rotation.y += delta * 2.0
		halo.position.y = 1.26 + sin(m.time * 3.0) * 0.03
	# (the weapon's pose, recoil and melee swings are HunterAnim's too)
	# cloaked: allies see a shimmer, enemies see nothing unless very close
	var lp: Ent = m.local_player()
	var see := true
	if cloak_t > 0.0:
		if lp and lp.team != team:
			see = lp.flat_dist(self) < 2.2 and int(m.time * 10.0) % 3 == 0
		else:
			see = int(m.time * 14.0) % 3 != 0
	model.visible = see and not Hex.active(self) and not HunterWisp.hides(self)    # a critter or a Wisp stands in
	ShieldLook.tick(self)
	SideRings.tick(self)
	var ring := model.get_node("TeamRing") as MeshInstance3D
	ring.visible = not downed
	_render_balloon(delta)
	Oomph.render_hit(self, delta)
	Hex.tick(self, delta)
	if (drink_t > 0.0 or kit_t > 0.0 or box_reviving()) and visible and see:
		vuln_fx_t -= delta
		if vuln_fx_t <= 0.0:
			vuln_fx_t = 0.22
			m.fx.ring(pos + Vector3(0, 0.05, 0), 1.05, Color(1.0, 0.33, 0.22, 0.85), 0.24)
			m.fx.burst(pos + Vector3(0, 2.05, 0), Color("ff6a4a"), 3, 1.2, 0.3, -1.0, 0.8)
