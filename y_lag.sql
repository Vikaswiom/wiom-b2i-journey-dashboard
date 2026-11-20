-- Yesterday's installs traced back: how many days before the install each earlier step first happened
WITH p AS (SELECT DATEADD(day,-1, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE) yday),
tl AS (SELECT execution_candidate_id ec, from_state f, to_state t, occurred_at::TIMESTAMP_NTZ ts FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED AND occurred_at >= '2026-09-01'),
firsts AS (
  SELECT ec,
    DATEADD(minute,330,MIN(IFF(t='ASSIGNED' AND f IS NULL, ts, NULL)))::DATE d_offer,
    DATEADD(minute,330,MIN(IFF(t='AWAITING_TECHNICIAN_ASSIGNMENT', ts, NULL)))::DATE d_ready,
    DATEADD(minute,330,MIN(IFF(t='TECHNICIAN_ASSIGNED', ts, NULL)))::DATE d_asg,
    DATEADD(minute,330,MIN(IFF(t='ARRIVED_AT_SITE', ts, NULL)))::DATE d_arr,
    DATEADD(minute,330,MIN(IFF(t='RATING_PENDING', ts, NULL)))::DATE d_otp,
    DATEADD(minute,330,MIN(IFF(t IN ('RATING_PENDING','CONNECTION_ACTIVE'), ts, NULL)))::DATE d_act
  FROM tl GROUP BY 1
),
y AS (SELECT * FROM firsts WHERE d_act = (SELECT yday FROM p))
SELECT step, CASE WHEN lag IS NULL THEN 'Not recorded' WHEN lag<=0 THEN 'Same day' WHEN lag=1 THEN '1 day before' WHEN lag<=3 THEN '2–3 days before' ELSE '4+ days before' END lag_bucket, COUNT(*) installs
FROM (
  SELECT 'arrived' step, DATEDIFF(day,d_arr,d_act) lag FROM y UNION ALL
  SELECT 'assigned', DATEDIFF(day,d_asg,d_act) FROM y UNION ALL
  SELECT 'accepted', DATEDIFF(day,d_ready,d_act) FROM y UNION ALL
  SELECT 'offered', DATEDIFF(day,d_offer,d_act) FROM y
) GROUP BY 1,2 ORDER BY 1,2
