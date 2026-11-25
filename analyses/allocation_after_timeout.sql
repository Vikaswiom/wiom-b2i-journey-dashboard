-- Why bookings were not reassigned after a CSP_NO_SHOW timeout: first ROUTING_FAILURE after the timeout and the exclusion reason per candidate CSP.
WITH n(cid,tout,tcsp) AS (SELECT * FROM VALUES <(connection_id, timed_out_ist, timed_out_csp) rows from timeout_bookings_*.tsv where latest task = timed-out task and not installed>),
a AS (SELECT n.cid, n.tcsp, n.tout, l.log_type, l.selected_csp_id, l.failure_flag, l.details, l.created_at FROM n JOIN PROD_DB.CSP_DEMAND_ALLOCATION_SERVICE_CSP_DEMAND_ALLOCATION_SERVICE.ALLOCATION_AUDIT_LOG l ON l.connection_id=n.cid AND DATEADD(minute,330,l.created_at::TIMESTAMP_NTZ) >= DATEADD(minute,-5,n.tout)),
f AS (SELECT * FROM a WHERE log_type='ROUTING_FAILURE' QUALIFY ROW_NUMBER() OVER (PARTITION BY cid ORDER BY created_at)=1),
e AS (SELECT f.cid, x.value:reason::STRING reason, x.value:csp_id::STRING=f.tcsp is_same FROM f, LATERAL FLATTEN(input=>TRY_PARSE_JSON(f.details::STRING):stages:"3b_eligibility":excluded, outer=>TRUE) x),
c AS (SELECT cid, COUNT(reason) n_cand, SUM(IFF(is_same,1,0)) has_same, MAX(IFF(is_same,reason,NULL)) same_reason,
  LISTAGG(DISTINCT IFF(is_same,NULL,reason),',') WITHIN GROUP (ORDER BY IFF(is_same,NULL,reason)) other_reasons FROM e GROUP BY 1),
ag AS (SELECT cid, MAX(IFF(selected_csp_id IS NOT NULL,1,0)) picked, MIN(DATEDIFF(minute,tout,DATEADD(minute,330,created_at::TIMESTAMP_NTZ))) min_after, COUNT(*) n_logs FROM a GROUP BY 1),
k AS (SELECT n.cid,
  CASE WHEN c.cid IS NOT NULL AND c.n_cand=0 THEN 'Failure, no candidate CSPs at all'
       WHEN c.cid IS NOT NULL AND c.n_cand=c.has_same THEN 'Only the timed-out CSP was a candidate'
       WHEN c.cid IS NOT NULL THEN 'Timed-out CSP plus others'
       WHEN ag.picked=1 THEN 'Allocation picked a CSP, but no task'
       WHEN ag.cid IS NOT NULL THEN 'Other allocation log only'
       ELSE 'No reroute attempt logged' END grp,
  c.same_reason, c.other_reasons, ag.min_after
  FROM n LEFT JOIN c ON c.cid=n.cid LEFT JOIN ag ON ag.cid=n.cid)
SELECT grp, COALESCE(same_reason,'') same_reason, COALESCE(other_reasons,'') other_reasons, COUNT(*) conns, MEDIAN(min_after) med_min_after FROM k GROUP BY 1,2,3 ORDER BY 1,4 DESC