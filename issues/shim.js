// Minimal stand-in for the claude.ai Data-artifact runtime so issues/index.html runs on GitHub Pages.
// Provides window.dash (data, calc, draw, colors) over one static JSON file per dataset.
(function () {
  const DATASETS = window.__DASH_FILES__;       // {datasetId: "data/file.json"}
  const raw = {}, calcs = {}, memo = {}, draws = [];
  let loaded = false;
  const rowsOf = (j) => (Array.isArray(j) ? j : j && Array.isArray(j.rows) ? j.rows : j && Array.isArray(j.data) ? j.data : []);
  function data(id) {
    if (calcs[id]) {
      if (!loaded) return { status: 'loading', data: null };
      if (!(id in memo)) {
        const c = calcs[id];
        const ins = c.inputs.map((i) => { const d = data(i); return d.data == null ? [] : d.data; });
        try { memo[id] = c.fn(...ins); } catch (e) { console.error('calc', id, e); memo[id] = []; }
      }
      return { status: 'ok', data: memo[id] };
    }
    if (!loaded) return { status: 'loading', data: [] };
    if (!(id in raw)) return { status: 'missing', data: [] };
    return { status: 'ok', data: raw[id], meta: raw[id + '__meta'] };
  }
  const visible = (el) => { for (let n = el; n; n = n.parentElement) if (n.hidden) return false; return true; };
  let pending = false;
  function redraw() {
    if (pending) return; pending = true;
    setTimeout(() => {
      pending = false;
      for (const d of draws) {
        document.querySelectorAll('[data-draw="' + d.name + '"]').forEach((el) => {
          if (!visible(el)) return;
          try {
            if (typeof d.fn === 'function') d.fn(el);
            else { if (!el.__made) { el.replaceChildren(); el.__made = d.fn.mount ? d.fn.mount(el) || {} : {}; } d.fn.update && d.fn.update(el, el.__made); }
          } catch (e) { console.error('draw', d.name, e); }
        });
      }
    }, 0);
  }
  window.dash = {
    data, calc: (id, o) => { calcs[id] = o; },
    draw: (name, fn) => { if (fn) draws.push({ name, fn }); else redraw(); },
    onData: () => {}, loader: () => {}, refresh: () => {}, params: () => ({}), setParams: () => {}, resetParams: () => {}, setLink: () => {},
    colors: ['var(--series-1)', 'var(--series-2)', 'var(--series-3)', 'var(--series-4)']
  };
  window.claude = { use: () => Promise.reject(new Error('Read-only copy')) };
  new MutationObserver(() => redraw()).observe(document.documentElement, { attributes: true, subtree: true, attributeFilter: ['hidden'] });
  let rt = null; addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(redraw, 150); });
  Promise.all(Object.entries(DATASETS).map(([id, url]) => fetch(url, { cache: 'no-cache' }).then((r) => r.json()).then((j) => { raw[id] = rowsOf(j); if (j && j.meta) raw[id + '__meta'] = j.meta; }).catch((e) => { console.error(url, e); raw[id] = []; })))
    .then(() => { loaded = true; redraw(); });
  document.addEventListener('DOMContentLoaded', redraw);
})();
