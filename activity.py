import json, datetime, collections
snap=json.load(open('b2i_yesterday_snapshot.json'))
L=open('t_activity.out').read().strip().split('\n'); h=[c.lower() for c in L[0].split('\t')]
A={}
for l in L[1:]:
    r=dict(zip(h,l.split('\t'))); d=r.pop('d')[:10]; A[d]={k:int(float(v)) for k,v in r.items()}
r1=lambda a,b: round(100*a/b,1) if b else None
keyf={'day':lambda d:d,'week':lambda d:(datetime.date.fromisoformat(d)-datetime.timedelta(days=datetime.date.fromisoformat(d).weekday())).isoformat(),'month':lambda d:d[:7]}
agg=collections.defaultdict(collections.Counter)
for d,v in A.items():
    for g,f in keyf.items(): agg[(g,f(d))].update(v)
for r in snap['datasets']['trend']['rows']:
    v=agg.get((r['grain'],r['period']),{})
    for k in ['offered','accepted','assigned','arrived','happy_code','installed']: r['act_'+k]=v.get(k,0)
    r['act_installed_per_assigned_pct']=r1(r['act_installed'],r['act_assigned'])
    r['act_arrived_per_assigned_pct']=r1(r['act_arrived'],r['act_assigned'])
    r['act_accepted_per_offered_pct']=r1(r['act_accepted'],r['act_offered'])
    r['act_installed_per_offered_pct']=r1(r['act_installed'],r['act_offered'])
snap['datasets']['trend']['sql']=snap['datasets']['trend']['sql']+'\n\n-- and (day activity) --\n\n'+open('t_activity.sql').read()
# yesterday activity funnel (bottom = offered)
yd=max(A); v=A[yd]
order=[('offered','Booking FPN sent to CSP'),('accepted','Accepted by the CSP'),('assigned','Technician assigned'),('arrived','Technician reached customer home'),('installed','Installed')]
rows=[];prev=None
for i,(k,n) in enumerate(order):
    rows.append(dict(step_no=i+1,key=k,step=n,tasks=v[k],pct_of_below=None if prev is None else r1(v[k],prev),pct_of_offered=r1(v[k],v['offered']))); prev=v[k]
snap['datasets']['y_activity']=dict(rows=rows,sql=open('t_activity.sql').read())
# lag
LL=open('y_lag.out').read().strip().split('\n')
lag=[]
nm=dict(order)
bo={'Same day':1,'1 day before':2,'2–3 days before':3,'4+ days before':4,'Not recorded':5}
for l in LL[1:]:
    s,b,n=l.split('\t'); lag.append(dict(step=nm[s],key=s,lag=b,lag_order=bo[b],installs=int(n),pct_of_installs=r1(int(n),v['installed'])))
snap['datasets']['y_lag']=dict(rows=lag,sql=open('y_lag.sql').read())
snap['shape_code']=snap['shape_code']+'\n\n# ---- activity.py ----\n'+open('activity.py').read()
json.dump(snap,open('b2i_yesterday_snapshot.json','w'),default=str)
print(rows); print(sum(x['installs'] for x in lag if x['key']=='assigned'))
