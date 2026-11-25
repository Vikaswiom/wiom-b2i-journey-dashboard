-- Timeouts by slot week; CSPs with other work due that installed nothing in the window.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, inst AS (SELECT ec, MIN(ts) t_inst FROM tl WHERE t IN ('RATING_PENDING','CONNECTION_ACTIVE') GROUP BY 1),
csp_day AS (SELECT i.csp_id, TO_DATE(DATEADD(minute,330,n.t_inst)) d, COUNT(*) n FROM inst n JOIN iec i ON i.ec=n.ec GROUP BY 1,2),
due_c AS (SELECT csp_id, slot_date d, COUNT(*) n FROM iec WHERE executor_id IS NOT NULL GROUP BY 1,2),
j AS (
  SELECT b.ec, b.mon, b.grp, b.final_slot, b.inst_day,
    (SELECT 1) one,
    COALESCE((SELECT SUM(cd.n) FROM csp_day cd WHERE cd.csp_id=b.csp_id AND cd.d BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot)),0) - IFF(b.inst_day BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot),1,0) c_inst_win,
    COALESCE((SELECT SUM(dc.n) FROM due_c dc WHERE dc.csp_id=b.csp_id AND dc.d BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot)),0) - 1 c_other_due_win
  FROM b)
SELECT mon, 'A slot week (final slot, week starting Monday): tasks / timeouts' sec, TO_CHAR(DATE_TRUNC('week', final_slot),'YYYY-MM-DD') k, COUNT(*) a, COUNT_IF(grp='timeout') b, NULL c FROM j GROUP BY 1,3
UNION ALL SELECT mon, 'B '||grp||': tasks / CSP had other technician-assigned tasks due in slot day..+3 / of those, CSP installed none in that window', '', COUNT(*), COUNT_IF(c_other_due_win>0), COUNT_IF(c_other_due_win>0 AND c_inst_win<=0) FROM j WHERE grp IN ('timeout','on_time') GROUP BY 1,2
ORDER BY 1,2,3
