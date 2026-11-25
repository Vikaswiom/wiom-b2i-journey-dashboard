-- Q5/Q7 App opens and app-initiated calls to the customer (CleverTap), by role.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, p AS (SELECT clevertap_id, MAX(UPPER(role)) role, MAX(identity) identity FROM PROD_DB.CLEVERTAP_CSP_API.PROFILE_DATA GROUP BY 1),
ce AS (
  SELECT PARSE_JSON(e.properties):execution_id::STRING ec, e.event_name en, TRY_TO_TIMESTAMP(e.timestamp) ts, p.role, p.identity, PARSE_JSON(e.properties):target::STRING target
  FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e LEFT JOIN p ON p.clevertap_id=e.clevertap_id
  WHERE TO_DATE(e.timestamp) >= '2026-10-01' AND e.event_name IN ('install_candidate_opened','install_task_assigned','call_initiated')
),
a AS (
  SELECT b.ec, b.mon, b.grp,
    COUNT_IF(en='install_task_assigned') n_push,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg)) o_any,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg) AND (role='TECHNICIAN' OR identity=b.executor_id::STRING)) o_tech,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg) AND identity=b.executor_id::STRING) o_assignee,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg) AND role IN ('OWNER','MANAGER','MANAGER_PLUS')) o_csp,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg) AND TO_DATE(ts) = b.final_slot) o_on_slot,
    COUNT_IF(en='install_candidate_opened' AND TO_DATE(ts) > b.final_slot) o_after_slot,
    COUNT_IF(en='install_candidate_opened' AND TO_DATE(ts) > b.final_slot AND identity=b.executor_id::STRING) o_after_slot_assignee,
    COUNT_IF(en='call_initiated' AND target='customer') c_any,
    COUNT_IF(en='call_initiated' AND target='customer' AND TO_DATE(ts) <= b.final_slot) c_by_slot,
    COUNT_IF(en='call_initiated' AND target='customer' AND ts >= DATEADD(minute,330,b.t_asg)) c_after_asg,
    COUNT_IF(en='call_initiated' AND target='customer' AND identity=b.executor_id::STRING) c_assignee
  FROM b LEFT JOIN ce ON ce.ec=b.ec GROUP BY 1,2,3)
SELECT mon, grp, COUNT(*) tasks, COUNT_IF(n_push>0) push_to_assignee, COUNT_IF(o_any>0) opened_by_anyone_after_assign, COUNT_IF(o_tech>0) opened_by_technician, COUNT_IF(o_assignee>0) opened_by_assigned_person,
  COUNT_IF(o_csp>0) opened_by_owner_or_manager, COUNT_IF(o_on_slot>0) opened_on_slot_day, COUNT_IF(o_after_slot>0) opened_after_slot_day, COUNT_IF(o_after_slot_assignee>0) opened_after_slot_by_assignee,
  COUNT_IF(c_any>0) call_any, COUNT_IF(c_by_slot>0) call_by_slot_day, COUNT_IF(c_after_asg>0) call_after_assign, COUNT_IF(c_assignee>0) call_by_assignee
FROM a GROUP BY 1,2 ORDER BY 1,2
