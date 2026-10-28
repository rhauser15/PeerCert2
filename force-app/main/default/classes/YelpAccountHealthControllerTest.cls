@IsTest
private class YelpAccountHealthControllerTest {
    @IsTest
    static void predictorsFollowFinSignals() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account a = new Account(Name = 'Health Test Group', Part2_Demo__c = true, Churn_Risk__c = 'Low',
            Fin_Sentiment__c = 'Slightly Negative', Expansion_Signal__c = 'New locations');
        Database.insert(a, dml);
        Database.insert(new List<Account>{
            new Account(Name = 'Brand - A', ParentId = a.Id, Cost_Per_Lead__c = 20),
            new Account(Name = 'Brand - B', ParentId = a.Id, Cost_Per_Lead__c = 40)
        }, dml);
        Map<String, Object> h = YelpAccountHealthController.getHealth(a.Id);
        System.assertEquals(74.6, h.get('score'));
        System.assertEquals('down', h.get('direction'));
        List<Map<String, Object>> ps = (List<Map<String, Object>>) h.get('predictors');
        System.assertEquals(3, ps.size());
        System.assert(String.valueOf(ps[1].get('label')).startsWith('B cost per lead is 1.3x'), ps[1].get('label'));
    }
}
