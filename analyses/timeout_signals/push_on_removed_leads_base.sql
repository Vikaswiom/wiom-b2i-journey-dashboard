-- Push notifications on leads the system removed (CSP_NO_SHOW from "technician assigned") on 22-24 Nov 2026 IST.
WITH tl AS (
  SELECT execution_candidate_id ec, from_state f, to_state t, reason_code rc, occurred_at::TIMESTAMP_NTZ ts  /* UTC wall clock; +330 min = IST, comparable with CleverTap's IST text timestamps */
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-10-25'
),
iec AS (
  SELECT execution_candidate_id ec, csp_id, executor_id, is_self_assigned, slot_date
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE
  QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1
),
lead AS (
  SELECT tl.ec, i.csp_id, i.executor_id::STRING executor_id, i.is_self_assigned, i.slot_date::DATE final_slot,
    TO_DATE(DATEADD(minute,330,tl.ts)) removed_day, DATEADD(minute,330,tl.ts) removed_ist,
    (SELECT DATEADD(minute,330,MIN(a.ts)) FROM tl a WHERE a.ec=tl.ec AND a.t='TECHNICIAN_ASSIGNED') asg_ist
  FROM tl JOIN iec i ON i.ec=tl.ec
  WHERE tl.t='CANCELLED_BY_UPSTREAM' AND tl.rc='CSP_NO_SHOW' AND tl.f='TECHNICIAN_ASSIGNED' AND TO_DATE(DATEADD(minute,330,tl.ts)) BETWEEN '2026-11-22' AND '2026-11-24'
),
p AS (SELECT clevertap_id, MAX(UPPER(role)) role, MAX(identity) identity FROM PROD_DB.CLEVERTAP_CSP_API.PROFILE_DATA GROUP BY 1),
ev AS (
  SELECT COALESCE(PARSE_JSON(e.properties):execution_id::STRING, PARSE_JSON(e.properties):execution_candidate_id::STRING) ec, e.event_name en,
    COALESCE(PARSE_JSON(e.properties):pn_type::STRING, PARSE_JSON(e.properties):source_event::STRING, PARSE_JSON(e.properties):event_type_id::STRING) pn_type,
    TRY_TO_TIMESTAMP(e.timestamp) ts, COALESCE(p.role, UPPER(PARSE_JSON(e.properties):user_role::STRING)) role, e.clevertap_id
  FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e LEFT JOIN p ON p.clevertap_id=e.clevertap_id
  WHERE TO_DATE(e.timestamp) >= '2026-11-01' AND e.event_name IN ('install_task_assigned','install_not_started_nudge_3PM','install_not_started_nudge','pn_delivered','pn_clicked','pn_ignored_logged_out')
),
dr AS (  -- install-day summary reminders have no task id: match on CSP + install date (owner/managers) or technician + install date
  SELECT e.event_name en, PARSE_JSON(e.properties):csp_id::STRING csp_id, PARSE_JSON(e.properties):technician_id::STRING technician_id,
    PARSE_JSON(e.properties):install_date::DATE install_date, PARSE_JSON(e.properties):run_slot::STRING run_slot
  FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e
  WHERE TO_DATE(e.timestamp) >= '2026-11-10' AND e.event_name IN ('install_day_reminder','install_day_executor_reminder')
)
