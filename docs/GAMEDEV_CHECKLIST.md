# Game dev expert checklist (apply to every request)

Use this list whenever a request is planned or reviewed. For each feature, ask which items apply and how an experienced game developer would handle them. Then name the concept explicitly in the agent brief, because precise terms get better results. The list was compiled from gamedev-cheatsheet.com's concept list, written in our own words and mapped to Project Boki.

## Game feel
- [ ] **Delta time:** every movement, timer and lerp scales with dt. Smoothing uses `1 - exp(-k*dt)`, and long frames are clamped. The match steps on a fixed DT, so keep it that way.
- [ ] **Coyote time and input buffering:** a short grace window for jump, dash and glide after leaving a ledge, plus buffered presses of about 0.1 s that are consumed once. One press means one action.
- [ ] **Acceleration and friction:** ramp toward the input, brake faster on a reversal, and give less control in the air. Check against MOVEMENT_FEEL.md numbers.
- [ ] **Hit stop:** a 50-100 ms freeze on attacker and target, scaled by hit tier. Input and UI keep running.
- [ ] **Screen shake:** driven by one trauma value, squared, with smooth noise. Never random per-frame jitter. Recording mode tones it down.
- [ ] **Squash and stretch:** on jumps, landings and impacts, conserving volume and pivoting at the feet.
- [ ] **Easing:** UI moves, camera pans and pop-ins use curves (out-back, out-cubic), never linear.
- [ ] **Camera deadzone and lead:** the camera holds inside a small box and leads in the direction of travel. Changes are smooth, never snapped.
- [ ] **Invulnerability frames:** a short window after a hit or on a dash, with a visible blink or tint and knockback.
- [ ] **Readability:** every attack has a wind-up tell, an active window and recovery. Every hold has a rising sound, a fill and a "full" tick.

## Systems
- [ ] **Finite state machines:** for hunters, Boki, bots and abilities. One active state, explicit transitions, and unlisted events ignored. No piles of booleans.
- [ ] **Hitbox and hurtbox:** hitboxes are live only during active frames, with one hit per target per swing (a hit-set per attack).
- [ ] **Tunnelling:** fast projectiles, dashes and launches use swept tests or sub-steps so they can't pass through walls.
- [ ] **Pathfinding and steering:** A* (or flow fields) on the tile grid for bots and Boki, steering with capped force, arrive slowing and separation.
- [ ] **Seeded randomness:** everything rolled per match (spawns, loot, live lairs, weather) uses a seeded RNG, with a separate RNG stream per system so adding a roll doesn't shift the others. Saves store seeds, not results.
- [ ] **Object pooling:** projectiles, particles, damage numbers and FX nodes are reused, not created and freed every shot.
- [ ] **Particle systems:** one emitter per effect with tunable rate, lifetime and curves. No hand-spawned node per particle.
- [ ] **Fixed timestep:** simulation runs at a fixed step, and rendering interpolates between states. Never put gameplay in `_process` with a variable dt.

## Performance (16.7 ms per frame at 60 fps)
- [ ] **Frame budget:** measure before optimising (`--hitch-check`, `--load-check`, profiler sections) and fix the biggest cost first.
- [ ] **Draw calls:** MultiMesh or instancing for flora, rocks and props. Merge static meshes that share a material.
- [ ] **Spatial partitioning:** a uniform grid or buckets for broad-phase queries (targets, pickups, separation). Never all-pairs loops over hunters, mobs and Boki.
- [ ] **Time slicing:** spread expensive AI thinking (bot decisions, target picks) across frames in buckets, while movement still runs every step.
- [ ] **Overdraw:** limit stacked transparent layers (fog, tints, glows) and render heavy effects at lower resolution.
- [ ] **Frustum and distance culling:** skip animation and FX updates for things off screen or far away. Use LOD with hysteresis for far models.
- [ ] **Atlases and shared materials** for UI icons and sprites.
- [ ] **Streaming:** when the map grows (rolling sessions), keep only nearby chunks active, with separate load and unload radii.

## 3D and rendering
- [ ] **Raycasts** for line of sight, gunfire and ground checks, using the real shot line (eye to chest), not a flat test.
- [ ] **Surface normals** to tell floors from steep slopes and walls (ledge rise, wall hug, bounces).
- [ ] **Billboards:** nameplates and bars face the camera, and upright sprites rotate only on Y.
- [ ] **Shaders** expose their values as uniforms for tuning, and are driven by gameplay values (for example abyss depth to tint).
- [ ] **No z-fighting:** no coplanar decals. Lift them slightly or use polygon offset, and keep a sane near plane.
- [ ] **Quaternions** for rotation blending (slerp, short arc); Euler angles only for display.

## Process
- [ ] **Data over code:** tuning lives in `content/` or named constants with units.
- [ ] **Every feature ships with a check** asserting its behaviour, and the check is cheap to run.
- [ ] **Follow AGENTS.md:** no growth in the god files, delete what you replace, a design note for core systems, review before merge.
