# dash_interactions refresh: JSON rows for a follow-up (job 20261109-100411-a1, no JSON changed)

- ashwick.json dash.ground.e is `buffer`, but `--dash-flow-check` (main d255acbee, reproducible, `=ashwick`) fails "ground dash -> e, pressed on its last step: fire (row: buffer)". Its own source says E goes the step the ram stops on the foe, i.e. closer to fire. Either the row should say fire or the kit should hold the press to the dash's end.
- archer.json (Lace): ext/lace-dash-charges (2 charges, 7b83eae87) is not on main, so no row or doc text mentions it; recheck dash.* rows when it merges.
- 55 rows are `[?]` (list in docs/KIT_PARITY.md item 20); no JSON row looked wrong beyond the one above.
