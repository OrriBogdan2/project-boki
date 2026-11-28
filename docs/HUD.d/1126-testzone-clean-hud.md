## Test Zone shows a clean HUD (11-26)

The Test Zone runs with `opts.training` (the practice dummies and spawner) but also `opts.test_zone`, and everything the
Training Grounds adds on top is gated on the second: the Hud banner, checklist and Guide pill, the Practice bar, the
Arena key line, DPS meter, ground sign and welcome toast, the `KitDrill` banner, the dodge drill and the duel pad. What
is left is bars, abilities, minimap and the weapon cards. The Test Zone page has a "Practice tools" switch
(`Arena.set_tools`) that brings the bar, key line, meter and dodge drill back; with the tools on, the key line is placed off the minimap
and the readout (`SafeArea.place`, below) and the bar above the carried-Boki and weapon cards
(`Practice.TEST_ZONE_PAD`). `--test-zone-shots` renders both sizes (1920x1080, 2560x1440) through six stages and lists every
HUD rect that intersects another (or the Hunter zone); `--test-zone-check` asserts none, tools off and on. Modal pages (the
Test Zone page, the L menu) dim the screen and are not counted.

### Reserved rects: the frame-rate readout and the minimap (owner 11-26)
- `SafeArea.reserved(sz)` is the one list of screen rects no popup, panel or toast may cover: the frame-rate readout
  (its live rect while it shows, else the room of its one line) and the minimap (at the HUD size setting's growth).
  `SafeArea.place(control, want, sz)` puts a popup at `want`, moved the shortest way off every reserved rect; the
  parity bench, the Arena key line, the Drills banner and the kit drill panel use it every frame
  while open, and the message lane slides its cards aside from the same list (`MsgLane.reserved`). A new popup calls
  `place`; it never carries an offset of its own against the readout or the map.
- `--test-zone-check` opens each station popup (bench, a toast, the Drills banner) with the frame-rate
  overlay on, in the Test Zone and the Training Grounds at 1920x1080 and 2560x1440, and asserts every popup keeps clear
  of `fps_counter` and `minimap` (`TestZoneShots.pairs`); `--test-zone-shots` prints the same pairs as `TZSHOT PAIR`.
- HUD lines that stay up hold their place in the same list (`SafeArea.hold(key, control)`): the Arena key line, the
  DPS meter and the kit drill panel, in that order. A held control keeps clear only of what was held before it (the kit
  drill panel sits under the key line), so two held lines never push each other in turn; every other popup and every
  toast keeps clear of all of them. The message lane places a card in one pass over every block (`MsgLane.spot`), so
  sliding off one never lands it on the next. `--test-zone-check` also asserts no HUD overlap at all with each station
  popup open, the Training Grounds' first-time kit drill up.
