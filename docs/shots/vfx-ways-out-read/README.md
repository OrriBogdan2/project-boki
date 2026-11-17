# Ways Out read from afar (ext/vfx-ways-out-read)

`--ways-out-vfx-shots --quality=low|high`: rows in match order (Sealed Lair raced by a rival and won; the Heart
locked, unlocked, early seat used; the Uplink open, raced, won; the Blight's wall), columns 8 / 20 / 40 / 60 m at
the match camera with two rivals fighting beside the player. Each frame is captioned.

- `before_low.jpg`: the 0.24.5 line as merged (an earlier row order: the Heart rows first). At 20-60 m nothing in the play view says where a quest seat is or
  what state it is in; the charging Heart's pink waypoint is the only far marker, the used Gate and the Blight's wall
  have none (the camera frames about 15 m round the player, so no beam or wall that far is ever in frame).
- `sheet_low.jpg`, `sheet_high.jpg`: with WaysOutPins. Each seat still to be had gets a pin on the edge toward it
  (the map badge: locked ring with its countdown arc, open bright ring and beam, in use in the squad's colour with
  its beam), its word and the distance; the Blight's wall within 70 m a crimson bar; won seats stay taken.

`sheet_low.jpg` / `sheet_high.jpg`: GPU, 1280x720, jobq 20261111-225400-21031 (low, RTX 4090) and
20261111-225403-29587 (high, RTX 4070 SUPER). `before_low.jpg`: software GL (Xvfb) on w2, 1920x1080.
