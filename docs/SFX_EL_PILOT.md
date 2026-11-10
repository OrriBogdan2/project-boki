# ElevenLabs SFX pilot (11-10)

Status: **tool ready, no sounds generated yet.** The worker that built it (rpc1) has no `ELEVENLABS_API_KEY`,
and the key is never copied around. To generate, on hetzner run:
`set -a; . ~/.config/boki/secrets.env; set +a; python3 tools/el_sfx_pilot.py` (reads credits, spends at most 15%,
writes `audio/el_<event>.wav` + `audio/el_<event>_1.wav` and the A/B page `/home/boki/art-review/sfx-1110/`).
Run `godot --headless --import` after that.

## Gap audit (origin/main d255acbee)
All ~470 sound names (939 wav files incl. takes) in `audio/` are synthesised in code (`tools/gen_sfx_*.py`); none are missing. Every Hunter set
in `content/sfx/` already has its own dash, hurt, down, death, steps and its ability sounds (`--sfx-set-check`).
So the "gaps" this pilot tries out are: (a) the shared combat events, which are one generic synth sound for every
fight, several with no takes; (b) shared generic sounds that a Hunter kit still plays for its own ability.

## Mapping: event -> call sites -> how to adopt a take
Adopting = point the call site at `el_<event>` (both variants rotate as takes), or move the el files over the old
name and drop that name from its gen script. The el files are not set-listed yet, so they would need an entry in
the group's `content/sfx/*.json` before shipping.

| event (cat) | played from | calls | adopt |
|---|---|---|---|
| hit (impact) | match.gd | 1 | one-liner |
| hit_heavy (heavy_impact) | juice.gd | 1 | one-liner |
| crit (impact) | arch_kit, ashwick_kit, match, biome_run | 8 | rename files |
| kill (impact) | juice, match | 5 | rename files |
| die_small / die_big | boss.gd / match.gd | 1 / 1 | one-liner |
| dash (dash; the dodge) | hunter, match | 2 | fallback only: Hunters with own `<arch>_dash` skip it |
| whoosh (fire) | 38 calls, home + combat | 38 | rename files (also used in menus/home) |
| pickup (ui) | pack, home trade/market, decorate | 37 | rename files; `<arch>_pickup` overrides it |
| level_up (ui) | hunter.gd | 1 | one-liner |
| ab_ready (ui) | arch_kit, thief/ashwick/juggernaut kits | 6 | rename files |
| skill / ult (cast) | arch_kit, match, utility_use / lairs, merge_xform, prologue | 6 / 3 | rename files |
| heal / shield (cast) | effects, match, utility_use, verbs | 6 / 14 | rename files |
| revive_done (cast), extract_ok (ui) | box_revive, kin_downed / juice | 2 / 1 | one-liner |
| ui_confirm / ui_back (ui) | ui.gd button meta `snd` (every button) | - | rename files |
| ui_deny (ui) | decorate, kinbox_view | 2 | one-liner |
| thief_swipe (fire) | thief_kit.gd:885 plays shared `swipe` | 1 | one-liner + thief.json entry |
| mage_wall (cast) | mage_kit.gd:671 plays shared `ab_wall` | 1 | one-liner + mage.json entry |
| tender_knock (impact) | tender_kit.gd:268/607/787 play shared `knock` | 3 | one-liner each + tender.json |
| ashwick_shield (cast) | ashwick_kit.gd:683 plays shared `shield` | 1 | one-liner + ashwick.json |
| bulwark_click (ui) | bulwark_kit.gd:444 plays shared `click` | 1 | one-liner + bulwark.json |

## Notes
- WAV, not OGG: one-shots load only `res://audio/<name>.wav` (`Sfx._lazy`), so takes are written as WAV, levelled
  by `sfx_lib.save_cat` to the category RMS (-14.5..-22 dBFS) with a -1 dBFS ceiling. The raw mp3 is kept on the page.
- Licence: docs/AUDIO.md allows outside sounds only if CC0. ElevenLabs output is the account holder's under its
  terms, not CC0. Adopting any take needs the owner to OK that and a `docs/CREDITS.md` entry.
