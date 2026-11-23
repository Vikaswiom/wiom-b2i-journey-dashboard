"""Turn the October run of the overview pipeline into b2i_oct_snapshot.json with o_-prefixed datasets."""
import json
d=json.load(open('b2i_snapshot.json'))
f=json.load(open('raw.json'))['sections']['funnel']['rows'][0]
ds=d['datasets']
s=ds['summary']['rows'][0]
s.update(cohort_from='2026-10-01',cohort_to='2026-10-31',old_flow_tasks=f['old_flow_tasks'],new_flow_tasks=f['tasks']-f['old_flow_tasks'],
         old_flow_pct=round(100*f['old_flow_tasks']/f['tasks'],1))
for r in ds['steps']['rows']:
    if r['step_no']==1: r['backend_event']='→ ASSIGNED (task created for the CSP)'
    if r['step_no']==2:
        r.update(step='CSP took the task', detail='Accepted the FPN (new flow) or assigned a technician (old flow)',
                 backend_event='New: AWAITING_CSP_ACCEPTANCE → AWAITING_TECHNICIAN_ASSIGNMENT · Old: → TECHNICIAN_ASSIGNED', app_event='install_accepted (new flow)')
for r in ds['offer']['rows']:
    if r['outcome']=='Accepted': r['outcome']='Accepted'
d['datasets']={'o_'+k:v for k,v in ds.items()}
d['cohort']='Install tasks created 1–31 Oct 2026 (IST); October mixes the customer-schedule flow and the CSP-acceptance flow (from ~23 Oct)'
d['shape_code']+='\n\n# ---- october/finish_oct.py ----\n'+open('finish_oct.py').read()
json.dump(d,open('../b2i_oct_snapshot.json','w'),default=str)
print(s['tasks'],s['installed'],s['install_pct'],s['accept_pct'],s['noaction_pct'],s['decline_pct'],s['bookings'],s['booking_install_pct'],s['old_flow_tasks'])
print([ (r['step'],r['tasks']) for r in ds['steps']['rows']])
