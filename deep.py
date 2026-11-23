import json, subprocess, urllib.request, datetime, notes
_today=(datetime.datetime.utcnow()+datetime.timedelta(minutes=330)).date()
import os
key = os.environ.get('METABASE_API_KEY') or subprocess.check_output(['security','find-generic-password','-s','wiom-metabase-api-key','-w']).decode().strip()
def run(sql):
    req = urllib.request.Request('https://metabase.wiom.in/api/dataset', data=json.dumps({"database":113,"type":"native","native":{"query":sql}}).encode(), headers={'x-api-key':key,'Content-Type':'application/json'})
    r = json.load(urllib.request.urlopen(req, timeout=600)); d=r['data']
    if r.get('error'): raise SystemExit(r['error'])
    cols=[c['name'].lower() for c in d['cols']]
    return [dict(zip(cols,row)) for row in d['rows']]
R={k:{'sql':open(k+'.sql').read()} for k in ['d_funnel','d_timing','d_notinst','d_live']}
for k in R: R[k]['rows']=run(R[k]['sql'])
gen=datetime.datetime.now().astimezone().isoformat(timespec='minutes')
r1=lambda x: round(x,1)
f=R['d_funnel']['rows'][0]; A=f['assigned']
defs=[(1,'Technician assigned','assigned',None,None),(2,'Technician reached customer home','arrived','m_arr','p_arr'),(3,'Selfie + Aadhaar done','kyc','m_kyc','p_kyc'),
 (4,'Security fee collected','fee','m_fee','p_fee'),(5,'Device set up + speed test','setup','m_setup','p_setup'),(6,'Installed (happy code submitted)','installed','m_otp','p_otp')]
steps=[];prev=None
for no,nm,k,m,p in defs:
    n=f[k]; steps.append(dict(step_no=no,step=nm,tasks=n,pct_of_assigned=r1(100*n/A),pct_of_prev=None if prev is None else r1(100*n/prev),lost=None if prev is None else prev-n,
      median_min=None if m is None else f[m],p90_min=None if p is None else round(f[p]))); prev=n
T=R['d_timing']['rows']
lab={'1':'Before slot day','2':'On slot day','3':'After slot day'}
timing=[]
for c in '123':
    rs=[r for r in T if r['timing'][0]==c]; n=sum(r['n'] for r in rs)
    timing.append(dict(timing=lab[c],installs=n,pct=r1(100*n/f['installed']),rescheduled=sum(r['n'] for r in rs if r['resched']=='Rescheduled')))
days={}
for r in T:
    k=int(r['days_vs_slot']); days.setdefault(k,{'days_vs_slot':k,'installs':0,'rescheduled':0})
    days[k]['installs']+=r['n']; days[k]['rescheduled']+=r['n'] if r['resched']=='Rescheduled' else 0
days=[days[k] for k in sorted(days)]
for d in days: d['timing']='Before slot day' if d['days_vs_slot']<0 else ('On slot day' if d['days_vs_slot']==0 else 'After slot day'); d['not_rescheduled']=d['installs']-d['rescheduled']
late={}
for r in T:
    if r['late_bucket']: late[r['late_bucket']]=late.get(r['late_bucket'],0)+r['n']
nl=sum(late.values()); late=[dict(late_by=k[2:],order=int(k[0]),installs=v,pct_of_late=r1(100*v/nl)) for k,v in sorted(late.items())]
a2i={}
for r in T:
    key=(r['asg_to_inst'],lab[r['timing'][0]]); a2i[key]=a2i.get(key,0)+r['n']
buckets=sorted({k[0] for k in a2i})
asg=[dict(order=int(b[0]),assign_to_install=b[2:],before_slot_day=a2i.get((b,'Before slot day'),0),on_slot_day=a2i.get((b,'On slot day'),0),after_slot_day=a2i.get((b,'After slot day'),0)) for b in buckets]
for a in asg: a['installs']=a['before_slot_day']+a['on_slot_day']+a['after_slot_day']
N=R['d_notinst']['rows']
rc_lab={'TIMEOUT_P41':'No response before deadline','CSP_NO_SHOW':'System timeout, task not moved','COVERAGE_NOT_FEASIBLE':'No coverage at address','OTHER':'Other (free text)',
 'DEVICE_UNAVAILABLE':'No Netbox in hand','CUSTOMER_CANCELLED':'Customer cancelled (per CSP)','USER_CANCELLATION':'Customer cancelled in app','CUSTOMER_UNREACHABLE':'Customer unreachable',
 'CANCEL_BY_CUSTOMER_BACKEND':'Cancelled by ops','SUSPENDED':'CSP suspended','TECHNICIAN_ASSIGNED_AWAITING_ARRIVAL':'Waiting for arrival','TECHNICIAN_CHANGED':'Technician changed',
 'CUSTOMER_ASKED_OTHER_DAY':'Customer asked for another day','NO_INSTALLER_AVAILABLE':'No installer available','OTP_VERIFIED':'Happy code done, rating pending',
 'STEP_SELFIE_SUBMITTED_BY_CSP':'Selfie done, Aadhaar pending','STEP_SELFIE_SUBMITTED_BY_TECHNICIAN':'Selfie done, Aadhaar pending'}
