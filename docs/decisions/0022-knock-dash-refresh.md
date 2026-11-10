# 0022: The knock dash refresh is one game-wide rule, with assists

**Problem.** Owner item 159 (Nov 5): every hunter gets the dash back on a knock or an assist; multi-charge
dashes get one charge (the source's patch). DashReset gave the knocker every charge and assists nothing,
and Vex and Cinder each added their own dash refund on top (double cues, Cinder's charge counted twice).

**Options.** (a) Per-kit refunds in every kit. (b) One rule in DashReset: the knocker through
Match.knock/eliminate (as before), assists through the kits' existing 5 s hit memory (ArchKit._tick_knocks).

**Choice.** (b). `DashReset.refresh`: a one-charge dash whole, else +1 charge, long-dash cooldown cleared.
`DashReset.assist`: a teammate whose blow knocked a hunter we hit in the last 5 s (owner said ~4 s; one
window for the kit assist heals and this). No heal on an assist. The kit duplicates are gone (Vex's Hot
Streak dash and cue, Cinder's +1 ram charge); kit-specific resets (Vex rank-3 RMB, Cinder's Cloak, Kael's
Riposte, Sable, Sparkle) stay in their kits. No per-hero opt-out flag yet (all 12 are on; add it when one is off).

**Affects.** Combat only; nothing synced changes shape (dash counts already sync), no save change.
Proof: `--knock-reset-check`; the full list is docs/KNOCK_RESETS.md.
