# Timeout data signals (25 Nov 2026)

Queries behind the data questions in the problem statement "1 in 10 bookings assigned to technician, but never installed" (install tasks removed by the system, `CSP_NO_SHOW`, four days after the slot day while still at "technician assigned").

## How to run
`base.sql` builds one row per task (CTE `b`) and ends inside its `WITH` list. Each `q*.sql` continues from there, so run `base.sql` + one `q*.sql` as a single statement on Metabase (database 113). Each takes 10–60 seconds. Results are aggregates; nothing returns customer details.

## Cohort (`base.sql`)
- Tasks created 1–31 Oct 2026 and 6–18 Nov 2026 (IST) that reached `TECHNICIAN_ASSIGNED`.
- `grp`:
  - `timeout`: ended `CSP_NO_SHOW` from `TECHNICIAN_ASSIGNED`
  - `on_time`: installed on or before the original slot day
  - `late`: installed after it
  - `other`: failed, cancelled, declined or still open
- Installed = first `→ RATING_PENDING`, falling back to `CONNECTION_ACTIVE`.
- Reconciles to the doc: October 10,132 tasks / 1,070 timeouts. November was 3,762 / 287 on 25 Nov (the doc's 23 Nov snapshot had 3,759 / 273).

## Data notes
- **Technician:** `INSTALL_EXECUTION_CANDIDATES.EXECUTOR_ID` (stays filled after a timeout). `IS_SELF_ASSIGNED` = the CSP assigned itself.
- **Area:** `ZONE_ID`, and `pincode` / `city` read out of the `SERVICE_ADDRESS` JSON. Never select the address itself.
- **App events:** `CLEVERTAP_CSP_API.EVENTS_DATA` joined on `properties:execution_id`. `TIMESTAMP` is IST text. `PROFILE_DATA.IDENTITY` equals `EXECUTOR_ID` (96% for technicians) and `ROLE` separates technician, owner and manager.
- **Calls:** `INSTALL_CALL_LOG` is empty. The queries use the app event `call_initiated` with `target = customer`: app-initiated calls only, with no connect status.
- **Comparing app events with backend times:** `OCCURRED_AT` is a `TIMESTAMP_TZ` in UTC and CleverTap's `TIMESTAMP` is IST text. `base.sql` casts `OCCURRED_AT` to `TIMESTAMP_NTZ` so that `+330 minutes` gives an IST value that compares correctly with CleverTap. The first version (25 Nov, commit `ddada4a`) compared the two types directly and missed app events in the first 5.5 hours after assignment. With the fix, 99.7% of on-time installs show an open after assignment, so opens are well covered.
- **Reminders:** `INSTALL_ATTENTION_EVENT_LOG` (`INSTALL_DAY_REMINDER`, urgent threshold events).
- **Pushes after technician assigned** (`push_on_removed_leads_*.sql`, leads removed 22–24 Nov 2026): `install_task_assigned` (push to the assigned person), `install_day_reminder` / `install_day_executor_reminder` (9 AM and 3 PM summaries; no task id, match on CSP or technician + install date; delivery and clicks are not logged), `install_not_started_nudge_3PM` (per task), and `install_not_started_nudge` (Home feed escalation, not a push). Delivery and clicks: `pn_delivered` / `pn_clicked` with `pn_type` and `execution_id`.
