/**
 * Context for the Fin Copilot panel (Keep and Grow demo): the Case Fin created at handoff,
 * the customer's account and its locations.
 */
public with sharing class FinCopilotController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContext(Id recordId) {
        Map<String, Object> ctx = new Map<String, Object>();
        if (recordId == null) {
            return ctx;
        }
        Id caseId = recordId;
        if (recordId.getSObjectType() == MessagingSession.SObjectType) {
            List<MessagingSession> sessions = [SELECT CaseId FROM MessagingSession WHERE Id = :recordId];
            caseId = sessions.isEmpty() ? null : sessions[0].CaseId;
        }
        if (caseId == null || caseId.getSObjectType() != Case.SObjectType) {
            return ctx;
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, Fin_Summary__c, Fin_Location__c, Fin_Contact_Reason__c, Fin_Actions_Taken__c,
                   Churn_Risk__c, Churn_Risk_Reason__c, Expansion_Signal__c, Contact.FirstName, Contact.Name,
                   AccountId, Account.Name, Account.Owner.FirstName, Account.Owner.Name
            FROM Case WHERE Id = :caseId
        ];
        if (cases.isEmpty()) {
            return ctx;
        }
        Case c = cases[0];
        ctx.put('caseNumber', c.CaseNumber);
        ctx.put('summary', c.Fin_Summary__c);
        ctx.put('location', c.Fin_Location__c);
        ctx.put('reason', c.Fin_Contact_Reason__c);
        ctx.put('actions', c.Fin_Actions_Taken__c);
        ctx.put('churnRisk', c.Churn_Risk__c);
        ctx.put('churnReason', c.Churn_Risk_Reason__c);
        ctx.put('expansion', c.Expansion_Signal__c);
        ctx.put('firstName', c.Contact?.FirstName);
        ctx.put('contactName', c.Contact?.Name);
        ctx.put('accountName', c.Account?.Name);
        ctx.put('ownerFirstName', c.Account?.Owner?.FirstName);
        ctx.put('ownerName', c.Account?.Owner?.Name);

        List<Account> locations = [
            SELECT Name, Brand__c, Monthly_Budget_Cap__c, Cost_Per_Lead__c
            FROM Account WHERE ParentId = :c.AccountId
        ];
        ctx.put('locationCount', locations.size());
        Account match;
        for (Account a : locations) {
            if (String.isNotBlank(c.Fin_Location__c) && a.Name.endsWith(c.Fin_Location__c)) {
                match = a;
            }
        }
        if (match != null) {
            Decimal total = 0;
            Integer n = 0;
            for (Account a : locations) {
                if (a.Id != match.Id && a.Brand__c == match.Brand__c && a.Cost_Per_Lead__c != null) {
                    total += a.Cost_Per_Lead__c;
                    n++;
                }
            }
            ctx.put('brand', match.Brand__c);
            ctx.put('locationCap', match.Monthly_Budget_Cap__c);
            ctx.put('locationCpl', match.Cost_Per_Lead__c);
            ctx.put('brandCpl', n == 0 ? null : (total / n).setScale(0));
        }
        return ctx;
    }
}
