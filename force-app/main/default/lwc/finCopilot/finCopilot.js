import { LightningElement, api, wire } from 'lwc';
import getContext from '@salesforce/apex/FinCopilotController.getContext';
import FIN_MARK from '@salesforce/resourceUrl/FinMark';

// Fin Copilot panel for the Keep and Grow demo. Answers come from the team's internal content (SOURCES)
// and the customer's account data; this build is scripted for the demo questions.
const SOURCES = {
    policy: { type: 'Internal article', title: 'Multi-Location Retention Policy (10+ locations)' },
    credit: { type: 'Internal article', title: 'Ad performance credits: eligibility and limits' },
    review: { type: 'Internal article', title: 'Booking a free Ads Optimization review' },
    pause: { type: 'Internal article', title: 'Multi-Location Retention Policy (10+ locations)' },
    playbook: { type: 'Internal article', title: 'Options for multi-location customers opening new locations or redirecting spend' },
    convo: { type: 'Conversation', title: 'Front Range Burger Co. · Cancel a location' },
    renewal: { type: 'Salesforce', title: 'Opportunity: Annual Renewal' },
    program: { type: 'Internal article', title: 'New Location Launch Program (10+ locations)' },
    shift: { type: 'Public article', title: 'Move budget between your locations' },
    launch: { type: 'Internal article', title: 'New location launch credit' }
};
const THINKING_MS = 1600;

let uid = 0;
const money = (n) => '$' + Math.round(n).toLocaleString('en-US');

export default class FinCopilot extends LightningElement {
    @api recordId;
    finMark = FIN_MARK;
    ctx = {};
    turns = [];
    draft = '';
    thinking = false;
    note = '';

    @wire(getContext, { recordId: '$recordId' })
    wiredContext({ data }) {
        if (data) this.ctx = data;
    }

    get isEmpty() {
        return !this.turns.length && !this.thinking;
    }
    get placeholder() {
        return this.turns.length ? 'Ask a follow up question...' : 'Ask a question...';
    }
    get sendDisabled() {
        return !this.draft.trim() || this.thinking;
    }
    get sendClass() {
        return 'send' + (this.sendDisabled ? '' : ' on');
    }

