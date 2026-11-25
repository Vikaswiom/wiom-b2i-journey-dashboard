-- Q8 Reminders and urgent attention events per group.
-- Append to base.sql (it ends inside a WITH list, at CTE b) and run the two together.
, at AS (
  SELECT a.execution_candidate_id ec,
    COUNT_IF(a.reason_code='INSTALL_DAY_REMINDER') n_day_rem, COUNT_IF(a.reason_code='ARRIVED_AT_SITE_URGENT') n_arr_urgent,
    COUNT_IF(a.reason_code='TECHNICIAN_ASSIGNMENT_URGENT') n_asg_urgent, COUNT_IF(a.reason_code='CSP changed install date') n_date_change,
    COUNT_IF(a.event_type='OPERATIONAL') n_operational, COUNT_IF(a.event_type='THRESHOLD_CROSSING') n_threshold
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_ATTENTION_EVENT_LOG a WHERE a.occurred_at >= '2026-09-30' AND NOT a._FIVETRAN_DELETED GROUP BY 1)
SELECT b.mon, b.grp, COUNT(*) tasks, COUNT_IF(at.ec IS NOT NULL) any_attention_row, COUNT_IF(n_day_rem>0) install_day_reminder, COUNT_IF(n_arr_urgent>0) arrived_urgent,
  COUNT_IF(n_asg_urgent>0) assign_urgent, COUNT_IF(n_date_change>0) date_change, COUNT_IF(n_operational>0) any_operational, COUNT_IF(n_threshold>0) any_threshold, COUNT_IF(customer_call_recorded_at IS NOT NULL) customer_call_recorded
FROM b LEFT JOIN at ON at.ec=b.ec GROUP BY 1,2 ORDER BY 1,2
