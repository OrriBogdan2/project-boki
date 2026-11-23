## Match start: nothing loops over the ship

The skyship sails over the void for the whole intro, plan and ride, so MusicDir's edge-of-the-world rule (`abyss`
layer = 1 over the void) kept the 26 s `amb_abyss` howl at full level through all of it: a loop heard for about 40 s
before anyone landed. `MusicDir._ambience` now keeps the abyss layer silent while the player is `riding` (ship or
squad rocket; the rocket has its own thrust loop). `--intro-deck-check` asserts that over the intro and the sail no
held loop is audible (volume over `QUIET_DB`) and the abyss layer stays quiet. The weather beds (gust, rain) still play.
