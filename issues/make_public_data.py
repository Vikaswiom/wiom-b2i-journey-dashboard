"""Copy the CSP Issue Lens dataset and the Understanding tree page into this repo for the public "Understanding issues" tab.
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
# The Understanding tree page (ticket rows are embedded in it): mask the same way inside its RAW array only.
t = open(os.path.join(src, 'understanding_tree.html')).read()
i = t.index('const RAW'); a = t.index('[', i); b = t.index('];', a) + 1
raw = [[mask(c) for c in row] for row in json.loads(t[a:b])]
open(os.path.join(here, 'tree.html'), 'w').write(t[:a] + json.dumps(raw, ensure_ascii=False, separators=(',', ':')) + t[b:])
print(len(d['rows']), 'tickets;', len(raw), 'tree rows;', n[0], 'numbers or ids masked')
