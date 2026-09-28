// Header EN/KO toggle. The preference lives on <html data-pref> (set before paint by the inline
// script in _layouts/default.html) and in localStorage.
//  - On an article page, the toggle switches to the other version of that article, and the
//    language it doesn't exist in is disabled (entries without a Korean version stay original).
//  - Elsewhere, it switches which version lists and search results show.
(() => {
  "use strict";

  const KEY = "archive-lang";
  const root = document.documentElement;
  const article = document.querySelector("article[data-page-lang]");
  const buttons = [...document.querySelectorAll("[data-set-lang]")];

  const save = (lang) => { try { localStorage.setItem(KEY, lang); } catch { /* storage blocked */ } };

  function sync() {
    const pageLang = article && article.dataset.pageLang;
    const active = pageLang || root.dataset.pref;
    for (const button of buttons) {
      const lang = button.dataset.setLang;
      const available = !article || lang === pageLang || article.dataset.altLang === lang;
      button.setAttribute("aria-pressed", String(lang === active));
      button.disabled = !available;
      button.title = available ? "" : lang === "ko" ? "한국어 버전이 없습니다" : "No English version";
    }
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-set-lang]");
    if (!button || button.disabled) return;
    const lang = button.dataset.setLang;
    save(lang);
    root.dataset.pref = lang;
    if (article && article.dataset.altLang === lang) {
      location.href = article.dataset.altUrl;
      return;
    }
    sync();
    document.dispatchEvent(new CustomEvent("archive:langchange", { detail: lang }));
  });

  sync();
})();
