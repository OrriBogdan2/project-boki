# Ability names audit: does each name, and where it visibly comes from, fit the Hunter?
Read-only audit (synth worker, 2026-11-09) for the owner's 11-08 rule: "ability names must make sense for that character and come from where the fantasy says (hand, weapon, relic, Boki)". Sources: `content/archetypes/*.json` (names, descriptions, `fantasy`, `silhouette`, `signature`), `content/vfx/*.json` anchors, `docs/heroes/*.md`, `briefs/art-refs/*_v2/index.md` (locked designs), `briefs/LORE_MASKS.md` and `briefs/DECISIONS.md` (Nov 7-8 locks).

**How to read it.** Origin = what the player sees the move come out of today. Fit = does the name plus that origin match the locked design and lore. **CLEAR** = an obvious fix the coordinator can apply. **TASTE** = the owner should pick (2-3 options given). "keep" = fine as is. The coordinator applies CLEAR rows; only TASTE rows go to the owner.

**Already decided (Vex, owner 11-08):** Burr Charge -> **Coin Blast** (she flips her first coin, the relic). Longneedle -> **Palm Lance** from the open palm of her cyborg hand (the task brief says "Finger Gun"; DECISIONS.md records the owner's correction the same day: not Finger Gun, it is long range, so Palm Lance). Neither is in the data yet (`grep "Coin Blast"` finds nothing on main).

**Cross-hunter clashes (CLEAR):**
- Vex's ult **Cinderfall** vs the Hunter **Cinder** (and her **Cinder Shot**). Rename Vex's (see her table).
- Two "Burr" moves: Vex's Burr Charge (going away) and Meeko's **Burrseed**. Solved once Coin Blast lands.
- Two seeds: Meeko's Burrseed and Motley's **Brimseed**. Motley's should go (a jester has no seeds; see his table).
- Grimble's **Anchor Drop** vs Albert the ship-knight (compass, capstan hammer): the 3D review already rejected anchor/pincer arm options for Grimble "because they overlap Breaker". The ability name has the same problem.
- Tenzo's **Molten Guard** vs Cinder: the Tarek v2 lock says the orange-fire glow belongs to Cinder; Tenzo's stone is matte grey with jade glyphs that never glow orange.

**Stale kit text that fights the locked designs (CLEAR data fixes, no owner call):** `fantasy`/`silhouette`/`signature` strings for Vex ("ember-rifle", "bandolier of spiked charges", "long-shrouded rifle", `quill_rifle`), Grimble ("harbour hauler, reels you in on a rope, drops an anchor", "round brass helm and rope drum"), Albert ("frozen prow shield and long ice-cased oar"), Neve ("rink-keeper from the high frosts"), Tenzo ("quarry-hand"; "molten" cracks in Basalt Spine), Motley (tells: "the lantern burns white and his ribbons lift"), Meeko (vfx anchor named `lantern`). These are display/data strings only; ids stay.

---

## Vex, the Hired Gun (gunslinger) — The Odd Jobs
Design lock: both arms mechanical, right forearm IS a brass six-barrel minigun (no hand), left hand flips a gold coin. Relic: her first coin.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Quill Rifle | the gun (data still calls it a shouldered rifle) | no: she has no rifle, the gun is her arm | **TASTE**: Gatling Arm / Brass Barrels / Tally Gun (one tally per bounty is her lore) |
| Passive | Hot Streak | HUD pip + heat shimmer | yes (hired gun on a streak) | keep |
| Dash | Slipstep | her feet, a skid or slide | yes | keep |
| RMB | Burr Charge | arm-cannon launcher | decided | **Coin Blast** (owner 11-08): flipped/thrown coin that bounces and blasts |
| E | Longneedle | charged beam from the gun | decided | **Palm Lance** (owner 11-08): from the open palm of the cyborg hand, green-fire emitter |
| X | Cinderfall | a shell fired straight up, falls on the disc, burns | name clashes with Cinder; a mortar shell from a minigun arm is odd but readable | **TASTE**: Brass Rain (she swept brass casings as a kid) / Bounty Drop / Sky Shell. Origin: the shell leaves the gatling barrels pointed up. |

## Albert, the Barnacle Knight (bulwark) — The Hearthguard
Design lock: hull armour, brass diving helmet, compass in chest, figurehead hatch shield, spiked capstan hammer chained to his wrist. Relic: the ship's compass.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | War Hammer & Aegis | capstan hammer thrown and recalled on its chain | yes (the chain explains the recall) | keep; "Aegis" see RMB |
| Passive | Guard (Shield Slam, Crushed) | shield + hammer | yes | keep |
| Dash | 360 Smash / Shield Charge | hammer spin / shield rush | yes | keep |
| RMB | Aegis | the figurehead hatch shield | works, but "Aegis" is a Greek myth word on a sunken ferryman | **TASTE**: keep Aegis / Hatch / Figurehead |
| E | Mending Ground | a green light column onto the hammer, heal zone follows it | origin fine; the name is generic and green on a cyan-sea Hunter | **TASTE**: Safe Harbour / Landfall / Mending Ground (keep). Colour note: his sea light is cyan, the heal is green. |
| X | Faultline | the hammer planted, a fissure down the lane | yes (it fits a hammer) but no sea or ice flavour | **TASTE**: keep Faultline / Icebreaker (he broke the ice for his refugees) / Keel Line |

## Sparkle, the Storm Chaser (mage) — The Odd Jobs
Design lock: copper lightning-rod backpack (the relic, pink arcs), copper coils on the wrists, bolts from her fingertips, hot-pink lightning. No kite in the v2 design.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Coilcaster (finger gun) | her fingertips, left then right | yes (wrist coils) | keep |
| Passive | Static | sparks on the foe | yes | keep |
| Dash | Wirerun | she streaks as lightning | yes (copper wire on her arms) | keep |
| RMB | Storm Rod | a copper rod summoned and thrown | yes: it is her relic's rod | keep |
| E | Skycall | a bolt from the sky | yes | keep |
| X | Kitefall | she launches up, hangs, strikes down as a bolt | the "kite" is gone from the design (the kit still says "copper rod mast and kite pennant") | **TASTE**: Boltfall / Spire Drop (she climbs spires to chase storms) / Rinkfall (no: Rink is the boy she lost; avoid). Also: her data colour is teal `#7dffd8`, lore says hot pink; flag for the VFX pass. |

## Kael, the Unbroken (juggernaut) — The Fallen Court
Design lock: cracked glowing greatsword (white-hot cracks), broken chain on his wrists and pommel (the relic), crimson curse on one arm.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Greatsword / Searing Wave | the blade | yes | keep |
| Passive | Rage | red shell, swelling | yes | keep |
| Dash | Rampage | a dash attack along the blade | yes | keep |
| RMB | Smash (text calls it "Finishing Slam") | the blade | yes, but two names for one move | **CLEAR**: pick one name everywhere; suggest **Finishing Slam** (it says what it does to the wounded) |
| E | Warchain | the chain from the pommel/wrist | yes: it is the relic | keep |
| X | Gilded Riposte | a gold guard, then a cleave | yes (arena champion); "gilded" is also Malgrave's gold | keep |

## Lace, the Red Stitch (archer) — The Fallen Court
Design lock: porcelain doll seamstress, black recurve bow strung with red thread, giant silver needles as arrows, red strings from her raised hand, stitched porcelain mask (the relic), a loose wrong-looking shadow.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Longbow | the bow, needles as arrows | yes | keep |
| Passive | Hawk Sense | nothing visible (see-through-cover) | no: nothing hawk-like on a seamstress | **TASTE**: Loose Thread / Red Thread (she follows the thread to the wounded) / Seamstress's Eye |
| Dash | Spirit Walk | a roll, then a green spirit shell | half: lore gives her a loose shadow, not a spirit | **TASTE**: Shadow Walk (her shadow came loose) / Cut Strings / keep Spirit Walk |
| RMB | Heavy Shot | a great needle on the bow, red thread trailing | origin perfect, name generic | **CLEAR**: name the needle: **Needle Shot** (alt: Great Needle) |
| E | Hail Wall | arrows rain on a curved wall; the scorch layer already has a `stitch` seam option | origin fine, name is weather on a stitcher | **TASTE**: Stitch Line / Seam / keep Hail Wall |
| X | Starpiercer | three big piercing arrows | no star anywhere on her | **TASTE**: Threadpiercer / Final Stitch / Through-Stitch |

## Cinder, the Ashen Kiss (ashwick) — The Fallen Court
Design lock (owner Nov 7-8): no flamethrower, hose or tank; fire from her bare hands (ext/cinder-v2-palms, in main, adds a fire point per palm). Horns, obsidian shard armour, flame-tipped tail, jets from heels and tail in flight. Relic: the empty Wyrm's-blood vial.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Torch Lance (weapon id `flamethrower`, vfx anchor `nozzle`) | should be the palms; data still says a stream from a nozzle | no: there is no torch or lance | **CLEAR**: rename the weapon to **Hand Fire** (alt: Bare Flame); move the `nozzle` anchor to the palm fire points |
| Passive | Flashover (Char, Ablaze) | flames over the foe | yes | keep |
| Dash | Soot Ram | head-first, her horns | yes | keep |
| RMB | Cinder Shot | a cinder from the hand | yes (her own name) | keep |
| E | Furnace Cloak | a heat blast round her, a swirling shield | yes | keep |
| X | Flue Flight | jets from heels and tail, lava carpet | a "flue" is a chimney pipe, a leftover of the tank design; the jets are hers now | **TASTE**: Ember Flight / Ash Wing / keep Flue Flight |

## Tenzo, the Stone Seer (dolm) — The Odd Jobs
Design lock: huge stone left arm, stone gauntlet on the right, three floating seeing-stones with jade eyes (one is the relic); matte grey stone, dark seams that never glow, carved glyphs glow jade. Orange belongs to Cinder.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Rubble Fists | the stone fists | yes | keep |
| Passive | Molten Guard / Tremor Sense | a shield per punch; a sensing cone while sneaking | "Molten" is Cinder's palette and breaks his design lock; Tremor Sense is perfect for a blind seer | **CLEAR**: rename to **Jade Ward** (alt: Stone Ward); keep Tremor Sense. Also recolour its ring from molten orange to jade. |
| Dash | Rock Hop | rocks burst up under his feet | yes | keep |
| RMB | Quakefall | a slam | yes | keep |
| E | Stone Row | rocks rise ahead | yes | keep |
| X | Basalt Spine | a ridge of rocks; "molten cracks show along the line" | name yes; the molten tell is wrong | **CLEAR**: the tell is jade glyph light, not molten cracks (text + VFX) |

## Grimble, the Scrap King (dredge) — Moth & Hook
Design lock: right arm IS a bruised-purple bone hook (no chain), hoard on his back, brass loupe (the relic is a brass monocle), blunderbuss, gauntlets.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Shotgun | a one-handed blunderbuss | yes | **CLEAR**: display name **Blunderbuss** (the weapon sheet calls it that) |
| Passive | Salvage | HUD stacks, brass glints | yes (Scrap King) | keep |
| Dash | Barge | a low clawing lunge | the word is a boat, the old harbour design | **TASTE**: Scramble / Scuttle / keep Barge |
| RMB | Abyssal Hand | the bone-hook arm stretching out | yes (renamed already) | keep |
| E | Anchor Drop | he raises his fist and slams it | no: anchors are Albert's sea; the thing coming down is the bone hook | **TASTE**: Hook Slam / Scrap Slam / Vault Drop (he came out of Malgrave's vault) |
| X | Brass Broadside | two waves of brass slugs | "broadside" is a ship's cannon volley, the old design, but brass slugs from the blunderbuss read fine | **TASTE**: Scrap Volley / Brass Barrage / keep Brass Broadside |

