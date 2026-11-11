# 0.24.6 stranded parity branches: merge notes

Branch ext/parity-stranded-0246 from origin/main 88b06b9e7, then ext/w0246-combat-b-wip 29b85a325 (the newest
0.24.6 combat train; it holds the 0.24.5 kit data these branches touch). Four READY parity branches were on no
train. Every changed value was re-checked against briefs/supervive-data/supervive_kits.md. Net.VERSION and the
save format are untouched (data, text and checks only).

## Merged
- `ext/parity-kael-cc-riders` 75e706c4a: no fireblast slow, no Chain Lunge or Haul Slam stun (Brall lists none;
  Obsidian Slam's slow and centre stun stay). Conflicts in juggernaut.json and the wiki only.
- `ext/parity-tenzo-rock-slows` 44040c047: rocks and the Rock Hop crash rock shred, no slow (Tetra: only
  Tetraform slows). **Owner:** docs/heroes/dolm.md cites the patch 2.00 notes saying punched rocks slow 0.8 s.
- `ext/cooldown-parity-verify` 2be9877c2: every kit at the source's level-1 cooldown (1.0x), with the rank
  cuts and rank texts set to match. **Owner:** ext/w0246-combat-a held this branch over the line's 0.8x pace.
  This branch takes 1.0x (the parity rule). To keep 0.8x instead, revert that merge commit.

## Held: `ext/hitstop-parity` c9315676d
Built on ext/supervive-impact (8 commits, 23 files). Its tier table (content/rules/hitstop.json, T1 light
hits hold 0 s) is superseded by ext/feel-impact-tiers on ext/w0246-feel: ImpactWeight, impact_weight.json,
light 25 ms. Merging it here would add a second hit-stop table that conflicts with that train. It also
conflicts with combat-b itself in arch_kit, dash_flow, warden_clips, ent.gd, check_registry and wiki/Rules.
**Owner:** should light hits hold 0 s (the footage, hitstop-parity) or 25 ms (feel-impact-tiers)? The feel
lane should port the rest of supervive-impact (strike-frame poses, stun clip, cast-lock buffer, Fuse shake)
onto ImpactWeight.

## Checks (rpc4, temp XDG, against the same run on combat-b-wip 29b85a325)
Same failures as the train, row for row: juggernaut-combo 214/1 (113.8 Rampage), dancer-combo 150/0,
ashwick-combo 133/0, dredge-combo 118/4, rimewright-combo 128/1, tender-combo 116/1, bulwark-combo 173/3,
mage-combo 146/4, gunslinger-combo 134/0, dolm-combo 174/0. kit-parity 0 fails, cooldown-parity 0 fails.
ttk 38 rows/21 fails, the same rows (Kael combo at rank 0 goes from 0.65 to 0.77 of the source).
