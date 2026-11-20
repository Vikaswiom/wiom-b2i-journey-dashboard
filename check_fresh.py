"""Fail (exit 1) unless the TAS tables have synced past 00:30 IST today, so 'yesterday' is complete.
CleverTap is not checked: it only feeds the Overview, whose cohort is 5+ days old."""
import json, subprocess, sys, os, urllib.request
key = os.environ.get('METABASE_API_KEY') or subprocess.check_output(['security','find-generic-password','-s','wiom-metabase-api-key','-w']).decode().strip()
sql = """SELECT t, MAX(s) last_synced, MAX(s) >= DATEADD(minute,30,CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::DATE::TIMESTAMP_NTZ) ok FROM (
 SELECT 'transitions' t, CONVERT_TIMEZONE('Asia/Kolkata', _fivetran_synced)::TIMESTAMP_NTZ s FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_STATE_TRANSITION_LOG WHERE _fivetran_synced >= DATEADD(day,-2,CURRENT_TIMESTAMP())
 UNION ALL SELECT 'outbox', CONVERT_TIMEZONE('Asia/Kolkata', _fivetran_synced)::TIMESTAMP_NTZ FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.OUTBOX_RECORD WHERE _fivetran_synced >= DATEADD(day,-2,CURRENT_TIMESTAMP())
 UNION ALL SELECT 'candidates', CONVERT_TIMEZONE('Asia/Kolkata', _fivetran_synced)::TIMESTAMP_NTZ FROM PROD_DB.CSP_TAS_SERVICE_CSP_TAS_SERVICE.INSTALL_EXECUTION_CANDIDATES WHERE _fivetran_synced >= DATEADD(day,-2,CURRENT_TIMESTAMP())
) GROUP BY 1"""
req = urllib.request.Request('https://metabase.wiom.in/api/dataset', data=json.dumps({"database":113,"type":"native","native":{"query":sql}}).encode(), headers={'x-api-key':key,'Content-Type':'application/json'})
r = json.load(urllib.request.urlopen(req, timeout=300))
if r.get('error'): sys.exit('freshness query failed: ' + str(r['error'])[:300])
rows = r['data']['rows']; bad = [x for x in rows if not x[2]]
for x in rows: print(f'{x[0]:14} last synced {x[1]}  {"ok" if x[2] else "NOT YET"}')
if len(rows) < 3 or bad: sys.exit('source data not complete for yesterday yet')
print('fresh')
