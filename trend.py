import json, datetime, collections
def load(p):
    L=open(p).read().strip().split('\n'); h=[c.lower() for c in L[0].split('\t')]
    out=[]
    for l in L[1:]:
        r=dict(zip(h,l.split('\t'))); r['d']=r['d'][:10]
        for k in r:
            if k!='d': r[k]=int(float(r[k]))
        out.append(r)
    return out
I={r['d']:r for r in load('t_installs.out')}; D={r['d']:r for r in load('t_due.out')}
days=sorted(set(I)|set(D))
RS='2026-09-18'; ACC='2026-11-03'
r1=lambda a,b: round(100*a/b,1) if b else None
def build(keyfn,labelfn,grain):
    g=collections.OrderedDict()
    for d in days:
        k=keyfn(d); g.setdefault(k,[]).append(d)
    rows=[]
    for k,ds in g.items():
        s=collections.Counter()
        for d in ds:
            for f,v in I.get(d,{}).items():
                if f!='d': s[f]+=v
            for f,v in D.get(d,{}).items():
                if f!='d': s['due_'+f if f in('accepted','assigned','arrived') else f]+=v
        x=s['x_on_day']+s['x_early']; y=s['y_on_time']+s['y_late']; z=s['z_late']; n=s['installs']
        full={'day':1,'week':7}.get(grain)
        if grain=='month':
            dt=datetime.date.fromisoformat(ds[0]); nxt=(dt.replace(day=28)+datetime.timedelta(days=4)).replace(day=1); full=(nxt-dt.replace(day=1)).days
        rows.append(dict(grain=grain,period=k,label=labelfn(k,ds),start=ds[0],end=ds[-1],days=len(ds),partial=len(ds)<full,
          resched_tracked=ds[0]>=RS, accept_step=ds[0]>=ACC,
          installs=n,x_on_day=s['x_on_day'],x_early=s['x_early'],y_on_time=s['y_on_time'],y_late=s['y_late'],z_late=z,x=x,y=y,z=z,
          x_pct=r1(x,n),y_pct=r1(y,n),z_pct=r1(z,n),x_on_day_pct=r1(s['x_on_day'],n),x_early_pct=r1(s['x_early'],n),y_on_time_pct=r1(s['y_on_time'],n),y_late_pct=r1(s['y_late'],n),
          on_time_pct=r1(x+s['y_on_time'],n),late_pct=r1(s['y_late']+z,n),
          due=s['due'],accepted=s['due_accepted'],assigned=s['due_assigned'],arrived=s['due_arrived'],installed_on_day=s['installed_on_day'],
          due_to_accepted_pct=r1(s['due_accepted'],s['due']),due_to_assigned_pct=r1(s['due_assigned'],s['due']),assigned_to_arrived_pct=r1(s['due_arrived'],s['due_assigned']),
          arrived_to_installed_pct=r1(s['installed_on_day'],s['due_arrived']),assigned_to_installed_pct=r1(s['installed_on_day'],s['due_assigned']),due_to_installed_pct=r1(s['installed_on_day'],s['due'])))
    return rows
fmtd=lambda d: datetime.date.fromisoformat(d).strftime('%-d %b')
daily=build(lambda d:d, lambda k,ds: datetime.date.fromisoformat(k).strftime('%a %-d %b'),'day')
weekly=build(lambda d:(datetime.date.fromisoformat(d)-datetime.timedelta(days=datetime.date.fromisoformat(d).weekday())).isoformat(),
             lambda k,ds:'Week of '+fmtd(k)+('' if len(ds)==7 else f' ({fmtd(ds[0])}–{fmtd(ds[-1])})'),'week')
monthly=build(lambda d:d[:7], lambda k,ds: datetime.date.fromisoformat(k+'-01').strftime('%b %Y')+('' if datetime.date.fromisoformat(ds[-1]).day>=28 else f' (1–{datetime.date.fromisoformat(ds[-1]).day})'),'month')
trend=daily+weekly+monthly
# yesterday comparison
yd=days[-1]; idx=days.index(yd)
def dayrow(d): return next(r for r in daily if r['period']==d)
def avg(ds,f):
    vals=[dayrow(d)[f] for d in ds if dayrow(d)[f] is not None]
    return round(sum(vals)/len(vals),1) if vals else None
def pooled(ds,num,den):
    a=sum(sum(dayrow(d)[f] for f in num) for d in ds); b=sum(dayrow(d)[den] for d in ds); return r1(a,b)
prev=days[idx-1]; lw=(datetime.date.fromisoformat(yd)-datetime.timedelta(days=7)).isoformat()
p7=days[idx-7:idx]; p28=days[idx-28:idx]
mets=[('installs','Installs',['installs'],None,'int',True),
 ('x_pct','On time, never rescheduled',['x_on_day','x_early'],'installs','pct',True),
 ('y_pct','Rescheduled (any outcome)',['y_on_time','y_late'],'installs','pct',False),
 ('z_pct','Late, never rescheduled',['z_late'],'installs','pct',False),
 ('late_pct','All late installs',['y_late','z_late'],'installs','pct',False),
 ('assigned','Due with a technician assigned',['assigned'],None,'int',True),
 ('installed_on_day','Due and installed on the day',['installed_on_day'],None,'int',True),
 ('assigned_to_installed_pct','Technician assigned → installed on the day',['installed_on_day'],'assigned','pct',True),
 ('due_to_installed_pct','Due → installed on the day',['installed_on_day'],'due','pct',True)]
cmp=[]
for f,lab,num,den,kind,higher_good in mets:
    if kind=='int':
        cmp.append(dict(metric=lab,field=f,kind=kind,higher_is_better=higher_good,yesterday=dayrow(yd)[f],previous_day=dayrow(prev)[f],same_day_last_week=dayrow(lw)[f],
          avg_prev_7_days=round(sum(dayrow(d)[f] for d in p7)/7,1),avg_prev_28_days=round(sum(dayrow(d)[f] for d in p28)/28,1)))
    else:
        cmp.append(dict(metric=lab,field=f,kind=kind,higher_is_better=higher_good,yesterday=dayrow(yd)[f],previous_day=dayrow(prev)[f],same_day_last_week=dayrow(lw)[f],
          avg_prev_7_days=pooled(p7,num,den),avg_prev_28_days=pooled(p28,num,den)))
for c in cmp:
    for k in ['previous_day','same_day_last_week','avg_prev_7_days','avg_prev_28_days']:
        c['vs_'+k]=None if c[k] is None else round(c['yesterday']-c[k],1)
snap=json.load(open('b2i_yesterday_snapshot.json'))
y=snap['datasets']
y['trend']=dict(rows=trend,sql=open('t_installs.sql').read()+'\n\n-- and --\n\n'+open('t_due.sql').read())
y['y_compare']=dict(rows=cmp,sql=y['trend']['sql'])
snap['shape_code']=snap['shape_code']+'\n\n# ---- trend.py ----\n'+open('trend.py').read()
json.dump(snap,open('b2i_yesterday_snapshot.json','w'),default=str)
print(len(daily),len(weekly),len(monthly)); print([ (m['label'],m['installs'],m['x_pct'],m['y_pct'],m['z_pct'],m['assigned_to_installed_pct']) for m in monthly]); print(weekly[-3:]); print(json.dumps(cmp,indent=0)[:1500])
