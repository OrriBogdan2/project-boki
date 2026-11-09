class_name BaseDemo
extends RefCounted
## --base-demo (GARDEN.md section 9.8): a base with four Boki, two friends and two rivals, the three toys, a few
## element snacks and an egg ready to hatch, so the garden can be shown without playing hours. Needs no real save:
## main.gd turns Save.no_write on and swaps Save.d for save(), so the player's own file is never read back or
## written. stage() runs on the built farm and puts it all near the landing; something happens within seconds.

const SEED := 7                  # the island (farm-start layout seed)
const FRIENDS := 0.8             # bond: friends (BaseLife friend_at is lower)
const RIVALS := -0.8             # bond: rivals
const THINK_SECS := 0.4          # s until each Boki's first choice, so a greeting or a toy shows at once
const JOY := 60.0                # joy need: under toys.json joy_below, so a Boki goes to play on its own
const SNACKS := {"emberberry": 3, "tidebloom": 3, "sunroot": 2, "puffcorn": 2}
const TOYS := {"toy_ball": Vector3(-3.5, 0, -3.0), "toy_post": Vector3(4.0, 0, -4.0), "toy_tub": Vector3(-6.0, 0, 2.0)}
const NOOK_AT := Vector3(8.0, 0, -8.0)
const EGG_SPECIES := "burrlet"
## name -> [species, offset from the landing, temper]. Moss and Pip are friends, Ash and Rocky rivals.
const CAST := {"Pip": ["zapple", Vector3(2.0, 0, 2.0), 0.1], "Moss": ["burrlet", Vector3(3.2, 0, 2.0), 0.1],
	"Ash": ["cindle", Vector3(-3.0, 0, 4.0), 0.95], "Rocky": ["pebbit", Vector3(-0.8, 0, 4.0), 0.95]}

## The demo's save: base_mode on, a farm-start island, the four Boki, their bonds, the snacks and the ready egg.
static func save() -> Dictionary:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	var recs := {}
	for nm in CAST:
		var rec := Save.new_kin(CAST[nm][0], nm)
		rec["traits"]["temper"] = CAST[nm][2]
		Care.ensure(rec)
		for n in Care.NEEDS:
			rec["needs"][n] = JOY if n == "joy" else 95.0
		recs[nm] = rec
		d["roster"].append(rec)
	recs["Pip"]["starter"] = true
	d["active"] = recs["Pip"]["uid"]
	BaseLife.add_bond(recs["Pip"], recs["Moss"], FRIENDS)
	BaseLife.add_bond(recs["Ash"], recs["Rocky"], RIVALS)
	d["crops"] = SNACKS.duplicate()
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, SEED)
	Save.d = d
	Incubator.ensure()
	var egg := Incubator.add(EGG_SPECIES)
	Incubator.find(String(egg["id"]))["heat"] = Incubator.HEAT_NEED
	return d

## Puts the toys and the Nook on the built farm, the Boki beside them, and sets the scene for the camera.
func stage(h) -> void:
	var land := HomeLayout.LANDING
	h.day_t = 0.42
	for id in TOYS:
		h.hg.demo_place(id, land + TOYS[id])
	h.hg.demo_place("nesting_nook", land + NOOK_AT)
	h._sync_fixtures()
	h.hinc.refresh()
	h.ppos = land + Vector3(0, 0, 1.0)
	h.player.position = h.ppos
	for k in h.kins:
		k["pos"] = h.world.free_spot_near(land + CAST[String(k["rec"]["name"])][1], [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]
		k["t"] = THINK_SECS
	h.cam.zoom_to = 1.2
	h.cam.zoom = 1.2
	h.cam.snap(land + Vector3(0, 0, 1.0))
