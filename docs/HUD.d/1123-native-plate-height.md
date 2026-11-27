## Plates over Meshy-native heads (--warden-native-check)

The plate hangs from `HudPlate.plate_offset(h)` (metres over the feet, the archetype's `plate_offset`), not from the
`anchor_head_top` empty, so a Meshy head, hair or hat that is taller or shorter than the contract model's needs its own
number in `content/archetypes/<id>.json`. The plate's bars hang about 17 px under its anchor (0.52 m of height at the
match camera), so the anchor sits 0.60 m over the highest drawn part of the model in its tallest state: the check
poses each native Hunter at idle, run, crouch and glide (the glider's bank), reads the skinned vertices (`PlateGap`)
over a cycle, and fails a gap under 0.55 m (bars on the face) or over 0.85 m outside the glide (a floating plate).
When a model's head, hair or hat changes, re-run the check, read its `PLATEGAP` lines and set `plate_offset` to the
tallest top plus 0.60.
