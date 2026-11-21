// ---------- usage (USAGE-REDESIGN 11-21: plain numbers + good/watch/bad verdict per account; no emails)
const noEmail = s => String(s ?? '').replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, ' ').replace(/\(\s*\)|\[\s*\]/g, ' ').replace(/([·,|:])\s*(?=[·,|:])/g, '').replace(/^[\s·,|:-]+|[\s·,|:-]+$/g, '').replace(/\s{2,}/g, ' ');
const uLeft = e => { if (!e) return null; const m = Math.max(0, Math.floor((e - now())/60)); const D = Math.floor(m/1440), H = Math.floor(m%1440/60), M = m%60;
  return D ? `${D}d ${H}h` : H ? `${H}h ${M}m` : `${M}m`; };
const U_TARGET = 90;   // the pacer's hold line: aim to end each week near here
function uVerdict(a){
  const h = a.resets_at ? Math.max(0, (a.resets_at - now())/3600) : null, b = a.ballistic, r = b && b.rate_h != null ? Math.max(0, b.rate_h) : null;
  const end = a.pct == null ? null : h == null || r == null ? null : Math.min(100, Math.round(a.pct + r*h));
  const v = (lv, word, why) => ({lv, word, why, end, h});
  if (a.pct == null) return v('none', 'No data', 'The meter could not be read. Numbers below may be old.');
  if (a.pct >= 95) return v('bad', 'Used up', `${pct(a.pct)} used. Jobs on this account wait for the reset.`);
  if (b && b.to90_h != null && h != null && b.to90_h < h - 1) return v('bad', 'Runs out early', `Hits ${U_TARGET}% in ${Math.round(b.to90_h)}h, but the reset is ${Math.round(h)}h away.`);
  if (end != null) { const waste = U_TARGET - end;
    if (waste >= 25 && h < 48) return v('bad', 'Wasting', `Will end near ${end}%: about ${waste}% of this week goes unused.`);
    if (waste >= 10) return v('warn', 'Under-used', `Will end near ${end}%. Room for about ${waste}% more work before the reset.`);
    return v('good', 'On track', `Will end near ${end}% (target ${U_TARGET}%).`); }
  if (a.pace_gap != null && a.pace_gap < -15) return v('warn', 'Behind', `${Math.round(-a.pace_gap)} points under where it should be by now.`);
  if (a.pace_gap != null && a.pace_gap > 15) return v('warn', 'Running hot', `${Math.round(a.pace_gap)} points over where it should be by now.`);
  return v('good', 'On track', 'Use is close to where it should be by now.');
}
const U_COL = {good:'var(--good)', warn:'var(--warn)', bad:'var(--crit)', none:'var(--muted)'}, U_RANK = {bad:0, warn:1, none:2, good:3};
VIEWS.usage = (u, el) => {
  const accs = (u.accounts || []).map(a => ({a, v: uVerdict(a)})).sort((x, y) => U_RANK[x.v.lv] - U_RANK[y.v.lv] || (x.v.h ?? 1e9) - (y.v.h ?? 1e9));
  const n = k => accs.filter(x => x.v.lv === k).length, running = accs.reduce((s, x) => s + (x.a.running || 0), 0);
  const tot = accs.reduce((s, x) => { const d = x.a.done_24h || {}; for (const k in d) s[k] = (s[k] || 0) + d[k]; return s; }, {});
  const sum = (lv, k, word) => `<div class="usum-i"><b class="num" style="color:${n(k) ? U_COL[lv] : 'var(--muted)'}">${n(k)}</b><span>${word}</span></div>`;
  el.innerHTML = `<div class="card usum">${sum('good','good','on track')}${sum('warn','warn','to watch')}${sum('bad','bad','need action')}
      <div class="usum-i"><b class="num">${running}</b><span>jobs running</span></div><div class="usum-i"><b class="num">${tot.done || 0}</b><span>done in 24h${tot.failed ? ` · <em style="color:var(--crit)">${tot.failed} failed</em>` : ''}</span></div>
      <div class="usum-t small muted">Updated ${esc(ago(u.snapshot_at))}${u.pacer_last_t ? ` · pacer ran ${esc(tEST(u.pacer_last_t))}` : ''}</div></div>
    <div class="ugrid" id="accs"></div>
    ${sectionH('Weekly use, last 7 days', `line at ${U_TARGET}% = target`)}<div class="card"><div class="chart" id="uc"></div></div>
    <div class="grid cols2" style="margin-top:14px"><div class="card"><h3>Jobs per day (ET)</h3><div class="chart" id="pd"></div></div><div class="card"><h3>Jobs per hour of day (ET)</h3><div class="chart" id="ph"></div></div></div>`;
  $('#accs', el).innerHTML = accs.map(({a, v}) => { const b = a.ballistic, d = a.done_24h || {}, c = U_COL[v.lv], lane = noEmail(a.lane);
    const jobs = ['done','partial','failed','skipped','blocked'].filter(k => d[k]).map(k => `<span class="uj-${k}">${d[k]} ${k}</span>`).join(' · ') || 'none';
    const ahead = a.pct != null && a.pace_pct != null ? Math.round(a.pct - a.pace_pct) : null;
    return `<div class="card ucard2" style="border-left:5px solid ${c}">
      <div class="uhead">${acct(a.label)}${a.coord ? '<span class="ucoord small">coord</span>' : ''}<span class="uverd" style="background:${c}">${esc(v.word)}</span></div>
      ${lane ? `<div class="small muted ulane">${esc(lane)}</div>` : ''}
      <div class="ubig"><b class="num">${pct(a.pct)}</b><span>used this week</span></div>${meter(a.pct, c)}
      <p class="uwhy">${esc(v.why)}</p>
      <dl class="ukv2">
        <dt>Resets in</dt><dd><b class="num" data-ureset="${a.resets_at || ''}">${uLeft(a.resets_at) || 'unknown'}</b>${a.resets_at ? ` <span class="muted">${esc(tEST(a.resets_at))}</span>` : ''}</dd>
        <dt>Should be at</dt><dd><span class="num">${pct(a.pace_pct)}</span>${ahead != null ? ` <span class="muted">(${ahead === 0 ? 'exactly on pace' : Math.abs(ahead) + (ahead > 0 ? ' ahead' : ' behind')})</span>` : ''}</dd>
        ${v.end != null ? `<dt>Ends near</dt><dd class="num">${v.end}%</dd>` : ''}
        ${b ? `<dt>Burn</dt><dd class="num">${b.rate_h >= 0 ? '+' : ''}${b.rate_h}% per hour${b.flag ? ' ' + badge('warning', b.flag) : ''}</dd>` : ''}
        <dt>Running</dt><dd class="num">${a.running ?? 0} job${a.running === 1 ? '' : 's'}</dd>
        <dt>Last 24h</dt><dd>${jobs}${a.spent_24h != null ? ` <span class="muted">(${a.spent_24h}% used)</span>` : ''}</dd>
        ${a.fable_pct != null ? `<dt>Fable</dt><dd class="num">${pct(a.fable_pct)}</dd>` : ''}</dl></div>`; }).join('') || '<div class="card muted">No accounts in the snapshot.</div>';
  if (!window._uTick) window._uTick = setInterval(() => document.querySelectorAll('[data-ureset]').forEach(x => { if (x.dataset.ureset) x.textContent = uLeft(+x.dataset.ureset); }), 30000);
  lineChart($('#uc', el), u.series.map(s => ({label:s.label==='corybogdan'?'Cory':noEmail(String(s.label).replace(/@.*/,'')), color:ACC[s.label]||ACC.acct, pts:s.pts, resets:s.resets})), {x0:u.x0, x1:u.x1, yMax:100, hold:U_TARGET, h:200});
  const keys = [{k:'done',label:'done',color:'var(--good)'},{k:'partial',label:'partial',color:'var(--c-yellow)'},{k:'skipped',label:'skipped',color:'var(--muted)'},{k:'failed',label:'failed',color:'var(--crit)'},{k:'blocked',label:'blocked',color:'var(--serious)'}];
  stackedBars($('#pd', el), u.jobs_per_day.map(d => ({label: d.day.slice(5), title: d.day, parts: d})), keys, {h:160});
  stackedBars($('#ph', el), u.jobs_per_hour.map((h,i) => ({label: i%3?'':String(i), title: `${i}:00 ET`, parts: h})), keys, {h:160});
};
