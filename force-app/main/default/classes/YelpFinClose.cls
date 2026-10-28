/**
 * When John ends a live chat that Fin handed off (Fin Messenger channel), close the conversation in Fin too, so
 * Sam's Messenger shows it as ended. Fin's handoff step ends its workflow, so Fin doesn't do this by itself.
 * Uses the Fin API token in Yelp_Fin_Api__mdt.Default.Fin_Access_Token__c; does nothing without it.
 */
public without sharing class YelpFinClose {
    @TestVisible static final String CLOSING_NOTE = 'Thanks for chatting with Yelp. This conversation is now closed. You can message us again any time.';

    public static void onSessionsEnded(List<MessagingSession> sessions, Map<Id, MessagingSession> previous) {
        for (MessagingSession s : sessions) {
            if (s.Status == 'Ended' && previous.get(s.Id).Status != 'Ended') close(s.Id);
        }
    }

    @future(callout=true)
    static void close(Id sessionId) {
        try {
            List<MessagingSession> ms = [SELECT MessagingEndUser.MessagingPlatformKey FROM MessagingSession WHERE Id = :sessionId];
            String key = ms.isEmpty() ? null : ms[0].MessagingEndUser.MessagingPlatformKey;
            if (key == null || !key.startsWith('Fin/')) return;
            String token = YelpFinSignals.token();
            if (String.isBlank(token)) return;
            String conversationId = key.substringAfterLast('/');
            YelpFinSignals.log(sessionId, 'close conversation ' + conversationId + ': ' + closeConversation(conversationId, token));
        } catch (Exception e) {
            YelpFinSignals.log(sessionId, 'close error: ' + e.getMessage());
        }
    }

    @TestVisible
    static String closeConversation(String conversationId, String token) {
        // The close is posted as the admin who owns the token
        Map<String, Object> me = (Map<String, Object>) JSON.deserializeUntyped(send('GET', '/me', null, token).getBody());
        HttpResponse res = send('POST', '/conversations/' + EncodingUtil.urlEncode(conversationId, 'UTF-8') + '/parts',
            JSON.serialize(new Map<String, Object>{
                'message_type' => 'close', 'type' => 'admin', 'admin_id' => String.valueOf(me.get('id')), 'body' => CLOSING_NOTE
            }), token);
        return res.getStatusCode() + ' ' + res.getBody().left(300);
    }

    static HttpResponse send(String method, String path, String body, String token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.intercom.io' + path);
        req.setMethod(method);
        req.setTimeout(10000);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Intercom-Version', '2.11');
        if (body != null) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
        }
        return new Http().send(req);
    }
}
