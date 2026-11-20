import json, subprocess, urllib.request, datetime
import os
key = os.environ.get('METABASE_API_KEY') or subprocess.check_output(['security','find-generic-password','-s','wiom-metabase-api-key','-w']).decode().strip()
def run(sql):
    req = urllib.request.Request('https://metabase.wiom.in/api/dataset', data=json.dumps({"database":113,"type":"native","native":{"query":sql}}).encode(), headers={'x-api-key':key,'Content-Type':'application/json'})
    r = json.load(urllib.request.urlopen(req, timeout=600)); d=r['data']
    if r.get('error'): raise SystemExit(r['error'])
    cols=[c['name'].lower() for c in d['cols']]
    return [dict(zip(cols,row)) for row in d['rows']]
SQL={k:open(k+'.sql').read() for k in ['y_installs','y_due']}
I=run(SQL['y_installs']); D=run(SQL['y_due'])
gen=datetime.datetime.now().astimezone()
yday=(gen.date()-datetime.timedelta(days=1))
r1=lambda x: round(x,1) if x is not None else None
S=lambda rows: sum(r['installs'] for r in rows)
nr=[r for r in I if r['resched']=='Not rescheduled']; rs=[r for r in I if r['resched']=='Rescheduled']
tot=S(I)
split=[
 dict(group='x',group_label='On time, never rescheduled',part='On time, never rescheduled · on the slot day',installs=S([r for r in nr if r['timing']=='On slot day'])),
 dict(group='x',group_label='On time, never rescheduled',part='On time, never rescheduled · before the slot day',installs=S([r for r in nr if r['timing']=='Before slot day'])),
 dict(group='y',group_label='Rescheduled, installed early or on time',part='Rescheduled, installed early or on time',installs=S([r for r in rs if r['timing']!='After slot day'])),
 dict(group='y',group_label='Rescheduled, installed late',part='Rescheduled, installed late',installs=S([r for r in rs if r['timing']=='After slot day'])),
 dict(group='z',group_label='Late, never rescheduled',part='Late, never rescheduled',installs=S([r for r in nr if r['timing']=='After slot day'])),
]
for s in split: s['pct_of_installs']=r1(100*s['installs']/tot)
late=[]
for g,rows in [('Late, never rescheduled',[r for r in nr if r['timing']=='After slot day']),('Rescheduled, installed late',[r for r in rs if r['timing']=='After slot day'])]:
    for d in sorted({r['days_vs_slot'] for r in rows}):
        late.append(dict(group=g,days_late=int(d),installs=S([r for r in rows if r['days_vs_slot']==d])))
resched_vs_orig=dict(on_or_before_original=S([r for r in rs if r['days_vs_original']<=0]),after_original=S([r for r in rs if r['days_vs_original']>0]))
# funnel of tasks due yesterday
T=lambda f: sum(r['tasks'] for r in D if f(r))
due=T(lambda r:True)
lv=[('Due yesterday',lambda r:True),('Accepted by the CSP',lambda r:r['acc_eod']==1),('Technician assigned',lambda r:r['asg_eod']==1),
    ('Technician reached customer home',lambda r:r['arr_eod']==1),('Installed on the day',lambda r:r['inst_eod']==1)]
funnel=[];prev=None
for i,(n,f) in enumerate(lv):
    c=T(f); funnel.append(dict(step_no=i+1,step=n,tasks=c,pct_of_due=r1(100*c/due),pct_of_prev=None if prev is None else r1(100*c/prev),lost=None if prev is None else prev-c)); prev=c
