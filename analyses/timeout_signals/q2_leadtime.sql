-- Q2 Lead times: assignment vs slot day, creation to assignment, slot weekday, when the timeout fires.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
SELECT mon, 'A technician assigned vs original slot day: tasks / timeouts / on time / late' sec,
  CASE WHEN DATEDIFF(day, asg_day, orig_slot) < 0 THEN '1: after the slot day had passed' WHEN DATEDIFF(day, asg_day, orig_slot)=0 THEN '2: on the slot day' WHEN DATEDIFF(day, asg_day, orig_slot)=1 THEN '3: 1 day before' WHEN DATEDIFF(day, asg_day, orig_slot)=2 THEN '4: 2 days before' ELSE '5: 3+ days before' END k,
  COUNT(*) a, COUNT_IF(grp='timeout') b, COUNT_IF(grp='on_time') c, COUNT_IF(grp='late') d FROM b GROUP BY 1,3
UNION ALL SELECT mon, 'B task created to technician assigned: tasks / timeouts / on time / late',
  CASE WHEN DATEDIFF(minute, t_created, t_asg) < 60 THEN '1: under 1 h' WHEN DATEDIFF(minute, t_created, t_asg) < 360 THEN '2: 1-6 h' WHEN DATEDIFF(minute, t_created, t_asg) < 1440 THEN '3: 6-24 h' WHEN DATEDIFF(minute, t_created, t_asg) < 2880 THEN '4: 1-2 days' ELSE '5: 2+ days' END,
  COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time'), COUNT_IF(grp='late') FROM b GROUP BY 1,3
UNION ALL SELECT mon, 'C task created to original slot day: tasks / timeouts / on time / late',
  CASE WHEN DATEDIFF(day, created_day, orig_slot) <= 0 THEN '1: same day or earlier' WHEN DATEDIFF(day, created_day, orig_slot)=1 THEN '2: next day' WHEN DATEDIFF(day, created_day, orig_slot)=2 THEN '3: 2 days' WHEN DATEDIFF(day, created_day, orig_slot)<=4 THEN '4: 3-4 days' ELSE '5: 5+ days' END,
  COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time'), COUNT_IF(grp='late') FROM b GROUP BY 1,3
UNION ALL SELECT mon, 'D slot weekday (original): tasks / timeouts / on time / late', DAYOFWEEKISO(orig_slot)||': '||DAYNAME(orig_slot), COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time'), COUNT_IF(grp='late') FROM b GROUP BY 1,3
UNION ALL SELECT mon, 'E timeout fired N days after the final slot day (timeouts only)', DATEDIFF(day, final_slot, TO_DATE(DATEADD(minute,330,t_end)))::STRING, COUNT(*), NULL, NULL, NULL FROM b WHERE grp='timeout' GROUP BY 1,3
UNION ALL SELECT mon, 'F hour of day technician was assigned (IST): tasks / timeouts / on time / late', LPAD(FLOOR(HOUR(DATEADD(minute,330,t_asg))/4)*4,2,'0')||'h block', COUNT(*), COUNT_IF(grp='timeout'), COUNT_IF(grp='on_time'), COUNT_IF(grp='late') FROM b GROUP BY 1,3
ORDER BY 1,2,3
