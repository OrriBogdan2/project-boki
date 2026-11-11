# In-match inventory and deathbox: 1280x720 and 3440x1440 pass (ext/ui-inventory-pass)

`--inv-shots --shots-size=WxH` (`tools/inv_shots.gd`). before_* = origin/main 88b06b9e7, after_* = this branch.
pack = inventory (I) with a full loadout, tip = compare card on a backpack piece, loot = deathbox beside it.
Files without `gpu` are local xvfb (software GL); the `gpu_` ones come from `jobq submit --needs gpu`.

Found (before), top three fixed:
1. The backpack showed 2.5 of 5 things at 720p (two-line rows, big buttons); the rest hid behind a scroll.
   After: one line each, the full 6-slot pack and its free room show whole.
2. Belt stacks put the count in the clipped name ("Smoke bomb x1"); armor/boots tiles (no key) sat a few px off
   the glove tiles. After: plain name, count on its own; the key row has one height.
3. The deathbox footer hint ran to the window edge, and the inventory (pushed to 490 px by its rows) slid under
   the deathbox. After: the hint is Smart loot's tooltip; the inventory stays 470 px, a clear gap between.

Checked fine: every slot has icon, name and key where it has one; the compare card stays on screen at both sizes;
the UI scales x2 at 3440x1440 (content scale), so the ultrawide layout matches 720p at the right edge.
Not touched: loot rows themselves (ext/loot-simple-1111 rewrites that window), smart-loot double F.