stuck={};reasons={};note_rows=[]
for r in N:
    st=r['stage'][2:]; k=(r['outcome'],st,r['time_in_stage'])
    stuck[k]=stuck.get(k,0)+r['n']
    k2=(r['outcome'],st,rc_lab.get(r['rc'],r['rc'])); reasons[k2]=reasons.get(k2,0)+r['n']
    note_rows.append(dict(outcome=k2[0],stage=k2[1],reason=k2[2],note=r.get('note'),n=r['n']))
stuck=[dict(outcome=k[0],stage=k[1],time_in_stage=k[2][2:],time_order=int(k[2][0]),tasks=v) for k,v in sorted(stuck.items())]
reasons=[dict(outcome=k[0],stage=k[1],reason=k[2],tasks=v) for k,v in sorted(reasons.items(),key=lambda kv:-kv[1])]
L=R['d_live']['rows']
live=[dict(stage=r['stage'][2:],stage_order=int(r['stage'][0]),time_in_stage=r['time_in_stage'][2:],time_order=int(r['time_in_stage'][0]),slot_status=r['slot_status'][2:],slot_order=int(r['slot_status'][0]),tasks=r['n']) for r in L]
ni=A-f['installed']
summary=dict(assigned=A,installed=f['installed'],install_pct=r1(100*f['installed']/A),not_installed=ni,not_installed_pct=r1(100*ni/A),
  before_slot=timing[0]['installs'],on_slot=timing[1]['installs'],after_slot=timing[2]['installs'],
  on_or_before_pct=r1(100*(timing[0]['installs']+timing[1]['installs'])/f['installed']),late_pct=timing[2]['pct'],early_pct=timing[0]['pct'],on_pct=timing[1]['pct'],
  median_assign_to_install_hours=r1(f['m_e2e']/60),p90_assign_to_install_hours=r1(f['p_e2e']/60),median_assign_to_arrive_hours=r1(f['m_arr']/60),p90_assign_to_arrive_hours=r1(f['p_arr']/60),
  onsite_median_min=round((f['m_kyc'] or 0)+(f['m_fee'] or 0)+(f['m_setup'] or 0)+(f['m_otp'] or 0)),
  rescheduled_tasks=f['resched_any'],rescheduled_pct=r1(100*f['resched_any']/A),rescheduled_multi=f['resched_multi'],
  arrived_before_slot=f['arr_early'],arrived_on_slot=f['arr_on'],arrived_after_slot=f['arr_late'],
  noshow_3d=sum(s['tasks'] for s in stuck if s['outcome']=='System timeout (no-show)' and s['time_order']==6),
  noshow_total=sum(s['tasks'] for s in stuck if s['outcome']=='System timeout (no-show)'),
  open_in_cohort=sum(s['tasks'] for s in stuck if s['outcome']=='Open'),
  live_open=sum(l['tasks'] for l in live),live_past_slot=sum(l['tasks'] for l in live if l['slot_order']>=3),
  live_waiting_arrival=sum(l['tasks'] for l in live if l['stage_order']==1),live_rating_pending=sum(l['tasks'] for l in live if l['stage_order']==7),
  late_1day=next((d['installs'] for d in days if d['days_vs_slot']==1),0),snapshot=gen,
  cohort_from=str((_today-datetime.timedelta(days=5)).replace(day=1)),cohort_to=str(_today-datetime.timedelta(days=5)))
data=dict(d_summary=[summary],d_steps=steps,d_timing=timing,d_days=days,d_late=late,d_assign_to_install=asg,d_stuck=stuck,d_reasons=reasons,d_live=live,d_notes=notes.build(note_rows,['outcome','stage','reason']) or [dict(outcome='',stage='',reason='',theme='',tasks=0,examples='',notes_total=0,reason_total=0)])
sqlmap=dict(d_summary='d_funnel',d_steps='d_funnel',d_timing='d_timing',d_days='d_timing',d_late='d_timing',d_assign_to_install='d_timing',d_stuck='d_notinst',d_reasons='d_notinst',d_live='d_live',d_notes='d_notinst')
base=open('deep_base.sql').read()
out=dict(generated_at=gen,cohort='Install tasks created from the 1st of the month (of the date 5 days back) to 5 days before generation (IST) that reached TECHNICIAN_ASSIGNED; live section = all open tasks now',
  datasets={k:dict(rows=v,sql=R[sqlmap[k]]['sql']) for k,v in data.items()},shape_code=open('deep.py').read())
json.dump(out,open('b2i_deep_snapshot.json','w'),default=str)
print(json.dumps(summary,indent=0)); print(timing); print(late); print(asg); print([s for s in steps])
