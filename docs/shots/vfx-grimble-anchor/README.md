# Anchor Drop (Grimble E): before | after

`--hero-vfx-reel --reel-hero=dredge --reel-only=e` at the match camera, Forward+ (rpc6 RTX 4090, xvfb, opengl3
driver flag), nine frames from the press to the end of the stun. The arena is the reel's own; the same seed gives the
same layout both sides.

- `before_e.jpg`: origin/main 88b06b9e7. A teal cone fills in front of him for everyone; a brass orb on his hand.
- `after_e.jpg`: ext/vfx-grimble-anchor. Only a thin outline of the exact hit cone (`e.radius`, `e.angle` from
  content/archetypes/dredge.json, the values the slam uses), and a giant translucent cel-shaded brass fist (HeroVfx
  `fist` layer, content/vfx/dredge.json `anchor_fist`) falling straight down into it over the 0.38 s wind-up,
  landing on the slam frame. A stun in the wind-up takes the fist away. Timing and stun are unchanged.
