import json, datetime, notes
_today=(datetime.datetime.utcnow()+datetime.timedelta(minutes=330)).date()
_cf=str(_today-datetime.timedelta(days=17)); _ct=str(_today-datetime.timedelta(days=5))
raw=json.load(open('raw.json')); S=raw['sections']; f=S['funnel']['rows'][0]
r1=lambda x: round(x,1)
T=f['tasks']
steps_def=[
 (1,'Booking FPN sent to CSP','Booking FPN fires','System','TAS: ASSIGNED → AWAITING_CSP_ACCEPTANCE','CT: install_task_created → fpn_delivered','offered',None,None),
 (2,'CSP accepts','Accept on FPN / task card','CSP','AWAITING_CSP_ACCEPTANCE → AWAITING_TECHNICIAN_ASSIGNMENT','install_accepted','accepted','m_accept','p90_accept'),
 (3,'Technician assigned','Rohit picked','CSP','→ TECHNICIAN_ASSIGNED','install_task_assigned','assigned','m_assign','p90_assign'),
 (4,'Technician reached customer home','Arrival marked','Technician','→ ARRIVED_AT_SITE','—','arrived','m_arrive','p90_arrive'),
 (5,'Selfie + Aadhaar done','KYC steps','Technician','ARRIVED → PRE_FEE → FEE_COLLECTION_PENDING','—','kyc',None,None),
 (6,'Security fee collected','Customer pays','Customer','FEE_COLLECTION_PENDING → POST_FEE','—','fee',None,None),
 (7,'Device set up + speed test','Install steps','Technician','POST_FEE → AWAITING_CUSTOMER_OTP','—','setup',None,None),
 (8,'Installed','Happy code submitted: customer OTP verified, internet live','Technician','AWAITING_CUSTOMER_OTP → RATING_PENDING','—','active','m_onsite',None),
]
steps=[];prev=None
for no,step,sub,who,be,ae,k,mk,pk in steps_def:
    n=f[k]
    steps.append(dict(step_no=no,step=step,detail=sub,actor=who,backend_event=be,app_event=ae,tasks=n,
      pct_of_offered=r1(100*n/T),pct_of_prev=None if prev is None else r1(100*n/prev),lost_after_prev=None if prev is None else prev-n,
      median_min_from_prev=f[mk] if mk else None,p90_min_from_prev=round(f[pk]) if pk else None))
    prev=n
offer=[dict(outcome='Accepted',tasks=f['accepted'],median_min=f['m_accept']),dict(outcome='No response',tasks=f['no_action'],median_min=f['m_noact']),
       dict(outcome='Declined',tasks=f['declined'],median_min=f['m_decline']),dict(outcome='Customer cancelled',tasks=f['cx_cancel_pre'],median_min=None),
       dict(outcome='Other / open',tasks=T-f['accepted']-f['no_action']-f['declined']-f['cx_cancel_pre'],median_min=None)]
for o in offer:o['pct']=r1(100*o['tasks']/T)
fpn=dict(tasks_offered=T,fpn_pushed=f['pushed'],fpn_rendered=f['fpn_seen'],fpn_tapped=f['fpn_cta'],fpn_dismissed=f['fpn_dismiss_only'],task_opened=f['opened'])
for k in list(fpn): 
    if k!='tasks_offered': fpn[k+'_pct']=r1(100*fpn[k]/T)
summary=dict(tasks=T,installed=f['active'],install_pct=r1(100*f['active']/T),accept_pct=r1(100*f['accepted']/T),noaction_pct=r1(100*f['no_action']/T),
  decline_pct=r1(100*f['declined']/T),median_e2e_hours=r1(f['m_e2e']/60),p90_e2e_hours=r1(f['p90_e2e']/60),noaction_median_hours=r1(f['m_noact']/60),
  fpn_rendered_pct=r1(100*f['fpn_seen']/T),cohort_from=_cf,cohort_to=_ct)
conn={r['k']:r for r in S['conn']['rows'] if r['k']!='inst_by_ntasks'}
c=conn['conn']; summary.update(bookings=c['a'],bookings_installed=c['b'],booking_install_pct=r1(100*c['b']/c['a']),tasks_per_booking=round(c['d'],2),
  bookings_reassigned=c['a']-c['e'],bookings_reassigned_pct=r1(100*(c['a']-c['e'])/c['a']),csps=conn['csp']['a'],csps_with_noaction=conn['csp']['b'])
