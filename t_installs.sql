-- Installs per IST day since 1 Aug 2026, split x/y/z
WITH tl AS (SELECT execution_candidate_id ec, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND to_state IN ('RATING_PENDING','CONNECTION_ACTIVE')),
inst AS (SELECT ec, MIN(ts) t_act, DATEADD(minute,330,MIN(ts))::DATE inst_day FROM tl GROUP BY 1 HAVING DATEADD(minute,330,MIN(ts))::DATE BETWEEN '2026-08-01' AND DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)),
iec AS (SELECT execution_candidate_id ec, slot_date FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, created_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD
       WHERE created_at >= '2026-07-25' AND payload LIKE '%"event_type":"ES_INSTALL_SLOT_AUTO_REDATED"%' AND payload LIKE '%"source":"CSP_RESCHEDULE"%'),
x AS (SELECT i.ec, i.inst_day, iec.slot_date, COUNT(rd.ec) n_r FROM inst i LEFT JOIN iec USING(ec) LEFT JOIN rd ON rd.ec=i.ec AND rd.ts <= i.t_act GROUP BY 1,2,3)
SELECT inst_day d, COUNT(*) installs,
  COUNT_IF(n_r=0 AND inst_day=slot_date) x_on_day, COUNT_IF(n_r=0 AND inst_day<slot_date) x_early,
  COUNT_IF(n_r>0 AND inst_day<=slot_date) y_on_time, COUNT_IF(n_r>0 AND inst_day>slot_date) y_late,
  COUNT_IF(n_r=0 AND inst_day>slot_date) z_late, COUNT_IF(slot_date IS NULL) no_slot
FROM x GROUP BY 1 ORDER BY 1