rc_lab={'TIMEOUT_P41':'FPN deadline passed','COVERAGE_NOT_FEASIBLE':'No coverage at address','OTHER':'Other (free text)','DEVICE_UNAVAILABLE':'No Netbox in hand',
 'CUSTOMER_CANCELLED':'Customer cancelled (per CSP)','USER_CANCELLATION':'Customer cancelled in app','CUSTOMER_UNREACHABLE':'Customer unreachable','NO_INSTALLER_AVAILABLE':'No installer available',
 'CUSTOMER_ASKED_OTHER_DAY':'Customer asked for another day','TECHNICIAN_ASSIGNED_AWAITING_ARRIVAL':'Technician assigned, did not arrive','ACCEPT_WITH_SLOT':'Accepted, no technician yet',
 'HOLD_FOR_CSP_ACCEPTANCE':'Waiting for CSP to accept','ALLOCATION_ASSIGNED':'FPN sent, waiting for CSP','TECHNICIAN_CHANGED':'Technician changed','STEP_SPEED_TEST_SUBMITTED':'On site, happy code pending',
 'STEP_SHARED_SUBMITTED':'On site, setup in progress','STEP_SELFIE_SUBMITTED_BY_CSP':'On site, KYC in progress','-':'—'}
flags=['acc_eod','asg_eod','arr_eod','inst_eod']
leaks={}
for r in D:
    if r['inst_eod']==1: continue
    lvl=0
    for i,fl in enumerate(flags):
        if r[fl]==1: lvl=i+1
    # lvl = highest step reached (0=due only). leak sits between step lvl+1 and lvl+2 (1-indexed steps)
    k=(lvl+1, r['day_outcome'], rc_lab.get(r['eod_rc'],r['eod_rc']))
    leaks[k]=leaks.get(k,0)+r['tasks']
leaks=[dict(from_step=k[0],outcome=k[1],reason=k[2],tasks=v) for k,v in sorted(leaks.items(),key=lambda kv:(kv[0][0],-kv[1]))]
summary=dict(date=str(yday),installs=tot,x=split[0]['installs']+split[1]['installs'],x_on_day=split[0]['installs'],x_early=split[1]['installs'],
  y=split[2]['installs']+split[3]['installs'],y_on_time=split[2]['installs'],y_late=split[3]['installs'],y_early=S([r for r in rs if r['timing']=='Before slot day']),y_on_day=S([r for r in rs if r['timing']=='On slot day']),y_on_time_pct=r1(100*split[2]['installs']/tot),y_late_pct=r1(100*split[3]['installs']/tot),z=split[4]['installs'],
  x_pct=r1(100*(split[0]['installs']+split[1]['installs'])/tot),y_pct=r1(100*(split[2]['installs']+split[3]['installs'])/tot),z_pct=r1(100*split[4]['installs']/tot),
  late_total=split[3]['installs']+split[4]['installs'],
  y_on_or_before_original=resched_vs_orig['on_or_before_original'],y_after_original=resched_vs_orig['after_original'],
  due=due,accepted=funnel[1]['tasks'],assigned=funnel[2]['tasks'],arrived=funnel[3]['tasks'],installed_on_day=funnel[4]['tasks'],
  assigned_to_installed_pct=r1(100*funnel[4]['tasks']/funnel[2]['tasks']),installs_not_due_yday=tot-funnel[4]['tasks'],
  snapshot=gen.isoformat(timespec='minutes'))
data=dict(y_summary=[summary],y_split=split,y_late=late,y_funnel=funnel,y_leaks=leaks)
sqlmap=dict(y_summary='y_installs',y_split='y_installs',y_late='y_installs',y_funnel='y_due',y_leaks='y_due')
out=dict(generated_at=summary['snapshot'],cohort=f'Yesterday = {yday} (IST)',datasets={k:dict(rows=v,sql=SQL[sqlmap[k]] if k!='y_summary' else SQL['y_installs']+'\n\n-- and --\n\n'+SQL['y_due']) for k,v in data.items()},shape_code=open('y.py').read())
json.dump(out,open('b2i_yesterday_snapshot.json','w'),default=str)
print(json.dumps(summary,indent=0)); print(split); print(late); print(funnel); print(leaks[:12])
