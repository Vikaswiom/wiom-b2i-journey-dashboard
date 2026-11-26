-- Removed tasks: who was assigned (CSP itself or another technician) x CSP reschedules, by outcome.
-- Run base.sql + this file as one statement, after changing base.sql's cohort line to
--   HAVING created_day BETWEEN '2026-10-01' AND '2026-10-31' OR created_day BETWEEN '2026-11-01' AND '2026-11-21'
-- (the Findings tab of 26 Nov 2026 uses that window; column in_doc_window counts the 6-18 Nov subset).
SELECT mon, grp, IFF(is_self_assigned IS NULL,'unknown',IFF(is_self_assigned,'self','other')) who, LEAST(n_resched,2) resched,
  COUNT(*) tasks, COUNT_IF(COALESCE(reschedule_count,0)>0) col_resched_pos, COUNT(DISTINCT csp_id) csps, COUNT(DISTINCT executor_id) technicians,
  COUNT_IF(created_day BETWEEN '2026-11-06' AND '2026-11-18') in_doc_window
FROM b GROUP BY 1,2,3,4 ORDER BY 1 DESC,2,3,4
