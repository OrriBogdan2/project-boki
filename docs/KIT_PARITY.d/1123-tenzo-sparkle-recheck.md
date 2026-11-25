## Tenzo (`dolm`) and Sparkle (`mage`) re-check on main 5a246f9696 (2026-11-23)

Every Tenzo and Sparkle row of this file and of `docs/heroes/{dolm,mage}.md` re-read against `content/archetypes/{dolm,mage}.json`,
`content/rules/{dash_feel,kit_parity}.json` and the kits, after the 11-15..11-22 merges. Numbers are the source's share of the
standard target (docs/TTK.md); owner rows (rock slows, Skycall slide, Rock Hop, Spine rocks-only, cooldown scale) untouched.

| Row | Was (file or data) | Data now | Moved by | Fix |
|---|---|---|---|---|
| Tenzo punch damage, knock | 12-24, 6-11 by charge | flat 10.6, 10 again | 7b130d5c7 (11-09) removed the scaling; the 11-14/15 merges of ext/review-design-1110 (864a12f68d) and ext/rename-guin-1112 (5b1534aaf7) put a stale copy of the line back; KIT_PARITY row said **done** | data, `_punch`, `--dolm-combo-check` (flat + short = full), dolm.md, 4 rows |
| Tenzo punch rate | KIT_PARITY "punch .7/.6" | .6 | 10633d83cd (11-09) | row |
| Tenzo Tremor Sense length | dolm.md "16 m" | 18 growing to 25 over 2 s | ext/tenzo-cone-grow | row |
| Tenzo ally hop | rows "not built", "SUPERSEDED, code removed", "no ally hop" beside "built" | built: `StoneStand._ally_hop` | eb93c5b62c (11-03), bots 618098895 | stale rows removed |
| Tenzo Spine | KIT_PARITY hit-shape row "len 12, 9 rocks, differ 40%" | 21 m, 15 rocks, match | 9034ef0dac (11-11) | row |
| Tenzo Rock Hop, rocks, Rockfall slam | 2.8 m / .26 s x.85 / x1.15, cd 12, rock 45 hp 9 s, slam cd 11 | same | none | match; "ROCKFALL" is a removed callout word, its duplicate rows dropped |
| Sparkle Kitefall damage | card chip "22 dmg", desc "takes 22", card "knocking everyone back", mage.md and KIT_PARITY "crash 22" | 9 (72 of 1285 x 154), no knock | a49e6e093a (11-14) 22 to 9, 4b3b15186f (11-16) re-fixed it after a merge, fcd6f69208 (11-20) cut the knock | json text, chip, wiki, docs |
| Sparkle Wirerun | desc "takes 20"; docs 40 m/s, 5.6-9.75 m and 7.5-13 m; `--ryzz-items-check` 2 reds | 18.3, 43 m/s, 6.02-10.48 m | 83386bb77c (11-11), 8f7f151981 (11-11, owner playtest, did not update the check) | desc, docs, check |
| Sparkle Skycall | docs "20 dmg, circle 1.5 kept on purpose" | 19.4, circle 1.8 | 83386bb77c, 7a40610b7 (11-11) | 4 rows |
| Sparkle Storm Rod | docs "18 to 30", no self-slow | 16-26.7, self-slow 18% | 83386bb77c, adf6eb2112 (11-19) | rows |
| Sparkle javelin countdown | 0.8 s | 0.8 s | none | match |
| Sparkle slide, Skycall cd, Kitefall hover/range/radius/cd | 3.4 m (owner 9b), 10.5, 1.7 s / 14.4 / 2.7 / 42 | same | none | match, slide **owner** |

The hero docs also carried merge copies (the same table row two to six times, older wording first): Sparkle's Kitefall,
Static and items 8-13 rows, Tenzo's Shardskin, Tremor Sense, Stone Row, Rock hop and Tetraform rows. The newest copy of each is kept.

**Checks (before, after):** `--dolm-combo-check` 209/0, 210/0 (one new assert: a short hold hits as hard as a full one);
`--mage-combo-check` 174 checks, 6 red, 4 red: the two Wirerun asserts of `--ryzz-items-check` are fixed; four reds remain on main
and are not parity data: LMB bolt reach 13.6 m at level 6 (check wants 13 +-0.5), the Kitefall dark-band look, the glide hand-over
after a streak (32.6 m/s), and the clip timing check ("Warden/Sync" missing on her model in this run). `--card-numbers-check` 344/0,
`--kit-text-check` 0 mismatches.