## Neve, the Snowglide (rimewright) — The Hearthguard
Design lock: frost bunny show-skater, candy-cane ice spear with a heart-crystal head, glowing blade skates (the relic).

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Hoar Fan (Ice Dart) | darts flicked from her hands | origin yes; "Hoar Fan" names a fan she never holds | **CLEAR**: weapon display name **Ice Darts** |
| Passive | Hoarfrost (Chill, Shatter) | frost on the foe | yes | keep |
| Dash | Skate | her skates | yes: it is the relic | keep |
| RMB | Ice Spear | a spear forms between her palms and is pushed out | she carries a real candy-cane spear; the move conjures a second one | **TASTE**: keep as conjured (name stays) / make it her carried spear thrown and re-formed in her hands (name stays, animation change) |
| E | Rink Wall | an ice block slides from her feet | yes (festival rink) | keep |
| X | Rimelock | a frost shell, a rink round her | yes | keep |

## Meeko, the Dawnfox (tender) — The Hearthguard
Design lock (Nov 7-8): fairy fox medic; a little sun and a shy raincloud float beside her; the brass lantern is retired. Relic: a glass globe holding sun and cloud. Lore: "she heals through the two of them". Today no ability uses the sun or the cloud, and the VFX anchor is still called `lantern` (hand.R).

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Ember Cast | embers from alternating hands | fits the hearth lore; the sun is right there and unused | **TASTE**: keep from the hands / embers cast from the little sun (name stays) |
| Passive | Carrier / Kindle | she shoulders the downed | yes (courier) | keep |
| Dash | Relay Step | a skip; a floaty glide on her wings | yes | keep |
| RMB | Burrseed | a seed thrown by hand, roots the foe | no: nothing about her is plants, and it collides with Vex's Burr | **TASTE**: Cloudburst / Raindrop Snare / Drizzle Root. Origin: the raincloud throws it (the cloud finally has a job). |
| E | Hearthlight | a ring of warm light round her; throwable | name yes (the hearth is her story); origin should be the sun | **CLEAR**: the ring comes from the little sun (anchor the VFX to the sun prop, not `lantern`/hand) |
| X | Hearth Call | a tether of light to a teammate | yes | keep; tether from the sun |