    handleInput(e) {
        this.draft = e.target.value;
    }
    handleKey(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            this.ask();
        }
    }
    handleSend() {
        this.ask();
    }
    handleSummarize() {
        if (this.thinking) return;
        this.respond('Summarize this conversation', this.summary());
    }

    ask() {
        const q = this.draft.trim();
        if (!q || this.thinking) return;
        this.draft = '';
        const box = this.template.querySelector('textarea');
        if (box) box.value = '';
        this.respond(q, this.answerFor(q));
    }

    respond(question, answer) {
        this.note = '';
        this.turns = [...this.turns, { id: ++uid, question, answer: null }];
        this.thinking = true;
        this.scrollDown();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.thinking = false;
            this.turns = this.turns.map((t) => (t.answer ? t : { ...t, answer: this.decorate(answer) }));
            this.scrollDown();
        }, THINKING_MS);
    }

    decorate(a) {
        const sources = (a.sources || []).map((k, i) => ({ ...SOURCES[k], n: i + 1, key: k }));
        return {
            ...a,
            sources,
            shown: sources.slice(0, 3),
            sourceLabel: sources.length === 1 ? '1 relevant source found' : `${sources.length} relevant sources found`,
            hasSources: sources.length > 0,
            more: sources.length > 3
        };
    }

    renderedCallback() {
        // Answers are built from trusted, local strings (no user input), so render their markup.
        this.template.querySelectorAll('.answer .body[data-id]').forEach((el) => {
            const t = this.turns.find((x) => String(x.id) === el.dataset.id);
            if (t && t.answer && el.dataset.rendered !== '1') {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                el.innerHTML = t.answer.html;
                el.dataset.rendered = '1';
                el.querySelectorAll('.cite').forEach((c) => {
                    const s = t.answer.sources[Number(c.textContent) - 1];
                    if (s) c.setAttribute('title', `${s.type}: ${s.title}`);
                });
            }
        });
    }

    scrollDown() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const el = this.template.querySelector('.scroll');
            if (el) el.scrollTop = el.scrollHeight;
        });
    }

    // ---- Answers -------------------------------------------------------------------------------------------
    facts() {
        const c = this.ctx || {};
        const cap = c.locationCap || 900;
        return {
            first: c.firstName || 'there',
            account: c.accountName || 'This account',
            count: c.locationCount || 12,
            loc: c.location || 'Aurora',
            cpl: c.locationCpl || 64,
            avg: c.brandCpl || 27,
            credit: Math.round(cap * 0.2),
            owner: c.ownerFirstName || 'Tom',
            expansion: c.expansion
        };
    }

    answerFor(q) {
        const s = q.toLowerCase();
        if (/summar/.test(s)) return this.summary();
        if (/confirm|wrap|close/.test(s)) return this.confirm();
        if (/draft|reply|write|respond|message/.test(s)) return this.reply();
        if (/option|offer|program|qualif|retention|save|keep|cancel|churn|credit|discount|new location|redirect|spend/.test(s)) return this.offers();
        return {
            html: "<p>I couldn't find anything in your team's content about that. Try asking about this customer's account, a policy, or a past conversation.</p>",
            sources: [],
            composer: false
        };
    }

    newCount() {
        const m = /^(\d+)/.exec((this.ctx && this.ctx.expansion) || '');
        return m ? Number(m[1]) : 4;
    }

    offers() {
        const f = this.facts();
        const n = this.newCount();
        const cite = (k) => `<span class="cite">${k}</span>`;
        const c = this.ctx || {};
        const renewal = c.renewalClose
            ? `<p><b>Heads up:</b> the Annual Renewal (${money(c.renewalAmount || 0)}) closes <b>${this.longDate(c.renewalClose)}</b>. ${cite(4)}</p>`
            : '';
        return {
            html:
                `<p>${f.first} is opening <b>${n} new locations</b> in January and wants to see how they perform before investing more. With <b>${f.count} active locations</b>, ${f.account} has three options in Support tools:</p><ul>` +
                `<li><b>Recommended: New Location Launch Program.</b> 10+ location customers get <b>$500 in ad credit per new location</b> in its first 60 days. For ${n} locations that's <b>${money(500 * n)}</b> to test performance before adding budget. ${cite(1)}</li>` +
                `<li><b>Pause ad spending for 90 days, no fee.</b> One location or the entire account. Ads restart automatically. ${cite(2)}</li>` +
                `<li><b>$1,000 retention offer</b> across all locations, if the concern is value. ${cite(2)}</li>` +
                `</ul><p><b>Account manager:</b> ${f.owner} is alerted automatically when you resolve the case (multi-location, $50K+ spend, expansion signal) and will offer an Ads Optimization Review. You don't need to book it. ${cite(3)}</p>` +
                renewal,
            text: '',
            sources: ['playbook', 'pause', 'review', 'renewal'],
            composer: false
        };
    }

    reply() {
        const f = this.facts();
        const n = this.newCount();
        const cite = (k) => `<span class="cite">${k}</span>`;
        const p1 =
            `Hi ${f.first}, congratulations on the ${n} new locations! Because you have ${f.count} active locations, you qualify for our New Location Launch Program: ` +
            `$500 in ad credit for each new location in its first 60 days, so ${money(500 * n)} across all ${n}. It's a way to see how they perform before you invest more.`;
        const p2 =
            `Credits are applied automatically when each new location's page goes live, and you can track their leads side by side in Yelp for Business. ` +
            `Your account manager will also reach out to plan launch budgets with you.`;
        const p3 = 'Want me to enroll your account?';
        return {
            html: `<p>${p1} ${cite(1)}</p><p>${p2} ${cite(2)}</p><p>${p3}</p>`,
            text: [p1, p2, p3].join(' '),
            sources: ['playbook', 'program'],
            composer: true
        };
    }

    confirm() {
        const f = this.facts();
        const n = this.newCount();
        const cite = (k) => `<span class="cite">${k}</span>`;
        const text =
            `Done, ${f.first}. Your account is enrolled in the New Location Launch Program. Each of your ${n} new locations gets $500 in ad credit for its first 60 days once its page is live. ` +
            `Your account manager will reach out to plan launch budgets together. Anything else I can help with today?`;
        return { html: `<p>${text} ${cite(1)}</p>`, text, sources: ['program'], composer: true };
    }

    longDate(d) {
        const [y, m, day] = String(d).split('-').map(Number);
        return new Date(y, m - 1, day).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    }

    summary() {
        const c = this.ctx || {};
        const f = this.facts();
        const bullets = (c.summary || 'No Fin summary on this conversation yet.')
            .split(/(?<=\.)\s+/)
            .filter((x) => x.trim())
            .map((x) => `<li>${x}</li>`)
            .join('');
        const actions = c.actions ? `<p class="h">What Fin did</p><p>${c.actions}</p>` : '';
        const flags = [
            c.churnRisk ? `Churn risk: <b>${c.churnRisk}</b>${c.churnReason ? ` (${c.churnReason})` : ''}` : '',
            f.expansion ? `Expansion signal: <b>${f.expansion}</b>` : ''
        ].filter((x) => x);
        return {
            html:
                `<p class="h">Question</p><p>${c.contactName || 'The customer'} is opening new locations and wants to redirect some existing spend to test them first.</p>` +
                `<p class="h">Summary</p><ul>${bullets}</ul>${actions}` +
                (flags.length ? `<p class="h">Signals</p><ul>${flags.map((x) => `<li>${x}</li>`).join('')}</ul>` : ''),
            text: (c.summary || '').trim(),
            sources: [],
            composer: true
        };
    }

    // ---- Add to composer -----------------------------------------------------------------------------------
    async handleCompose(e) {
        const t = this.turns.find((x) => String(x.id) === e.currentTarget.dataset.id);
        if (!t || !t.answer) return;
        const text = t.answer.text;
        const toolkit = this.template.querySelector('lightning-conversation-toolkit-api');
        try {
            await toolkit.setAgentInput(this.recordId, { text });
            this.note = '';
        } catch (err) {
            try {
                await navigator.clipboard.writeText(text);
                this.note = 'Copied. Paste it into the conversation.';
            } catch (err2) {
                this.note = "Couldn't add to the composer.";
            }
        }
    }
}
