# Owner review 01:39 ET 11-09: owner-approved art is final. Drop pending fix/redesign/stance jobs for approved sheets and pending
# portrait jobs for approved portraits (cards are still made). build_jobs.py removes DROP ids from the queue if not started.
import json as _jl, re as _rl
_L=_jl.load(open(HERE/'owner_locked.json'))
_ls=[n.split('_')[0].lower() for n in _L['sheet']]; _lp=[n.lower() for n in _L['portrait']]
DROP=set()
for _s in SPECS:
    _i=_s['id']
    if _rl.search(r'_card\d*$',_i) or _i.startswith('ta_'): continue
    _m=_rl.match(r'^(?:c_|stance2?_|portrait_stance2_)?([a-z]+)',_i.replace('portrait_stance2_','stance2_'))
    _b=_m.group(1) if _m else ''
    if _i.startswith('portrait_'):
        _pb=_rl.match(r'^portrait_(?:stance2_)?([a-z]+)',_i).group(1)
        if _pb in _lp and 'stance2' not in _i: DROP.add(_i)
        if 'stance2' in _i and _pb in _ls: DROP.add(_i)
        continue
    if _b in _ls: DROP.add(_i)
# Intentionality audit 02:50 ET 11-09: these sheets were just redesigned/replaced (their stance-audit text describes the old
# design), Chandelotl waits on the Glassolotl variant pick, lodestick_r2 is an old-wave leftover.
DROP|={'portrait_stance3_'+n for n in ('arcestrel','briarlynx','galleotter','flarmink','chandelotl','glassolotl','prismander','zippelith')}
DROP|={'portrait_chandelotl_full','lodestick_r2'}
# 03:06 ET: new-species sheets get one card job (<n>_card) from the roster wave; skip the duplicate _card3 from wave50.
DROP|={n+'_card3' for n in 'bladypus bullsfrog clinkpede fawngus glaciammoth glazolm grainspin grammite hydrangor lensling loafhopper lurklet malletary maracoil morelkin nymphane puffuse reelacine sarcobra starcap sundormouse tootle torpecone'.split()}
# 03:20 ET: owner cut Puffamus (Teapotamus > Chuggamus). No more Puffamus jobs.
DROP|={s['id'] for s in SPECS if 'puffamus' in s['id']}
# 08:22Z: un-locking Reapant/Thistlynx/Thunderstrich for redesign re-admitted their old stance jobs; those designs are being replaced.
DROP|={p+n for n in ('thunderstrich','reapant','thistlynx') for p in ('stance_','portrait_stance3_','portrait_stance2_')}
# 03:32 ET: owner cut the starters' branch finals: Lashyx and Amanitusk removed. Old Glaivyx/Ringrove fix jobs replaced by wave62.
DROP|={s['id'] for s in SPECS if any(k in s['id'] for k in ('lashyx','amanitusk'))}
DROP|={s['id'] for s in SPECS if any(k in s['id'] for k in ('glaivyx','ringrove')) and not s['id'].startswith(('c_glaivyx_g','c_ringrove_r','c_glaivyx_h','c_glaivyx_o','c_ringrove_y')) and not s['id'].endswith(('_p79','_card9','_p86','_card86','_r86','_p88','_card88','_r88','_gap','_p93','_card93','_r93','_p95','_card95','_r95','_p96','_card96','_p99','_card99','_card100','_pz','_cardz','_rz','_py','_cardy','_ry','_px','_cardx','_rx','_cardw','_pb','_cardb','_pc','_cardc'))}
# 04:22 ET: Boki whose design came from an owner-reviewed pick already get their own card/portrait/sheet from the pick waves;
# don't let the generic roster waves add duplicate cards or old-audit stance jobs for them.
_PICKED={'glaciatee','bucketmander','barrelmander','gravitank','mortarfly','orbitle','glaivyx','ringrove','terrasloth','lunowl','thunderstrich','reapant','barokat','chandelotl','lanceron','pyrraven','eclipsowl','effigoon','chandelapi','canvastross','glintmole','gloamspire','glomworth','gongibbon','knotling','lanternlong','lyrewing','mossbastion','parasolth','pipeworth','ribbonwyrm','rimekit','rimeshrew','rimefang','selenwhale','tidalisk','umbrathere','nettlynx','sporcupine','teapotamus','umbrink','vespox','anchorbill','zippelith','glassolotl','prismander','anchorhorn','bastionpet','briarlynx','cisternmander','crofthollow','thistlynx','lodestick','moatpole','moundlet','murmuron','spanglin','vaultara','dreadnoyak','voltalon','geysirbara','chuggamus','seamwyrm','forgebrock','furnacowary','gongrowl','galleotter','chandelapi','reapant','glassolotl','vespox','flarmink','rimink','rippmink','prismink','cisternmander','effigoon','lanternmit','stormit','terrarimit','sporcupine','geodemole','skateron','dragonkite','lodestaff'}
DROP|={s['id'] for s in SPECS if (s['id'] in {n+'_card' for n in _PICKED}|{n+'_card3' for n in _PICKED}) or any(s['id'] in (p+n,) for n in _PICKED for p in ('stance_','portrait_stance3_','portrait_stance2_'))}
# 06:25 ET: stance jobs for Boki under redesign are pointless (the design is changing). Drop them all.
_REDES=('vaultara','dreadnoyak','voltalon','geysirbara','chuggamus','seamwyrm','forgebrock','furnacowary','lanternmit','stormit','terrarimit','sporcupine','geodemole','skateron','dragonkite','gongrowl','galleotter','chandelapi','reapant')
DROP|={s['id'] for s in SPECS if 'stance' in s['id'] and any(n in s['id'] for n in _REDES)}
# 12:41 ET 11-09: owner-picked new designs (OWNER REVIEW batch 1): no auto hero-card or stance re-poses over the picked cards.
_PICKED_B1=('coolatee','druzemole','scythant','jibbatross')
DROP|={s['id'] for s in SPECS if s['id'] in ({n+'_card' for n in _PICKED_B1}|{n+'_card3' for n in _PICKED_B1}|{p+n for n in _PICKED_B1 for p in ('stance_','portrait_stance3_','portrait_stance2_')})}
# 15:13 ET 11-09: owner round-4 picks are live (sheet+card+portrait). No auto default cards, stance re-poses or auto-chained concepts
# over them; the next stages already have their own c_<name>_gp jobs.
_PICKED_R4=('arcestrel','soakybara','geysirbara','lockatara','glazolm','slog','crofthorn','anchorhorn','spanglin','tinbrock','shinobant','reapant','harvantis','lurklet','bulwartoad','barostorm','quivertoad','bonsolith','mumblet','chiptero','narfoil','pinster','pagodito','pavonazar','bullpole','pocketpus','scoopsy','gambitfin','hourachnid','rosedart','fanpire','chainipede','scarabit','meteorab')
DROP|={s['id'] for s in SPECS if s['id'] in ({n+'_card' for n in _PICKED_R4}|{n+'_card3' for n in _PICKED_R4}|{p+n for n in _PICKED_R4 for p in ('stance_','portrait_stance3_','portrait_stance2_')})}
DROP|={'c_checkmare','c_klaxada','c_pagoguana','c_pickadactyl','c_parrywhal','c_tiltster','c_critwom','c_sirencada'}
# 15:58 ET 11-09: round-5 picks live; same protection as round 4.
_PICKED_R5=('druzemole','pipwom','checkmare','pickadactyl','parrywhal','tiltster','pagoguana','cetorgan','ghoulamari','wayshell','siegephant','aurostag','cindermaw','sphinxblight','klaxada','glacione')
DROP|={s['id'] for s in SPECS if s['id'] in ({n+'_card' for n in _PICKED_R5}|{n+'_card3' for n in _PICKED_R5}|{p+n for n in _PICKED_R5 for p in ('stance_','portrait_stance3_','portrait_stance2_')})}
DROP|={'glacione_card','glacione_card3','klaxada_card','klaxada_card3'}

