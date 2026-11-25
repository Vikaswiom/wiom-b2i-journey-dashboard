# CSP Booking-to-Install Journey: full context

The full background for this dashboard: what it shows, how the data is defined, how it refreshes, and what the one-off analyses found. `README.md` covers the refresh steps only. Last updated 25 Nov 2026.

> This repo is **public**. Never commit keys, customer details or personal data. The Metabase key lives only in the macOS Keychain (`wiom-metabase-api-key`) and the GitHub secret `METABASE_API_KEY`.

## 1. Where it lives

| | |
|---|---|
| Live page (GitHub Pages, refreshed every 30 minutes) | https://vikaswiom.github.io/wiom-b2i-journey-dashboard/ |
| claude.ai copy (Data artifact) | https://claude.ai/artifact/WUWh5LShPxE5zb36fcvZmW |
| Source page | `index.html` (one file for both copies) |
| Data | Snowflake through Metabase (`https://metabase.wiom.in/api/dataset`, database 113) |

## 2. Tabs

| Tab | Anchor | What it shows | Window |
|---|---|---|---|
| Overview | `#overview` | Funnel traced back from install to the Booking FPN, with clickable drop-off reasons, reassignment, CSP groups, hour of day and FPN reach | Tasks created from the 1st of the month to 5 days ago |
| October | `#october` | The same view for 1–31 Oct 2026 (fixed snapshot, `o_` datasets) | 1–31 Oct |
| Deep dive | `#after-assign` | After the technician is assigned: early, on-time or late against the slot day, how late, where non-installs stopped and for how long, open tasks now | Same cohort as Overview |
| Daily tracker | `#daily-tracker` | Yesterday's installs split 4 ways, flags against the last 28 days, the day's activity funnel, "supposed to be installed yesterday", day, week and month trends | Yesterday; trends since 1 Aug 2026 |
| CSP reschedule behaviour | `#csp-reschedule` | CSPs that install late without ever rescheduling, which suggests they don't know about the feature | Installs in the last 30 days |
| Definitions | `#definitions` | Every term, with its backend and app event | |
| Shipped features | `#shipped` | The CSP App Ship Tracker site, embedded in a frame that loads when the tab is first opened and grows to fit its content | Whatever the tracker shows |

### UI rules agreed with the user
- **Wording:**
  - Say **"FPN"**, never "offer".
  - Say **"Technician reached customer home"**, never "Reached home".
  - No x/y/z placeholder labels anywhere in the UI.
- **Funnel direction:** each funnel has a switch placed directly above it ("Install → back to FPN" / "FPN → forward to install"). The choice is saved per viewer.
- **Definitions:** they live only on the Definitions tab. No repeated Definitions buttons in the other tabs.
- **Daily tracker checks:** shows only the **top 5** (`YC_TOP`, in this order):
  1. Bookings due that day installed on time
  2. Installs done
  3. Technician assigned → installed on the day
  4. All late installs
  5. Due → accepted by CSP

  The other checks sit in a collapsed list.
- **Yesterday's installs:** split 4 ways, and the parts sum to the total:
  - On time, never rescheduled
  - Rescheduled, installed early or on time
  - Rescheduled, installed late
  - Late, never rescheduled
- **Percentages** are shown everywhere.
- **Status line:** the page shows "Data updated", the date of yesterday, and "Refreshes every 30 minutes".

## 3. Data model

**Backend (TAS):** `PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE`
- `INSTALL_STATE_TRANSITION_LOG` holds EXECUTION_CANDIDATE_ID, FROM_STATE, TO_STATE, REASON_CODE, ACTOR_TYPE and OCCURRED_AT. **OCCURRED_AT is stored in UTC**, so add 330 minutes for IST. A task is created by the transition `NULL → ASSIGNED`.
- `INSTALL_EXECUTION_CANDIDATES` is Fivetran history. Filter on `_FIVETRAN_ACTIVE` and take the latest `_fivetran_synced`. It holds CONNECTION_ID, CSP_ID, SLOT_DATE, CURRENT_STATE, P41_DEADLINE_AT and FAILURE_DETAIL. FAILURE_DETAIL is the CSP's free text, filled for OTHER failures and for declines.
- `OUTBOX_RECORD` events:
  - `ES_INSTALL_SLOT_AUTO_REDATED`: original_slot_date, new_slot_date, and source `CSP_RESCHEDULE` or `CREATION_INHERITANCE`. **CSP_RESCHEDULE exists only from 18 Sep 2026.**
  - `TAS_INSTALL_TERMINAL`: slot_day, on_time, terminal_outcome.

**Flows:**
- **New flow (every task from 3 Nov 2026; mixed with the old flow from about 23 Oct):**
  - ASSIGNED → AWAITING_CSP_ACCEPTANCE.
  - From there the CSP accepts (→ AWAITING_TECHNICIAN_ASSIGNMENT), declines (→ DECLINED), or doesn't respond (→ CANCELLED_BY_UPSTREAM with `TIMEOUT_P41`, median about 16 h).
  - After acceptance: TECHNICIAN_ASSIGNED → ARRIVED_AT_SITE → INSTALLATION_IN_PROGRESS_PRE_FEE (selfie and Aadhaar) → FEE_COLLECTION_PENDING → POST_FEE (device setup) → AWAITING_CUSTOMER_OTP → **RATING_PENDING (happy code)** → CONNECTION_ACTIVE (rating).
