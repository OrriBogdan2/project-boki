import json,re
tips={t['br']:t for t in json.load(open('/tmp/ma/tips.json'))}; A=json.load(open('/tmp/ma/anc.json'))
L={r['br']:r for r in json.load(open('/tmp/ma/lines2.json'))}; RS=json.load(open('/tmp/ma/resid.json'))
scope=[l.split()[0] for l in open('/tmp/ma/scope.txt')]
ready={}
for l in open('/tmp/ma/e2m.md'):
    m=re.search(r'READY (ext/[^\s]+) ([0-9a-f]{7,40}) ?\(?(.*)',l)
    if m: ready[m.group(1)]=(m.group(2),m.group(3))
WHY={
'ext/combat-fusion-band':'all its unmerged lines are in ext/feel-landing-recovery (B06), which merged it',
'ext/combat-glove-band':'all its unmerged lines are in ext/wisp-guardian-rebased-rebased (rides with B08)',
'ext/combat-perk-orbs-rebased':'all its unmerged lines are in ext/feel-landing-recovery (B06)',
'ext/flow-rows-source':'all its unmerged lines are in ext/w0246-misc (rides with B06/B11)',
'ext/heal-knock-source-rebased':'all its unmerged lines are in ext/w0246-misc (rides with B06/B11); also docs/checks only, last work 11-08 (c)',
'ext/input-latency-check':'all its unmerged lines are in ext/w0246-feel (rides with B06/B11)',
'ext/kit-parity-refresh-1':'all its unmerged lines are in ext/feel-landing-recovery (B06)',
'ext/perf-visibility-ranges-rebased':'all its unmerged lines are in ext/wisp-guardian-rebased-rebased (rides with B08)',
'ext/sfx-garden-games-rebased':'all its unmerged lines are in ext/garden-snacks-all-types-rebased (B21)',
'ext/sfx-knock-confirm':'all its unmerged lines are in ext/vfx-meeko-weight-rebased-rebased (B11)',
'ext/sfx-loot-open':'all its unmerged lines are in ext/w0246-garden (rides with B08/B21)',
'ext/sfx-status-cues':'all its unmerged lines are in ext/w0246-audio-vfx (rides with B11/B13), which merged it',
'ext/step-smooth-rebased':'all its unmerged lines are in ext/w0246-misc (rides with B06/B11)',
'ext/tut-first-race-garden':'all its unmerged lines are in ext/tut-first-race-rebased (B20)',
'ext/ui-buff-stack':'all its unmerged lines are in ext/ui-interact-port (rides with B21), which merged it',
'ext/ui-fusion-hud':'all its unmerged lines are in ext/ui-interact-port (rides with B21)',
'ext/vfx-capture-read':'all its unmerged lines are in ext/wisp-guardian-rebased-rebased (rides with B08)',
'ext/zone1-batch1':'integ tip; all its unmerged lines are in ext/w0246-misc (rides with B06/B11), which merged it',
'ext/combat-boss-parity':'in ext/vfx-motley-port (B11) except its net VERSION bump (0.24.5; main and B11 carry newer)',
'ext/combat-lair-prize':'in ext/vfx-motley-port (B11) except its net VERSION bump',
'ext/net-rejoin':'in ext/w0246-misc (rides with B06/B11) except its net VERSION bump',
'ext/rocket-drop-1111':'in ext/anim-stomp-per-hunter (B09) except its net VERSION bump',
'ext/perf-mob-cap':'in ext/vfx-motley-port (B11) except one perf_bench config line',
'ext/stomp-lock-1111':'in ext/anim-stomp-starters (B10) except one DEATH_AND_REVIVE.md doc line',
'ext/stuck-integ-fb4b4275':'integ tip; in ext/anim-react-settle-neve-tenzo (B10) except one docstring line in tools/art1/glb_react.py',
'ext/tut-first-echo':'in ext/w0246-tutorial (rides with B06) except one test-setup line in garden_sfx_check.gd',
'ext/ui-steal-callout':'in ext/early-steal-window (B21) except one HUD.md doc row',
'ext/vfx-dot-body':'in ext/vfx-telegraph-timing-rebased (B11) except one comment line in ent.gd',
'ext/revive-source-numbers':'in ext/anim-swim-reds (B08) except dropping one unused local in box_revive.gd',
'ext/combat-meeko-carry-drop':'in ext/feel-landing-recovery (B06) except 3 doc-table rows it rewrote',
'ext/meeko-rmb-motion-rebased-rebased':'READY successor ext/meeko-rmb-motion-rebased-rebased-rebased says "supersedes" it; that one rides with a top-10 tip',
'ext/tut-first-heartspark':'READY successor ext/tut-first-heartspark-rebased (B20) says "supersedes" it',
'ext/vfx-albert-gap8':'READY successor ext/vfx-albert-slab (B11) says "Supersedes ext/vfx-albert-gap8" (owner-sheet arc, not its dome)',
'ext/garden-trait-drift':'on main (base_drift.gd and its check), main reworded it since; 7 lines differ, all rework',
'ext/garden-lantern-match':'on main and grown since (main has 29 items, 8 prize games incl. lantern; branch says 27/7)',
'ext/tutorial-idle-check':'main has its own stall nag (NAG_T) and KEY_WAIT_T anti-strand; branch is the older take on the same steps',
'ext/neve-skirt-chiffon':'main has newer Claire v95 art at both art paths; one src json line differs',
'ext/vfx-albert-smash':'the feature (HeroVfx spin ring) is on main; only a before/after screenshot is not',
'ext/farm-arrival-rank-0245':'on main except one line in tools/raising_check.gd',
'ext/agent-briefs-rebased':'briefs-only (TOWN_HUB.md doc); that doc is now on ext/agent-briefs',
}
REASON={'a0':'a','at':'a','ar':'a','b':'b'}
plan=[l.split() for l in open('/tmp/ma/tagplan.txt')]
arch={p[1]:p for p in plan}
# exclude + log
open('/tmp/ma/out/merge-exclude-add-archive-1113.txt','w').write(''.join(p[1]+'\n' for p in plan))
with open('/tmp/ma/out/merge-archive-1113.log','w') as f:
    for r,b,h,tag,st in plan:
        f.write("ARCHIVED %s %s class=%s READY=%s tag=%s (%s) | %s | restore: git push origin '%s^{commit}:refs/heads/%s' (branch was not deleted; restore = remove the line from merge-exclude.txt; the push is only needed if the branch was deleted later)\n"%(b,h,REASON[r],ready.get(b,('?',''))[0],tag,'existed' if st=='exists' else 'new',WHY[b],tag,b))
