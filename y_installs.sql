-- Installs done yesterday (IST), split by reschedule and timing vs slot day
WITH p AS (SELECT DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE) yday),
tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, occurred_at ts, DATEADD(minute,330,occurred_at)::TIMESTAMP_NTZ ist
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-10-01'),
inst AS (SELECT ec, MIN(ts) t_act, MIN(ist) ist_act FROM tl WHERE t IN ('RATING_PENDING','CONNECTION_ACTIVE') GROUP BY 1 HAVING MIN(ist)::DATE = (SELECT yday FROM p)),
asg AS (SELECT tl.ec, MIN(tl.ts) t_asg FROM tl JOIN inst USING(ec) WHERE tl.t='TECHNICIAN_ASSIGNED' GROUP BY 1),
term AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, PARSE_JSON(payload):slot_day::DATE slot_day
         FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= DATEADD(day,-3,CURRENT_DATE()) AND payload ILIKE '%TAS_INSTALL_TERMINAL%'
         QUALIFY ROW_NUMBER() OVER (PARTITION BY ec ORDER BY created_at DESC)=1),
iec AS (SELECT execution_candidate_id ec, slot_date FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, created_at, PARSE_JSON(payload):original_slot_date::DATE orig, PARSE_JSON(payload):new_slot_date::DATE nw
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= '2026-10-01' AND payload ILIKE '%ES_INSTALL_SLOT_AUTO_REDATED%' AND PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE'),
x AS (
  SELECT i.ec, i.ist_act::DATE inst_day, HOUR(i.ist_act) inst_hour, COALESCE(term.slot_day, iec.slot_date) slot_day,
    COUNT(rd.ec) n_resched, MIN_BY(rd.orig, rd.created_at) first_orig, DATEDIFF(minute, a.t_asg, i.t_act) asg_to_inst_min
  FROM inst i LEFT JOIN term USING(ec) LEFT JOIN iec USING(ec) LEFT JOIN asg a USING(ec) LEFT JOIN rd ON rd.ec=i.ec AND rd.created_at <= i.t_act
  GROUP BY 1,2,3,4,7
)
SELECT IFF(n_resched>0,'Rescheduled','Not rescheduled') resched,
  CASE WHEN inst_day < slot_day THEN 'Before slot day' WHEN inst_day = slot_day THEN 'On slot day' ELSE 'After slot day' END timing,
  DATEDIFF(day, slot_day, inst_day) days_vs_slot,
  DATEDIFF(day, COALESCE(first_orig, slot_day), inst_day) days_vs_original,
  LEAST(n_resched,3) n_resched_capped,
  COUNT(*) installs, MEDIAN(asg_to_inst_min) med_asg_to_inst_min
FROM x GROUP BY 1,2,3,4,5 ORDER BY 1,2,3,4
