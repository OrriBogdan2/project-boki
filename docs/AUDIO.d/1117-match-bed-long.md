## Match start: the wind bed is a long, even loop

`amb_match`, the bed heard from the first frame (the ship, then the ground), was a 13 s filtered-noise loop with a
sine swell every 3 to 5 s and a level jump where it wrapped: it read as a repeating whoosh over the whole ship ride.
`tools/gen_amb_match.py` now writes a 48 s loop (wind, a little air, a low engine-room rumble) built in the
frequency domain, so it closes on itself with no crossfade seam and its level wanders on a 6 to 20 s scale instead of
beating. It sits 6.1 dB lower (RMS -19.2 to -25.3 dBFS) and the envelope's strongest repeat between 3 and 20 s fell
from 0.41 to 0.16 (the swing from 11.6 to 3.3 dB). `--ship-sound-check` logs every audio start over the first 30 s of a
match (none but a held loop or a bed starts twice within 4 s) and wants the main bed at least 30 s long.
