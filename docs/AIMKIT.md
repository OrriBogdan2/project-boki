# AimKit: shared aiming and telegraphs for the hero kits

Code: `scripts/match/aim/`. Check: `--aimkit-check` (tools/aimkit_check.gd). Screenshots:
`--aimkit-check --shots-dir=<dir>` under xvfb (tools/aimkit_shots.gd writes one PNG per shape and
cursor state plus `MANIFEST.txt`).

| File | What it is |
|---|---|
| `aim_mode.gd` (`AimMode`) | Where a shot or placement goes (cursor-clamped vs max range), plus membership tests that match the shapes |
| `aim_kit.gd` (`AimKit`) | The API kit code calls: the shapes, hide/clear, the cursor states |
| `aim_draw.gd` (`AimDraw`) | One node per match. Rebuilds every telegraph into one ImmediateMesh surface each frame |
| `aim_shapes.gd` (`AimShapes`) | The shape builders and the quiet default look |
| `aim_geo.gd` (`AimGeo`) | Triangle helpers (ribbons, rings, sectors, chevrons, stars) that sit each vertex on the ground |
| `aim_reticle.gd` (`AimReticle`) | The cursor states: charge ring, full flare, perfect star |

Scale: 1 body height (bh) = 1.8 m (`AimKit.BH`). The hero sheets measure in bh.

## 1. Aim modes

Two modes:
- `AimMode.CURSOR`: lands at the cursor point, clamped to `[1.5 m, max range]`.
- `AimMode.MAX`: always flies the full range in the aim direction.

Which mode a weapon shot uses (`Hunter._emit_shot`):
1. **Per shot.** Set `h.shot_aim = AimMode.CURSOR` (or `MAX`) just before the shot leaves. The next
   `_emit_shot` takes it once, like `shot_range_k`. A burst's later rounds go back to the weapon's own mode.
2. **Per weapon.** `"aim": "cursor"` or `"aim": "max"` in `content/weapons/<id>.json` `primary`.
3. **Default (unchanged).** A weapon with `"boom"` is cursor-placed. Everything else flies its full range.

In cursor mode the round's life is cut so it stops at the cursor. On a weapon with `"decel"` (slugs),
cursor mode cuts the flight short rather than re-solving the slow-down.

