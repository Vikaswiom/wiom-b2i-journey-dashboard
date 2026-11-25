# CSP Booking-to-Install Journey — refresh pipeline

**Live page (refreshed and published by GitHub Actions every 3 hours, started by the Ship Tracker's schedule; a run is skipped while `check_fresh.py` says yesterday has not fully synced):** https://vikaswiom.github.io/wiom-b2i-journey-dashboard/

- `.github/workflows/refresh.yml` runs `refresh_all.py` with the `METABASE_API_KEY` repo secret, then `build_site.py`, and publishes `docs/` straight to GitHub Pages. Nothing is committed, so `docs/index.html` and the 4 refreshed JSON files are not in the repo (only the static October snapshot is). Run it any time from the Actions tab (Run workflow).
- `index.html` is the one source page. `build_site.py` wraps it with `site_shim.js` (a small stand-in for the claude.ai dashboard runtime) into `docs/index.html`.
- The claude.ai copy below is the older home of the page and is only refreshed when Claude republishes it.

Dashboard: https://claude.ai/artifact/WUWh5LShPxE5zb36fcvZmW (Data artifact; page = store doc `files/index.html`, numbers = 4 JSON assets).

## Daily refresh (run by Claude, ~09:15 IST, session cron job 97efb8ea, expires after 7 days)
1. `python3 refresh_all.py > refresh.log 2>&1` — runs every Metabase query (Keychain key `wiom-metabase-api-key`) and writes the 4 JSON files. Last line of the log is a JSON summary; a `FAILED` line means stop and report.
2. Upload each JSON as an asset to the artifact (Artifact tool, `asset: true`, one file per call): b2i_snapshot.json → overview, b2i_deep_snapshot.json → deep, b2i_yesterday_snapshot.json → yesterday, b2i_csp_snapshot.json → csp.
3. `python3 make_batch.py prepare overview=<id> deep=<id> yesterday=<id> csp=<id>` → prints the writes; send them with ArtifactData `batch`.
4. After the batch succeeds: `python3 make_batch.py commit` → prints old asset ids. (Version mismatch? list collection `datasets`, copy versions into state.json `dataset_versions`, prepare again.)
5. Delete each printed old asset id (Artifact `delete` with `path`).
6. Read `data/users/me` (check/runs) if a page is open; report failures.

The page file itself (`index.html` here = store `files/index.html`) only changes when the design changes; edit, wrap as `{"text": ...}`, and `update` it with its `if_version`.

## Windows (all IST, relative to the run day)
- Overview + Deep dive: tasks created from the 1st of the month (of the date 5 days back) to 5 days ago (month to date). Queries are flow-aware (1–2 Nov mix old customer-schedule flow + new CSP-acceptance flow).
- Daily tracker: yesterday; trends since 1 Aug 2026; flags vs previous 28 days.
- CSP reschedule behaviour: installs in the 30 days up to yesterday.