# 17:29 ET 11-09: the V2 pilot jobs for Glaivyx and Ringrove are wanted (owner approved the V2 pilot 17:23); keep them out of the old glaivyx/ringrove drop.
DROP-={'v2a_glaivyx','v2b_glaivyx','v2a_ringrove','v2b_ringrove'}
DROP-={'glaivyx_clean_card','glaivyx_clean_portrait','glaivyx_clean_v2pilot','glaivyx_clean_sheet'}  # owner 17:55: tone down the slime
DROP-={'fam_ringrove_a','fam_ringrove_b'}  # owner 17:57: Ringrove to match Mycroll
DROP-={'v2g_ringrove_tilt'}  # owner 19:53
DROP-={'v2g_glaivyx_white'}  # owner 19:53
DROP-={'v2a_'+_r[0].lower() for _r in _B1}  # V2 batch 1, owner gave full control 19:51
DROP-={'fem_arcestrel','fem_hourachnid','fem_pavonazar','fem_gongrowl','fem_furnacowary'}
DROP-={'v2g_ringrove_tilt2'}
DROP-={'v2x_'+_n.lower() for _n in _B1FIX}|{'v2s_'+_n.lower() for _n in _B1PICK}|{'v2p_'+_n.lower() for _n in _B1PICK}
DROP-={'v2t_barostorm','v2t_chimelop','v2t_maulangler','v2t_bastling','v2t_barrelmander','v2t_mycroll'}
DROP-={'rd_effigeetle_a','rd_effigeetle_b'}
DROP-={'pk_pinster','pk_bullpole'}
DROP-={'v2s_chimelop','v2p_chimelop'}
DROP-={'pk_bullpole_star','pk_bullpole_diamond','pk_bullpole_arrow','pk_bullpole_cross','pk_bullpole_chevron'}
DROP-={'rd_tiltster_a','rd_tiltster_b','rd_pinster_b'}
DROP-={'v2t_bullpole','v2t_pinster','v2t_tiltster'}
DROP-={'v2t_jerbit','v2t_jerbolt','v2t_dynaboa','v2s_pinster','v2p_pinster','v2s_tiltster','v2p_tiltster','v2x_bullpole'}
DROP|={'citadoad_card','critwom_card','sirencada_card'}  # auto jobs from promoting their V2 sets; cards are already V2
DROP-={'v2s_tiltster_pb','v2p_tiltster_pb'}
# 21:58 ET 11-09 (new art session): Chimelop promoted in V2; its auto jobs must not run.
DROP|={'chimelop_card','portrait_stance3_chimelop','stance_chimelop'}
DROP|={'jerbit_card','jerbolt_card','dynaboa_card','bastling_card'}  # new V2 Boki: no auto card jobs
DROP-={'v2k_glaivyx','v2k_ringrove'}  # 11-10: straight V2 cards for the last two starters-line finals
DROP|={'fem_eclipsowl','fem_gongibbon','fem_kestrike','fem_lunowl','fem_murmurling','fem_murmuron','fem_sandwidow','fem_voltalon'}  # 11-10: duplicate ids of the fv2_ female jobs
DROP-={'v2s_glaivyx_last','v2p_glaivyx_last','v2s_ringrove_last','v2p_ringrove_last'}
DROP|={'fs_furnacowary','fp_furnacowary','fv2_furnacowary','fem_furnacowary'}  # owner 11-10: Furnacowary has no female form
DROP-={'v2s_glaivyx_k','v2p_glaivyx_k','v2s_ringrove_k','v2p_ringrove_k'}
DROP-={'opt_ringrove_a','opt_ringrove_b','opt_ringrove_c'}
DROP-={'v2s_ringrove_p2','v2p_ringrove_p2'}
DROP|={'fs2_lunowl','fp2_lunowl'}
DROP-={'opt_ringrove_u1','opt_ringrove_u2','opt_ringrove_u3','v2s_ringrove_p2','v2p_ringrove_p2'}
