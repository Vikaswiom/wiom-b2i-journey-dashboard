import json, subprocess, urllib.request, datetime, sys
import os
key = os.environ.get('METABASE_API_KEY') or subprocess.check_output(['security','find-generic-password','-s','wiom-metabase-api-key','-w']).decode().strip()
def run(sql):
    req = urllib.request.Request('https://metabase.wiom.in/api/dataset', data=json.dumps({"database":113,"type":"native","native":{"query":sql}}).encode(), headers={'x-api-key':key,'Content-Type':'application/json'})
    r = json.load(urllib.request.urlopen(req, timeout=600)); d=r['data']
    if r.get('error'): raise SystemExit(r['error'])
    cols=[c['name'].lower() for c in d['cols']]
    out=[]
    for row in d['rows']:
        o={}
        for c,v in zip(cols,row):
            if isinstance(v,str) and v[:4].isdigit() and 'T00:00' in v: v=v[:10]
            o[c]=v
        out.append(o)
    return out
sec={}
for name in ['funnel','exits','fpn','daily','conn','cspband','hour']:
    sql=open(f'{name}.sql').read()
    sec[name]={'sql':sql,'rows':run(sql)}
    print(name,len(sec[name]['rows']),file=sys.stderr)
json.dump({'generated_at':datetime.datetime.now().astimezone().isoformat(timespec='minutes'),'cohort':'Install tasks created 17 to 5 days before generation (IST), outcomes observed to generation time','sections':sec},open('raw.json','w'),indent=1,default=str)
