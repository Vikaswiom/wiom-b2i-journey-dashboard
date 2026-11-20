-- Due-day funnel per IST day since 1 Aug 2026. A task is due on D if, when D began (or when the task was created, if later),
-- it was open and its slot day was D. The slot history is rebuilt from ES_INSTALL_SLOT_AUTO_REDATED events as time intervals.
WITH tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-07-01'),
born AS (SELECT ec, MIN(ts) t_created FROM tl GROUP BY 1),
iec AS (SELECT execution_candidate_id ec, slot_date FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, created_at::TIMESTAMP_NTZ ts, PARSE_JSON(payload):original_slot_date::DATE orig, PARSE_JSON(payload):new_slot_date::DATE nw
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= '2026-07-25' AND payload LIKE '%"event_type":"ES_INSTALL_SLOT_AUTO_REDATED"%'),
rdo AS (SELECT rd.*, ROW_NUMBER() OVER (PARTITION BY ec ORDER BY ts) rn, LEAD(ts) OVER (PARTITION BY ec ORDER BY ts) nxt FROM rd),
iv AS (
  -- interval before the first redate (or the whole life if never redated)
  SELECT b.ec, b.t_created s_from, COALESCE(r.ts, '2100-01-01'::TIMESTAMP_NTZ) s_to, COALESCE(r.orig, i.slot_date) slot
  FROM born b JOIN iec i ON i.ec=b.ec LEFT JOIN rdo r ON r.ec=b.ec AND r.rn=1
  UNION ALL
  SELECT r.ec, r.ts, COALESCE(r.nxt, '2100-01-01'::TIMESTAMP_NTZ), r.nw FROM rdo r JOIN born b ON b.ec=r.ec
),
cand AS (
  SELECT iv.ec, iv.slot d, GREATEST(DATEADD(minute,-330, iv.slot::TIMESTAMP_NTZ), b.t_created) anchor, DATEADD(minute,-330, DATEADD(day,1,iv.slot)::TIMESTAMP_NTZ) t1
  FROM iv JOIN born b ON b.ec=iv.ec
  WHERE iv.slot BETWEEN '2026-08-01' AND DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)
),
due AS (
  SELECT DISTINCT c.ec, c.d, c.anchor, c.t1 FROM cand c JOIN iv ON iv.ec=c.ec AND iv.slot=c.d AND c.anchor >= iv.s_from AND c.anchor < iv.s_to
  WHERE c.anchor < c.t1
),
st AS (
  SELECT d.ec, d.d,
    MAX_BY(IFF(tl.ts <= d.anchor, tl.t, NULL), IFF(tl.ts <= d.anchor, tl.ts, NULL)) state0,
    MAX(IFF(tl.t IN ('AWAITING_TECHNICIAN_ASSIGNMENT','TECHNICIAN_ASSIGNED','ARRIVED_AT_SITE','RATING_PENDING','CONNECTION_ACTIVE') AND tl.ts < d.t1,1,0)) acc,
    MAX(IFF(tl.t='TECHNICIAN_ASSIGNED' AND tl.ts < d.t1,1,0)) asg,
    MAX(IFF(tl.t='ARRIVED_AT_SITE' AND tl.ts < d.t1,1,0)) arr,
    MAX(IFF(tl.t IN ('RATING_PENDING','CONNECTION_ACTIVE') AND tl.ts < d.t1,1,0)) inst
  FROM due d JOIN tl ON tl.ec=d.ec GROUP BY 1,2
)
SELECT d, COUNT(*) due, SUM(acc) accepted, SUM(asg) assigned, SUM(arr) arrived, SUM(inst) installed_on_day
FROM st WHERE COALESCE(state0,'ASSIGNED') NOT IN ('CANCELLED_BY_UPSTREAM','CANCELLED_BY_CUSTOMER','INSTALLATION_REPORTED_FAILED','DECLINED','RATING_PENDING','CONNECTION_ACTIVE')
GROUP BY 1 ORDER BY 1
