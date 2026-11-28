## Grounded read (11-28)

While you are Grounded (KitStatus `gnd`: no dash, jump or glide) your own bar shows it, with no words: the dash slot
is veiled grey and the Space hint beside you (the tapped-Space "Hold" ring's place) is a grey disc, each with the plate's
Grounded icon and a thin ring in the status colour that empties with the time left. The colour, the clock and the ring's
total come from the plate's own status row (`HudPlate.row`), so the bar and an enemy's plate read the same.
Both clear the frame the status ends. Code: `scripts/ui/grounded_read.gd`, drawn from `DashSlot.row_slot` and the
glider block of `Hud`. Check: `--ability-bar-check` ("grounded:" lines).