Helpers for kit-driven shots and placements:
```gdscript
var d := AimMode.dist(h, 12.0)                  # cursor distance clamped to [1.5, 12]
var d2 := AimMode.dist(h, 12.0, AimMode.MAX)    # 12
var at := AimMode.point(h, 9.0)                 # the ground point at the cursor, clamped to 9 m
var md := AimMode.mode_of(h)                    # what the next shot will do (does not consume)
m.spawn_shot(h, start, dir * spd, dmg, AimMode.dist(h, rng) / spd, size, col, extra)
```
Membership tests (flat XZ), so a kit's hit test matches what it draws:
`AimMode.in_lane(from, dir, len, width, p)`, `in_cone(from, dir, len, deg, p, inner)`,
`in_arc(center, dir, radius, deg, thick, p)` and `in_circle(at, r, p)`. Each takes an optional `pad`
(for example a target's radius).

## 2. Telegraphs

**Immediate style.** Call the shape every step while it should show, under an id of your own. The same
id replaces the previous one. Stop calling and it disappears after 0.1 s of match time.
- `AimKit.hide(h, id)` drops it at once.
- A `"dur": secs` param keeps a one-off up that long with no further calls (a 0.2 s edge ring, a stuck
  grenade's cone for its fuse).
- Nothing makes a node: every entry is drawn into one ImmediateMesh owned by the match's `AimDraw`.

Common params (every shape):

| Param | Default | Meaning |
|---|---|---|
| `col` | the archetype's `"color"` | the hero colour |
| `col2` | the archetype's resource colour | the accent: sweet spot, merged V, glints, fill front |
| `alpha` | 1.0 | overall strength. 1 is the quiet default; don't go above about 1.4 |
| `hot` | 0 | 0..1, brightens toward white. Lanes, Vs and sweet circles go hot by themselves at `k >= 1` |
| `lw` | 0.06 | rim width in m |
| `all` | false | foes and allies see it too. A foe's is tinted toward the hostile rim colour. Default: only your own player sees it (aim reticles) |
| `dur` | 0.1 | seconds it stays without a refresh |

Directions are flat `Vector2(x, z)`, the same as `h.aim_dir()`. Points are `Vector3`. Every shape sits
on the ground under its anchor and follows terraces and stairs, but never climbs a wall or drops into a pit.

### Lane: fixed, growing, narrowing
```gdscript
# Vex RMB: a fixed lane with an arrow tip, out past the cursor
AimKit.lane(h, "rmb", {"len": 10.0, "width": 0.72, "tip": true})
# Juggernaut RMB charge: grows 1.2 -> 5.4 m with the charge, filling, magenta at full
AimKit.lane(h, "rmb", {"len": 5.4, "len0": 1.2, "k": k, "fill": k, "width": 1.3, "col_full": Color("ff3df0")})
# Vex E: a long lane that narrows over the cast
AimKit.lane(h, "e", {"len": 16.0, "width": 1.0, "width_to": 0.12, "k": cast_k})
# Sparkle Surge: rails with chevrons (pair it with a circle for the end marker)
AimKit.lane(h, "dash", {"len": 13.0, "width": 0.35, "rails": true, "chevrons": 5})
```
Params: `from` (the hunter), `dir` (the aim), `len` (6), `width` (0.9), `k`, `len0`, `width_to`,
`taper` (the end width as a fraction of the start width, 1), `fill` (0..1 front), `rails`, `chevrons`
(count), `tip`, `col_full`.

### Dotted lane
```gdscript
AimKit.dotted(h, "rmb", {"len": 15.0})     # Meeko seed: a faint 0.4 bh strip with dots, to max range
```
Params: `from`, `dir`, `len` (8), `width` (0.72), `gap` (0.6 m between dots), `dot` (0.06 m radius).

### Filling line
No shape of its own: two lines and a circle.
```gdscript
# Lace's draw: a faint line to the cursor, a bright fill growing out along it, a circle at the perfect point
AimKit.line(h, "draw", {"len": L, "arrow": false})
AimKit.line(h, "draw_fill", {"len": L * fill, "arrow": false})
AimKit.circle(h, "draw_mark", {"at": point, "r": 0.22})
```

### V that closes into one line
Nothing in the game uses it now (Lace's draw was the V until owner item 55b).
```gdscript
AimKit.vee(h, "draw", {"k": stage_k, "glint": stage_k * 0.4, "col2": Color("b6ff8a")})
```
Params: `from`, `dir`, `len` (to the cursor, clamped 1.5-20), `k`, `open` (degrees, 25), `glint`
(0..1 along the line, -1 for none).

### Cone
```gdscript
# Vex wall cone: from the stuck point back out, everyone sees it for the fuse
AimKit.cone(h, "wallcone", {"from": stick, "dir": back, "len": 6.0, "deg": 100.0, "fill": fuse_k, "all": true, "dur": 0.8})
# Grimble Buckshot: just the two edge lines
AimKit.cone(h, "spread", {"len": 6.3, "deg": 30.0 + h.wbloom, "edges": true})
```
Params: `from`, `dir`, `len` (4), `deg` (60), `inner` (0.3 m), `edges`, `fill`.

### Landing circle
```gdscript
AimKit.circle(h, "r", {"r": 2.9, "ticks": true})                     # Vex Mini Nuke at the cursor
AimKit.circle(h, "e", {"self": true, "r": 4.5, "all": true, "dur": 0.2})   # Cinder's 0.2 s edge ring
AimKit.circle(h, "end", {"at": end_p, "r": 2.25, "ticks": true, "star": true})   # Sparkle Surge end marker
```
Params: `at` (the cursor point, clamped to `range`), `range`, `self` (centred on the hunter), `r`
(1.35), `fill` (0..1 radial), `ticks`, `star`, `dashed`, `core`, `pointer` (a `Vector2`: a chevron on
the rim pointing that way, as on Sparkle's E drag disc).

### Circle with a growing sweet spot
```gdscript
# Tenzo RMB: a 2.5 bh circle a hop ahead; the inner ring grows 0.5 -> 1 bh with the charge
AimKit.sweet(h, "rmb", {"at": h.pos + Vector3(d.x, 0, d.y) * 2.6, "k": k, "fill": k, "all": true})
```
Params: as for the circle (`r` defaults to 4.5 m), plus `k`, `core0` (0.9) and `core1` (1.8).

### Curved arc wall
```gdscript
AimKit.arc_wall(h, "e", {"rmax": reach})       # Lace's Rain of Arrows: at the cursor distance, 120 deg
var w := AimKit.entry(h, "e")                  # read the radius back for the cast
```
Params: `center` (the hunter), `dir`, `radius` (the cursor distance clamped to `rmin`..`rmax`, 2..9),
`deg` (120), `thick` (0.9), `panels` (7).

### Two-end swap marker
```gdscript
AimKit.swap(h, "dash", {"range": 9.0, "fill": t / swap_t})   # Motley: origin ring, destination sigil filling
```
Params: `a` (the hunter), `b` (the cursor point, clamped to `range`), `r` (1.35), `fill`.

### Extras the sheets need
```gdscript
AimKit.line(h, "aim")                                        # the thin aim line to the cursor (Motley, Neve)
AimKit.line(h, "aim", {"col": Color("ffd25a"), "hot": 0.6})   # Sable's gold empowered line
AimKit.line(h, "aim", {"len": 20.0})                          # past the cursor to max range (Lace stage 2)
AimKit.span(h, "r", {"len": 21.6, "chevrons": 4})             # Tenzo Tetraform: a long line, inward chevrons, centre ring
AimKit.star(h, "lock", {"at": foe.pos, "size": 0.5})          # a glint on the ground
```
The two parallel lines (Motley RMB) are `lane` with `"rails": true` and no chevrons. The Mossy R
rectangle is a plain `lane`. The Juggernaut hold-blast arc round the body is `circle` with
`"self": true`. A target highlight ring at someone's feet is a small `circle` at their position. Sparkle's E is a
`circle` with `ticks` and `"pointer": drag_dir`, plus a `lane` with `"from": disc, "tip": true` for the
drag arrow.

### Reading back, hiding, clearing
- `AimKit.shown(h, id)`: is it up?
- `AimKit.entry(h, id)`: the resolved params, for example the arc radius the kit should cast at.
- `AimKit.hide(h, id)`: drop one now.
- `AimKit.clear(h)`: everything this hunter shows, cursor states included.

## 3. Cursor states (local player only)
```gdscript
AimKit.charge(h, k)                  # every step while charging: a thin ring fills round the cursor
                                     # crossing k = 1 fires the flare once (pass "flare": false to skip)
AimKit.flare(h)                      # the full-charge flare now: a ring snaps out, a glint (0.28 s)
AimKit.perfect(h)                    # the perfect-window star: gold 4-point star and ring, 0.12 s
AimKit.reticle(h)                    # {charge, flare, perfect}, for checks
```
Params: `col` (charge ring colour, default the hero colour), `col2` (flare colour), and `col` on
`perfect` (gold by default). The states run on real time, so they show through hit stop. The ring sits
at 26 px, outside the HUD's 22 px ammo ring and inside its 30 px resource arc.

## 4. Guide for kit agents
- **Call per step from your kit's tick or hold callbacks** (`rmb_hold_tick`, `lmb_override`, `_tick`).
  Use a stable id per ability (`"rmb"`, `"e_drag"`). Don't call from `_process`.
- **Hold telegraphs need no cleanup code.** When the hold ends, stop calling and it goes within 0.1 s.
  Call `AimKit.hide` if it must vanish on the release frame.
- **Merge start is handled.** Whatever starts a merge, a merged or transforming hunter
  (`KinMerge.active` / `KinMerge.transforming`) shows nothing: AimDraw drops its entries and cursor
  states, and new calls are ignored until the merge ends. `ArchKit.drop_holds()` (your `_drop_holds()`
  then `AimKit.clear(h)`) also clears it on the spot. Inside ArchKit code call `drop_holds()`, not
  `_drop_holds()`. (KinMerge, which is reserved, calls `_drop_holds()` directly; the gate covers it.)
- **Who sees it.**
  - Aim reticles (lanes, Vs, lines) stay at the default `all: false`.
  - A kit that draws its own aim line returns true from `own_aim_line()`, so the shared weapon line hides
    (two lines read as two aims). The per-hero audit is docs/AIM_PREVIEWS.md.
  - Areas a foe must read or dodge (slam circles, a stuck grenade's cone, a placed nuke) use `all: true`.
  - None of this is synced over Net. A remote player sees your `all` telegraphs only if their machine
    runs your kit. Today remote hunters are puppets, so add a Net event if a sheet needs foes online
    to see one (see Open questions in the branch report).
- **Colour.**
  - Pass `col` for the hero's own look. The default is the archetype colour.
  - Use `col2` for the accent, and `col_full` for a lane that changes colour at full charge.
  - Keep `alpha` near 1. These are meant to be readable, not loud.
- **Aim mode.**
  - For the signature weapon, set `"aim"` in the weapon JSON, or `h.shot_aim` per shot (Lace: stage 1
    cursor, stage 2 `MAX`).
  - For kit-spawned shots, use `AimMode.dist` and `AimMode.point` so the telegraph and the shot agree.
- **Checks.** In combo checks, assert `AimKit.shown(h, id)` while aiming or holding, and read
  `AimKit.entry(h, id)` for the length, width, k or radius you expect.
- **The old helpers.** `ArchKit.tele_circle` and `tele_lane` (one tweened node per telegraph) still work.
  Move your kit's calls to AimKit as you touch them (docs/DEBT.md).
