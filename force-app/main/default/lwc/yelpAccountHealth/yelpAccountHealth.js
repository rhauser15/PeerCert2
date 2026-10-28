import { LightningElement, api } from 'lwc';
import getHealth from '@salesforce/apex/YelpAccountHealthController.getHealth';

// Account Health: Likelihood to Renew and its top predictors, read from the account's fields so it always matches
// the account card after Fin's write-back.
export default class YelpAccountHealth extends LightningElement {
    @api recordId;
    data;

    connectedCallback() {
        getHealth({ recordId: this.recordId })
            .then((d) => {
                d.predictors = (d.predictors || []).map((p) => ({ ...p, cls: 'imp ' + p.tone }));
                this.data = d;
            })
            .catch(() => { this.data = undefined; });
    }

    get scoreLabel() { return this.data.score + '%'; }
    get changeLabel() {
        if (this.data.direction === 'flat') return 'No change since the last Fin signal';
        return (this.data.direction === 'down' ? '↓ ' : '↑ ') + this.data.change + '% vs last change';
    }
    get changeClass() { return 'chg ' + this.data.direction; }
}