bk=sorted([r for r in S['conn']['rows'] if r['k']=='inst_by_ntasks'],key=lambda r:r['a'])
bookings=[dict(csps_tried=str(r['a']),bookings=int(r['c']),installed=r['b']) for r in bk]
rest_b=c['a']-sum(b['bookings'] for b in bookings); rest_i=c['b']-sum(b['installed'] for b in bookings)
bookings.append(dict(csps_tried='5+',bookings=rest_b,installed=rest_i))
for b in bookings:b['install_pct']=r1(100*b['installed']/b['bookings'])
fpnresp=[]
lab={'a':'Tapped the FPN','b':'Dismissed the FPN','c':'Saw FPN, no tap','d':'FPN never shown'}
for r in S['fpn']['rows']:
    fpnresp.append(dict(fpn_response=lab[r['grp'][0]],tasks=r['n'],accepted=r['acc'],declined=r['dec'],no_response=r['noact'],installed=r['act'],
      accept_pct=r1(100*r['acc']/r['n']),no_response_pct=r1(100*r['noact']/r['n']),install_pct=r1(100*r['act']/r['n'])))
stage_lab={'1':'After FPN','2':'After accept','3':'After tech assigned','4':'After reaching customer home'}
out_lab={'CANCELLED_BY_UPSTREAM':'System cancelled','DECLINED':'CSP declined','INSTALLATION_REPORTED_FAILED':'CSP reported failure','CANCELLED_BY_CUSTOMER':'Customer cancelled'}
rc_lab={'TIMEOUT_P41':'No response before deadline','CSP_NO_SHOW':'Timed out, task not moved','COVERAGE_NOT_FEASIBLE':'No coverage at address','OTHER':'Other (free text)',
 'DEVICE_UNAVAILABLE':'No Netbox in hand','CUSTOMER_CANCELLED':'Customer cancelled (per CSP)','USER_CANCELLATION':'Customer cancelled in app',
 'CUSTOMER_UNREACHABLE':'Customer unreachable','CANCEL_BY_CUSTOMER_BACKEND':'Cancelled by ops','SUSPENDED':'CSP suspended'}
agg={}; note_rows=[]
for r in S['exits']['rows']:
    st=r['stage'][0]
    if st=='9':continue
    o=out_lab.get(r['last_state'],'Still open')
    lbl='Still open' if o=='Still open' else rc_lab.get(r['rc'],r['rc'])
    key=(st,o,lbl); agg[key]=agg.get(key,0)+r['n']
    note_rows.append(dict(stage_no=int(st),outcome=o,reason=lbl,note=r.get('note'),n=r['n']))
exits=[dict(stage_no=int(k[0]),stage=stage_lab[k[0]],outcome=k[1],reason=k[2],tasks=v) for k,v in agg.items()]
exits.sort(key=lambda e:(e['stage_no'],-e['tasks']))
tot_noact=sum(r['noact'] for r in S['cspband']['rows']); tot_t=sum(r['tasks'] for r in S['cspband']['rows'])
bl={'1':'Accept 70%+ of FPNs','2':'Accept 40–70%','3':'Accept under 40%','4':'Never accepted'}
bands=[dict(csp_group=bl[r['band'][0]],csps=r['csps'],tasks=r['tasks'],accepted=r['acc'],no_response=r['noact'],installed=r['act'],
  share_of_tasks=r1(100*r['tasks']/tot_t),share_of_no_response=r1(100*r['noact']/tot_noact),install_pct=r1(100*r['act']/r['tasks'])) for r in S['cspband']['rows']]
hourly=[dict(hour=r['h'],tasks=r['n'],accepted=r['acc'],no_response=r['noact'],accept_pct=r1(100*r['acc']/r['n']),no_response_pct=r1(100*r['noact']/r['n'])) for r in S['hour']['rows']]
daily=[dict(date=r['d'],tasks=r['n'],fpn_rendered=r['seen'],accepted=r['acc'],declined=r['dec'],no_response=r['noact'],assigned=r['asg'],arrived=r['arr'],installed=r['act'],
  accept_pct=r1(100*r['acc']/r['n']),no_response_pct=r1(100*r['noact']/r['n']),install_pct=r1(100*r['act']/r['n'])) for r in S['daily']['rows']]
sqlmap={'steps':'funnel','offer':'funnel','fpn_reach':'funnel','summary':'funnel','exits':'exits','fpn_response':'fpn','bookings':'conn','csp_groups':'cspband','hourly':'hour','daily':'daily','exit_notes':'exits'}
data=dict(summary=[summary],steps=steps,offer=offer,fpn_reach=[fpn],exits=exits,fpn_response=fpnresp,bookings=bookings,csp_groups=bands,hourly=hourly,daily=daily,exit_notes=notes.build(note_rows,['stage_no','outcome','reason']) or [dict(stage_no=0,outcome='',reason='',theme='',tasks=0,examples='',notes_total=0,reason_total=0)])
shape_code=open('shape.py').read()
out={'generated_at':raw['generated_at'],'cohort':raw['cohort'],'datasets':{k:{'rows':v,'sql':S[sqlmap[k]]['sql']} for k,v in data.items()},'shape_code':shape_code}
json.dump(out,open('b2i_snapshot.json','w'),indent=0,default=str)
print(json.dumps(summary,indent=0)); print(exits[:6]); print(bands); print(bookings)
