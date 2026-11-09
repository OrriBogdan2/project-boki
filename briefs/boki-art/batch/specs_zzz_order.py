# Owner 23:37 ET: new species first. Order = concepts/turnarounds of new species, then evolution and other sheets, then
# Pokedex portrait touch-ups last (relics stay after everything via build_jobs). Runs after every other specs file.
_ids=[s['id'] for s in SPECS]
_seen=list(dict.fromkeys(PRIORITY+_ids))
_new=[i for i in _seen if i.startswith(('c_','ta_'))]
_port=[i for i in _seen if (i.startswith('portrait_') or i.endswith('_card') or '_card_' in i) and not i.endswith('_card3')]
_rest=[i for i in _seen if i not in _new and i not in _port]
PRIORITY=_new+_rest+_port
