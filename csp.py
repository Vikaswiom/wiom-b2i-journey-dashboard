import json, collections, datetime
L=open('c_csp.out').read().strip().split('\n'); h=[c.lower() for c in L[0].split('\t')]
R=[dict(zip(h,l.split('\t'))) for l in L[1:]]
ints=['installs','ontime_no_resched','ontime_resched','late_resched','late_no_resched','resched_events_ever','resched_tasks_ever','resched_events_30d','open_overdue_no_resched']
SEG={1:'Never used reschedule, installs late',2:'Uses reschedule sometimes, still late without it',3:'Uses reschedule, never late without it',4:'Never late, never rescheduled'}
def seg(r):
    if r['late_no_resched']>0 and r['resched_events_ever']==0: return 1
    if r['late_no_resched']>0: return 2
    if r['resched_events_ever']>0: return 3
    return 4
rows=[]
for r in R:
    for k in ints: r[k]=int(r[k])
    r['avg_days_late_no_resched']=None if r['avg_days_late_no_resched'] in ('None','') else float(r['avg_days_late_no_resched'])
    r['last_resched_day']=None if r['last_resched_day']=='None' else r['last_resched_day'][:10]
    r['app_version']=None if r['app_version']=='None' else r['app_version']
    r['csp_name']=None if r['csp_name']=='None' else r['csp_name']
    s=seg(r); r['segment_no']=s; r['segment']=SEG[s]
    r['late_no_resched_pct']=round(100*r['late_no_resched']/r['installs'],1)
    slipped=r['late_no_resched']+r['late_resched']+r['ontime_resched']
    r['date_slipped']=slipped
    r['rescheduled_when_slipped_pct']=round(100*(r['late_resched']+r['ontime_resched'])/slipped,1) if slipped else None
    rows.append(r)
tot_late=sum(r['late_no_resched'] for r in rows); tot_inst=sum(r['installs'] for r in rows)
segs=[]
for s in [1,2,3,4]:
    g=[r for r in rows if r['segment_no']==s]
    segs.append(dict(segment_no=s,segment=SEG[s],csps=len(g),installs=sum(r['installs'] for r in g),late_no_resched=sum(r['late_no_resched'] for r in g),
      share_of_late_no_resched=round(100*sum(r['late_no_resched'] for r in g)/tot_late,1),open_overdue_no_resched=sum(r['open_overdue_no_resched'] for r in g),
      on_old_app=sum(1 for r in g if r['app_version'] and r['app_version']<'1.2.21'),no_app_activity=sum(1 for r in g if not r['app_version'])))
yday=(datetime.date.today()-datetime.timedelta(days=1)); start=yday-datetime.timedelta(days=29)
summary=dict(window_from=str(start),window_to=str(yday),csps=len(rows),installs=tot_inst,late_no_resched=tot_late,late_no_resched_pct=round(100*tot_late/tot_inst,1),
  never_csps=segs[0]['csps'],never_late=segs[0]['late_no_resched'],never_share=segs[0]['share_of_late_no_resched'],
  some_csps=segs[1]['csps'],some_late=segs[1]['late_no_resched'],some_share=segs[1]['share_of_late_no_resched'],
  open_overdue_no_resched=sum(r['open_overdue_no_resched'] for r in rows),
  resched_on_1_2_18=sum(1 for r in rows if r['app_version']=='1.2.18' and r['resched_events_30d']>0),
  snapshot=datetime.datetime.now().astimezone().isoformat(timespec='minutes'))
sql=open('c_csp.sql').read()
out=dict(generated_at=summary['snapshot'],cohort=f'Installs {start} to {yday} (IST), per CSP',datasets=dict(c_summary=dict(rows=[summary],sql=sql),c_segments=dict(rows=segs,sql=sql),c_csps=dict(rows=rows,sql=sql)),shape_code=open('csp.py').read())
json.dump(out,open('b2i_csp_snapshot.json','w'),default=str)
print(summary); [print(s) for s in segs]
