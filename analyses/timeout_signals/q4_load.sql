-- Q4 Technician and CSP load on the slot day, and whether they installed anything else in slot day..+3.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, inst AS (SELECT ec, MIN(ts) t_inst FROM tl WHERE t IN ('RATING_PENDING','CONNECTION_ACTIVE') GROUP BY 1),
xi AS (SELECT i.executor_id, i.csp_id, TO_DATE(DATEADD(minute,330,n.t_inst)) d FROM inst n JOIN iec i ON i.ec=n.ec),
tech_day AS (SELECT executor_id, d, COUNT(*) n FROM xi WHERE executor_id IS NOT NULL GROUP BY 1,2),
csp_day AS (SELECT csp_id, d, COUNT(*) n FROM xi GROUP BY 1,2),
due_t AS (SELECT executor_id, slot_date d, COUNT(*) n FROM iec WHERE executor_id IS NOT NULL GROUP BY 1,2),
due_c AS (SELECT csp_id, slot_date d, COUNT(*) n FROM iec WHERE executor_id IS NOT NULL GROUP BY 1,2),
w AS (
  SELECT b.ec, SUM(IFF(td.d=b.final_slot,td.n,0)) same_day, SUM(td.n) win4
  FROM b LEFT JOIN tech_day td ON td.executor_id=b.executor_id AND td.d BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot) GROUP BY 1),
wc AS (
  SELECT b.ec, SUM(IFF(cd.d=b.final_slot,cd.n,0)) same_day, SUM(cd.n) win4
  FROM b LEFT JOIN csp_day cd ON cd.csp_id=b.csp_id AND cd.d BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot) GROUP BY 1),
j AS (
  SELECT b.mon, b.grp, dt.n load_t, dc.n load_c,
    COALESCE(w.same_day,0) - IFF(b.inst_day=b.final_slot,1,0) t_other_same,
    COALESCE(w.win4,0) - IFF(b.inst_day BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot),1,0) t_other_win,
    COALESCE(wc.same_day,0) - IFF(b.inst_day=b.final_slot,1,0) c_other_same,
    COALESCE(wc.win4,0) - IFF(b.inst_day BETWEEN b.final_slot AND DATEADD(day,3,b.final_slot),1,0) c_other_win
  FROM b LEFT JOIN due_t dt ON dt.executor_id=b.executor_id AND dt.d=b.final_slot LEFT JOIN due_c dc ON dc.csp_id=b.csp_id AND dc.d=b.final_slot
       LEFT JOIN w ON w.ec=b.ec LEFT JOIN wc ON wc.ec=b.ec
)
SELECT mon, 'A tasks due that day for the same technician (incl. this one): tasks / timeouts / on time / late' sec, CASE WHEN load_t IS NULL THEN '0: none found' WHEN load_t=1 THEN '1: only this task' WHEN load_t=2 THEN '2: 2 tasks' WHEN load_t<=4 THEN '3: 3-4 tasks' WHEN load_t<=7 THEN '4: 5-7 tasks' ELSE '5: 8+ tasks' END k,
  COUNT(*) a, COUNT_IF(grp='timeout') b, COUNT_IF(grp='on_time') c, COUNT_IF(grp='late') d FROM j GROUP BY 1,3
UNION ALL SELECT mon, 'B tasks due that day for the same CSP: tasks / timeouts / on time / late', CASE WHEN load_c IS NULL THEN '0: none found' WHEN load_c=1 THEN '1: only this task' WHEN load_c<=3 THEN '2: 2-3 tasks' WHEN load_c<=6 THEN '3: 4-6 tasks' WHEN load_c<=10 THEN '4: 7-10 tasks' ELSE '5: 11+ tasks' END,
  COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time'), COUNT_IF(grp='late') FROM j GROUP BY 1,3
UNION ALL SELECT mon, 'C per group: tasks / technician installed another task on the slot day / in slot day..+3 / CSP installed another on the slot day', grp, COUNT(*), COUNT_IF(t_other_same>0), COUNT_IF(t_other_win>0), COUNT_IF(c_other_same>0) FROM j GROUP BY 1,3
UNION ALL SELECT mon, 'D per group: tasks / CSP installed another task in slot day..+3 / technician installed nothing in that window / CSP installed nothing in that window', grp, COUNT(*), COUNT_IF(c_other_win>0), COUNT_IF(t_other_win<=0), COUNT_IF(c_other_win<=0) FROM j GROUP BY 1,3
ORDER BY 1,2,3