## Motley, the Void Jester (ostra) — no faction
Design lock: a jester on a brass spring rising from a hovering jack-in-the-box (the relic), starry void face, gloved hand with long fingers, burning cards. He steals laughter; his bells ring only when he swaps. No lantern anywhere in the v2 design.

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Tether Lantern | orbs from his hand (kit id `tether_lantern`) | no: no lantern on him | **TASTE**: Dealt Cards (the orbs become spinning cards; the `card` particle layer exists) / Void Orbs / Stolen Laughs |
| Passive | Swell (a pink sphere, "Swollen") | a sphere round him | works, but pink on a starry void jester | **TASTE**: keep Swell / Punchline (full = the joke lands) / Big Finish |
| Dash | Lantern Trade | he lobs a lantern, swaps places with whoever stands there | origin wrong: it should be the box (his bells ring when he swaps) | **CLEAR** origin: he lobs the jack-in-the-box (or a copy of it) and springs out of it at the far end. **TASTE** name: Box Swap / Jack Swap / Switcheroo |
| RMB | Shard Snap | a bundle of shards from his hand, stuns | shards of what? nothing on him is glass | **TASTE**: Card Snap (a fan of burning cards) / Snap (keep short) / Wild Card |
| E | Brimseed | a seed that grows and pops | no: a jester has no seeds; clashes with Meeko | **TASTE**: Surprise Box (a small box that swells until it bursts) / Pop Goes (press E again to pop) / Big Laugh |
| X | Nightwell | a void well that drags foes in | yes (the Void he fell into) | keep |

