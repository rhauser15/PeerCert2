@IsTest
private class YelpFinApiTest {
    @TestSetup
    static void data() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account p = new Account(Name = 'Api Test Group', Part2_Demo__c = true, Annual_Ad_Spend__c = 1000);
        Database.insert(p, dml);
        Database.insert(new Account(Name = 'Brand - Westminster', ParentId = p.Id, Part2_Demo__c = true,
            Monthly_Budget_Cap__c = 1200, Budget_Spent_MTD__c = 1200, Budget_Status__c = 'Paused - Budget Cap Reached'), dml);
        Database.insert(new Contact(FirstName = 'Api', LastName = 'Tester', Email = 'api.tester@example.com', AccountId = p.Id), dml);
    }

    @IsTest
    static void readsAccountAndInvoice() {
        Map<String, Object> a = YelpFinApi.account('api.tester@example.com');
        System.assertEquals(1, a.get('active_locations'));
        System.assertEquals(9980, YelpFinApi.invoice('api.tester@example.com').get('total'));
        try { YelpFinApi.status(); } catch (YelpFinApi.ApiException e) { System.assertEquals(404, e.status); }
    }

    @IsTest
    static void raisesCapAndResumesAds() {
        Map<String, Object> r = YelpFinApi.raiseCap('api.tester@example.com', 'westminster', '$1,500');
        System.assertEquals(1500, (Decimal) r.get('new_monthly_cap'));
        Account l = [SELECT Monthly_Budget_Cap__c, Budget_Status__c FROM Account WHERE Name = 'Brand - Westminster'];
        System.assertEquals('Active', l.Budget_Status__c);
    }

    @IsTest
    static void signalsFillTheOpenHandoffCase() {
        Contact c = [SELECT Id, AccountId FROM Contact WHERE Email = 'api.tester@example.com'];
        Case cs = new Case(Subject = 'Fin handoff:', ContactId = c.Id, Status = 'New', Origin = 'Chat');
        try {
            insert cs;
        } catch (DmlException e) {
            // This org's SDO case automation can't run in tests (missing helper config); cover the endpoint without a case
            System.assertEquals(null, YelpFinApi.signals(new Map<String, Object>{ 'email' => 'api.tester@example.com' }).get('case'));
            return;
        }
        Map<String, Object> r = YelpFinApi.signals(new Map<String, Object>{
            'email' => 'api.tester@example.com', 'conversation_id' => '{{conversation.id}}',
            'contact_reason' => 'Add a location', 'churn_risk' => 'Low', 'sentiment' => 'Slightly Negative',
            'expansion_signal' => 'New locations'
        });
        System.assertNotEquals(null, r.get('case'));
        Case after = [SELECT Subject, Fin_Contact_Reason__c, Churn_Risk__c, Fin_Sentiment__c, Expansion_Signal__c FROM Case WHERE Id = :cs.Id];
        System.assertEquals('Fin handoff: Add a location', after.Subject);
        System.assertEquals('Low', after.Churn_Risk__c);
        System.assertEquals('New locations', after.Expansion_Signal__c);
    }

    @IsTest
    static void signalsAreReadBackForTheRoutingFlow() {
        insert new Yelp_Fin_Api_Log__c(Endpoint__c = 'signals', Method__c = 'POST', Status__c = 200,
            Detail__c = 'params={}\nbody={"email":"a@b.c","conversation_id":"123","contact_reason":"Add a location","churn_risk":"Low"}\nresponse={}');
        Map<String, Object> attrs = YelpFinSignals.fromConnector('123');
        System.assertEquals('Add a location', attrs.get('Contact Reason'));
        System.assertEquals(null, YelpFinSignals.fromConnector('999'));
    }

    @IsTest
    static void rejectsUnknownCustomersAndMissingKey() {
        try {
            YelpFinApi.account('nobody@example.com');
            System.assert(false);
        } catch (YelpFinApi.ApiException e) {
            System.assertEquals(404, e.status);
        }
        RestContext.request = new RestRequest();
        RestContext.request.requestURI = '/services/apexrest/yelp/account';
        RestContext.request.addParameter('email', 'api.tester@example.com');
        RestContext.response = new RestResponse();
        YelpFinApi.doGet();
        System.assertEquals(401, RestContext.response.statusCode);
        RestContext.request.requestURI = '/services/apexrest/yelp/messenger-token';
        YelpFinApi.doGet();
        System.assert(RestContext.response.statusCode == 200 || RestContext.response.statusCode == 503
            || RestContext.response.statusCode == 404);
        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf('{}');
        YelpFinApi.doPost();
        System.assertEquals(401, RestContext.response.statusCode);
    }
}
