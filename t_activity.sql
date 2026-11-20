-- Day's activity funnel: tasks reaching each step for the first time on each IST day, since 1 Aug 2026
WITH tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-07-25'),
firsts AS (
  SELECT ec,
    MIN(IFF(t='ASSIGNED' AND f IS NULL, ts, NULL)) t_offer,
    MIN(IFF(t='AWAITING_TECHNICIAN_ASSIGNMENT', ts, NULL)) t_ready,
    MIN(IFF(t='TECHNICIAN_ASSIGNED', ts, NULL)) t_asg,
    MIN(IFF(t='ARRIVED_AT_SITE', ts, NULL)) t_arr,
    MIN(IFF(t='RATING_PENDING', ts, NULL)) t_otp,
    MIN(IFF(t IN ('RATING_PENDING','CONNECTION_ACTIVE'), ts, NULL)) t_act
  FROM tl GROUP BY 1
),
ev AS (
  SELECT 'offered' step, DATEADD(minute,330,t_offer)::DATE d FROM firsts WHERE t_offer IS NOT NULL UNION ALL
  SELECT 'accepted', DATEADD(minute,330,t_ready)::DATE FROM firsts WHERE t_ready IS NOT NULL UNION ALL
  SELECT 'assigned', DATEADD(minute,330,t_asg)::DATE FROM firsts WHERE t_asg IS NOT NULL UNION ALL
  SELECT 'arrived', DATEADD(minute,330,t_arr)::DATE FROM firsts WHERE t_arr IS NOT NULL UNION ALL
  SELECT 'happy_code', DATEADD(minute,330,t_otp)::DATE FROM firsts WHERE t_otp IS NOT NULL UNION ALL
  SELECT 'installed', DATEADD(minute,330,t_act)::DATE FROM firsts WHERE t_act IS NOT NULL
)
SELECT d, COUNT_IF(step='offered') offered, COUNT_IF(step='accepted') accepted, COUNT_IF(step='assigned') assigned, COUNT_IF(step='arrived') arrived, COUNT_IF(step='happy_code') happy_code, COUNT_IF(step='installed') installed
FROM ev WHERE d BETWEEN '2026-08-01' AND DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)
GROUP BY 1 ORDER BY 1
