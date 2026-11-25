-- Q8 When attention events fired on timed-out tasks, relative to the final slot day.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
SELECT b.mon, a.event_type, a.reason_code,
  CASE WHEN TO_DATE(DATEADD(minute,330,a.occurred_at)) < b.final_slot THEN '1 before slot day' WHEN TO_DATE(DATEADD(minute,330,a.occurred_at)) = b.final_slot THEN '2 on slot day' WHEN DATEDIFF(day, b.final_slot, TO_DATE(DATEADD(minute,330,a.occurred_at))) <= 3 THEN '3 slot+1 to +3' ELSE '4 slot+4 or later' END when_,
  COUNT(*) events, COUNT(DISTINCT b.ec) tasks
FROM b JOIN PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_ATTENTION_EVENT_LOG a ON a.execution_candidate_id=b.ec AND NOT a._FIVETRAN_DELETED
WHERE b.grp='timeout' AND a.reason_code NOT LIKE 'Technician assigned:%'
GROUP BY 1,2,3,4 ORDER BY 1,4,5 DESC
