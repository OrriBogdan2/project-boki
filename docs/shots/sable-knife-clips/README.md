# Sable: Shadow Knife throw and recast (ext/sable-knife-clips)

`--clip-shots --warden=thief --clips=knife,arrive --fps=15` (frame N = N/15 s).

- `knife`: wind-up spin f000-f001, arm out at f002 (0.133 s). The kit releases at 0.12 s (`ThiefKit.KNIFE_RELEASE_S`),
  the key pose. Footage: the spin and flash at 0222, the dagger already flying at 0223 (5 fps).
- `arrive`: f000 is the clip's first key (STAR, her body stretched out of the blink, every channel keyed). By f001
  (0.06 s) she has dropped low with a hand down, then rises to f010 (0.6 s). Footage: the blink is 1 frame (0237 -> 0238).

`xvfb_*` are local opengl3 previews; `gpu_*` (when present) come from the jobq GPU run.

GPU run: jobq 20261112-151456-32597 (rp1-3, rc 0). `gpu_arrive_strip.jpg` matches the xvfb one. In `gpu_knife_strip.jpg`
the title's fade-in covers f000-f003 (the known first-frames fade of `--clip-shots`), so the release pose is only
visible in `xvfb_knife_strip.png`; f004-f008 (the follow-through) match.
