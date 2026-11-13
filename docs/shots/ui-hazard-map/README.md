# Hazards on the minimap and full map (ext/ui-hazard-map)

1280x720, `--hazard-map-shots` (tools/hazard_map_shots.gd), Hollow Crown, seed 5, carried Boki Cindowary (Ember: counters lava).
Rendered on rpc7 under xvfb with the opengl3 (Compatibility) renderer, because the GPU queue was 100+ jobs deep.

- `after/`: branch head 6ac80778e (with the dark casing).
- `before/`: the same tree with the HazardMap draw/key calls removed from hud.gd and full_map.gd (the game without the map layer).
- `mm_hold.jpg`: the minimap with Tab held, 2x crop. After: the Cinder Steps lava area is tinted and has a shield, because Cindowary walks lava.
- `full_map.jpg`: every hazard area is tinted by kind, and the key strip along the bottom is from before the main merge: the kinds now sit as rows in the full map's corner key (MapKey).
- `full_zoom.jpg`: zoomed in on the two Cinder Steps lava fields.
- `compare_north.jpg`: full map, Frostgate / Stormbreak area, before (left) and after (right). It shows the ice sheet and static flats outlines.
