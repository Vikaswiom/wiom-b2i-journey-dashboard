import json, statistics, datetime
snap=json.load(open('b2i_yesterday_snapshot.json'))
daily=[r for r in snap['datasets']['trend']['rows'] if r['grain']=='day']
yd=daily[-1]; prior=daily[:-1]
M=[ # field, name, direction(+1 higher better,-1 lower better,0 neutral), unit, min_start, what it means
 ('installs','Installs done','+','int','2026-08-01','installations completed during the day'),
 ('x_pct','On time, never rescheduled','+','pct','2026-09-18','share of installs on or before the slot day with no reschedule'),
 ('y_pct','Rescheduled (any outcome)','-','pct','2026-09-18','share of installs whose date the CSP moved before installing'),
 ('z_pct','Late, never rescheduled','-','pct','2026-09-18','share of installs after the slot day with no reschedule'),
 ('late_pct','All late installs','-','pct','2026-09-18','share of installs after the slot day'),
 ('due','Tasks due','0','int','2026-11-03','open tasks whose slot day was the day'),
 ('due_to_accepted_pct','Due → accepted by CSP','+','pct','2026-11-03','share of due tasks the CSP had accepted by midnight'),
 ('due_to_assigned_pct','Due → technician assigned','+','pct','2026-11-03','share of due tasks with a technician by midnight'),
 ('assigned_to_arrived_pct','Technician assigned → reached customer home','+','pct','2026-08-01','share of due tasks with a technician that reached the customer home that day'),
 ('arrived_to_installed_pct','Reached customer home → installed','+','pct','2026-08-01','share of home visits that ended in an install that day'),
 ('assigned_to_installed_pct','Technician assigned → installed on the day','+','pct','2026-08-01','share of due tasks with a technician installed that day'),
 ('due_to_installed_pct','Due → installed on the day','+','pct','2026-11-03','share of all due tasks installed that day'),
 ('act_assigned','Technicians assigned during the day','+','int','2026-08-01','tasks that got a technician that day'),
 ('act_arrived','Customer homes reached during the day','+','int','2026-08-01','tasks where the technician reached the customer home that day'),
 ('act_installed_per_assigned_pct','Installs ÷ technicians assigned (same day)','+','pct','2026-08-01','installs done that day as a share of technicians assigned that day'),
 ('pr_on_time_pct','Bookings due that day installed on time','+','pct','2026-08-01','share of bookings supposed to be installed that day that were installed on or before it'),
]
flags=[]
for f,name,dirn,unit,start,desc in M:
    base=[r[f] for r in prior if r['start']>=start and r[f] is not None][-28:]
    v=yd[f]
    if v is None or len(base)<7: continue
    mean=statistics.mean(base); sd=statistics.pstdev(base) or 1e-9
    z=(v-mean)/sd
    sb=sorted(base); p10=sb[max(0,int(round(0.1*(len(sb)-1))))]; p90=sb[int(round(0.9*(len(sb)-1)))]
    bad = (dirn=='+' and z<0) or (dirn=='-' and z>0)
    if dirn=='0':
        status='Unusual' if abs(z)>=2 else 'Normal'
    elif bad and abs(z)>=2: status='Off'
    elif bad and abs(z)>=1.5: status='Watch'
    elif (not bad) and abs(z)>=2: status='Better than usual'
    else: status='Normal'
    rank=sum(1 for b in base if (b<v if dirn!='-' else b>v))
    flags.append(dict(metric=name,field=f,status=status,order={'Off':0,'Watch':1,'Unusual':2,'Better than usual':3,'Normal':4}[status],
      unit=unit,direction={'+':'higher is better','-':'lower is better','0':'neither'}[dirn],meaning=desc,
      yesterday=v,usual=round(mean,1),usual_low=round(p10,1),usual_high=round(p90,1),z_score=round(z,2),
      change=round(v-mean,1),baseline_days=len(base),baseline_from=[r['start'] for r in prior if r['start']>=start][-28:][0],
      same_day_last_week=next((r[f] for r in prior if r['start']==(datetime.date.fromisoformat(yd['start'])-datetime.timedelta(days=7)).isoformat()),None)))
flags.sort(key=lambda r:(r['order'],-abs(r['z_score'])))
snap['datasets']['y_flags']=dict(rows=flags,sql=snap['datasets']['trend']['sql'])
snap['shape_code']=snap['shape_code']+'\n\n# ---- flags.py ----\n'+open('flags.py').read()
json.dump(snap,open('b2i_yesterday_snapshot.json','w'),default=str)
for r in flags: print(r['status'],'|',r['metric'],r['yesterday'],'usual',r['usual'],f"[{r['usual_low']}–{r['usual_high']}]",'z',r['z_score'],'n',r['baseline_days'])
