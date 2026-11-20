-- Per-CSP reschedule behaviour: installs in the last 30 days (IST) up to yesterday, late installs with and without a reschedule,
-- reschedule use ever (CSP_RESCHEDULE events since 18 Sep 2026), open overdue tasks never rescheduled, latest CSP app version.
WITH p AS (SELECT DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE) yday),
tl AS (SELECT execution_candidate_id ec, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND to_state IN ('RATING_PENDING','CONNECTION_ACTIVE') AND occurred_at >= '2026-10-01'),
iec AS (SELECT execution_candidate_id ec, csp_id, slot_date, current_state FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec, PARSE_JSON(payload):csp_id::STRING csp_id, created_at::TIMESTAMP_NTZ ts
       FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE created_at >= '2026-09-18' AND payload LIKE '%"event_type":"ES_INSTALL_SLOT_AUTO_REDATED"%' AND payload LIKE '%"source":"CSP_RESCHEDULE"%'),
inst AS (SELECT ec, MIN(ts) t_act, DATEADD(minute,330,MIN(ts))::DATE inst_day FROM tl GROUP BY 1 HAVING DATEADD(minute,330,MIN(ts))::DATE BETWEEN DATEADD(day,-29,(SELECT yday FROM p)) AND (SELECT yday FROM p)),
x AS (SELECT i.ec, iec.csp_id, i.inst_day, iec.slot_date, COUNT(rd.ec) n_r FROM inst i JOIN iec USING(ec) LEFT JOIN rd ON rd.ec=i.ec AND rd.ts <= i.t_act GROUP BY 1,2,3,4),
per AS (
  SELECT csp_id, COUNT(*) installs,
    COUNT_IF(n_r=0 AND inst_day<=slot_date) ontime_no_resched, COUNT_IF(n_r>0 AND inst_day<=slot_date) ontime_resched,
    COUNT_IF(n_r>0 AND inst_day>slot_date) late_resched, COUNT_IF(n_r=0 AND inst_day>slot_date) late_no_resched,
    AVG(IFF(n_r=0 AND inst_day>slot_date, DATEDIFF(day,slot_date,inst_day), NULL)) avg_days_late_no_resched
  FROM x GROUP BY 1
),
rs AS (SELECT csp_id, COUNT(*) resched_events_ever, COUNT(DISTINCT ec) resched_tasks_ever, MAX(ts) last_resched,
         COUNT_IF(DATEADD(minute,330,ts)::DATE >= DATEADD(day,-29,(SELECT yday FROM p))) resched_events_30d FROM rd GROUP BY 1),
open_od AS (SELECT i.csp_id, COUNT(*) open_overdue_no_resched FROM iec i LEFT JOIN (SELECT DISTINCT ec FROM rd) r ON r.ec=i.ec
            WHERE i.current_state IN ('AWAITING_TECHNICIAN_ASSIGNMENT','TECHNICIAN_ASSIGNED','ARRIVED_AT_SITE','INSTALLATION_IN_PROGRESS_PRE_FEE','FEE_COLLECTION_PENDING','INSTALLATION_IN_PROGRESS_POST_FEE','AWAITING_CUSTOMER_OTP')
              AND i.slot_date < CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE AND r.ec IS NULL GROUP BY 1),
ctmap AS (SELECT DISTINCT clevertap_id, PARSE_JSON(properties):csp_id::STRING csp_id FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA
          WHERE event_name='install_task_created' AND TRY_TO_TIMESTAMP(timestamp) >= DATEADD(day,-31,CURRENT_DATE()) AND PARSE_JSON(properties):csp_role::STRING IN ('OWNER','MANAGER')),
ver AS (SELECT m.csp_id, MAX_BY(PARSE_JSON(e.properties):"CT App Version"::STRING, TRY_TO_TIMESTAMP(e.timestamp)) app_version
        FROM ctmap m JOIN PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e ON e.clevertap_id=m.clevertap_id
        WHERE TRY_TO_TIMESTAMP(e.timestamp) >= DATEADD(day,-10,CURRENT_DATE()) AND e.event_name IN ('install_candidate_opened','fpn_delivered','fpn_action_taken','install_accepted') GROUP BY 1),
acct AS (SELECT csp_id, MAX_BY(name, updated_at) csp_name FROM PROD_DB.CSP_GATEWAY_SERVICE_CSP_GATEWAY_SERVICE.CSP_ACCOUNT WHERE _FIVETRAN_ACTIVE GROUP BY 1)
SELECT per.csp_id, acct.csp_name, per.installs, per.ontime_no_resched, per.ontime_resched, per.late_resched, per.late_no_resched,
  ROUND(per.avg_days_late_no_resched,1) avg_days_late_no_resched,
  COALESCE(rs.resched_events_ever,0) resched_events_ever, COALESCE(rs.resched_tasks_ever,0) resched_tasks_ever, COALESCE(rs.resched_events_30d,0) resched_events_30d,
  DATEADD(minute,330,rs.last_resched)::DATE last_resched_day, COALESCE(od.open_overdue_no_resched,0) open_overdue_no_resched, ver.app_version
FROM per LEFT JOIN rs ON rs.csp_id=per.csp_id LEFT JOIN open_od od ON od.csp_id=per.csp_id LEFT JOIN ver ON ver.csp_id=per.csp_id LEFT JOIN acct ON acct.csp_id=per.csp_id
ORDER BY per.late_no_resched DESC
