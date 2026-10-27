import { LightningElement, api, wire } from 'lwc';
import getMetrics from '@salesforce/apex/YelpAccountMetricsController.getMetrics';

const money = (n) => (n === null || n === undefined ? '—' : '$' + Math.round(n).toLocaleString('en-US'));

// Yelp Ads performance for an operator account (or the account behind an opportunity): budget, spend,
// leads and cost per lead by location, plus Fin conversation stats.
export default class YelpAccountMetrics extends LightningElement {
    @api recordId;
    data;

    @wire(getMetrics, { recordId: '$recordId' })
    wired({ data }) {
        if (data) this.data = data;
    }

    get ready() {
        return this.data && this.data.accountName;
    }
    get tiles() {
        const d = this.data;
        const renew = d.renewalDate
            ? new Date(d.renewalDate + 'T12:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
            : '—';
        return [
            { k: 'a', label: 'Annual ad spend', value: money(d.annualSpend) },
            { k: 'b', label: 'Monthly budget', value: money(d.monthlyBudget), sub: `${money(d.spentMtd)} spent this month` },
            { k: 'c', label: 'Leads (30 days)', value: (d.leads || 0).toLocaleString('en-US'), sub: `${money(d.cpl)} per lead` },
            { k: 'd', label: 'Renewal', value: renew, sub: d.renewalLikelihood ? `${d.renewalLikelihood}% likely to renew` : '' },
            { k: 'e', label: 'Fin conversations (90 days)', value: String(d.finConversations || 0),
              sub: d.finResolutionRate === null || d.finResolutionRate === undefined ? '' : `${d.finResolutionRate}% resolved by Fin` },
            { k: 'f', label: 'CSAT', value: d.csat ? `${d.csat} / 5` : '—', sub: `${d.openCases || 0} open cases` }
        ];
    }
    get rows() {
        const locs = this.data.locations || [];
        const avg = this.data.cpl || 0;
        return locs.map((l) => {
            const pct = l.cap ? Math.min(100, Math.round((100 * (l.spent || 0)) / l.cap)) : 0;
            const status = l.status || 'Active';
            return {
                ...l,
                capLabel: money(l.cap),
                spentLabel: money(l.spent),
                cplLabel: money(l.cpl),
                barStyle: `width:${pct}%`,
                pct: `${pct}%`,
                cplClass: avg && l.cpl > avg * 1.5 ? 'cpl hi' : 'cpl',
                statusLabel: status.startsWith('Paused') ? 'Paused' : status,
                statusClass: 'pill ' + (status === 'Active' ? 'ok' : status === 'Cancelled' ? 'bad' : 'warn'),
                url: `/lightning/r/Account/${l.id}/view`
            };
        });
    }
}
