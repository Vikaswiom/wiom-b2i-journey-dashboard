"""Build docs/index.html (GitHub Pages) from index.html, the one source page also used by the claude.ai artifact."""
import json, re
st=json.load(open('state.json'))
files={ds:'data/'+fname for fname,ent in st['files'].items() for ds in ent['datasets']}
page=open('index.html').read().replace('<meta name="dash-one-writer">\n','')
head='''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>CSP Booking-to-Install Journey</title>
<meta name="robots" content="noindex, nofollow">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Source+Serif+4:opsz,wght@8..60,400;8..60,600&display=swap">
<style>
:root { color-scheme: light;
  --color-bg: #fbfbfa; --color-fg: #1f1e1c; --color-fg-muted: #6b6862; --color-panel: #ffffff; --color-border-line: #e4e2dc;
  --color-ok: #2f8f5b; --color-warn: #c47a12; --color-bad: #c6403a;
  --series-1: #3a6fd8; --series-2: #8a5cc7; --series-3: #1c9aa8; --series-4: #c75c8a;
  --cds-chart-muted: #b9b5ad; --cds-chart-grid: #ebe9e3; --cds-chart-axis: #c9c6be; --cds-text-secondary: #6b6862;
  --cds-surface-popover: #ffffff; --cds-border: #dcd9d2; --cds-shadow-popover: 0 6px 24px rgba(0,0,0,.12);
  --font-anthropic-sans: "Inter", system-ui, -apple-system, "Segoe UI", sans-serif; --font-anthropic-serif: "Source Serif 4", Georgia, serif;
  --cds-font-size-caption: 12px; --cds-font-size-body: 14px; --cds-font-size-heading: 18px; --cds-font-size-title: 30px; --cds-font-weight-medium: 600;
  --cds-gap-xs: 4px; --cds-gap-sm: 8px; --cds-gap-md: 14px; --cds-gap-lg: 20px; --cds-gap-xl: 32px;
  --cds-pad-xs: 4px; --cds-pad-sm: 8px; --cds-pad-md: 12px; --cds-pad-lg: 18px; --cds-pad-xl: 24px; --cds-radius: 10px;
  --cds-dur-slow: 500ms; --cds-ease-out: cubic-bezier(.2,.8,.2,1); }
@media (prefers-color-scheme: dark) { :root { color-scheme: dark;
  --color-bg: #161615; --color-fg: #ecebe7; --color-fg-muted: #a09c94; --color-panel: #1f1f1d; --color-border-line: #33322f;
  --color-ok: #5cc28a; --color-warn: #e0a24a; --color-bad: #ec6d66;
  --series-1: #7aa2f0; --series-2: #b48ee6; --series-3: #4cc4d1; --series-4: #e88ab3;
  --cds-chart-muted: #5d5a54; --cds-chart-grid: #2b2a27; --cds-chart-axis: #45433f; --cds-text-secondary: #a09c94;
  --cds-surface-popover: #262624; --cds-border: #3a3936; --cds-shadow-popover: 0 6px 24px rgba(0,0,0,.5); } }
html, body { margin: 0; background: var(--color-bg); color: var(--color-fg); font-family: var(--font-anthropic-sans); font-size: 14px; }
#dash-root { max-width: 1200px; margin: 0 auto; padding-block: 24px 48px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
[hidden] { display: none !important; }
.dash-select { font: inherit; font-size: 13px; color: var(--color-fg); background-color: var(--color-panel); border: 1px solid var(--color-border-line); border-radius: 8px; padding: 6px 10px; }
</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"></script>
<script>window.__DASH_FILES__ = '''+json.dumps(files)+''';</script>
<script>'''+open('site_shim.js').read()+'''</script>
</head>
<body>
<div id="dash-root">
'''
open('docs/index.html','w').write(head+page+'\n</div>\n</body>\n</html>\n')
print('docs/index.html', len(head+page), 'bytes;', len(files), 'datasets')

# "Understanding issues" tab: the CSP Issue Lens page, built as its own page (docs/issues/) and shown in a frame.
# Same head as above with its own title, datasets and runtime stand-in. Its data is static (issues/tickets.json).
import os, shutil
os.makedirs('docs/issues/data', exist_ok=True)
ihead = head.replace('<title>CSP Booking-to-Install Journey</title>', '<title>CSP Issue Lens</title>') \
    .replace(json.dumps(files), json.dumps({'tickets': 'data/tickets.json'})) \
    .replace(open('site_shim.js').read(), open('issues/shim.js').read()) \
    .replace('--cds-chart-muted: #b9b5ad;', '--cds-chart-muted: #b9b5ad; --cds-chart-status-critical: #c6403a;') \
    .replace('--cds-chart-muted: #5d5a54;', '--cds-chart-muted: #5d5a54; --cds-chart-status-critical: #ec6d66;')
assert 'issues' not in head and 'tickets.json' in ihead and 'dash.calc' not in head and 'calc:' in ihead and ihead.count('status-critical') == 2
ipage = open('issues/index.html').read().replace('<meta name="dash-one-writer">\n', '')
open('docs/issues/index.html', 'w').write(ihead + ipage + '\n</div>\n</body>\n</html>\n')
shutil.copy('issues/tickets.json', 'docs/issues/data/tickets.json')
print('docs/issues/index.html', len(ihead + ipage), 'bytes')

