-- Tasks due yesterday: open tasks whose slot day was yesterday, as the slot stood when the day began
-- (or when the task was created, if created during the day)
WITH p AS (SELECT DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE) yday),
w AS (SELECT yday, CONVERT_TIMEZONE('Asia/Kolkata','UTC', yday::TIMESTAMP_NTZ) t0, CONVERT_TIMEZONE('Asia/Kolkata','UTC', DATEADD(day,1,yday)::TIMESTAMP_NTZ) t1 FROM p),
tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, reason_code rc, occurred_at::TIMESTAMP_NTZ ts
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-10-01'),
iec AS (SELECT execution_candidate_id ec, slot_date, csp_id FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, created_at::TIMESTAMP_NTZ ts, PARSE_JSON(payload):original_slot_date::DATE orig, PARSE_JSON(payload):new_slot_date::DATE nw, PARSE_JSON(payload):source::STRING src
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= '2026-10-01' AND payload ILIKE '%ES_INSTALL_SLOT_AUTO_REDATED%'),
born AS (SELECT ec, MIN(ts) t_created FROM tl GROUP BY 1),
anchor AS (SELECT b.ec, GREATEST(w.t0, b.t_created) ta FROM born b, w WHERE b.t_created < w.t1),
st0 AS (SELECT a.ec, a.ta, MAX_BY(tl.t, tl.ts) state0 FROM anchor a JOIN tl ON tl.ec=a.ec AND tl.ts <= a.ta GROUP BY 1,2),
rdx AS (SELECT s.ec, MAX_BY(IFF(r.ts <= s.ta, r.nw, NULL), IFF(r.ts <= s.ta, r.ts, NULL)) last_before, MIN_BY(IFF(r.ts > s.ta, r.orig, NULL), IFF(r.ts > s.ta, r.ts, NULL)) first_after
        FROM st0 s JOIN rd r ON r.ec=s.ec GROUP BY 1),
due AS (
  SELECT s.ec FROM st0 s JOIN iec i ON i.ec=s.ec LEFT JOIN rdx ON rdx.ec=s.ec, w
  WHERE s.state0 NOT IN ('CANCELLED_BY_UPSTREAM','CANCELLED_BY_CUSTOMER','INSTALLATION_REPORTED_FAILED','DECLINED','RATING_PENDING','CONNECTION_ACTIVE')
    AND COALESCE(rdx.last_before, rdx.first_after, i.slot_date) = w.yday
),
ev AS (
  SELECT d.ec,
    MAX(IFF(tl.f='AWAITING_CSP_ACCEPTANCE' AND tl.t IN ('AWAITING_TECHNICIAN_ASSIGNMENT','AWAITING_SLOT_PROPOSAL') AND tl.ts < w.t1,1,0)) acc_eod,
    MAX(IFF(tl.t='TECHNICIAN_ASSIGNED' AND tl.ts < w.t1,1,0)) asg_eod,
    MAX(IFF(tl.t='ARRIVED_AT_SITE' AND tl.ts < w.t1,1,0)) arr_eod,
    MAX(IFF(tl.t='RATING_PENDING' AND tl.ts < w.t1,1,0)) otp_eod,
    MAX(IFF(tl.t IN ('RATING_PENDING','CONNECTION_ACTIVE') AND tl.ts < w.t1,1,0)) inst_eod,
    MAX(IFF(tl.t IN ('RATING_PENDING','CONNECTION_ACTIVE'),1,0)) inst_ever,
    MAX_BY(IFF(tl.ts < w.t1, tl.t, NULL), IFF(tl.ts < w.t1, tl.ts, NULL)) state_eod,
    MAX_BY(IFF(tl.ts < w.t1, tl.rc, NULL), IFF(tl.ts < w.t1, tl.ts, NULL)) rc_eod
  FROM due d JOIN tl ON tl.ec=d.ec, w GROUP BY 1
),
moved AS (SELECT r.ec, MAX(1) moved_yday FROM rd r, w WHERE r.ts >= w.t0 AND r.ts < w.t1 AND r.src='CSP_RESCHEDULE' GROUP BY 1)
SELECT
  CASE WHEN inst_eod=1 THEN 'Installed on the day'
       WHEN state_eod='INSTALLATION_REPORTED_FAILED' THEN 'CSP reported failure'
       WHEN state_eod='CANCELLED_BY_CUSTOMER' THEN 'Customer cancelled'
       WHEN state_eod='DECLINED' THEN 'CSP declined'
       WHEN state_eod='CANCELLED_BY_UPSTREAM' AND rc_eod='TIMEOUT_P41' THEN 'FPN expired, no response'
       WHEN state_eod='CANCELLED_BY_UPSTREAM' THEN 'System / ops cancelled'
       WHEN m.moved_yday=1 THEN 'Rescheduled to a later day'
       ELSE 'Still open at end of day' END day_outcome,
  acc_eod, asg_eod, arr_eod, otp_eod, inst_eod, inst_ever, COALESCE(IFF(inst_eod=0, rc_eod, NULL),'-') eod_rc,
  COUNT(*) tasks, COUNT(DISTINCT i.csp_id) csps
FROM ev LEFT JOIN moved m USING(ec) LEFT JOIN iec i USING(ec)
GROUP BY 1,2,3,4,5,6,7,8 ORDER BY tasks DESC
