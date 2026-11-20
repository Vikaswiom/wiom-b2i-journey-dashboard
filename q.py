import sys, json, subprocess, urllib.request
import os
key = os.environ.get('METABASE_API_KEY') or subprocess.check_output(['security','find-generic-password','-s','wiom-metabase-api-key','-w']).decode().strip()
sql = open(sys.argv[1]).read() if sys.argv[1].endswith('.sql') else sys.argv[1]
req = urllib.request.Request('https://metabase.wiom.in/api/dataset', data=json.dumps({"database":113,"type":"native","native":{"query":sql}}).encode(), headers={'x-api-key':key,'Content-Type':'application/json'})
r = json.load(urllib.request.urlopen(req, timeout=600))
d = r.get('data',{})
if r.get('error'): print('ERR', r['error']); sys.exit(1)
cols=[c['name'] for c in d['cols']]
print('\t'.join(cols))
for row in d['rows']: print('\t'.join(str(x) for x in row))
