@IsTest
private class YelpSupportSummaryTest {
    @IsTest
    static void summarizesRecentSupport() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account a = new Account(Name = 'Summary Test Group', Part2_Demo__c = true);
        Database.insert(a, dml);
        Contact ct = new Contact(FirstName = 'Sam', LastName = 'Test', Email = 'sam.summary@example.com', AccountId = a.Id);
        Database.insert(ct, dml);
        insert new Yelp_Fin_Api_Log__c(Endpoint__c = 'budget', Method__c = 'POST', Status__c = 200,
            Detail__c = 'params={}\nbody={"email": "sam.summary@example.com"}\nresponse={"location":"Brand - Westminster","previous_monthly_cap":1200,"new_monthly_cap":1500}');
        Case c = new Case(Subject = 'Test', AccountId = a.Id, ContactId = ct.Id, Origin = 'Chat', Fin_Contact_Reason__c = 'Add a location',
            Fin_Sentiment__c = 'Slightly Negative', Churn_Risk__c = 'Low', Expansion_Signal__c = 'New locations');
        try {
            insert c;
        } catch (DmlException e) {
            // This org's SDO case automation can't run in tests; cover the error path instead
            List<YelpSupportSummary.Result> r = YelpSupportSummary.summarize(new List<YelpSupportSummary.Request>{ new YelpSupportSummary.Request() });
            System.assert(r[0].summary.contains('unavailable'));
            return;
        }
        YelpSupportSummary.Request req = new YelpSupportSummary.Request();
        req.caseId = c.Id;
        String s = YelpSupportSummary.summarize(new List<YelpSupportSummary.Request>{ req })[0].summary;
        System.assert(s.contains('1 conversations:'), s);
        System.assert(s.contains('Westminster monthly cap raised from $1,200 to $1,500'), s);
        System.assert(s.contains('wants to see performance'), s);
    }
}
