-- Bookings that were supposed to be installed on each slot day (IST), and what happened to them by now. One row per booking (connection) per slot day.
-- Supposed = a task of the booking was open with that slot day when the day began (or when created that day), or the booking was installed early for that slot day.
WITH tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-07-01'),
born AS (SELECT ec, MIN(ts) t_created FROM tl GROUP BY 1),
iec AS (SELECT execution_candidate_id ec, connection_id, slot_date, current_state, reason_code, created_at::TIMESTAMP_NTZ created_at FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, created_at::TIMESTAMP_NTZ ts, PARSE_JSON(payload):original_slot_date::DATE orig, PARSE_JSON(payload):new_slot_date::DATE nw, PARSE_JSON(payload):source::STRING src
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= '2026-07-25' AND payload LIKE '%"event_type":"ES_INSTALL_SLOT_AUTO_REDATED"%'),
rdo AS (SELECT rd.*, ROW_NUMBER() OVER (PARTITION BY ec ORDER BY ts) rn, LEAD(ts) OVER (PARTITION BY ec ORDER BY ts) nxt FROM rd),
iv AS (
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
due_t AS (
  SELECT DISTINCT c.ec, c.d, c.anchor FROM cand c JOIN iv ON iv.ec=c.ec AND iv.slot=c.d AND c.anchor >= iv.s_from AND c.anchor < iv.s_to WHERE c.anchor < c.t1
),
due_open AS (
  SELECT d.ec, d.d FROM due_t d JOIN tl ON tl.ec=d.ec
  GROUP BY 1,2, d.anchor
  HAVING COALESCE(MAX_BY(IFF(tl.ts <= d.anchor, tl.t, NULL), IFF(tl.ts <= d.anchor, tl.ts, NULL)),'ASSIGNED') NOT IN ('CANCELLED_BY_UPSTREAM','CANCELLED_BY_CUSTOMER','INSTALLATION_REPORTED_FAILED','DECLINED','RATING_PENDING','CONNECTION_ACTIVE')
),
inst_t AS (SELECT ec, MIN(ts) t_act FROM tl WHERE t IN ('RATING_PENDING','CONNECTION_ACTIVE') GROUP BY 1),
early AS (  -- installed before its slot day: still counts as supposed for that day
  SELECT i.ec, iec.slot_date d FROM inst_t i JOIN iec ON iec.ec=i.ec
  WHERE DATEADD(minute,330,i.t_act)::DATE < iec.slot_date AND iec.slot_date BETWEEN '2026-08-01' AND DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)
),
supp AS (
  SELECT DISTINCT iec.connection_id conn, s.d FROM (SELECT ec, d FROM due_open UNION SELECT ec, d FROM early) s JOIN iec ON iec.ec=s.ec WHERE iec.connection_id IS NOT NULL
),
conn_inst AS (SELECT iec.connection_id conn, DATEADD(minute,330,MIN(i.t_act))::DATE inst_day FROM inst_t i JOIN iec ON iec.ec=i.ec GROUP BY 1),
conn_now AS (SELECT connection_id conn, MAX_BY(current_state, created_at) state_now, MAX_BY(slot_date, created_at) slot_now, MAX_BY(reason_code, created_at) rc_now FROM iec WHERE connection_id IS NOT NULL GROUP BY 1),
moved AS (SELECT DISTINCT iec.connection_id conn, r.orig d FROM rd r JOIN iec ON iec.ec=r.ec WHERE r.src='CSP_RESCHEDULE' AND r.nw > r.orig),
x AS (
  SELECT s.conn, s.d, ci.inst_day, cn.state_now, cn.slot_now, cn.rc_now, IFF(m.conn IS NULL,0,1) moved
  FROM supp s LEFT JOIN conn_inst ci ON ci.conn=s.conn LEFT JOIN conn_now cn ON cn.conn=s.conn LEFT JOIN moved m ON m.conn=s.conn AND m.d=s.d
)
SELECT d,
  CASE WHEN inst_day < d THEN 'Installed early'
       WHEN inst_day = d THEN 'Installed on the day'
       WHEN inst_day > d AND moved=1 THEN 'Rescheduled, installed later'
       WHEN inst_day > d THEN 'Late, installed later'
       WHEN state_now = 'CANCELLED_BY_CUSTOMER' THEN 'Customer cancelled'
       WHEN state_now = 'CANCELLED_BY_UPSTREAM' AND rc_now = 'TIMEOUT_P41' THEN 'No CSP accepted in time'
       WHEN state_now = 'DECLINED' THEN 'CSP declined'
       WHEN state_now IN ('INSTALLATION_REPORTED_FAILED','INSTALLATION_CANCELLED_ONSITE','WITHDRAWN_BY_CSP') THEN 'CSP reported failure'
       WHEN state_now IN ('CANCELLED_BY_UPSTREAM','INSTALLATION_EXPIRED') THEN 'Dropped by system'
       WHEN state_now IN ('ASSIGNED','AWAITING_CSP_ACCEPTANCE') THEN 'Still finding a CSP'
       WHEN moved=1 OR slot_now > d THEN 'Rescheduled, not installed yet'
       ELSE 'Overdue, still open' END outcome,
  IFF(inst_day > d, LEAST(DATEDIFF(day, d, inst_day), 4), NULL) days_late,
  COUNT(*) bookings
FROM x GROUP BY 1,2,3 ORDER BY 1,2,3
