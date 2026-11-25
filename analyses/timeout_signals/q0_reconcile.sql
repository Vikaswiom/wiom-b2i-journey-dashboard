-- Reconcile: tasks, bookings, CSPs and technicians per month and group.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
SELECT mon, grp, COUNT(*) tasks, COUNT(DISTINCT connection_id) bookings, COUNT(DISTINCT csp_id) csps, COUNT(executor_id) has_exec, COUNT(DISTINCT executor_id) techs,
  COUNT_IF(is_self_assigned) self_asg, COUNT(pincode) has_pin, COUNT(zone_id) has_zone, COUNT(orig_slot) has_slot, COUNT_IF(n_resched>0) resched, COUNT_IF(n_asg>1) reassigned_tech
FROM b GROUP BY ROLLUP(mon, grp) ORDER BY 1,2
