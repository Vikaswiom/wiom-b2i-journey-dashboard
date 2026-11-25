-- What the app shows for each timed-out task (called / opened / untouched) and the last touch.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, p AS (SELECT clevertap_id, MAX(UPPER(role)) role, MAX(identity) identity FROM PROD_DB.CLEVERTAP_CSP_API.PROFILE_DATA GROUP BY 1),
ce AS (
  SELECT PARSE_JSON(e.properties):execution_id::STRING ec, e.event_name en, TRY_TO_TIMESTAMP(e.timestamp) ts, p.identity, PARSE_JSON(e.properties):target::STRING target
  FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e LEFT JOIN p ON p.clevertap_id=e.clevertap_id
  WHERE TO_DATE(e.timestamp) >= '2026-10-01' AND e.event_name IN ('install_candidate_opened','call_initiated')
),
act AS (SELECT p.identity FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e JOIN p ON p.clevertap_id=e.clevertap_id
        WHERE TO_DATE(e.timestamp) >= '2026-10-01' AND e.properties LIKE '%"CT Source": "Mobile"%' GROUP BY 1),
a AS (
  SELECT b.ec, b.mon, b.grp, b.n_resched, b.is_self_assigned, IFF(act.identity IS NULL,1,0) never_app,
    COUNT_IF(en='install_candidate_opened' AND ts >= DATEADD(minute,330,b.t_asg)) o_any,
    COUNT_IF(en='call_initiated' AND target='customer') c_any,
    COUNT_IF(en='call_initiated' AND target='customer' AND TO_DATE(ts) <= b.final_slot) c_by_slot,
    MAX(IFF(en IN ('install_candidate_opened','call_initiated'), DATEDIFF(day, b.final_slot, TO_DATE(ts)), NULL)) last_touch_vs_slot
  FROM b LEFT JOIN ce ON ce.ec=b.ec LEFT JOIN act ON act.identity=b.executor_id::STRING
  WHERE b.grp='timeout' GROUP BY 1,2,3,4,5,6)
SELECT mon, 'A what the app shows for each timed-out task' sec,
  CASE WHEN c_by_slot>0 THEN '1: customer called from the app on or before the slot day'
       WHEN c_any>0 THEN '2: customer called from the app, only after the slot day'
       WHEN o_any>0 THEN '3: task opened after assignment, customer never called from the app'
       WHEN never_app=1 AND NOT is_self_assigned THEN '4: no open or call; assigned technician not seen in the app since 1 Oct'
       ELSE '5: no open or call after assignment' END k, COUNT(*) n, COUNT_IF(n_resched>0) rescheduled
FROM a GROUP BY 1,3
UNION ALL SELECT mon, 'B last open or call on the task, in days relative to the final slot day', CASE WHEN last_touch_vs_slot IS NULL THEN '0: none' WHEN last_touch_vs_slot<0 THEN '1: before the slot day' WHEN last_touch_vs_slot=0 THEN '2: on the slot day' WHEN last_touch_vs_slot=1 THEN '3: 1 day after' WHEN last_touch_vs_slot<=3 THEN '4: 2-3 days after' ELSE '5: 4+ days after (around or after the timeout)' END, COUNT(*), NULL FROM a GROUP BY 1,3
ORDER BY 1,2,3
