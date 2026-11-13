# stuck-integ-f6bd2b7c: the stuck READY list of 2026-11-13 01:35

Built 2026-11-13 by job 20261113-013548-a5 (rpc7) on `ext/stuck-integ-f6bd2b7c`, from `ext/mc-demo-1112` 2f8aa22ab
(the newest mc; it carries main 18402df5b). The list is the same ~490 branches as stuck-integ-fb4b4275
(docs/STUCK_INTEG_FB4B4275.md on that branch, 2026-11-12 08:00). Only the branches below posted a READY after that
build; every other name keeps the call in that doc (in main or an mc batch, carried by a w0246 wave, held, superseded).

**Merged here** (newest READY sha; resolutions in each merge commit):
- `combat-revive-diminish` 2902a0f3a, `tut-skip-check` e7fd6d567, `ui-death-recap` 900206e64, `dash-nd-rows-a`
  ce98194eb: clean.
- `anim-jump-land` 5df86ec76: CLIPS.md keeps the branch's air/land keys (dur, moving, rate) and HEAD's kmoves
  (hold_at, lead) and crouch; clip_check keeps SPAWN_KEY and the JL constants. One duplicate `vel` local fixed.
- `parity-downed-numbers` 7c69d0e90: life.gd stomp and revive take both the source crowd curve and the revive.json
  diminish (`crowd(n) * diminish(o, key)`), the bar decays at `revive_decay`.
- `feel-held-fire-resume` 48ab15aac: both paragraphs (cast-lock buffer, held LMB) in gen_wiki; dash_interactions.md
  regenerated from content/dash_flow (drops HEAD's duplicated rows).
- `albert-size-boop` c117f697d: the branch's hop, 5.5 m lane, lunge and boop wording with the base's TTK numbers
  (Shield Charge 12.4, Faultline strike 1.9 / eruption 24.8, recall 13 at the 0.45 s cadence); the boop behind the
  aegis is kept, the button-up latch stays gone (held-fire-resume dropped it).
- `vex-dash-parity-rebased` ad34d150d: one dash charge and the lime slot colour; the base's rattle_k 0.383, Dazed +38%
  and VvFx tracer/emitter rider stay. VFX_QUALITY lists seven data-driven kits (gil and gunslinger).
- `vex-coin-palm-1108` 775e4a78e: names and the coin and palm (Coin Blast, Palm Lance, `_coin_mesh`, `palm_at`) from the
  branch; numbers (19.5 coin, 24 lance, +38%) and the HeroVfx e_charge / e_fire looks from the base, the palm's green
  fire star added over the charge. The ult shell's heart is LIME (EMBER is gone from the kit).
- `art1-clip-port` 35c82137d: this base's breaker/claire/hem/ryzz/sable glbs with the branch's op lines re-run
  (docs/art/REACT_AUDIT.md: breaker hips nudge, hem hit_b x1.8, hit_f/hit_b retime). Run ext/anim-react-settle-neve-tenzo's
  claire anchor after it, as its note says.

**Carried by READY `ext/stuck-integ-d2f36c16`** (newest READY sha is in it): `airdash-anims-1108`,
`dash-interactions-refresh`, `dash-nd-rows-b`, `docs-heroes-sweep`, `hero-docs-sync-a`, `hero-docs-sync-b`,
`input-latency-check`, `parity-no-riders-meeko`, `snag-audit`, `tenzo-playtest-1108`.

Not merged here: `ext/stuck-integ-fb4b4275` and `ext/stuck-integ-d2f36c16` themselves (each is its own READY).
