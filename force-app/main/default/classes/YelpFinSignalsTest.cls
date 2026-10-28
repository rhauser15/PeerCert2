@IsTest
private class YelpFinSignalsTest {
    class FinMock implements HttpCalloutMock {
        Integer status;
        FinMock(Integer status) { this.status = status; }
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().endsWith('/conversations/215476596829392'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody('{"id":"215476596829392","custom_attributes":{"Contact Reason":"Add a location","Churn Risk":"Low","Expansion Signal":"New locations"}}');
            return res;
        }
    }

    @IsTest
    static void readsAttributesFromFin() {
        Test.setMock(HttpCalloutMock.class, new FinMock(200));
        Test.startTest();
        Map<String, Object> attrs = YelpFinSignals.fetch('215476596829392', 'token');
        Test.stopTest();
        System.assertEquals('Add a location', YelpFinSignals.pick(null, attrs, 'Contact Reason'));
        System.assertEquals('Low', YelpFinSignals.pick('', attrs, 'churn risk'));
        System.assertEquals('Neutral', YelpFinSignals.pick('Neutral', attrs, 'Sentiment'));
        System.assertEquals(null, YelpFinSignals.pick(null, attrs, 'Sentiment'));
    }

    @IsTest
    static void apiErrorIsReported() {
        Test.setMock(HttpCalloutMock.class, new FinMock(401));
        try {
            YelpFinSignals.fetch('215476596829392', 'token');
            System.assert(false, 'expected an exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('401'));
        }
    }

    @IsTest
    static void unknownSessionLeavesInputsUnchanged() {
        YelpFinSignals.Signals s = new YelpFinSignals.Signals();
        s.sessionId = '0Mw000000000001AAA';
        s.contactReason = 'Other';
        List<YelpFinSignals.Signals> out = YelpFinSignals.fill(new List<YelpFinSignals.Signals>{ s });
        System.assertEquals('Other', out[0].contactReason);
        System.assertEquals(null, out[0].churnRisk);
    }
}
