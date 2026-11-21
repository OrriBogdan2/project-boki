# USAGE-REDESIGN (11-21)
/usage now redirects to /admin/#usage, so this redesigns `VIEWS.usage` in the admin page (site-repo `admin/index.html`).
- Summary strip: N on track / to watch / need action, jobs running, done in 24h.
- One card per account, worst first: verdict chip (On track / Under-used / Wasting / Runs out early / Used up / No data),
  big % used, one plain sentence why, then Resets in (2d 4h + ET time), Should be at, Ends near, Burn, Running, Last 24h.
- No emails: lane text is scrubbed, acct() drops anything after '@', chart legend too. Rendered DOM: 6 emails before, 0 after (mock).
Apply on hetzner: `python3 apply.py ~/site-repo/admin/index.html ~/site-repo/admin/index.html` then `site-push "admin: usage redesign"`.
Test: `python3 mock_api.py 8791`, open `http://127.0.0.1:8791/after_admin_index.html?api=http://127.0.0.1:8791/api&token=t#usage`.
Shots in shots/ (mock data, placeholder accounts). before_admin_index.html = live admin page fetched 11-21 07:30 ET-5.
