# Consumables against the source

PARITY FIRST (briefs/DECISIONS.md, 2026-11-07). Every belt item (keys 1-4), what we do, what the source does, and the verdict. Numbers live in `content/utility/*.json` (the `channel` block of the tonic and armor kit, with its citation); the check is `--airheal-check`.

Evidence: **[W]** the item's wiki page (supervive.wiki.gg, raw wikitext read Nov 9 2026), **[D]** docs/SUPERVIVE_DATA.md, **[S]** docs/SOURCE_UTILITIES.md. The briefs on ext/agent-briefs (supervive-data, hero-ref 5 fps sheets) hold no consumable footage or numbers: the only hit is the HUD sheet (item slots with counts on number keys). So **move speed while using, and whether dash, jump or abilities cancel, are not published anywhere we have.** Footage is the open question for those rows.

HP scale: source hunters have 880-1,596 HP (median 1,030) [D]; ours 124/145/193 (light/medium/heavy). About 7.2x.

## Drinks and repairs

| Item | Ours (after) | Source | Verdict | Evidence |
|---|---|---|---|---|
| **Tonic** use time | 1.0 s (was 1.1) | Vive Brew: heals "after 1s" | **fixed** | [W] Vive_Brew |
| Tonic move speed while drinking | 1.0, no slow (was 0.45, inline in hunter.gd, unsourced) | The Brew page lists no slow. Hypervive names its slow (60%), so a plain Brew has none | **fixed**, best reading; footage should confirm | [W] Vive_Brew, Hypervive |
| Tonic blocks firing | yes | not stated | unverified, kept | none |
| Tonic hit taken while drinking | x1.2 (`Hunter.CONSUME_VULN`) | "Vulnerable" while drinking; Vulnerable is 2x damage [D] | **differs, not changed**: the same constant serves the armor kit and box revive (owner 101b), so it is a card for the owner | [W], [D] status table |
| Tonic cancelled by damage, effect lost | a hit of 1+ damage (after x1.2) spills it; nothing is used up, the tonic is kept | "Cancelled on taking damage". Whether the item is used up is not stated | match on the cancel; keep-the-item is ours | [W] Vive_Brew |
| Tonic cancelled by dash | yes (kept) | not stated | unverified, kept | none |
| Tonic cancelled by stun, going down, glider | yes (kept) | not stated; the Brew's Silence rule ("no consumables") is separate [D] | unverified, kept | [D] Silence row |
| Tonic cancelled by jump or an ability | no (neither ends the drink) | not stated | unverified, kept | none |
| Tonic amount | flat 42 HP (was 40% of max, 49-77 HP) | 304 HP, flat; 304 / 7.2 = 42 | **fixed** (about 29% of a medium hunter, as in the source: 304 / 1,030). Perk Remedy and gear still scale it | [W], [D] |
| Tonic at full health | refuses (buzz) | not stated | unverified, kept | none |
| **Armor kit** use time | 1.6 s | "short cast time", no number | **unsourced, kept** (now in data) | [W] Portable_Armor_Repair |
| Armor kit move speed | 0.45 (now in data) | not stated | **unsourced, kept** | none |
| Armor kit cancels | same as the tonic | not stated | unverified, kept | none |
| Armor kit amount | repairs armor to full | one press repairs 1 bar = 500 armor; from 1.04 a press restores 80/40/30% on grey/green/blue [S] | **differs, not changed**: 500 of an armor of 2.2 x HP (~2,270 on a median hero) is ~22% a press. Switching means kit prices, stack and bring limits need to move together, so it is the owner's call | [W], [S] |
| Mending kit (`medkit`) | instant, 40 HP + 20 armor | none: no such item | ours only (see [S]) | [S] 1c |
| Shield cell (`shield_cell`) | instant, 40 shield for 8 s | none | ours only | [S] 1c |

## Utilities used from the belt

| Item | Ours | Source | Verdict |
|---|---|---|---|
| Swift draught (`stim`) | instant, +35% speed 6 s | nearest: Elixir of Speed (gone by 1.0) | ours only, keep |
| Smoke bomb | instant, cloud 8 s | Ethereal Smoke: moving team cloak, stealth + 50 move speed, 30 s | differs (S): keep |
| Spring pad | instant place, armed at once, 20 s | Jump Pad: arms after 2 s, 30 s or 10 s after first use, stack 2 | differs (S): a card, not a change here |
| Seeker flare | instant, 26 tiles, 3 s | Pocket UAV: map marks, duration unknown | differs (S) |
| Chest key, Rift key | instant | Gold Key / Evil Key | have / differs (S) |

None of those have a published use time or slow in the source either, so nothing there is a clear mismatch beyond what [S] already lists.

## Ideas of ours (not built)

- Hypervive ("Deep Draught" in [S]): a 5 s Vulnerable, 60% slow, full heal item. The slow here is the only consumable slow with a source.
- Chained drinks by holding the key (patch 1.02): our belt press ignores a hold.
- Stack of 8 for the tonic and kit (source) against our 5 and 4.
- Footage pass for: slow while drinking, dash/jump/ability cancels, whether a cancelled Brew is used up.
