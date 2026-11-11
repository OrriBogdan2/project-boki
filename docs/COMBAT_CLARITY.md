# Combat clarity: who, what, and what it did (2026-11-11)

Owner playtest 11-11 (0.24.4): "very unclear when fighting people who they are, what they're doing ... the combat
needs to be way more clear (doesn't mean more UI on the screen), just more clear abilities". This pass makes the
shared layer carry the read on the bodies and the ground, and takes clutter off the screen. The per-Hunter looks are
the per-Hunter jobs' (VFX_QUALITY.md); the audit below lists what is still theirs.

## How the source keeps a fight readable (and what we take)
`docs/DASHES_AND_ABILITY_FEEL.md` §5 has the research (SUPERVIVE, Battlerite, Riot, Overwatch). In short: the enemy
is red on the body and on the ground (outline + telegraph rim), your own and allies' looks are calmer; a cast reads on
the caster first; crowd control reads on the victim's body (a stun ring over the head, roots at the feet); floating
text is rare. Our looks stay ours: the signature colour is the body of every effect, the side colour is an edge.

## The shared rules (code)
| what | where | rule |
|---|---|---|
| who: the body | `SideRings` + `hero_toon` `side_rim` | every other Hunter's silhouette carries a band in the viewer's side colour (`SideColor`: ally blue, rival red), outside the signature band; none on your own body (your ring says it) |
| whose: the looks | `SideColor.fx` | other people's ground areas, telegraphs (ArchKit `tele_circle` / `tele_lane`, AimKit shapes with `all`), charge rings, shot halos and area landings lean to their side: a teammate's 30% to ally blue, a rival's 45% to hostile `#ff2d55`; the core of a shot keeps the shooter's colour |
| what: the cast | `BodyTell` | any ability (not the LMB or the dash) glints the caster's body in their signature colour (0.3 s) and rings their feet in the side colour; AbilityFx's own caster ring stays for Boki only |
| the true area | `AbilityFx.land` / `cast` | an area landing rings exactly its radius (was 1.15x), in the side lean; a zone cast rings its radius once (the extra 1.8x ring is gone) |
| the hit | `Ent.render` | the hit flash holds full white for 3 frames (`FLASH_FADE`), then fades |
| what it did: CC | `BodyTell` | stun: stars spinning over the head; root: tendrils growing round the feet; slow: frost running down the legs (not a big hit's stagger); and the body pulses that colour while it lasts. Grounded and Dazed keep their own body looks (`KitStatus`). No floating CC words, no icon tiles beside other Hunters' plates (the plate's word stays in place of the name) |
| less text | `Fx.word` | one floating word at a spot at a time (`WORD_ROOM` 3 m, `WORD_HOLD` 0.6 s), smaller (28 / 40 px) |

Checked by `--clarity-check` (side edges per viewer, the side lean, the shot halo, stars / tendrils / frost / tint on
and off, the cast glint and ring).

## Films
`docs/shots/combat-clarity/fight_3v3_a.mp4` (Tenzo, Sparkle, Lace vs Kael, Cinder, Vex) and `fight_3v3_b.mp4` (Meeko,
Albert, Neve vs Grimble, Motley, Sable): the same seeded 3v3 before (left, main 272368589) and after (right), at the
match camera. Made with `--gameplay-media --media-clip=1 --media-fight=<a,b,c/d,e,f> --media-zoom=1.0 --media-secs=12
--media-size=1280x720` (a software render under xvfb-run here: the GPU queue was 50+ deep). The bots don't fight the
same way twice, so the two halves drift apart after the first seconds.

## Audit (game camera, match zoom, from the films and docs/parity_reel)
Grade: clear / unclear, worst first. "Shared" = fixed or helped by this pass; the rest is the Hunter's own job.

| Hunter | grade | why (what still reads badly) | owner |
|---|---|---|---|
| Grimble (dredge) | unclear | the ult's giant violet-and-gold spiked shape covers the whole fight for seconds; four colours across the kit | per-Hunter job |
| Motley (ostra) | unclear | several large violet well discs at once, no edge to tell whose (now leaning red/blue via shared telegraphs only where they go through ArchKit/AimKit); indigo vs teal signature | per-Hunter job |
| Meeko (tender) | unclear | big gold seed rings and teal ult dome fill the ground under everyone; heals and hurts look alike | per-Hunter job |
| Sable (thief) | unclear | LMB hits barely show; her X discs are pale | per-Hunter job |
| Albert (bulwark) | unclear | gold E box and the big gold ring under him read as one blob with Meeko's | per-Hunter job |
| Sparkle (mage) | unclear | Kitefall's range disc washes the ground pink-violet; the Storm Rod lane is a thin cyan line next to pink orbs | follow-up (this pass: shared only) |
| Tenzo (dolm) | clear-ish | Stone Row rocks read as objects; Quakefall's slam ring is plain and the X spine's line is thin at match zoom | follow-up (this pass: shared only) |
| Vex (gunslinger) | clear-ish | the lime body reads; LMB tracers are faint | per-Hunter job |
| Neve (rimewright) | clear | shards and the shatter read; the dash ice path is flat boxes | per-Hunter job |
| Lace (archer) | clear | orchid threads and the Heavy Shot read | per-Hunter job |
| Kael (juggernaut) | clear | the bar: slash arcs, burning lanes | per-Hunter job |
| Cinder (ashwick) | clear | the bar: layered flame cone | per-Hunter job |

Shared things still noisy in the films (follow-ups, not this pass): Boki ability names (`Stinger Hook`, `Prism
Wall`, `Spore Patch`) still float as words (now one at a spot); world hints ("Echolope: behind you!", "Hold F to
stomp") print over the fight and overlap each other; Boki rings and the Hunters' cast rings stack under a melee.
