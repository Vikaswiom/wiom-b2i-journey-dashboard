# CSP Booking-to-Install Journey — refresh pipeline

**Live page (auto-refreshed daily by GitHub Actions at 03:00 IST, retries 03:30 and 04:00; 3 attempts per run; `check_fresh.py` makes sure yesterday has fully synced):** https://vikaswiom.github.io/wiom-b2i-journey-dashboard/

- `.github/workflows/refresh.yml` runs `refresh_all.py` with the `METABASE_API_KEY` repo secret, then `build_site.py`, and commits `docs/index.html` + `docs/data/*.json`. Run it any time from the Actions tab (Run workflow).
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
- Overview + Deep dive: tasks created 17 → 5 days ago (13 days).
- Daily tracker: yesterday; trends since 1 Aug 2026; flags vs previous 28 days.
- CSP reschedule behaviour: installs in the 30 days up to yesterday.
