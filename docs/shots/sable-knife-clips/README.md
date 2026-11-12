# Sable: Shadow Knife throw and recast (ext/sable-knife-clips)

`--clip-shots --warden=thief --clips=knife,arrive --fps=15` (frame N = N/15 s).

- `knife`: wind-up spin f000-f001, arm out at f002 (0.133 s). The kit releases at 0.12 s (`ThiefKit.KNIFE_RELEASE_S`),
  the key pose. Footage: the spin and flash at 0222, the dagger already flying at 0223 (5 fps).
- `arrive`: f000 is the clip's first key (STAR, her body stretched out of the blink, every channel keyed). By f001
  (0.06 s) she has dropped low with a hand down, then rises to f010 (0.6 s). Footage: the blink is 1 frame (0237 -> 0238).

`xvfb_*` are local opengl3 previews; `gpu_*` (when present) come from the jobq GPU run.
