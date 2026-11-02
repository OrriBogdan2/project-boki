2026-11-02T04:17:34Z

ext/heroes-joule-ghost | 9ad329d | ready to merge | 0.10.0 (no new sync) | full suite 0 failures on final commit, health/gen_wiki OK
ext/heroes-elluna-celeste | b658b74 | ready to merge | 0.10.1 (new "carry" event) | full suite 0 failures on final commit, health/gen_wiki OK
ext/heroes-kingpin-felix | a6c29a1 | ready to merge | 0.10.0 (no new sync) | full suite 0 failures on final commit, health/gen_wiki OK
ext/heroes-tetra-void | da15c32 | ready to merge (vs sync58 e5f25ec; main now fcc3745, re-merge needed) | 0.10.1 (new "zone" event) | full suite 0 failures on final commit, health/gen_wiki OK
ext/heroes-myth-oath | 1603a44 | running (finish pass) | pending | pending
ext/kits2-nor | e5f25ec (from main, not pushed yet) | running | pending | pending
ext/farmbuild | e5f25ec (from main, not pushed yet) | running | pending | pending
ext/classes | - | queued (after hero finish passes are pushed) | - | -
ext/hero-shots | - | running (first 4 pairs; myth-oath and kits2-nor added when done) | - | -

Running now: myth-oath finish pass; ext/farmbuild; ext/kits2-nor; ext/hero-shots assembly (4 Sonnet agents)
Queued: ext/classes (after myth-oath is pushed); add myth-oath + kits2-nor shots to ext/hero-shots
Last INBOX entry handled: 2026-11-02 03:20 UTC
Questions for the owner: (1) Tamsin/rimewright: add real healing, or keep source-accurate ice control plus a wall shield? (2) Myth+Oath: keep our own additions (Archer snare/Focus, Bulwark Guard/Shield Slam)?
Merge notes: hero branches each append to Sfx.NAMES, Arch.ORDER, KMOVES and the arena swap keys; keep both sides when resolving.
Note: origin/main moved to fcc3745 after the hero finish passes merged sync58 e5f25ec; the hero branches merge cleanly against sync58 and need a re-merge with fcc3745 (tetra-void dry run: 4 conflict hunks).
