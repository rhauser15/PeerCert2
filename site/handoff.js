// Live handoff from the Fin Messenger to a Salesforce agent, using the Messaging for In-App and Web
// REST API (Custom Client deployment). The customer keeps chatting in the Fin Messenger.
//
// Fin's data travels as routing attributes; the Omni-Channel routing Flow turns them into a Case with the
// transcript, summary, churn risk and expansion signal, links it to the Messaging Session, and routes it.
// Add ?live=0 to the URL to rehearse without Salesforce (a scripted agent reply is shown instead).
window.Handoff = (() => {
  const cfg = DEMO.miaw;
  const live = new URLSearchParams(location.search).get("live") !== "0";
  let token = null, convId = null, abort = null, active = false, handlers = {}, joined = false, seen = new Set();

  const uuid = () => crypto.randomUUID();
  const chunks = (text, n, size = 255) => {
    const out = {};
    for (let k = 0; k < n; k++) out[k] = text.slice(k * size, (k + 1) * size);
    return out;
  };
  // Retries briefly on 503 (the messaging service can be slow to pick up a newly published deployment).
  async function api(path, body, method = "POST", tries = 3) {
    for (let k = 1; ; k++) {
      try { return await once(path, body, method); }
      catch (e) { if (k >= tries || !/ 503 /.test(e.message)) throw e; await new Promise(r => setTimeout(r, 1500)); }
    }
  }
  async function once(path, body, method) {
    const r = await fetch(cfg.scrt + path, {
      method,
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!r.ok) throw new Error(`${path} ${r.status} ${await r.text()}`);
    return r.status === 204 ? null : r.json().catch(() => null);
  }

  async function start(opts) {
    handlers = opts; joined = false; seen = new Set();
    if (!live) return offline(opts);
    try {
      const auth = await api("/iamessage/api/v2/authorization/unauthenticated/access-token", {
        orgId: cfg.orgId, esDeveloperName: cfg.deployment, capabilitiesVersion: "1", platform: "Web",
      });
      token = auth.accessToken;
      // Summary and transcript are split across 255-character parameters; the Flow joins them back up.
      const s = chunks(opts.summary, 3), t = chunks(opts.transcript, 10);
      const routingAttributes = { ...opts.attrs };
      for (let k = 0; k < 3; k++) routingAttributes[`Fin_Summary_${k + 1}`] = s[k];
      for (let k = 0; k < 10; k++) routingAttributes[`Fin_Transcript_${k + 1}`] = t[k];
      convId = uuid();
      await api("/iamessage/api/v2/conversation", { conversationId: convId, esDeveloperName: cfg.deployment, routingAttributes });
      listen();
      await api(`/iamessage/api/v2/conversation/${convId}/message`, message(opts.firstMessage));
      active = true;
      opts.onQueued?.();
      console.info("[handoff] live conversation", convId);
    } catch (e) {
      console.warn("[handoff] live handoff failed, using rehearsal mode:", e);
      return offline(opts);
    }
  }

  // Fin resolved the conversation: "Create Salesforce case on resolution". Opens a conversation carrying Fin's data
  // (the routing Flow creates a closed case and doesn't route it), then ends it.
  async function resolve(opts) {
    if (!live) return;
    try {
      const auth = await once("/iamessage/api/v2/authorization/unauthenticated/access-token", {
        orgId: cfg.orgId, esDeveloperName: cfg.deployment, capabilitiesVersion: "1", platform: "Web",
      });
      const t = auth.accessToken, id = uuid();
      const s = chunks(opts.summary, 3), tr = chunks(opts.transcript, 10);
      const routingAttributes = { ...opts.attrs };
      for (let k = 0; k < 3; k++) routingAttributes[`Fin_Summary_${k + 1}`] = s[k];
      for (let k = 0; k < 10; k++) routingAttributes[`Fin_Transcript_${k + 1}`] = tr[k];
      const post = (path, body, method = "POST") => fetch(cfg.scrt + path, { method, headers: { "Content-Type": "application/json", Authorization: "Bearer " + t }, body: body ? JSON.stringify(body) : undefined });
      let r;
      for (let k = 0; k < 3; k++) {
        r = await post("/iamessage/api/v2/conversation", { conversationId: id, esDeveloperName: cfg.deployment, routingAttributes });
        if (r.status !== 503) break;
        await new Promise(res => setTimeout(res, 1500));
      }
      if (!r.ok) throw new Error("conversation " + r.status);
      setTimeout(() => post(`/iamessage/api/v2/conversation/${id}?esDeveloperName=${cfg.deployment}`, null, "DELETE").catch(() => {}), 8000);
      console.info("[handoff] logged resolved conversation", id);
    } catch (e) { console.warn("[handoff] couldn't log the resolved conversation", e); }
  }

  const message = text => ({
    message: { id: uuid(), messageType: "StaticContentMessage", staticContent: { formatType: "Text", text } },
    esDeveloperName: cfg.deployment, isNewMessagingSession: false,
  });

  async function send(text) {
    if (!active) return;
    if (!live || !convId) return offlineReply(text);
    try { await api(`/iamessage/api/v2/conversation/${convId}/message`, message(text)); }
    catch (e) { console.warn("[handoff] send failed", e); }
  }

  // Server-sent events (EventSource can't send the auth headers, so read the stream with fetch).
  async function listen() {
    abort = new AbortController();
    try {
      const r = await fetch(cfg.scrt + "/eventrouter/v1/sse", {
        headers: { Authorization: "Bearer " + token, "X-Org-Id": cfg.orgId, Accept: "text/event-stream" },
        signal: abort.signal,
      });
      const reader = r.body.getReader(), dec = new TextDecoder();
      let buf = "";
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        let cut;
        while ((cut = buf.indexOf("\n\n")) >= 0) {
          const raw = buf.slice(0, cut); buf = buf.slice(cut + 2);
          const ev = /^event:\s*(.*)$/m.exec(raw)?.[1], data = /^data:\s*(.*)$/m.exec(raw)?.[1];
          if (ev && data) { try { onEvent(ev.trim(), JSON.parse(data)); } catch (e) { console.warn(e); } }
        }
      }
    } catch (e) {
      if (e.name !== "AbortError") { console.warn("[handoff] event stream closed", e); if (active) setTimeout(listen, 1500); }
    }
  }

  function onEvent(ev, data) {
    const entry = data.conversationEntry || {};
    if (entry.conversationId && convId && entry.conversationId.toLowerCase() !== convId.toLowerCase()) return;
    const role = entry.sender?.role;
    let payload = {};
    try { payload = JSON.parse(entry.entryPayload || "{}"); } catch (e) { /* ignore */ }
    if (ev === "CONVERSATION_MESSAGE" && role === "Agent") {
      const text = payload.abstractMessage?.staticContent?.text;
      const id = payload.abstractMessage?.id || entry.identifier;
      if (text && !seen.has(id)) { seen.add(id); join(); handlers.onAgentMessage?.(text); }
    } else if (ev === "CONVERSATION_PARTICIPANT_CHANGED") {
      const add = (payload.entries || []).some(x => x.operation === "add" && x.participant?.role === "Agent");
      if (add) join();
    } else if (ev === "CONVERSATION_TYPING_STARTED_INDICATOR" && role === "Agent") {
      join(); handlers.onTyping?.(true);
    } else if (ev === "CONVERSATION_TYPING_STOPPED_INDICATOR" && role === "Agent") {
      handlers.onTyping?.(false);
    } else if (ev === "CONVERSATION_CLOSE_CONVERSATION") {
      active = false; handlers.onEnd?.();
    }
  }
  function join() { if (!joined) { joined = true; handlers.onJoin?.(); } }

  // Rehearsal mode: same screens, no Salesforce.
  function offline(opts) {
    active = true; offlineTurn = 0;
    opts.onQueued?.();
    setTimeout(() => { join(); handlers.onTyping?.(true); }, 5000);
    setTimeout(() => {
      handlers.onTyping?.(false);
      handlers.onAgentMessage?.("Hi Sam, John here from the Multi-Location team. Thanks for being upfront about Aurora. Before you drop it, there are two options that keep it on Yelp: we can pause Aurora's ads for up to 90 days at no cost, so the page and its reviews stay up, or keep it running with a $240 credit for each of the next two months while our specialist retunes its targeting. And congratulations on Castle Rock! If its ads go live within 30 days of opening, you'll get $500 in launch credit. I've asked Tom, your account manager, to reach out this week so it's set up before you open. Which would you prefer for Aurora?");
    }, 9000);
  }
  let offlineTurn = 0;
  function offlineReply() {
    const turn = ++offlineTurn;
    setTimeout(() => handlers.onTyping?.(true), 1500);
    setTimeout(() => {
      handlers.onTyping?.(false);
      if (turn === 1) handlers.onAgentMessage?.("Done, Sam. Aurora's ads are paused for 90 days with no fee, so the page and its reviews stay up and you can restart any time. Tom, your account manager, will reach out this week to get Castle Rock set up before you open. Anything else I can help with tonight?");
      else { handlers.onAgentMessage?.("Anytime, Sam. Good luck with Castle Rock!"); setTimeout(() => { active = false; handlers.onEnd?.(); }, 2500); }
    }, 5000);
  }

  async function end() {
    const id = convId;
    active = false; convId = null; abort?.abort();
    if (live && id && token) {
      try { await api(`/iamessage/api/v2/conversation/${id}?esDeveloperName=${cfg.deployment}`, null, "DELETE"); } catch (e) { /* already closed */ }
    }
    token = null;
  }

  return { start, resolve, send, end, active: () => active, live: () => live };
})();
