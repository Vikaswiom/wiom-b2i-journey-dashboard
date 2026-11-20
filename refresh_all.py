"""Refresh every data file behind the CSP Booking-to-Install Journey dashboard.
Runs all Metabase queries (Snowflake, db 113) and shapes four JSON snapshots:
  b2i_snapshot.json (Overview), b2i_deep_snapshot.json (Deep dive),
  b2i_yesterday_snapshot.json (Daily tracker), b2i_csp_snapshot.json (CSP reschedule behaviour).
Uploading them to the artifact is done by Claude with the Artifact tools (see README.md)."""
import subprocess, sys, time, json, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
def sh(cmd, out=None):
    t=time.time(); print('>', cmd, flush=True)
    if out:
        with open(out,'w') as fh: r=subprocess.run(cmd, shell=True, stdout=fh, stderr=subprocess.PIPE, text=True)
    else: r=subprocess.run(cmd, shell=True, stderr=subprocess.PIPE, text=True)
    if r.returncode!=0: print(r.stderr); sys.exit(f'FAILED: {cmd}')
    if out and open(out).read().startswith('ERR'): sys.exit(f'FAILED (query error): {cmd}\n'+open(out).read()[:500])
    print(f'  ok {time.time()-t:.0f}s', flush=True)
# Overview
sh('python3 build.py'); sh('python3 shape.py')
# Deep dive
sh('python3 deep.py')
# Daily tracker (order matters: y.py creates the file, the rest add to it)
sh('python3 q.py t_installs.sql', 't_installs.out'); sh('python3 q.py t_due.sql', 't_due.out')
sh('python3 y.py'); sh('python3 trend.py')
sh('python3 q.py t_activity.sql', 't_activity.out'); sh('python3 q.py y_lag.sql', 'y_lag.out'); sh('python3 activity.py')
sh('python3 q.py t_promise.sql', 't_promise.out'); sh('python3 promise.py')
sh('python3 flags.py')
# CSP reschedule behaviour
sh('python3 q.py c_csp.sql', 'c_csp.out'); sh('python3 csp.py')
files=['b2i_snapshot.json','b2i_deep_snapshot.json','b2i_yesterday_snapshot.json','b2i_csp_snapshot.json']
ys=json.load(open('b2i_yesterday_snapshot.json'))['datasets']['y_summary']['rows'][0]
print(json.dumps({'done':True,'files':files,'yesterday':ys['date'],'installs':ys['installs'],'snapshot':ys['snapshot']}))
