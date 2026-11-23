# Motley v95 r3 A in game (11-17)
`motley_r3A_ingame.jpg`: A = LIVE in game (grey), B = NOW in game (red: no visible gain), master r3 A in Cycles for reference.
Rows: front, 3/4, back, face. Real GPU (`--warden-shots`, RTX 4090, jobq 20261117-163303-23990 / 20261117-165901-12624).
The game glb's `v95` image now carries r3 A's tail paint (2.4% of texels, tail only); mesh, weights, clips and face are
byte-identical to live (glb_image_swap.py). In game the tail was already dark indigo with no pale smear (toon light),
so LIVE and NOW differ by 0.33/255 mean on the turnaround. Stretch: unchanged (same mesh and weights; live worst 7.93).
