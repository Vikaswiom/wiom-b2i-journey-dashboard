WITH tl AS (
  SELECT execution_candidate_id ec, from_state f, to_state t, reason_code rc, actor_type a, occurred_at ts
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED
),
cohort AS (
  SELECT ec, MIN(ts) created_at FROM tl WHERE t='ASSIGNED' AND f IS NULL GROUP BY 1
  HAVING TO_DATE(DATEADD(minute,330,MIN(ts))) BETWEEN DATE_TRUNC('month', DATEADD(day,-5, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)) AND DATEADD(day,-5, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)
),
ct AS (
  SELECT PARSE_JSON(properties):execution_id::STRING ec, event_name e, PARSE_JSON(properties):action::STRING act, TRY_TO_TIMESTAMP(timestamp) ts
  FROM PROD_DB.CLEVERTAP_CSP_API.EVENTS_DATA
  WHERE event_name IN ('fpn_delivered','fpn_action_taken','install_candidate_opened','install_task_created')
    AND TRY_TO_TIMESTAMP(timestamp) >= '2026-11-02'
),
ctf AS (
  SELECT ec, MAX(IFF(e='install_task_created',1,0)) pushed, MAX(IFF(e='fpn_delivered',1,0)) fpn_seen,
    MAX(IFF(e='fpn_action_taken' AND act='primary_cta',1,0)) fpn_cta, MAX(IFF(e='fpn_action_taken' AND act<>'primary_cta',1,0)) fpn_dismiss,
    MAX(IFF(e='install_candidate_opened',1,0)) opened
  FROM ct GROUP BY 1
),
f AS (
  SELECT c.ec, c.created_at,
   MIN(IFF(t='AWAITING_CSP_ACCEPTANCE',ts,NULL)) t_offer,
   MIN(IFF(f='AWAITING_CSP_ACCEPTANCE' AND t IN ('AWAITING_TECHNICIAN_ASSIGNMENT','AWAITING_SLOT_PROPOSAL'),ts,NULL)) t_acc,
   MIN(IFF(f='AWAITING_CSP_ACCEPTANCE' AND t='DECLINED',ts,NULL)) t_dec,
   MIN(IFF(f='AWAITING_CSP_ACCEPTANCE' AND rc='TIMEOUT_P41',ts,NULL)) t_noact,
   MIN(IFF(f='AWAITING_CSP_ACCEPTANCE' AND t='CANCELLED_BY_CUSTOMER',ts,NULL)) t_pre_cxcan,
   MIN(IFF(t='TECHNICIAN_ASSIGNED',ts,NULL)) t_asg,
   MIN(IFF(t='ARRIVED_AT_SITE',ts,NULL)) t_arr,
   MIN(IFF(t='FEE_COLLECTION_PENDING',ts,NULL)) t_kyc,
   MIN(IFF(f='FEE_COLLECTION_PENDING' AND t='INSTALLATION_IN_PROGRESS_POST_FEE',ts,NULL)) t_fee,
   MIN(IFF(t='AWAITING_CUSTOMER_OTP',ts,NULL)) t_setup,
   MIN(IFF(t='RATING_PENDING',ts,NULL)) t_otp,
   MIN(IFF(t IN ('RATING_PENDING','CONNECTION_ACTIVE'),ts,NULL)) t_act,
   MAX_BY(t, ts) last_state, MAX_BY(f, ts) last_from, MAX_BY(rc, ts) last_rc
  FROM cohort c JOIN tl ON tl.ec=c.ec GROUP BY 1,2
),
x AS (SELECT f.*, COALESCE(ctf.pushed,0) pushed, COALESCE(ctf.fpn_seen,0) fpn_seen, COALESCE(ctf.fpn_cta,0) fpn_cta, COALESCE(ctf.fpn_dismiss,0) fpn_dismiss, COALESCE(ctf.opened,0) opened FROM f LEFT JOIN ctf ON ctf.ec=f.ec)
