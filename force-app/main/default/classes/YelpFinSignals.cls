/**
 * Fills in Fin's conversation attributes (Contact Reason, Churn Risk, Sentiment, Expansion Signal) for a live
 * handoff when they didn't arrive as routing parameters. Called first in the "Yelp - Fin Handoff Routing" Flow,
 * before any record changes, because it makes a callout.
 *
 * The Fin conversation ID is the last part of the Messaging End User's platform key (Fin/<workspace>/<conversation>).
 * Uses Yelp_Fin_Api__mdt.Default.Fin_Access_Token__c. Without a token, or on any error, the inputs come back unchanged.
 */
public without sharing class YelpFinSignals {
    public class Signals {
        @InvocableVariable(label='Messaging Session ID' required=true)
        public Id sessionId;
        @InvocableVariable(label='Contact Reason')
        public String contactReason;
        @InvocableVariable(label='Churn Risk')
        public String churnRisk;
        @InvocableVariable(label='Sentiment')
        public String sentiment;
        @InvocableVariable(label='Expansion Signal')
        public String expansionSignal;
    }

    @InvocableMethod(label='Get Fin conversation attributes' description='Reads Fin conversation attributes from the Fin API for a handoff from the Fin Messenger.' callout=true)
    public static List<Signals> fill(List<Signals> requests) {
        for (Signals s : requests) {
            try {
                fillOne(s);
            } catch (Exception e) {
                log(s.sessionId, 'error: ' + e.getMessage());
            }
        }
        return requests;
    }

    static void fillOne(Signals s) {
        if (String.isNotBlank(s.contactReason) && String.isNotBlank(s.churnRisk) && String.isNotBlank(s.sentiment)
            && String.isNotBlank(s.expansionSignal)) return;
        List<MessagingSession> ms = [SELECT MessagingEndUser.MessagingPlatformKey FROM MessagingSession WHERE Id = :s.sessionId];
        String key = ms.isEmpty() ? null : ms[0].MessagingEndUser.MessagingPlatformKey;
        if (key == null || !key.startsWith('Fin/')) return;
        String token = token();
        if (String.isBlank(token)) return;
        Map<String, Object> attrs = fetch(key.substringAfterLast('/'), token);
        s.contactReason = pick(s.contactReason, attrs, 'Contact Reason');
        s.churnRisk = pick(s.churnRisk, attrs, 'Churn Risk');
        s.sentiment = pick(s.sentiment, attrs, 'Sentiment');
        s.expansionSignal = pick(s.expansionSignal, attrs, 'Expansion Signal');
        log(s.sessionId, 'attributes=' + JSON.serialize(attrs));
    }

    @TestVisible
    static Map<String, Object> fetch(String conversationId, String token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.intercom.io/conversations/' + EncodingUtil.urlEncode(conversationId, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(8000);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Intercom-Version', '2.11');
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Fin API ' + res.getStatusCode() + ': ' + res.getBody().left(300));
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object attrs = body.get('custom_attributes');
        return attrs instanceof Map<String, Object> ? (Map<String, Object>) attrs : new Map<String, Object>();
    }

    @TestVisible
    static String pick(String current, Map<String, Object> attrs, String name) {
        if (String.isNotBlank(current)) return current;
        for (String k : attrs.keySet()) {
            if (k.equalsIgnoreCase(name) && attrs.get(k) != null) return String.valueOf(attrs.get(k));
        }
        return current;
    }

    public static String token() {
        List<Yelp_Fin_Api__mdt> rows = [SELECT Fin_Access_Token__c FROM Yelp_Fin_Api__mdt WHERE DeveloperName = 'Default' LIMIT 1];
        String t = rows.isEmpty() ? null : rows[0].Fin_Access_Token__c;
        if (String.isBlank(t)) {
            // Also accept the token entered as the field's default value in Setup
            String dv = Yelp_Fin_Api__mdt.Fin_Access_Token__c.getDescribe().getDefaultValueFormula();
            t = dv == null ? null : dv.trim().removeStart('"').removeEnd('"').removeStart('\'').removeEnd('\'');
        }
        return t;
    }

    // Troubleshooting: record what Fin returned (never the token)
    public static void log(Id sessionId, String detail) {
        try {
            insert new Yelp_Fin_Api_Log__c(Endpoint__c = 'fin-signals', Method__c = 'GET', Status__c = 200,
                Detail__c = ('session=' + sessionId + '\n' + detail).left(32000));
        } catch (Exception e) { /* logging must never break routing */ }
    }
}
