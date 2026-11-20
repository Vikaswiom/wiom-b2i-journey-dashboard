import json, datetime, collections
snap=json.load(open('b2i_yesterday_snapshot.json'))
G={'Installed on the day':'On time','Installed early':'On time','Late, installed later':'Late','Rescheduled, installed later':'Late',
   'Rescheduled, not installed yet':'Delayed, not installed yet','Overdue, still open':'Delayed, not installed yet','Still finding a CSP':'Delayed, not installed yet',
   'Customer cancelled':'Not going ahead','No CSP accepted in time':'Not going ahead','CSP declined':'Not going ahead','CSP reported failure':'Not going ahead','Dropped by system':'Not going ahead'}
O=list(G)
rows=[]
for l in open('t_promise.out').read().strip().split('\n')[1:]:
    d,o,dl,n=l.split('\t'); rows.append(dict(d=d[:10],outcome=o,days_late=None if dl=='None' else int(dl),bookings=int(n)))
r1=lambda a,b: round(100*a/b,1) if b else None
yd=max(r['d'] for r in rows)
Y=[r for r in rows if r['d']==yd]; tot=sum(r['bookings'] for r in Y)
yp=[]
for i,o in enumerate(O):
    n=sum(r['bookings'] for r in Y if r['outcome']==o)
    yp.append(dict(order=i+1,group=G[o],outcome=o,bookings=n,pct=r1(n,tot)))
gs=['On time','Late','Delayed, not installed yet','Not going ahead']
ysum=dict(date=yd,supposed=tot,**{('g_'+g.split(',')[0].lower().replace(' ','_')):sum(x['bookings'] for x in yp if x['group']==g) for g in gs})
for g in gs: k='g_'+g.split(',')[0].lower().replace(' ','_'); ysum[k+'_pct']=r1(ysum[k],tot)
ysum['installed_on_day']=sum(x['bookings'] for x in yp if x['outcome']=='Installed on the day'); ysum['installed_early']=sum(x['bookings'] for x in yp if x['outcome']=='Installed early')
# trend by grain
keyf={'day':lambda d:d,'week':lambda d:(datetime.date.fromisoformat(d)-datetime.timedelta(days=datetime.date.fromisoformat(d).weekday())).isoformat(),'month':lambda d:d[:7]}
agg=collections.defaultdict(collections.Counter)
for r in rows:
    for g,f in keyf.items():
        agg[(g,f(r['d']))][r['outcome']]+=r['bookings']
        if r['days_late']: agg[(g,f(r['d']))]['late_'+str(r['days_late'])]+=r['bookings']
for r in snap['datasets']['trend']['rows']:
    c=agg.get((r['grain'],r['period']),collections.Counter()); n=sum(c[o] for o in O)
    r['pr_supposed']=n
    for g in gs:
        k='pr_'+g.split(',')[0].lower().replace(' ','_'); r[k]=sum(c[o] for o in O if G[o]==g); r[k+'_pct']=r1(r[k],n)
    r['pr_installed_on_day']=c['Installed on the day']; r['pr_installed_early']=c['Installed early']
    r['pr_no_csp']=c['No CSP accepted in time']; r['pr_no_csp_pct']=r1(c['No CSP accepted in time'],n)
snap['datasets']['trend']['sql']+='\n\n-- and (bookings supposed to be installed) --\n\n'+open('t_promise.sql').read()
snap['datasets']['y_promise']=dict(rows=yp,sql=open('t_promise.sql').read())
late=[dict(outcome=r['outcome'],days_late=r['days_late'],bookings=r['bookings']) for r in Y if r['days_late']]
snap['datasets']['y_promise_late']=dict(rows=late or [dict(outcome='—',days_late=0,bookings=0)],sql=open('t_promise.sql').read())
snap['datasets']['y_summary']['rows'][0].update({'pr_'+k:v for k,v in ysum.items() if k!='date'})
snap['shape_code']+='\n\n# ---- promise.py ----\n'+open('promise.py').read()
json.dump(snap,open('b2i_yesterday_snapshot.json','w'),default=str)
print(ysum); print([ (r['label'],r['pr_supposed'],r['pr_on_time_pct'],r['pr_late_pct'],r['pr_delayed_pct'],r['pr_not_going_ahead_pct']) for r in snap['datasets']['trend']['rows'] if r['grain']=='month'])
