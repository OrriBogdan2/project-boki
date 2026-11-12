# Downed Hunters (Wisps) and abilities: source rules vs ours

Parity first (briefs/DECISIONS.md 2026-11-07). A downed Hunter is a Wisp (docs/decisions/0019, presentation only). Our
`Match.foes_of` skips downed Hunters and `Hunter.hurt` returns 0 for them, so every ability that finds targets through
those two ignores Wisps. Evidence tags: [D] hero card / `briefs/supervive-data/supervive_kits.md`, [W] wiki row quoted in
docs/heroes, [F] footage frames in `briefs/hero-ref/*.md` (5 fps, 0.2 s a frame). Magnitudes marked "unknown" are not
in the refs: nobody has measured them.

## Rules

| # | Rule (source) | Evidence | Ours now | Proposed | Net impact |
|---|---|---|---|---|---|
| 1 | Sparkle's Lightning Strike launches Wisps like any body in its circle | [W] Joule; mage.md row 114 | **Built here**: rival Wisps in the circle get the same slide tow (no Static, no Grounded: a Wisp can't be shot or grounded) | done | none: `Displace.tow` already mirrors to the owner's game |
| 2 | Lace's Hail Wall affects Wisps | [W] Myth; archer.md row 112 | **Built here**: rival Wisps inside the wall lose `down_hp` each wall tick: tick damage (5) x `ArcherKit.WISP_DRAIN_K` 2.5 (the stomp multiplier) = 12.5 of the 100 pool, [est]. No slow, no burn. Allies' Wisps untouched | done; owner to confirm the magnitude and whether the source slows Wisps | none: the hit rides the existing `"hit"` topic (`src` `wisp`) and `Life.wisp_hit` drains `down_hp` in the Wisp's own game; `down_hp` already replicates in the `"st"` hunter row (`match.gd` index 12), so every game sees the bar fall |
| 3 | Grimble's Abyssal Grasp scoops Wisps on its path and reels them in | [D] kits:57, [F] dredge.md f-9 | **Built** (dredge_kit `scoop`, dredge.md rows 101/162) | none | tow `haul`, already Net-safe |
| 4 | Elluna's Soulpack: walk over an ally Wisp to carry (2), carried Wisps don't bleed, can't be stomped; damage or stun drops them, 4 s lockout | [D] kits:7, [F] mooshmoosh.md | **Built** (tender_kit, `CareUtil`); "which hits drop" not traced | trace the drop list against footage | none |
| 5 | Elluna's Divine Intervention heals an ally Wisp, resurrects it and teleports it to her at the end; continues if the ally is knocked | [D] kits:13, [F] mooshmoosh.md 244-257 | **Built** (tender.md rows 48/75, `_call_home`) | none | `Displace.teleport` plus the `"rev"` event, already used |
| 6 | Bjorn's Regen Field burst: allied Wisps hit begin to resurrect | [D] kits:92 | **Built** (+0.35 of the revive bar; bulwark.md 87/118) | none | none |
| 7 | Ostra Level 4: allies and Wisps entering the outgoing zone get a shield | [W] ostra.md 145 | allies only | a shield on a Wisp has no meaning while Wisps take no damage: still skipped: rule 2 drains the Wisp, it does not damage a body a shield could soak | none |
| 8 | Juggernaut: R no longer resets on Wisp execution (patch 22.01.25) | [W] | n/a, hunters only | none | none |
| 9 | Stomp: standing on an enemy Wisp drains it, blocks revive; stun or knockback breaks the stomp | [W] SUPERVIVE_DATA.md 56 | **Built** (life.gd, `stomp_mult`, `stomp_slow`) | none | none |
| 10 | Knocked-down mate pulled by a knock/launch while an enemy stomps: unknown | none in refs | Rule 1 can launch a stomped Wisp off the stomper; the stomper's channel "misses" as for a drifting Wisp | keep; check footage if a clip appears | none |

## Open questions (owner, not built)
- Does Lightning Strike launch **allied** Wisps too? The wiki row says "Wisps" without a team. We launch rivals only, like the rest of the strike (alternative: both teams, one condition).
- Rule 2 magnitude (built as [est], `WISP_DRAIN_K`), and whether it slows the Wisp as well as draining it.
- Whether other displacement (Dolm chain, knockback arrows, Pin pushes) moves Wisps: no source row found, so nothing proposed.
