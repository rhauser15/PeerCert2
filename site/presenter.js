// Presenter controls shared by the demo mockups.
//   → / Space / PageDown (clicker): next step     ← / PageUp: previous step
//   R: restart                                    H: show/hide presenter notes (hidden by default)
//   B: toggle a fake browser bar with a realistic URL (or ?frame=1)
//   ?step=N in the URL jumps to step N
//   Pages can also call Presenter.onClick({ step: [elementIds] }) so clicking the real UI advances the demo
window.Presenter = {
  init(steps, reset) {
    let i = 0, busy = false;
    const box = document.getElementById("presenter");
    const render = () => {
      box.innerHTML = `<b>${i}/${steps.length - 1}</b> ${steps[i]?.[0] || ""}<span class="keys">→ next · ← back · R restart · H hide</span>`;
    };
    const run = async (n, instant) => { busy = true; try { await steps[n][1](instant); } finally { busy = false; } };
    const next = async () => { if (busy || i >= steps.length - 1) return; i++; render(); await run(i, false); };
    const back = async () => {
      if (busy || i === 0) return;
      i--; reset();
      for (let n = 0; n <= i; n++) await run(n, true);
      render();
    };
    document.addEventListener("keydown", e => {
      // While typing in a field, only a clicker's PageDown/PageUp drive the demo.
      if (e.target.closest?.("input, textarea, [contenteditable]") && !["PageDown", "PageUp"].includes(e.key)) return;
      if (["ArrowRight", " ", "PageDown"].includes(e.key)) { e.preventDefault(); next(); }
      else if (["ArrowLeft", "PageUp"].includes(e.key)) { e.preventDefault(); back(); }
      else if (e.key.toLowerCase() === "r") { i = 0; reset(); run(0, true); render(); }
      else if (e.key.toLowerCase() === "h") box.classList.toggle("hidden");
      else if (e.key.toLowerCase() === "b") this.frame(!document.documentElement.classList.contains("framed"));
    });
    box.addEventListener("click", next);
    box.classList.add("hidden");  // keep the screen clean for the audience; H shows notes
    const bar = document.createElement("div");
    bar.className = "fakebar";
    const icon = document.querySelector('link[rel="icon"]')?.href || "";
    bar.innerHTML = `<div class="fb-tabs"><span class="fb-lights"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></span>
        <span class="fb-tab">${icon ? `<img src="${icon}" alt="">` : ""}<span class="fb-t">${document.title}</span><span class="fb-x">✕</span></span><span class="fb-plus">＋</span></div>
      <div class="fb-bar"><span class="fb-nav"><svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M10 3 5 8l5 5"/></svg><svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.6"><path d="m6 3 5 5-5 5"/></svg><svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M13 8a5 5 0 1 1-1.5-3.5M13 2.5V5h-2.5"/></svg></span><span class="fb-url"><svg class="fb-lock" viewBox="0 0 12 14" width="11" height="13" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="1.5" y="6" width="9" height="7" rx="1.5"/><path d="M3.5 6V4a2.5 2.5 0 0 1 5 0v2"/></svg><span class="fb-host"></span><span class="fb-path"></span></span><span class="fb-me">${document.querySelector(".avatar, .me")?.textContent || ""}</span></div>`;
    document.body.prepend(bar);
    const meta = document.querySelector('meta[name="demo-url"]');
    if (meta) this.setUrl(meta.content);
    // ?still=1 turns off animations (for screenshots)
    if (new URLSearchParams(location.search).get("still")) document.documentElement.classList.add("still");
    const q = new URLSearchParams(location.search).get("frame");
    this.frame(q != null ? q !== "0" : localStorage.getItem("demoFrame") === "1");
    this.next = next;
    this.index = () => i;  // current step, so a page can advance when its target element is clicked
    this.busy = () => busy;
    reset(); run(0, true); render();
    // ?step=N jumps straight to step N (for rehearsal).
    const jump = parseInt(new URLSearchParams(location.search).get("step"), 10);
    if (jump > 0) (async () => { for (let n = 1; n <= Math.min(jump, steps.length - 1); n++) await run(n, true); i = Math.min(jump, steps.length - 1); render(); })();
  },
  // Types into an input quickly, with an uneven pace and short pauses after punctuation.
  async type(input, text) {
    const wait = ms => new Promise(r => setTimeout(r, ms));
    input.value = "";
    for (const ch of text) {
      input.value += ch;
      input.scrollTop = input.scrollHeight;
      let ms = 6 + Math.random() * 10;  // fast: reads as typing without slowing the demo
      if (",.?!".includes(ch)) ms += 40;
      await wait(ms);
    }
    await wait(200);
  },
  // Clicking a listed element advances to that step. Steps check Presenter.clicked() to skip their
  // own simulated click when the presenter clicked for real.
  onClick(targets) {
    let real = false;
    this.clicked = () => { const r = real; real = false; return r; };
    document.addEventListener("click", e => {
      if (this.busy()) return;
      const want = targets[this.index() + 1];
      if (want && want.some(id => e.target.closest("#" + id))) { real = true; this.next(); }
    });
    const css = document.createElement("style");
    css.textContent = [...new Set(Object.values(targets).flat())].map(id => `#${id}`).join(",") + "{cursor:pointer}";
    document.head.appendChild(css);
  },
  // Brief pressed state on a button, as if clicked.
  async press(el) {
    if (!el) return;
    el.classList.add("pressed");
    await new Promise(r => setTimeout(r, 180));
    el.classList.remove("pressed");
  },
  // Show or hide the fake browser bar; the choice is remembered between pages.
  frame(on) {
    document.documentElement.classList.toggle("framed", on);
    localStorage.setItem("demoFrame", on ? "1" : "0");
  },
  setUrl(url) {
    const [host, ...rest] = url.split("/");
    document.querySelectorAll(".fakebar .fb-host").forEach(e => e.textContent = host);
    document.querySelectorAll(".fakebar .fb-path").forEach(e => e.textContent = rest.length ? "/" + rest.join("/") : "");
  },
};
