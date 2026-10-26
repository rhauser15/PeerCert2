import { LightningElement, api, wire } from 'lwc';
import getContext from '@salesforce/apex/FinCopilotController.getContext';
import FIN_MARK from '@salesforce/resourceUrl/FinMark';

// Fin Copilot panel for the Keep and Grow demo. Answers come from the team's internal content (SOURCES)
// and the customer's account data; this build is scripted for the demo questions.
const SOURCES = {
    policy: { type: 'Internal article', title: 'Multi-Location Retention Policy (10+ locations)' },
    credit: { type: 'Internal article', title: 'Ad performance credits: eligibility and limits' },
    review: { type: 'Internal article', title: 'Booking a free Ads Optimization review' },
    pause: { type: 'Public article', title: 'Pause ads for one location' },
    convo: { type: 'Conversation', title: 'Front Range Burger Co. · Cancel a location' },
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
        if (/retention|offer|qualif|save|keep|cancel|drop|churn|credit|discount/.test(s)) return this.offers();
        return {
            html: "<p>I couldn't find anything in your team's content about that. Try asking about this customer's account, a policy, or a past conversation.</p>",
            sources: [],
            composer: false
        };
    }

    offers() {
        const f = this.facts();
        const cite = (n) => `<span class="cite">${n}</span>`;
        return {
            html:
                `<p>${f.account} has <b>${f.count} active locations</b>, so it's covered by the Multi-Location retention policy for accounts with 10 or more locations. ${cite(1)}</p>` +
                `<p>Before a location is cancelled, you can offer:</p><ul>` +
                `<li><b>Pause instead of cancel.</b> Pause ${f.loc}'s ads for up to 90 days with no fee. The page, reviews and ad history stay live. ${cite(1)}</li>` +
                `<li><b>Performance credit.</b> ${f.loc}'s cost per lead (${money(f.cpl)}) is more than 2x the account's other locations (${money(f.avg)}), so it qualifies for up to 20% of its monthly budget for 2 months: <b>${money(f.credit)}/month</b>. ${cite(2)}</li>` +
                `<li><b>New location launch credit.</b> $500 in ad credit for each new location whose ads go live within 30 days of opening. ${cite(1)}</li>` +
                `<li><b>Free Ads Optimization review</b> with a Multi-Location specialist to retune targeting. ${cite(3)}</li>` +
                `</ul><p>Credits above $1,000 a month need CS manager approval. ${cite(1)}</p>`,
            text:
                `${f.account} has ${f.count} active locations and qualifies for: a 90-day pause for ${f.loc} with no fee; ` +
                `a performance credit of ${money(f.credit)}/month for 2 months; $500 launch credit per new location; a free Ads Optimization review.`,
            sources: ['policy', 'credit', 'review', 'convo'],
            composer: true
        };
    }

    reply() {
        const f = this.facts();
        const cite = (n) => `<span class="cite">${n}</span>`;
        const castle = f.expansion
            ? ` And congratulations on Castle Rock! If its ads go live within 30 days of opening, you'll get $500 in launch credit. I've asked ${f.owner}, your account manager, to reach out this week so it's set up before you open.`
            : '';
        const text =
            `Hi ${f.first}, thanks for being upfront about ${f.loc}. Before you drop it, there are two options that keep it on Yelp: ` +
            `we can pause ${f.loc}'s ads for up to 90 days at no cost, so the page and its reviews stay up, or keep it running with a ` +
            `${money(f.credit)} credit for each of the next two months while our specialist retunes its targeting.${castle} ` +
            `Which would you prefer for ${f.loc}?`;
        return {
            html:
                `<p>Hi ${f.first}, thanks for being upfront about ${f.loc}. Before you drop it, there are two options that keep it on Yelp: ` +
                `we can pause ${f.loc}'s ads for up to 90 days at no cost, so the page and its reviews stay up, or keep it running with a ` +
                `${money(f.credit)} credit for each of the next two months while our specialist retunes its targeting. ${cite(1)} ${cite(2)}</p>` +
                (castle ? `<p>${castle.trim()} ${cite(3)}</p>` : '') +
                `<p>Which would you prefer for ${f.loc}?</p>`,
            text,
            sources: ['policy', 'credit', 'launch', 'pause'],
            composer: true
        };
    }

    confirm() {
        const f = this.facts();
        const until = new Date(Date.now() + 90 * 864e5).toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
        const cite = (n) => `<span class="cite">${n}</span>`;
        const castle = f.expansion
            ? ` ${f.owner}, your account manager, will reach out this week to get Castle Rock set up before you open.`
            : '';
        const text =
            `Done, ${f.first}. ${f.loc}'s ads are paused until ${until} with no fee, so the page and its reviews stay up and you can restart any time.` +
            `${castle} Anything else I can help with tonight?`;
        return {
            html: `<p>${text} ${cite(1)}</p>`,
            text,
            sources: ['pause', 'policy'],
            composer: true
        };
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
                `<p class="h">Question</p><p>${c.contactName || 'The customer'} wants to drop the ${f.loc} location and mentioned a new location.</p>` +
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
