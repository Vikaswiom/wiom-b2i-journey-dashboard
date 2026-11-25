-- Q5 Was the assigned person active in the app on the slot day, or ever since 1 Oct.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, p AS (SELECT clevertap_id, MAX(identity) identity FROM PROD_DB.CLEVERTAP_CSP_API.PROFILE_DATA GROUP BY 1),
act AS (SELECT p.identity, TO_DATE(e.timestamp) d FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA e JOIN p ON p.clevertap_id=e.clevertap_id
        WHERE TO_DATE(e.timestamp) >= '2026-10-01' AND e.properties LIKE '%"CT Source": "Mobile"%' GROUP BY 1,2),
ever AS (SELECT identity, COUNT(*) days FROM act GROUP BY 1),
w AS (SELECT b.ec, COUNT_IF(act.d=b.final_slot) same_day, COUNT(act.d) days_in_win
      FROM b LEFT JOIN act ON act.identity=b.executor_id::STRING AND act.d BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot) GROUP BY 1)
SELECT b.mon, b.grp, IFF(b.is_self_assigned,'CSP itself','separate technician') who, COUNT(*) tasks, COUNT_IF(w.same_day>0) assignee_in_app_on_slot_day, COUNT_IF(w.days_in_win>0) assignee_in_app_slot_to_plus3,
  COUNT_IF(ever.identity IS NULL) assignee_never_in_app_since_1_oct, COUNT_IF(ever.days BETWEEN 1 AND 5) assignee_in_app_1_to_5_days_total
FROM b LEFT JOIN w ON w.ec=b.ec LEFT JOIN ever ON ever.identity=b.executor_id::STRING GROUP BY 1,2,3 ORDER BY 1,2,3
