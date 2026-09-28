// Client-side search over /search.json: free text + keyword facets + date range.
// All state lives in the URL (?q=&k=&from=&to=&kind=&sort=) so searches are shareable.
// An original and its Korean translation share a `group`. A query matches the group if either
// version matches, and the group is shown once in the reader's language (header EN/KO toggle,
// assets/js/lang.js), falling back to the original when there's no version in that language.
(() => {
  "use strict";

  const form = document.getElementById("search");
  const $ = (id) => document.getElementById(id);
  const input = $("q"), from = $("from"), to = $("to"), kind = $("kind"), sort = $("sort");
  const facets = $("facets"), status = $("status"), results = $("results");

  const WEIGHT = { title: 10, keywords: 8, summary: 4, content: 1 };
  const MAX_CONTENT_HITS = 10;
  const MAX_FACETS = 24;

  let entries = [];
  const versions = new Map(); // group -> [original, translation?]
  let selected = new Set(); // keyword facets, AND-ed

  // ---------- text helpers ----------

  // Plain lowercasing (no Unicode decomposition) keeps string offsets aligned with the
  // original text — needed for snippets — and leaves Hangul syllables intact.
  const fold = (s) => (s || "").toLowerCase();
  const escapeHTML = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const escapeRE = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  // `actor "main thread" -combine` → terms: actor, main thread; excluded: combine
  function parseQuery(q) {
    const terms = [], excluded = [];
    const re = /(-?)(?:"([^"]+)"|(\S+))/g;
    let m;
    while ((m = re.exec(q))) {
      const t = fold((m[2] || m[3]).trim());
      if (!t) continue;
      (m[1] ? excluded : terms).push(t);
    }
    return { terms, excluded };
  }

  function countOf(haystack, needle) {
    let n = 0, i = haystack.indexOf(needle);
    while (i !== -1 && n < MAX_CONTENT_HITS) { n++; i = haystack.indexOf(needle, i + needle.length); }
    return n;
  }

  function highlight(text, terms) {
    const safe = escapeHTML(text);
    if (!terms.length) return safe;
    const re = new RegExp(`(${terms.map((t) => escapeRE(escapeHTML(t))).join("|")})`, "gi");
    return safe.replace(re, "<mark>$1</mark>");
  }

  function snippet(entry, terms) {
    const text = entry.content || "";
    const lower = entry._content;
    for (const t of terms) {
      const i = lower.indexOf(t);
      if (i === -1) continue;
      const start = Math.max(0, text.lastIndexOf(" ", Math.max(0, i - 80)) + 1);
      const end = Math.min(text.length, i + 180);
      return (start > 0 ? "…" : "") + text.slice(start, end).trim() + (end < text.length ? "…" : "");
    }
    return entry.summary || (text.length > 220 ? text.slice(0, 220).trim() + "…" : text);
  }

  // ---------- search ----------

  function run() {
    const { terms, excluded } = parseQuery(input.value);
    const lo = from.value, hi = to.value, type = kind.value;

    let matched = [];
    for (const e of entries) {
      if (type && e.kind !== type) continue;
      if (lo && e.date < lo) continue; // ISO dates compare correctly as strings
      if (hi && e.date > hi) continue;
      if (selected.size && ![...selected].every((k) => e._keywordSet.has(k))) continue;
      if (excluded.some((t) => e._all.includes(t))) continue;

      let score = 0, ok = true;
      for (const t of terms) {
        const s =
          WEIGHT.title * countOf(e._title, t) +
          WEIGHT.keywords * countOf(e._keywords, t) +
          WEIGHT.summary * countOf(e._summary, t) +
          WEIGHT.content * countOf(e._content, t);
        if (!s) { ok = false; break; } // every term must match somewhere
        score += s;
      }
      if (ok) matched.push({ e, score });
    }
    matched = onePerGroup(matched);

    const byDate = (a, b) => (a.e.date < b.e.date ? 1 : a.e.date > b.e.date ? -1 : 0);
    if (sort.value === "oldest") matched.sort((a, b) => -byDate(a, b));
    else if (sort.value === "newest" || !terms.length) matched.sort(byDate);
    else matched.sort((a, b) => b.score - a.score || byDate(a, b));

    render(matched.map((m) => m.e), terms);
    renderFacets(matched.map((m) => m.e));
    syncURL();
  }

  // One result per group: best score across its versions, displayed in the preferred language.
  function onePerGroup(matched) {
    const best = new Map();
    for (const m of matched) best.set(m.e.group, Math.max(best.get(m.e.group) ?? 0, m.score));
    const pref = document.documentElement.dataset.pref || "en";
    return [...best].map(([group, score]) => {
      const all = versions.get(group);
      return { e: all.find((v) => v.lang === pref) || all.find((v) => !v.translation) || all[0], score };
    });
  }

  function render(list, terms) {
    const filtered = input.value.trim() || selected.size || from.value || to.value || kind.value;
    status.textContent = filtered
      ? `${list.length} result${list.length === 1 ? "" : "s"}${list.length ? "" : " — try fewer words or a wider date range"}`
      : `${list.length} ${list.length === 1 ? "entry" : "entries"} in the archive`;

    results.innerHTML = list.map((e) => `
      <li class="result">
        <div class="result-meta">
          <span class="badge badge-${escapeHTML(e.kind)}">${escapeHTML(e.kind)}</span>
          <time datetime="${e.date}">${formatDate(e.date)}</time>
          ${e.author ? `<span>· ${escapeHTML(e.author)}</span>` : ""}
        </div>
        <h3 class="result-title"><a href="${escapeHTML(e.url)}">${highlight(e.title, terms)}</a></h3>
        <p class="result-snippet">${highlight(snippet(e, terms), terms)}</p>
        ${e.keywords.length ? `<ul class="chips">${e.keywords.map((k) =>
          `<li><button type="button" class="chip${selected.has(k) ? " is-on" : ""}" data-k="${escapeHTML(k)}">${escapeHTML(k)}</button></li>`
        ).join("")}</ul>` : ""}
      </li>`).join("");
  }

  function renderFacets(list) {
    const counts = new Map();
    for (const e of list) for (const k of e.keywords) counts.set(k, (counts.get(k) || 0) + 1);
    for (const k of selected) if (!counts.has(k)) counts.set(k, 0); // keep active filters visible

    const top = [...counts].sort((a, b) =>
      selected.has(b[0]) - selected.has(a[0]) || b[1] - a[1] || a[0].localeCompare(b[0])
    ).slice(0, MAX_FACETS);

    facets.innerHTML = top.map(([k, n]) =>
      `<button type="button" class="chip${selected.has(k) ? " is-on" : ""}" data-k="${escapeHTML(k)}" aria-pressed="${selected.has(k)}">` +
      `${escapeHTML(k)} <span class="count">${n}</span></button>`
    ).join("") + (selected.size ? `<button type="button" class="chip chip-clear" data-clear>Clear keywords</button>` : "");
  }

  const formatDate = (iso) =>
    new Date(`${iso}T00:00:00`).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });

  // ---------- URL state ----------

  function syncURL() {
    const p = new URLSearchParams();
    if (input.value.trim()) p.set("q", input.value.trim());
    for (const k of selected) p.append("k", k);
    if (from.value) p.set("from", from.value);
    if (to.value) p.set("to", to.value);
    if (kind.value) p.set("kind", kind.value);
    if (sort.value) p.set("sort", sort.value);
    const qs = p.toString();
    history.replaceState(null, "", qs ? `?${qs}` : location.pathname);
  }

  function readURL() {
    const p = new URLSearchParams(location.search);
    input.value = p.get("q") || "";
    selected = new Set(p.getAll("k").flatMap((k) => k.split(",")).map((k) => k.trim()).filter(Boolean));
    from.value = p.get("from") || "";
    to.value = p.get("to") || "";
    kind.value = p.get("kind") || "";
    sort.value = p.get("sort") || "";
  }

  // ---------- events ----------

  let timer;
  input.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(run, 120); });
  for (const el of [from, to, kind, sort]) el.addEventListener("change", run);
  document.addEventListener("archive:langchange", run);

  form.addEventListener("click", (ev) => {
    const preset = ev.target.closest("[data-preset]");
    if (!preset) return;
    const days = preset.dataset.preset;
    if (days === "all") { from.value = ""; to.value = ""; }
    else {
      const d = new Date();
      to.value = "";
      d.setDate(d.getDate() - Number(days));
      from.value = d.toISOString().slice(0, 10);
    }
    run();
  });

  document.addEventListener("click", (ev) => {
    const chip = ev.target.closest("button.chip");
    if (!chip) return;
    if (chip.hasAttribute("data-clear")) selected.clear();
    else {
      const k = chip.dataset.k;
      selected.has(k) ? selected.delete(k) : selected.add(k);
    }
    run();
  });

  document.addEventListener("keydown", (ev) => {
    if (ev.key === "/" && document.activeElement !== input && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) {
      ev.preventDefault();
      input.focus();
      input.select();
    } else if (ev.key === "Escape" && document.activeElement === input && input.value) {
      input.value = "";
      run();
    }
  });

  // ---------- boot ----------

  readURL();
  fetch(form.dataset.index)
    .then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then((data) => {
      entries = data.map((e) => {
        const keywords = e.keywords || [];
        const prepared = {
          ...e,
          keywords,
          _keywordSet: new Set(keywords),
          _title: fold(e.title),
          _keywords: fold(keywords.join(" | ")),
          _summary: fold(e.summary),
          _content: fold(e.content),
        };
        prepared._all = [prepared._title, prepared._keywords, prepared._summary, prepared._content].join("\n");
        return prepared;
      });
      for (const e of entries) versions.set(e.group, [...(versions.get(e.group) || []), e]);
      run();
    })
    .catch((err) => { status.textContent = `Could not load the search index (${err.message}).`; });
})();