- **Old flow (most of October; part of 1–2 Nov):**
  - ASSIGNED → AWAITING_CUSTOMER_SCHEDULE → SLOT_CONFIRMED_BY_CUSTOMER → AWAITING_TECHNICIAN_ASSIGNMENT.
  - The CSP decides by assigning a technician, declining, or letting `TIMEOUT_P41` fire.
  - **How the queries handle both flows:** they detect old-flow tasks by the presence of `AWAITING_CUSTOMER_SCHEDULE`. Step 2 is then labelled **"CSP took the task"**: accepted the FPN (new flow) or assigned a technician (old flow).
- **No-show timeout:** after a technician is assigned, `CSP_NO_SHOW` is the system timeout. It fires at **00:00 exactly 4 days after the slot day**.

**Definitions:**
- **Installed = happy code submitted.** That is the first `→ RATING_PENDING`, falling back to `CONNECTION_ACTIVE`. This is the user's decision and applies across the whole dashboard. The rating can come days later, so it is not counted.
- **Slot day:** a whole day, 00:00–23:59 IST (`SLOT_DATE`). Early, on time or late compares the IST install date with it. The backend's own `on_time` flag counts early installs as on time.
- **Due yesterday:** the slot day as it stood at 00:00 IST, rebuilt from the redate events.
- **Task vs booking:** a task is one booking sent to one CSP. A booking is the `CONNECTION_ID` and can have several tasks.

**App events (CleverTap):** `PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA`, joined on `PARSE_JSON(properties):execution_id`. Events used:
- `install_task_created`: the push was sent.
- `fpn_delivered`: the pop-up was drawn.
- `fpn_action_taken`: `action` is `primary_cta` or `dismiss`.
- `install_candidate_opened`, `install_accepted`.
- `pn_delivered` / `pn_clicked`, by `pn_type`.
- `install_not_started_nudge_3PM`, `install_day_reminder`.

**Connection and allocation:**
- `CSP_CONNECTION_LIFECYCLE_SERVICE…CONNECTIONS` holds the booking's CURRENT_STATE.
- `CSP_DEMAND_ALLOCATION_SERVICE…ALLOCATION_AUDIT_LOG` holds every routing attempt: `log_type` is ROUTING_DECISION or ROUTING_FAILURE, with `failure_flag` and `details.stages."3b_eligibility".excluded[]`, which gives the reason each CSP was excluded.

**Free-text notes:** `notes.py` groups CSP notes into themes. Notes appear on the public page only if seen 2+ times, or 6 words or fewer with no digits. Anything with 5+ digits or "@" is never shown.

## 4. Pipeline

`refresh_all.py` runs the stages below in order.

| Stage | Queries | Script | Output |
|---|---|---|---|
| Overview | funnel, exits, fpn, daily, conn, cspband, hour `.sql` | `build.py` → `shape.py` | `b2i_snapshot.json` |
| Deep dive | `deep_base`, `d_funnel`, `d_timing`, `d_notinst`, `d_live` | `deep.py` | `b2i_deep_snapshot.json` |
| Daily tracker | y_installs, y_due, t_installs, t_due, t_activity, y_lag, t_promise | `y.py`, `trend.py`, `activity.py`, `promise.py`, `flags.py` | `b2i_yesterday_snapshot.json` |
| CSP behaviour | `c_csp` | `csp.py` | `b2i_csp_snapshot.json` |
| October (one-off) | `october/*.sql` | `october/finish_oct.py` | `b2i_oct_snapshot.json` |

**Cohort window (Overview and Deep dive):**
- **Window:** `BETWEEN DATE_TRUNC('month', DATEADD(day,-5,today_IST)) AND DATEADD(day,-5,today_IST)`. It grows each day and restarts on the 6th of each month. On the 1st–5th it shows the previous full month.
- **Why the 5-day lag:** it gives each task time to finish.
- **CleverTap window:** the CleverTap filter starts 2 days before the cohort.

**Flags (Daily tracker):** yesterday is compared with the previous 28 days (acceptance-step checks only from 3 Nov):
- **Off:** 2+ standard deviations worse.
- **Watch:** 1.5–2 standard deviations worse.
- **Better than usual:** 2+ standard deviations better.

