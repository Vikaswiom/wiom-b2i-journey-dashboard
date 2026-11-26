"""Copy the CSP Issue Lens dataset, the Understanding tree page and the Calls to Tickets page into this repo for the public "Understanding issues" tab.
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
# Names used on this dashboard (user's naming, 26 Nov 2026). The Issue Lens project itself still tags tickets with
# the lens "Experience gap"; here it is shown as "Action gap", and its two summary groups take the tree's names.
RENAME = [('Experience gap', 'Action gap'), ('experience gap', 'action gap'), ('Design can act on', 'Experience issue'), ('Outside design', 'Bug')]
for f in ('tickets.json', 'index.html'):
    fp = os.path.join(here, f); t = open(fp).read()
    for a, b in RENAME: t = t.replace(a, b)
    open(fp, 'w').write(t)

# The Understanding tree page (ticket rows are embedded in it): mask the same way inside its RAW array only.
t = open(os.path.join(src, 'understanding_tree.html')).read()
i = t.index('const RAW'); a = t.index('[', i); b = t.index('];', a) + 1
raw = [[mask(c) for c in row] for row in json.loads(t[a:b])]
open(os.path.join(here, 'tree.html'), 'w').write(t[:a] + json.dumps(raw, ensure_ascii=False, separators=(',', ':')) + t[b:])
print(len(d['rows']), 'tickets;', len(raw), 'tree rows;', n[0], 'numbers or ids masked')

# The Calls to Tickets page (calls/calls_tree.html + cvt_calls.json + cvt_tickets.json, fetched by relative URL).
# For the public copy: mask long numbers, UPI ids and emails in every text field, and drop the links to the
# internal support portal and Slack threads (internal addresses must not be published).
cdir = os.path.join(src, 'calls'); cout = os.path.join(here, 'calls'); os.makedirs(cout, exist_ok=True)
mail = re.compile(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+')
mention = re.compile(r'@[A-Z][a-z]+(?: [A-Z][a-z]+)?')   # an agent tagged by name in a note
def clean(v): return mask(mention.sub('[agent]', mail.sub('[email]', v))) if isinstance(v, str) else v
m0 = n[0]; dropped = 0
calls = json.load(open(os.path.join(cdir, 'cvt_calls.json')))
calls = [[row[0]] + [clean(c) for c in row[1:]] for row in calls]
tks = json.load(open(os.path.join(cdir, 'cvt_tickets.json')))
for row in tks:
    for i in range(1, len(row)):
        if isinstance(row[i], dict):
            for k in ('portal', 'slack'):
                if row[i].get(k): row[i][k] = ''; dropped += 1
            row[i] = {k: clean(v) for k, v in row[i].items()}
        else: row[i] = clean(row[i])
json.dump(calls, open(os.path.join(cout, 'cvt_calls.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
json.dump(tks, open(os.path.join(cout, 'cvt_tickets.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
# Inside the dashboard the page sits in a frame: a smooth scroll does not carry to the page around it, so jump instead.
page = open(os.path.join(cdir, 'calls_tree.html')).read().replace('"smooth"', '"auto"')
open(os.path.join(cout, 'page.html'), 'w').write(page)
print(len(calls), 'call issues;', len(tks), 'tickets with details;', n[0] - m0, 'more numbers or ids masked;', dropped, 'internal links dropped')
