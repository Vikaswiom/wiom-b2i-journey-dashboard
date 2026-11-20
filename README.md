# CSP Booking-to-Install Journey — refresh pipeline

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
