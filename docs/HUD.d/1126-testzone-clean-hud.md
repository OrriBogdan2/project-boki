## Test Zone shows a clean HUD (11-26)

The Test Zone runs with `opts.training` (the practice dummies and spawner) but also `opts.test_zone`, and everything the
Training Grounds adds on top is gated on the second: the Hud banner, checklist and Guide pill, the Practice bar, the
Arena key line, DPS meter, ground sign and welcome toast, the `KitDrill` banner, the dodge drill and the duel pad. What
is left is bars, abilities, minimap and the weapon cards. The Test Zone page has a "Practice tools" switch
(`Arena.set_tools`) that brings the bar, key line, meter and dodge drill back; with the tools on, the practice layout keeps
the key line clear of the minimap (`Arena.MINIMAP_CLEAR`) and the bar above the carried-Boki and weapon cards
(`Practice.TEST_ZONE_PAD`). `--test-zone-shots` renders both sizes (1920x1080, 2560x1440) through six stages and lists every
HUD rect that intersects another (or the Hunter zone); `--test-zone-check` asserts none, tools off and on. Modal pages (the
Test Zone page, the L menu) dim the screen and are not counted.
