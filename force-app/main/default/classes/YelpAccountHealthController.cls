/**
 * Account Health card (Keep and Grow demo account page). Shows Likelihood to Renew (Renewal_Likelihood__c) and its
 * top predictors from the same fields, so the card always matches the account's score after Fin's write-back.
 * Rule-based stand-in for an Einstein Discovery / Prediction Builder model (see the script's implementation guide).
 */
public with sharing class YelpAccountHealthController {
    @TestVisible static final Decimal BASELINE = 79.5; // score before any Fin signal (formula default)

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getHealth(Id recordId) {
        Account a = [SELECT Id, ParentId, Renewal_Likelihood__c, Renewal_Outlook__c, Churn_Risk__c, Fin_Sentiment__c,
                            Expansion_Signal__c FROM Account WHERE Id = :recordId];
        if (a.ParentId != null) {
            a = [SELECT Id, ParentId, Renewal_Likelihood__c, Renewal_Outlook__c, Churn_Risk__c, Fin_Sentiment__c,
                        Expansion_Signal__c FROM Account WHERE Id = :a.ParentId];
        }
        Decimal score = a.Renewal_Likelihood__c == null ? BASELINE : a.Renewal_Likelihood__c;
        List<Map<String, Object>> predictors = new List<Map<String, Object>>();
        String churn = a.Churn_Risk__c;
        Boolean negative = a.Fin_Sentiment__c != null && a.Fin_Sentiment__c.containsIgnoreCase('negative');
        if (churn == 'High') predictors.add(p('Fin flagged high churn risk', 'Strong negative', 'neg'));
        else if (churn == 'Medium') predictors.add(p('Fin flagged medium churn risk', 'Moderate negative', 'neg'));
        else if (negative) predictors.add(p('Fin flagged low churn risk, with a value concern', 'Moderate negative', 'neg'));
        else if (churn == 'Low') predictors.add(p('Fin flagged low churn risk', 'Minor positive', 'pos'));

        // Cost per lead: the highest location vs the average across locations
        Decimal total = 0, top = 0;
        Integer n = 0;
        String topName;
        for (Account l : [SELECT Name, Cost_Per_Lead__c FROM Account WHERE ParentId = :a.Id AND Cost_Per_Lead__c != null]) {
            total += l.Cost_Per_Lead__c;
            n++;
            if (l.Cost_Per_Lead__c > top) { top = l.Cost_Per_Lead__c; topName = l.Name.substringAfterLast(' - '); }
        }
        if (n > 1 && top / (total / n) >= 1.2) {
            predictors.add(p(topName + ' cost per lead is ' + (top / (total / n)).setScale(1) + 'x average', 'Minor negative', 'neg'));
        }
        if (String.isNotBlank(a.Expansion_Signal__c) && a.Expansion_Signal__c.toLowerCase() != 'none') {
            predictors.add(p('Expansion signal: ' + a.Expansion_Signal__c.toLowerCase(), 'High impact', 'pos'));
        }
        Decimal change = (score - BASELINE).setScale(1);
        return new Map<String, Object>{
            'score' => score.setScale(1), 'outlook' => a.Renewal_Outlook__c, 'change' => change.abs(),
            'direction' => change < 0 ? 'down' : (change > 0 ? 'up' : 'flat'), 'predictors' => predictors
        };
    }

    static Map<String, Object> p(String label, String impact, String tone) {
        return new Map<String, Object>{ 'label' => label, 'impact' => impact, 'tone' => tone };
    }
}