## Sable, the Silver Thief (thief) — Moth & Hook
Design lock: moth antennae, grey-lilac skin, twin pistols, a sheath on each hip with moth-wing throwing knives (the relic), a belt of keys with one tiny bell. The owner rejected bell bolas ("looks like bells, not a weapon").

| Slot | Current name | Comes from | Fit | Proposal |
|---|---|---|---|---|
| LMB | Arc Shots | the twin pistols | yes | keep |
| Passive | Marks | gold diamonds over the foe | yes | keep |
| Dash | Vault | a cartwheel; a gold glint in her throwing hand | yes (she robbed the vault) | keep |
| RMB | Bola | something wrapped round the foe's legs | no prop on the model for it, and bolas were rejected in the design | **TASTE**: Key Ring (she whips her belt keys, the bell jingles) / Moth Snare (a silk line) / Trip Wire |
| E | Shadow Knife | a thrown dagger she blinks to | yes: it is the moth-wing knife, the relic | **CLEAR**: **Moth Knife** (says the relic; alt keep Shadow Knife) |
| X | Encore | she dances, blades fly from her hands | yes | keep |

---

## Summary for the coordinator
**CLEAR (apply):** Vex Coin Blast + Palm Lance (decided); Kael Smash -> Finishing Slam (one name); Lace Heavy Shot -> Needle Shot; Cinder Torch Lance -> Hand Fire with the VFX anchor moved to the palms; Tenzo Molten Guard -> Jade Ward and the Basalt Spine tell to jade; Grimble LMB -> Blunderbuss; Neve LMB -> Ice Darts; Meeko Hearthlight from the sun (anchor rename); Motley's swap lobs the box, not a lantern; Sable Shadow Knife -> Moth Knife; plus the stale fantasy/silhouette/tell strings listed at the top.

**TASTE (owner picks):** Vex LMB and ult names; Albert Aegis / Mending Ground / Faultline; Sparkle Kitefall; Lace Hawk Sense / Spirit Walk / Hail Wall / Starpiercer; Cinder Flue Flight; Grimble Barge / Anchor Drop / Brass Broadside; Neve Ice Spear (conjured or carried); Meeko Ember Cast origin and Burrseed; Motley LMB / Swell / swap name / Shard Snap / Brimseed; Sable Bola.

Nothing in this audit changes gameplay. Renames are display strings, `docs/heroes`, wiki (`tools/gen_wiki.py`), checks that assert names (`hero_title_check`, `archetype_check`), and VFX anchors where the origin moves.
