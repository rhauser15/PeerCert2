@IsTest
private class YelpFinCloseTest {
    class FinMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().endsWith('/me')) {
                res.setBody('{"type":"admin","id":"8675309"}');
            } else {
                System.assert(req.getEndpoint().endsWith('/conversations/215476596829392/parts'));
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                System.assertEquals('close', body.get('message_type'));
                System.assertEquals('8675309', body.get('admin_id'));
                res.setBody('{"type":"conversation","id":"215476596829392","state":"closed"}');
            }
            return res;
        }
    }

    @IsTest
    static void closesTheFinConversation() {
        Test.setMock(HttpCalloutMock.class, new FinMock());
        Test.startTest();
        String result = YelpFinClose.closeConversation('215476596829392', 'token');
        Test.stopTest();
        System.assert(result.startsWith('200'), result);
    }

    @IsTest
    static void ignoresSessionsThatDidNotEnd() {
        MessagingSession s = new MessagingSession(Id = '0Mw000000000001AAA', Status = 'Active');
        YelpFinClose.onSessionsEnded(new List<MessagingSession>{ s }, new Map<Id, MessagingSession>{ s.Id => s });
    }
}