**GitHub Action** (`.github/workflows/refresh.yml`, "Refresh and publish"):
- **Schedule:** every 30 minutes (`7,37 * * * *`), plus every push to `main` and by hand (`workflow_dispatch`). GitHub starts scheduled runs late and sometimes drops them; a 30-minute schedule on another repo of this account really ran every 1.5–3.5 hours.
- **Freshness check:** `check_fresh.py` requires the TAS tables to have synced past 00:30 IST. Until then the run ends cleanly and leaves the page as it is.
- **Steps:** `refresh_all.py` (2 attempts) → `build_site.py` (wraps `index.html` with `site_shim.js`) → copy the 4 JSON files into `docs/data/` → publish `docs/` to GitHub Pages as an artifact.
- **Nothing is committed.** Pages is set to "GitHub Actions" as its source. `docs/index.html` and the 4 refreshed JSON files are git-ignored; only `docs/data/b2i_oct_snapshot.json` (static) is in the repo. This keeps the repo from growing by about 6 MB a day.
- **Shipped features tab:** its data comes from the Ship Tracker's own refresh, every 3 hours (private repo, limited free Actions minutes). The two refreshes are independent; the earlier chain (trigger branches, `B2I_DEPLOY_KEY`) and the "Refresh now" link were removed on 25 Nov.

**claude.ai copy:** follow `README.md`:
1. Upload the 4 JSON files as assets.
2. Run `make_batch.py prepare`, then send its writes as an ArtifactData batch.
3. Run `make_batch.py commit`, then delete the old asset ids.

`state.json` tracks the dataset versions, asset ids and the page version (store doc `files/index.html`; v23 on 25 Nov).

**Known issues:**
- **Metabase cap:** Metabase returns at most 2,000 rows per query.
- **Hung queries:** a query can occasionally hang. The 24 Nov local run stuck on `build.py`, so check for a stale `refresh_all.py` process before rerunning.

## 5. Findings from one-off analyses (SQL in `analyses/`)

**"Other (free text)" at the accept → technician step (Nov):**

| Theme | Share |
|---|---|
| Really "no coverage at the address" | ~52% |
| Customer unreachable | ~19% |
| Customer not interested, or asked for later | ~14% |

- About 75–80% of these notes match a reason that is already on the list.
- Watch: staff shortages around the festival, customers expecting "₹10 internet", and customers switching to Airtel or Jio.

**Technician assigned, then timed out (`CSP_NO_SHOW`, technician never reached customer home)**

Customer outcome:

| | Nov cohort (6–18 Nov) | October |
|---|---|---|
| Tasks | 273 (7.2% of tasks with a technician) | 1,070 (10.6%) |
| Ever installed | 20 (7.3%) | 106 (9.9%) |
| Days late vs the original slot (median) | 5 | 5.5 |
| First FPN → install (median) | 6.4 d | 6.6 d |
| Installed on or before the original slot | 0 | 0 |

**Why these bookings were not reassigned** (corrected 23 Nov; the earlier label "Never sent to another CSP" was wrong):
- **Not reassigned:** Nov 87 bookings, Oct 348. For these, the timed-out task was the last task.
- **The system did try:** for Nov 84/87 and Oct 348/348, the allocation service attempted a reroute at the timeout. It logged `ROUTING_FAILURE`, usually `LOOP_EXHAUSTED`.
- **Why it failed:**

| | Oct | Nov |
|---|---|---|
| Only the timed-out CSP covered the customer, and it was blocked (`P51_COOLDOWN` or `INELIGIBLE_EXPOSURE_BAND`) | 203 (58%) | 46 (53%) |
| Other CSPs nearby, but all excluded (`PERMANENT_REFUSAL`: declined earlier; `P195_PING_PONG`: booking already bounced; load limit) | 145 | 38 |

- These exclusion meanings are read from the code names. They haven't been confirmed in the backend specs.
- **Takeaway:** this is a coverage gap, not a reassignment bug. Two possible levers:
  - Allow one more attempt with the same CSP in single-CSP areas, or escalate to ops.
  - Time out sooner than 4 days after the slot.

**Escalation pushes for "technician assigned, not arrived"** (CleverTap `pn_type`):

| Period | Push | Notes |
|---|---|---|
| Mid-Sep → about 26 Oct | `ES_INSTALL_TECHNICIAN_ASSIGNED_ESCALATION` | About 1,100–1,800 delivered per week |
| 27 Oct → 15 Nov | Nothing | |
| From about 16 Nov | 3 PM `install_not_started` nudge | 2,452 delivered in its first week |

- The slot-confirmed escalation is a different push. It stopped on 25 Sep.
- **October's 1,070 timed-out tasks:** the escalation reached 72% of them, but only 9.6% were opened.
- **November's 273:** 441 nudges were sent, 166 delivered and 20 opened.

**Headline numbers:**

| | October | 1–18 Nov |
|---|---|---|
| FPNs | 31,732 | 18,338 |
| CSP took the task | 34.6% | 38.7% |
| No response | 52.0% | 47.6% |
| FPN → installed | 20.2% | 19.9% |
| Bookings installed | 40.3% | 37.8% |

- **When the first CSP takes the booking:** about 54–57% are installed.
- **After one reassignment:** about 23–31% are installed.

## 6. Open ideas (not built)

| Idea | Status |
|---|---|
| Customer-outcome and escalation view as a click-through on "Timed out, task not moved" | Not built |
| Full November month tab | From 1 Dec |
| Refresh exactly on time | GitHub's scheduler runs late; a reliable 30 minutes needs an external scheduler calling `workflow_dispatch` (not set up) |
