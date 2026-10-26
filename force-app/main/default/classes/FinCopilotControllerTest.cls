@IsTest
private class FinCopilotControllerTest {
    @IsTest
    static void returnsCaseAndLocationContext() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account parent = new Account(Name = 'Copilot Test Group');
        Database.insert(parent, dml);
        List<Account> locs = new List<Account>{
            new Account(Name = 'Test Brand - Aurora', ParentId = parent.Id, Brand__c = 'Test Brand', Monthly_Budget_Cap__c = 900, Cost_Per_Lead__c = 64),
            new Account(Name = 'Test Brand - Lakewood', ParentId = parent.Id, Brand__c = 'Test Brand', Monthly_Budget_Cap__c = 1000, Cost_Per_Lead__c = 24),
            new Account(Name = 'Test Brand - Littleton', ParentId = parent.Id, Brand__c = 'Test Brand', Monthly_Budget_Cap__c = 900, Cost_Per_Lead__c = 30)
        };
        Database.insert(locs, dml);
        Contact con = new Contact(FirstName = 'Sam', LastName = 'Tester', AccountId = parent.Id);
        Database.insert(con, dml);
        Case c = new Case(Subject = 'Test', AccountId = parent.Id, ContactId = con.Id, Fin_Location__c = 'Aurora', Origin = 'Website');
        insert c;

        Map<String, Object> ctx = FinCopilotController.getContext(c.Id);
        System.assertEquals('Sam', ctx.get('firstName'));
        System.assertEquals(3, ctx.get('locationCount'));
        System.assertEquals(64, (Decimal) ctx.get('locationCpl'));
        System.assertEquals(27, (Decimal) ctx.get('brandCpl'));
        System.assert(FinCopilotController.getContext(null).isEmpty());
        System.assert(FinCopilotController.getContext(parent.Id).isEmpty());
    }
}
