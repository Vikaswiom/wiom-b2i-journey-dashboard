WITH tl AS (
  SELECT execution_candidate_id ec, from_state f, to_state t, reason_code rc, occurred_at ts
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE NOT _FIVETRAN_DELETED
),
cohort AS (
  SELECT ec FROM tl WHERE t='ASSIGNED' AND f IS NULL GROUP BY 1
  HAVING TO_DATE(DATEADD(minute,330,MIN(ts))) BETWEEN DATEADD(day,-17, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE) AND DATEADD(day,-5, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE)
),
asg AS (SELECT c.ec FROM cohort c JOIN tl ON tl.ec=c.ec AND tl.t='TECHNICIAN_ASSIGNED' GROUP BY 1),
iec AS (SELECT execution_candidate_id ec, slot_date, terminal_outcome FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _FIVETRAN_ACTIVE QUALIFY ROW_NUMBER() OVER (PARTITION BY execution_candidate_id ORDER BY _fivetran_synced DESC)=1),
rd AS (
  SELECT PARSE_JSON(payload):execution_candidate_id::STRING ec,
    COUNT_IF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE') n_resched,
    MIN_BY(PARSE_JSON(payload):original_slot_date::DATE, IFF(PARSE_JSON(payload):source::STRING='CSP_RESCHEDULE', created_at, NULL)) first_orig
  FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD
  WHERE created_at >= '2026-11-01' AND payload ILIKE '%ES_INSTALL_SLOT_AUTO_REDATED%'
  GROUP BY 1
),
st AS (
  SELECT a.ec,
   MIN(IFF(t='TECHNICIAN_ASSIGNED',ts,NULL)) t_asg,
   MIN(IFF(t='ARRIVED_AT_SITE',ts,NULL)) t_arr,
   MIN(IFF(t='FEE_COLLECTION_PENDING',ts,NULL)) t_kyc,
   MIN(IFF(f='FEE_COLLECTION_PENDING' AND t='INSTALLATION_IN_PROGRESS_POST_FEE',ts,NULL)) t_fee,
   MIN(IFF(t='AWAITING_CUSTOMER_OTP',ts,NULL)) t_setup,
   MIN(IFF(t='RATING_PENDING',ts,NULL)) t_otp,
   MIN(IFF(t IN ('RATING_PENDING','CONNECTION_ACTIVE'),ts,NULL)) t_act,
   MAX(IFF(t IN ('CANCELLED_BY_UPSTREAM','CANCELLED_BY_CUSTOMER','INSTALLATION_REPORTED_FAILED','DECLINED','RATING_PENDING','CONNECTION_ACTIVE'),ts,NULL)) t_end,
   MAX_BY(t, ts) cur_state, MAX_BY(f, ts) end_from, MAX_BY(rc, ts) end_rc, MAX(ts) t_last
  FROM asg a JOIN tl ON tl.ec=a.ec GROUP BY 1
),
-- when the task last entered the state it ended (or sits) in
entered AS (
  SELECT s.ec, MAX(tl.ts) t_enter_stage
  FROM st s JOIN tl ON tl.ec=s.ec AND tl.t = IFF(s.t_end IS NULL, s.cur_state, s.end_from) AND COALESCE(tl.f,'') <> tl.t AND tl.ts <= COALESCE(s.t_end, s.t_last)
  GROUP BY 1
),
x AS (
  SELECT s.*, e.t_enter_stage, i.slot_date final_slot, i.terminal_outcome,
    COALESCE(rd.n_resched,0) n_resched, COALESCE(rd.first_orig, i.slot_date) orig_slot,
    TO_DATE(DATEADD(minute,330,s.t_act)) inst_day,
    CASE WHEN s.t_end IS NULL THEN 'Open' WHEN s.t_act IS NOT NULL THEN 'Installed'
         WHEN s.cur_state='INSTALLATION_REPORTED_FAILED' THEN 'CSP reported failure'
         WHEN s.cur_state='CANCELLED_BY_CUSTOMER' THEN 'Customer cancelled'
         WHEN s.end_rc='CSP_NO_SHOW' THEN 'System timeout (no-show)'
         ELSE 'Cancelled by ops / other' END outcome,
    CASE COALESCE(IFF(s.t_end IS NULL, s.cur_state, s.end_from),'')
      WHEN 'TECHNICIAN_ASSIGNED' THEN '1 Technician assigned, not at home'
      WHEN 'ARRIVED_AT_SITE' THEN '2 Technician reached customer home'
      WHEN 'INSTALLATION_IN_PROGRESS_PRE_FEE' THEN '3 Selfie / Aadhaar'
      WHEN 'FEE_COLLECTION_PENDING' THEN '4 Waiting for fee'
      WHEN 'INSTALLATION_IN_PROGRESS_POST_FEE' THEN '5 Device setup'
      WHEN 'AWAITING_CUSTOMER_OTP' THEN '6 Waiting for happy code'
      WHEN 'RATING_PENDING' THEN '7 Waiting for rating'
      ELSE '9 Other' END stage
  FROM st s LEFT JOIN entered e ON e.ec=s.ec LEFT JOIN iec i ON i.ec=s.ec LEFT JOIN rd ON rd.ec=s.ec
)
SELECT outcome, stage,
  CASE WHEN m < 120 THEN '1 Under 2 h' WHEN m < 720 THEN '2 2–12 h' WHEN m < 1440 THEN '3 12–24 h' WHEN m < 2880 THEN '4 1–2 days' WHEN m < 4320 THEN '5 2–3 days' ELSE '6 3+ days' END time_in_stage,
  COALESCE(end_rc,'-') rc, COUNT(*) n
FROM (SELECT x.*, DATEDIFF(minute, t_enter_stage, COALESCE(t_end, CURRENT_TIMESTAMP())) m FROM x WHERE outcome<>'Installed')
GROUP BY 1,2,3,4 ORDER BY 1,2,3
