/* Minimal stand-in for the claude.ai dashboard runtime, so the same page runs on GitHub Pages.
   Implements what this page uses: dash.loader, dash.data, dash.draw, dash.colors, dash.setLink. */
(function () {
  const FILES = window.__DASH_FILES__;          // {datasetId: "data/file.json"}
  const loaders = {}, drawings = {}, results = {}, state = {}, mounted = new WeakMap();
  let loaded = false;
  const dash = {
    colors: ['var(--series-1)', 'var(--series-2)', 'var(--series-3)', 'var(--series-4)'],
    loader(id, def) { loaders[id] = def; },
    data(id) {
      if (!loaded) return { status: 'loading', data: [] };
      const r = results[id];
      if (!r) return { status: 'missing', data: [] };
      if (r.error) return { status: 'error', data: [], message: r.error };
      return { status: 'ok', data: r.data, columns: r.columns, meta: r.meta };
    },
    draw(name, def) {
      if (def === undefined) { runDrawing(name); return; }
      drawings[name] = def; if (loaded) runDrawing(name);
    },
    setLink(id) { try { history.replaceState(null, '', id ? '#' + id : location.pathname); } catch (e) { /* ignore */ } },
    onData() {}, params() { return {}; }, setParams() {}, resetParams() {}, refresh() {}
  };
  function runOn(el, name) {
    const def = drawings[name]; if (!def) return;
    try {
      if (typeof def === 'function') { def(el); return; }
      if (!mounted.has(el)) { el.replaceChildren(); mounted.set(el, def.mount ? def.mount(el) : undefined); }
      if (def.update) def.update(el, mounted.get(el));
    } catch (e) { console.error('drawing ' + name + ' failed', e); }
  }
  function visible(el) { return !el.closest('[hidden]'); }
  function runDrawing(name) { document.querySelectorAll('[data-draw="' + name + '"]').forEach((el) => { if (visible(el)) runOn(el, name); }); }
  function runAll(root) { (root || document).querySelectorAll('[data-draw]').forEach((el) => { if (visible(el)) runOn(el, el.getAttribute('data-draw')); }); }
  window.dash = dash;
  window.claude = { use: async () => null };
  async function load() {
    const byFile = {};
    Object.entries(FILES).forEach(([id, f]) => { (byFile[f] = byFile[f] || []).push(id); });
    await Promise.all(Object.entries(byFile).map(async ([file, ids]) => {
      let answer = null, err = null;
      try { const r = await fetch(file + '?v=' + Date.now(), { cache: 'no-store' }); if (!r.ok) throw new Error('HTTP ' + r.status); answer = await r.json(); }
      catch (e) { err = 'Failed to load ' + file + ': ' + e.message; }
      for (const id of ids) {
        if (err) { results[id] = { error: err }; continue; }
        try {
          const out = loaders[id] ? await loaders[id].fn({ answer }) : answer;
          results[id] = Array.isArray(out) ? { data: out, columns: out[0] ? Object.keys(out[0]) : [] } : { data: out.data, columns: out.columns, meta: out.meta };
        } catch (e) { results[id] = { error: e.message }; }
      }
    }));
    loaded = true; runAll();
  }
  document.addEventListener('DOMContentLoaded', () => {
    runAll();   // first frame: placeholders
    load();
    let t; window.addEventListener('resize', () => { clearTimeout(t); t = setTimeout(() => runAll(), 150); });
    new MutationObserver((ms) => { ms.forEach((m) => { if (m.attributeName === 'hidden' && !m.target.hidden) runAll(m.target); }); })
      .observe(document.body, { attributes: true, subtree: true, attributeFilter: ['hidden'] });
  });
})();
