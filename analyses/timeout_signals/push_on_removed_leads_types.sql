-- Append to push_on_removed_leads_base.sql. Every push or feed event on the removed leads, by type, recipient role and timing.
SELECT ev.en, ev.pn_type, COALESCE(ev.role,'-') role,
  CASE WHEN ev.ts < l.asg_ist THEN '0 before technician assigned' WHEN TO_DATE(ev.ts) < l.final_slot THEN '1 after assigned, before slot day' WHEN TO_DATE(ev.ts) = l.final_slot THEN '2 on slot day'
       WHEN ev.ts < l.removed_ist THEN '3 slot+1 to removal' ELSE '4 at or after removal' END when_,
  COUNT(*) events, COUNT(DISTINCT l.ec) leads
FROM lead l JOIN ev ON ev.ec=l.ec GROUP BY 1,2,3,4 ORDER BY 4,2,1,3