# keep list
NOTMAIN={'ext/infra-usage-plan':'standalone history (usage pacer), not a main merge','ext/infra-usage-remote-source':'standalone history (usage-track helper), not a main merge','ext/rename-guin-1112':'briefs-only rename rows on the agent-briefs line, not a main merge'}
FLAG={'ext/scrapking-lmb-1111':'owner 11-11 top-priority successor of ext/scrapking-lmb, which rides with a top-10 tip: the top-10 job should take -1111, not the old PR #19 head',
'ext/first-hints-check-rebased':'newer than ext/first-hints-check, which rides with a top-10 tip; merge after it',
'ext/vfx-vex-tracer':'same VFX_QUALITY item 3 as ext/vfx-vex-tracer-0246 (B11); not a newer copy (106 own lines), owner look call, likely drop after -0246 lands',
'ext/vfx-vex-tracer-strips':'same item as ext/vfx-vex-tracer-0246 (B11); 106 own lines; likely drop after -0246 lands',
'ext/vfx-vex-tracer-data':'data-driven take on the same Vex tracer item as ext/vfx-vex-tracer-0246 (B11); newer, 350 own lines'}
rows=[]
for b in scope:
    if b in arch: continue
    r=L[b]; rs=RS.get(b) or {}; best=rs.get('best') if rs else None
    miss=r.get('miss',0)
    kind=[]
    if r['art_new']+r['art_pend']: kind.append('art not in game (%d files)'%(r['art_new']+r['art_pend']))
    code=[p for p in r['paths'] if re.match(r'(scripts|content|shaders|scenes|art)/',p)]
    kind.append('player-facing code/data (%d files)'%len(code) if code else 'checks/docs only')
    txt=ready.get(b,('',''))[1]
    if re.search(r'\b(fix|bug|crash|broken|stuck)\b',txt,re.I): kind.append('fix')
    if re.search(r'owner',txt,re.I): kind.append('owner')
    near=''
    if best and best[0]<=30 and rs['n']>=20: near='; near-dupe of %s (%d own lines)'%(best[1],best[0])
    t=tips.get(b)
    note=NOTMAIN.get(b) or FLAG.get(b) or ''
    rows.append(dict(b=b,tip=bool(t),B=t['b'] if t else None,I=t['I'] if t else None,H=t['H'] if t else None,miss=miss,kind=', '.join(kind)+near,note=note,carriers=[x for x in A['carriedby'].get(b,[])],what=txt[:90]))
json.dump(rows,open('/tmp/ma/keep.json','w'))
print(len(plan),len(rows),sum(r['tip'] for r in rows))
