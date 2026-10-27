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
