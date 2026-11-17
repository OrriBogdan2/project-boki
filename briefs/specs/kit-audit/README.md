# Kit audit vs SUPERVIVE (orchestrator, 2026-11-03 23:30 UTC)
Read-only audit of all 12 kits on **main 200effce** against briefs/supervive-data (data), briefs/hero-ref (footage), DECISIONS.md and OWNER_REVIEW_1103 (incl. items 50 and 51). The full tables (slot, ours with file:line, source ref, gap, severity, fix) are in the four files here:
- zedran_bjorn_pin.md (Brall, Oath, Myth)
- tarek_ostra_claire.md (Tetra, Void, Celeste)
- vex_vireo_sable.md (Ghost, Joule, Shiv)
- cinder_dredge_moosh.md (Felix, Kingpin, Elluna)

**Caveat:** this audits main only. Some gaps may already be fixed on unmerged branches: dancer-feel (Sable item 7), tarek-glide-slam (Tarek RMB from a glide), bjorn-48-49-51 (Bjorn 49/51), parity-ostra-claire-moosh, combo-51 work. Each hero agent must check its own branch before fixing anything.

## Cross-cutting (fix once, for everyone)
1. **ONLINE BUG (HIGH):** Cinder's E pull (ashwick_kit.gd:612) and Dredge's hook (dredge_kit.gd:353-354) skip `remote` bodies, so they never move other human players online (match.gd:5843, :5972). They only work against bots. Audit every displacement (pulls, knocks, swaps, hooks: Ostra Trade, Zedran chain, Vireo E, Bjorn push, Tarek punch-rocks) for the same skip. Must be fixed before online testers.
2. **Item 50 not on main:** own abilities still shake your own screen (feel.gd:228-242 gives the caster a share, plus direct add_trauma/punch calls in most kits).
3. **No-rings rule:** cosmetic rings, discs and bursts on dashes and resets remain:
   - Vex: slide discs every 0.05 s; rank-3 slide end; knock reset.
   - Vireo: Wirerun arrival ring; Blowout ring.
   - Sable: blink ring.
   - Pin: roll start ring and bursts.
   - Bjorn: dash bursts; full-swing ring.
   - Zedran: ult reset, Enrage and wind-up rings.
   - Cinder: cloak-reset ring.

   Gameplay rings drawn bigger than their real area: Vireo E 2.3 m vs a 1.5 m hit; the ult ring is 1.45x.
4. **Item 51 (combine, don't cancel):** Shift still cancels Pin's draw and Bjorn's LMB hold. Most dash rows still buffer to the dash end; item 51 (newer than DECISIONS' "~0.1 s buffering") says abilities fire mid-dash where the source is silent.
5. **Owner decisions not built yet:**
   - Ostra's ult still locks him for 4.5 s (the owner wants ~1 s, then free).
   - Claire's RMB is still a throw (the owner wants a push-like emerge).
   - Claire's ult from a skate stops her dead (the owner wants a forward carry, then rooted).
   - Moosh still enforces the dropped 3x rule (10.7 m glide; care_combo_check.gd:539 asserts it).
   - Zedran's chain pull ignores facing and movement (the owner wants it like Brall's).
   - Zedran's RMB hold auto-fires at 1.2 s and has no perfect release (DECISIONS); its pose should be the sword over his head.
   - Vex's RMB is still an overhand throw (DECISIONS: side toss).
   - Dredge's "Abyssal Hand" rename and look (DECISIONS) isn't done.
6. **Text:** the wiki still has old names (Class-Marlowe.md, Class-Dolm.md, Classes.md with a Tamsin link); Ostra's text says "her" (he's male); Vex's text has "his rifle" (she's female).

## Top gaps per hero (HIGH unless noted)
- **Zedran:** chain pull model (see 5); RMB hold auto-fire, perfect release and overhead pose; MED: Slam should reset X on any knock with it, E/X cooldowns vs data 16 s / 45 s, the rings.
- **Bjorn:** item 49 launch + glide hand-off (check bjorn-48-49-51); Shift should keep the hold (51); MED: normal swing carries 3.4 m (cap 2 m), stun on every knock incl. the throw/recall, invented Guard meter / Shield Slam / Crush, shield rise 0.2 s vs 0.1 s, ult cd 33 s vs 50 s.
- **Pin:** Shift cancels the draw (51); Spirit Walk roll too fast (2.55 m / 0.18 s vs 3 m / 0.27 s; the owner said "Pin's Shift feels fast"); MED: invented Focus/Deadeye and knock heal, the Heavy Shot wall-pin bonus is far below the source (~5x), cooldowns from the footage instead of the data (Shift 9.5 s, E 15 s, X 60 s).
- **Tarek:** RMB from a glide (check tarek-glide-slam); MED: the hunter viewer plays the wrong moves; RMB cd 9 s vs 11 s; the wiki text.
- **Ostra:** ult lock (see 5); MED: the empowered orb should pass through terrain; invented seed auto-pop, 40% swap slow and orb magazine; text "her" and the old lamplighter concept.
- **Claire:** RMB motion and ult carry (see 5); LMB darts stop homing while skating; MED: the 3 heavy darts at the end of each burst are missing; ice trail 1.2 s vs "a few seconds"; skate cd 8.5 s vs 13 s, ult 47 s vs 80 s; spear landing hit 4 dmg vs a 156-dmg small area; an invented 0.5 s root.
- **Vex:** RMB side toss; slide discs; MED: rifle 24 rounds / 1.7 s reload vs 30 with rapid idle reload; Dazed adds an invented 35% slow; dash rows have no source text.
- **Vireo:** E should be hold, drag, release (today a fixed 0.3 s flick); E gives 2 Static (data: 1); LMB pierce is invented; MED: dash pass hit about half the data's ratio; the ult is missing the Static spread.
- **Sable:** item 7 (check dancer-feel: empowered 3.5x -> ~2.3x, throw pose mid-flip); MED: invented Shred and Grounded slow; Bola/knife cooldowns ~0.54x the data.
- **Cinder:** online pull (see 1); cloak-reset ring; MED: invented 8 s fuel and a 20% slow while firing; Cinder Shot should be allowed during the ult (51).
- **Dredge:** online hook (see 1); Abyssal Hand; 3 chained dashes vs one every 7 s; MED: he walks at full speed while reeling (should be rooted/braced); the dash shoves foes (not in the source).
- **Moosh Moosh:** 3x rule (see 5); on the ground with the charge spent, Shift fires the air glide along the ground (tender_kit.gd:284 lacks `not h.grounded`); her ult heals herself instead of the downed ally; MED: no glide steering (the owner asked for air control); Burrseed cd ~10.5 s per the data.

## Open owner questions (the source or data can't settle them)
1. Claire "LMB tracks while skating": should her darts home in on targets while she skates?
2. Tarek's rocks: the data says allies can hop friendly rocks by jumping; item 25 kept walls caster-only. Follow the data?
3. Smaller ones, each agent's call with a note: whether Bjorn's raised shield blocks melee from the front; the source tether's max length; whether Ostra's swap moves units standing at the origin.
