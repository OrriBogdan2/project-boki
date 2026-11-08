# Settings audit (November 2026)

Every key in `Settings.DEFAULTS` (`scripts/core/settings.gd`), what still reads it, and what we did
with it. Removed keys are listed in `Settings.REMOVED`: they are dropped from `user://settings.cfg`
the next time the game starts, and `--uipolish-check` asserts that.

## Removed

| Key | Was | Why |
|---|---|---|
| `dash_hold` | Gameplay: "Hold Shift for the long dash" | Hold-dashes are per hunter now (`inp["dash_down"]`, Slide, Rampage). The option only stretched the old non-hero dash into an "ex" dash. Its read in `match.gd` and the stretch in `hunter.gd` are gone. |
| `kin_auto` | Gameplay: "Boki also use your E ability on their own" | E is the hunter's utility now. The Boki's own ability is ordered by you (G), and the Merge is on T. A switch that lets the Boki spend that cooldown on its own fights all of that, so it is off for everyone. |
| `hud_opacity` | (no row in the menu) | Nothing has read it since the HUD rework. |

## Kept, with where they now live

| Key | Section | Read by | Note |
|---|---|---|---|
| `name` (save, not settings) | Gameplay > You | `Save.d["name"]` | |
| `damage_numbers` | Gameplay > Combat | `fx.gd` | |
| `tips` | Gameplay > Combat | `hud.gd` | renamed "Tips during expeditions" |
| `kin_chatter` | Gameplay > Boki | `kin_companion.gd` | renamed "How much your Boki talks" |
| `mod_mode` | Gameplay > Admin (admin only) | `game.gd` | |
| `lobby_enabled` | Gameplay > Admin (admin only) | `prematch.gd`, `game.gd` | on by default: the 90 s pre-match lobby before each expedition; off shows the plain loading screen (docs/decisions/0019-prematch-lobby.md) |
| `bot_diff` | Admin tools page | `match.gd`, `duel.gd` | the duplicate row in Gameplay is gone: the Admin tools page already sets it |
| `cast_on_press` | Controls > How keys behave | `match.gd` | moved from Gameplay: it's about how a key press acts |
| `dash_to_cursor` | Controls > How keys behave | `hunter.gd` | moved from Gameplay |
| `crouch_toggle` | Controls > How keys behave | `match.gd`, `home.gd` | moved from Gameplay, renamed "Tap to sneak" (the action is Sneak) |
| `keys`, `keys_v`, `keys2_v` ... `keys5_v` | Controls (bindings) | `settings.gd`, `key_migrate.gd` | internal version markers stay; step 5 moved middle mouse from the Boki key to Ping |
| `reticle_shape`, `reticle_size`, `reticle_col`, `reticle_alpha`, `reticle_outline` | Gameplay > Reticle | `reticle.gd` | the aiming reticle's style (`--reticle-check`) |
| `cam_style` | Camera | `cam.gd`, `match.gd` | new Camera tab (was a Gameplay group) |
| `cam_follow` | Camera | `cam.gd`, `match.gd` | |
| `cam_lead` | Camera | `match.gd` -> `cam.gd` | |
| `master`, `music`, `sfx`, `ambience` | Audio > Volume | `settings.gd` (buses) | |
| `reset_cue` | Audio > Sounds | `sfx.gd` | moved from Gameplay, renamed "Ability ready again" |
| `mute_unfocused` | Audio > Window | `settings.gd` | |
| `fullscreen`, `vsync`, `max_fps` | Video > Display | `settings.gd` | |
| `quality`, `msaa`, `shadows` | Video > Quality | `settings.gd` | `quality_found`, `video_v` stay internal |
| `show_fps` | Video > Quality | `overlay.gd` | |
| `ui_scale` | Accessibility > Readability | `settings.gd` | |
| `shake`, `reduce_flashes` | Accessibility > Comfort | `cam.gd`; `hud.gd`, `reset_pop.gd` | |
| `rec_level`, `demo_weather`, `demo_blight`, `demo_fresh` | Demo | `settings.gd` (`demo_opts`, `Record`) | Recording mode also forces v-sync and a 60 fps cap (`Record.frame_cap`). The Demo tab's Quick start buttons (`DemoQuick`, also `--demo=expedition\|farm\|hatch`) are not settings: they play on a made-up save that is never written. |

## Looked for and not found

No settings remain for taming, the shoulder-start Boki, the old kit or loaner, the 1/2/3 perk prompt
or class ultimates. The key bindings for the Boki (C ability, G orders, T Merge) were already current;
the X ultimate is the main session's (ultbond).

## Tab order

Gameplay, Controls, Camera, Audio, Video, Accessibility, Demo. The Esc menu's Settings entry opens
Gameplay (or the last tab you used); its Controls entry opens Controls.
