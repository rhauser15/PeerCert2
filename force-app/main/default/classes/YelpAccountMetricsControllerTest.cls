@IsTest
private class YelpAccountMetricsControllerTest {
    @IsTest
    static void rollsUpLocationsAndFinStats() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account parent = new Account(Name = 'Metrics Test Group', Annual_Ad_Spend__c = 1000);
        Database.insert(parent, dml);
        Database.insert(new List<Account>{
            new Account(Name = 'Test - A', ParentId = parent.Id, Monthly_Budget_Cap__c = 100, Budget_Spent_MTD__c = 80, Leads_Last_30_Days__c = 4, Cost_Per_Lead__c = 20),
            new Account(Name = 'Test - B', ParentId = parent.Id, Monthly_Budget_Cap__c = 200, Budget_Spent_MTD__c = 120, Leads_Last_30_Days__c = 6, Cost_Per_Lead__c = 20)
        }, dml);
        insert new List<Case>{
            new Case(Subject = 'a', AccountId = parent.Id, FinInvolved__c = true, FinResolutionState__c = 'Hard Resolution', Fin_CSAT__c = 5, Conversation_Date__c = Date.today()),
            new Case(Subject = 'b', AccountId = parent.Id, FinInvolved__c = true, FinResolutionState__c = 'Routed to team', Conversation_Date__c = Date.today())
        };
        Opportunity o = new Opportunity(Name = 'Renewal', AccountId = parent.Id, StageName = 'Discovery', CloseDate = Date.today());
        Database.insert(o, dml);

        Map<String, Object> m = YelpAccountMetricsController.getMetrics(o.Id);
        System.assertEquals(300, (Decimal) m.get('monthlyBudget'));
        System.assertEquals(10, (Decimal) m.get('leads'));
        System.assertEquals(2, m.get('finConversations'));
        System.assertEquals(50, m.get('finResolutionRate'));
        System.assertEquals(2, ((List<Object>) m.get('locations')).size());
        System.assert(YelpAccountMetricsController.getMetrics(null).isEmpty());
    }
}
