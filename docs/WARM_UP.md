# Match warm-up (scripts/match/warm_up.gd)

The loading screen's last step (`Match.warm_up`) draws what the match will draw so shaders compile before
play. Measure it with `jobq submit --needs gpu --only rp2g-1 --tree <tree> -- --hitch-check --load-check`
(the `build.warm_up` step and the `warm-up ms:` note). Drop `--load-check` to also judge the ride, drop and
landing.

## Where the time goes (rp2g, RTX 4090, Forward+, cold shader cache, 11-23)
- On Forward+ and Mobile a new shader compiles on the first frame that draws 3D after its material exists,
  whether or not anything shows it. Hiding a stand-in, waiting with 3D off or turning off shadows, sky,
  SSAO, glow and fog did not move that cost.
- The first two 3D frames take about 1 s even with no stand-ins. That is the match's own world materials,
  which play needs anyway.
- The stand-in batches cost 0.6-0.9 s, the three views about 0.6 s (half of it the first frame drawing the
  whole map), and the late pass about 0.2 s.

## What changed (ext/warm-up-cut)
- Forward+ and Mobile draw one light setup per batch, one frame each. A batch's second frame added no
  pipeline compiles. Compatibility still draws 4 light setups x 2 frames.
- The stand-in holder stays, hidden and still, instead of being freed. Freeing it cost the next frame
  0.5-0.7 s, and the shaders stay built for later.
- When the match opens with a planning phase (DropSquad) on Forward+ or Mobile, these stand-ins are built
  during planning, 2 a frame: the mob models not yet in the match, the kit effect quads, and every
  `res://shaders` file. Nothing can land, fight or cast before planning ends. Under the loading screen
  they had cost two frames of 0.5-1 s.
- Result: `build.warm_up` went from 3.73-3.77 s to 2.66-2.73 s, and LOAD total from about 24.9-25.1 s to
  about 23.9 s.
- Full `--hitch-check`: ride, drop and landing still have 0 shader compiles, and the landing stall stayed
  at 82-83 ms. The planning phase now takes 18 compiles (worst frame 83 ms) and the first frames take 6
  (worst 104 ms). The start-of-match stall went from 156 to 104 ms.

## Not done
- warm_up is still above 2 s. The rest is the world's own first compile. Godot 4.5+'s export shader baker
  (`shader_baker/enabled` in an export preset) is the lever for shipped builds. It is untested here, and
  a source run cannot measure it.
