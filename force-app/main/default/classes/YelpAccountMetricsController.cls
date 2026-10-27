/**
 * Yelp Ads metrics for the account and opportunity pages (Keep and Grow demo): budget, spend, leads and
 * cost per lead by location, plus Fin conversation stats.
 */
public with sharing class YelpAccountMetricsController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMetrics(Id recordId) {
        Map<String, Object> out = new Map<String, Object>();
        if (recordId == null) {
            return out;
        }
        Id accountId = recordId;
        if (recordId.getSObjectType() == Opportunity.SObjectType) {
            accountId = [SELECT AccountId FROM Opportunity WHERE Id = :recordId].AccountId;
        }
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType) {
            return out;
        }
        Account a = [
            SELECT Id, Name, ParentId, Annual_Ad_Spend__c, Renewal_Date__c, Renewal_Likelihood__c, Customer_Since__c
            FROM Account WHERE Id = :accountId
        ];
        if (a.ParentId != null) {
            a = [SELECT Id, Name, ParentId, Annual_Ad_Spend__c, Renewal_Date__c, Renewal_Likelihood__c, Customer_Since__c
                 FROM Account WHERE Id = :a.ParentId];
        }
        List<Map<String, Object>> locs = new List<Map<String, Object>>();
        Decimal cap = 0, spent = 0, leads = 0;
        for (Account l : [
            SELECT Id, Name, Brand__c, Monthly_Budget_Cap__c, Budget_Spent_MTD__c, Leads_Last_30_Days__c,
                   Cost_Per_Lead__c, Budget_Status__c
            FROM Account WHERE ParentId = :a.Id ORDER BY Leads_Last_30_Days__c DESC NULLS LAST
        ]) {
            cap += l.Monthly_Budget_Cap__c == null ? 0 : l.Monthly_Budget_Cap__c;
            spent += l.Budget_Spent_MTD__c == null ? 0 : l.Budget_Spent_MTD__c;
            leads += l.Leads_Last_30_Days__c == null ? 0 : l.Leads_Last_30_Days__c;
            locs.add(new Map<String, Object>{
                'id' => l.Id, 'name' => l.Name, 'cap' => l.Monthly_Budget_Cap__c, 'spent' => l.Budget_Spent_MTD__c,
                'leads' => l.Leads_Last_30_Days__c, 'cpl' => l.Cost_Per_Lead__c, 'status' => l.Budget_Status__c
            });
        }
        Date since = Date.today().addDays(-90);
        Integer finTotal = 0, finResolved = 0, rated = 0, openCases = 0;
        Decimal csatSum = 0;
        for (Case c : [
            SELECT FinResolutionState__c, Fin_CSAT__c, IsClosed FROM Case
            WHERE AccountId = :a.Id AND FinInvolved__c = true AND Conversation_Date__c >= :since
        ]) {
            finTotal++;
            if (c.FinResolutionState__c == 'Hard Resolution' || c.FinResolutionState__c == 'Soft Resolution') finResolved++;
            if (c.Fin_CSAT__c != null) { rated++; csatSum += c.Fin_CSAT__c; }
        }
        openCases = [SELECT COUNT() FROM Case WHERE AccountId = :a.Id AND IsClosed = false];
        out.put('accountName', a.Name);
        out.put('annualSpend', a.Annual_Ad_Spend__c);
        out.put('renewalDate', a.Renewal_Date__c);
        out.put('renewalLikelihood', a.Renewal_Likelihood__c);
        out.put('monthlyBudget', cap);
        out.put('spentMtd', spent);
        out.put('leads', leads);
        out.put('cpl', leads == 0 ? null : (spent / leads).setScale(0));
        out.put('locations', locs);
        out.put('finConversations', finTotal);
        out.put('finResolutionRate', finTotal == 0 ? null : Math.round(100.0 * finResolved / finTotal));
        out.put('csat', rated == 0 ? null : (csatSum / rated).setScale(1));
        out.put('openCases', openCases);
        return out;
    }
}
