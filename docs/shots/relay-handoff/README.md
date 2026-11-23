# Relay Cup hand-off (ext/anim-relay-handoff)

`--gameplay-media --media-clip=8 --media-secs=24 --media-size=1280x720` (opengl3, the driver the media child always
uses), frames cut from clip8.avi and cropped 2x on the relay stand.

- `relay_strip.jpg` top row: 5.2-6.0 s the arriving runner reaches the next and both play the 0.3 s contact react
  (bump / brace), 6.4 s the next runner launches on the burst (run clip at 1.6x for 0.4 s).
  Bottom row: 20.2-20.6 s the last legs, 22.2-22.8 s both teams home, the finish beat (cheer / sulk, or the
  head drop where a species has no sulk clip) holds 2 s before the result card.
- `handoff_wide.jpg`: the full frame at 6.0 s.

Rendered on rpc4 on the CPU (llvmpipe) with the same Godot driver as the GPU queue; GPU job 20261112-043019-29329
renders the same clip.
