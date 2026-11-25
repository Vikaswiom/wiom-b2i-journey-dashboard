-- One row per install task that got a technician, for the two cohorts in the problem statement.
-- grp: timeout = removed by the system (CSP_NO_SHOW) while still at "technician assigned";
--      on_time = installed on or before the original slot day; late = installed after it; other = everything else.
WITH tl AS (
  SELECT execution_candidate_id ec, from_state f, to_state t, reason_code rc, occurred_at::TIMESTAMP_NTZ ts  /* UTC wall clock; +330 min = IST, comparable with CleverTap's IST text timestamps */, actor_type, actor_id
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-09-30'
),
cohort AS (
  SELECT ec, TO_DATE(DATEADD(minute,330,MIN(ts))) created_day FROM tl WHERE t='ASSIGNED' AND f IS NULL GROUP BY 1
  HAVING created_day BETWEEN '2026-10-01' AND '2026-10-31' OR created_day BETWEEN '2026-11-06' AND '2026-11-18'
),
asg AS (SELECT c.ec, c.created_day FROM cohort c JOIN tl ON tl.ec=c.ec AND tl.t='TECHNICIAN_ASSIGNED' GROUP BY 1,2),
iec AS (
  SELECT execution_candidate_id ec, connection_id, csp_id, executor_id, is_self_assigned, slot_date, zone_id, reschedule_count,
    TRY_PARSE_JSON(service_address):pincode::STRING pincode, TRY_PARSE_JSON(service_address):city::STRING city, customer_call_recorded_at
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE
  QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1
),
rd AS (
  SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec,
    COUNT_IF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE') n_resched,
    MIN_BY(PARSE_JSON(payload):original_slot_date::DATE, IFF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE', created_at, NULL)) first_orig,
    MIN(IFF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE', created_at, NULL)) t_first_resched,
    MAX(IFF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE', created_at, NULL)) t_last_resched
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD
  WHERE created_at >= '2026-09-30' AND payload ILIKE '%ES_INSTALL_SLOT_AUTO_REDATED%'
  GROUP BY 1
),
st AS (
  SELECT a.ec, a.created_day,
   MIN(IFF(f IS NULL AND t='ASSIGNED',ts,NULL)) t_created,
   MIN(IFF(t='AWAITING_TECHNICIAN_ASSIGNMENT',ts,NULL)) t_accept,
   MIN(IFF(t='TECHNICIAN_ASSIGNED',ts,NULL)) t_asg,
   MAX(IFF(t='TECHNICIAN_ASSIGNED',ts,NULL)) t_asg_last,
   COUNT_IF(t='TECHNICIAN_ASSIGNED') n_asg,
   MIN(IFF(t='ARRIVED_AT_SITE',ts,NULL)) t_arr,
   MIN(IFF(t IN ('RATING_PENDING','CONNECTION_ACTIVE'),ts,NULL)) t_act,
   MAX(IFF(t IN ('CANCELLED_BY_UPSTREAM','CANCELLED_BY_CUSTOMER','INSTALLATION_REPORTED_FAILED','DECLINED','RATING_PENDING','CONNECTION_ACTIVE'),ts,NULL)) t_end,
   MAX_BY(t, ts) cur_state, MAX_BY(f, ts) end_from, MAX_BY(rc, ts) end_rc, MAX(ts) t_last
  FROM asg a JOIN tl ON tl.ec=a.ec GROUP BY 1,2
),
b AS (
  SELECT s.*, IFF(s.created_day < '2026-11-01','Oct','Nov') mon,
    i.connection_id, i.csp_id, i.executor_id, i.is_self_assigned, i.slot_date final_slot, i.zone_id, i.pincode, i.city, i.reschedule_count, i.customer_call_recorded_at,
    COALESCE(rd.n_resched,0) n_resched, COALESCE(rd.first_orig, i.slot_date) orig_slot, rd.t_first_resched, rd.t_last_resched,
    TO_DATE(DATEADD(minute,330,s.t_asg)) asg_day, TO_DATE(DATEADD(minute,330,s.t_act)) inst_day,
    CASE WHEN s.t_end IS NOT NULL AND s.t_act IS NULL AND s.end_rc='CSP_NO_SHOW' AND s.end_from='TECHNICIAN_ASSIGNED'
              AND s.cur_state NOT IN ('INSTALLATION_REPORTED_FAILED','CANCELLED_BY_CUSTOMER') THEN 'timeout'
         WHEN s.t_end IS NOT NULL AND s.t_act IS NOT NULL AND TO_DATE(DATEADD(minute,330,s.t_act)) <= COALESCE(rd.first_orig, i.slot_date) THEN 'on_time'
         WHEN s.t_end IS NOT NULL AND s.t_act IS NOT NULL THEN 'late'
         ELSE 'other' END grp
  FROM st s LEFT JOIN iec i ON i.ec=s.ec LEFT JOIN rd ON rd.ec=s.ec
)
