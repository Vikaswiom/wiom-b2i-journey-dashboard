-- Append to push_on_removed_leads_base.sql. One row per removed lead: sent, delivered and clicked per push type.
, a AS (
  SELECT l.ec,
    COUNT_IF(ev.en='install_task_assigned') asg_sent,
    COUNT_IF(ev.en='pn_delivered' AND ev.pn_type='ES_INSTALL_TECHNICIAN_ASSIGNED') asg_delivered,
    COUNT_IF(ev.en='pn_clicked' AND ev.pn_type='ES_INSTALL_TECHNICIAN_ASSIGNED') asg_clicked,
    COUNT_IF(ev.en='install_not_started_nudge_3PM') nudge_sent,
    COUNT_IF(ev.en='pn_delivered' AND ev.pn_type='ES_INSTALL_NOT_STARTED_NUDGE') nudge_delivered,
    COUNT_IF(ev.en='pn_clicked' AND ev.pn_type='ES_INSTALL_NOT_STARTED_NUDGE') nudge_clicked,
    COUNT_IF(ev.en='pn_ignored_logged_out' AND ev.ts >= l.asg_ist AND ev.ts < l.removed_ist) ignored_logged_out,
    COUNT_IF(ev.en='install_not_started_nudge') escalation_feed_sent,
    COUNT_IF(ev.en='pn_delivered' AND ev.ts >= l.asg_ist AND ev.ts < l.removed_ist) any_delivered,
    COUNT_IF(ev.en='pn_clicked' AND ev.ts >= l.asg_ist AND ev.ts < l.removed_ist) any_clicked,
    COUNT_IF(ev.en='pn_delivered' AND TO_DATE(ev.ts) > l.final_slot AND ev.ts < l.removed_ist) delivered_after_slot_day
  FROM lead l LEFT JOIN ev ON ev.ec=l.ec GROUP BY 1),
d1 AS (SELECT l.ec, COUNT_IF(dr.run_slot='9AM') rem_9am, COUNT_IF(dr.run_slot='3PM') rem_3pm FROM lead l LEFT JOIN dr ON dr.en='install_day_reminder' AND dr.csp_id=l.csp_id AND dr.install_date=l.final_slot GROUP BY 1),
d2 AS (SELECT l.ec, COUNT(dr.en) exec_rem FROM lead l LEFT JOIN dr ON dr.en='install_day_executor_reminder' AND dr.technician_id=l.executor_id AND dr.install_date=l.final_slot GROUP BY 1)
SELECT TO_CHAR(l.removed_day,'YYYY-MM-DD') removed_day, l.csp_id, l.ec, IFF(l.is_self_assigned,1,0) self_asg, a.asg_sent, a.asg_delivered, a.asg_clicked, a.nudge_sent, a.nudge_delivered, a.nudge_clicked,
  a.escalation_feed_sent, d1.rem_9am, d1.rem_3pm, d2.exec_rem, a.ignored_logged_out, a.any_delivered, a.any_clicked, a.delivered_after_slot_day
FROM lead l JOIN a ON a.ec=l.ec JOIN d1 ON d1.ec=l.ec JOIN d2 ON d2.ec=l.ec ORDER BY 1,2
