"""Copy the CSP Issue Lens dataset into this repo for the public "Understanding issues" tab.
Source: ~/Projects/csp-issue-lens/csp_issue_lens.json (built by the csp-issue-lens skill; phone numbers already masked).
Also masks any run of 8+ digits (UTRs, ticket and customer ids) and UPI handles. Run after each Issue Lens rebuild, then commit."""
import json, os, re, shutil
src = os.path.expanduser('~/Projects/csp-issue-lens')
d = json.load(open(os.path.join(src, 'csp_issue_lens.json')))
n = [0]
def mask(v):
    if not isinstance(v, str): return v
    def m(x): n[0] += 1; return 'XXXX' + x.group()[-2:] if x.group().isdigit() else '[UPI id]'
    return re.sub(r'\d{8,}|[\w.+-]+@[a-zA-Z][\w-]*\b(?!\.)', m, v)
for r in d['rows']:
    for k in list(r):
        if k not in ('ref', 'created', 'month'): r[k] = mask(r[k])
here = os.path.dirname(os.path.abspath(__file__))
json.dump(d, open(os.path.join(here, 'tickets.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
shutil.copy(os.path.join(src, 'index.html'), os.path.join(here, 'index.html'))
print(len(d['rows']), 'tickets;', n[0], 'numbers or ids masked')
