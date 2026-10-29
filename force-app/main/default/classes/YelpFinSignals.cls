/**
 * Fills in Fin's conversation attributes (Contact Reason, Churn Risk, Sentiment, Expansion Signal) for a live
 * handoff when they didn't arrive as routing parameters. Called first in the "Yelp - Fin Handoff Routing" Flow,
 * before any record changes, because it may make a callout.
 *
 * Sources, in order:
 *   1. the "Log handoff signals" data connector call (POST /yelp/signals, logged in Yelp_Fin_Api_Log__c)
 *   2. the Fin API, if Yelp_Fin_Api__mdt.Default.Fin_Access_Token__c is set
 * The Fin conversation ID is the last part of the Messaging End User's platform key (Fin/<workspace>/<conversation>).
 * On any error the inputs come back unchanged.
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
        @InvocableVariable(label='Title (Fin AI Title)')
        public String title;
        @InvocableVariable(label='Customer email')
        public String email;
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
            && String.isNotBlank(s.expansionSignal) && String.isNotBlank(s.email)) return;
        List<MessagingSession> ms = [SELECT MessagingEndUser.MessagingPlatformKey FROM MessagingSession WHERE Id = :s.sessionId];
        String key = ms.isEmpty() ? null : ms[0].MessagingEndUser.MessagingPlatformKey;
        if (key == null || !key.startsWith('Fin/')) return;
        String conversationId = key.substringAfterLast('/');
        Map<String, Object> attrs = fromConnector(conversationId);
        String token = token();
        if (attrs == null && String.isBlank(token)) return;
        if (attrs == null) attrs = fetch(conversationId, token);
        s.contactReason = pick(s.contactReason, attrs, 'Contact Reason');
        s.churnRisk = pick(s.churnRisk, attrs, 'Churn Risk');
        s.sentiment = pick(s.sentiment, attrs, 'Sentiment');
        s.expansionSignal = pick(s.expansionSignal, attrs, 'Expansion Signal');
        s.title = pick(s.title, attrs, 'Title');
        s.email = pick(s.email, attrs, 'Email');
        log(s.sessionId, 'attributes=' + JSON.serialize(attrs));
    }

    // The latest "Log handoff signals" call in the last 30 minutes for this conversation (or without a conversation ID)
    @TestVisible
    static Map<String, Object> fromConnector(String conversationId) {
        Datetime since = Datetime.now().addMinutes(-30);
        for (Yelp_Fin_Api_Log__c l : [SELECT Detail__c FROM Yelp_Fin_Api_Log__c WHERE Endpoint__c = 'signals'
                AND Status__c = 200 AND CreatedDate >= :since ORDER BY CreatedDate DESC LIMIT 20]) {
            String json = l.Detail__c == null ? null : l.Detail__c.substringAfter('body=').substringBefore('\nresponse=');
            if (String.isBlank(json)) continue;
            Map<String, Object> b = (Map<String, Object>) System.JSON.deserializeUntyped(json);
            String conv = b.get('conversation_id') == null ? '' : String.valueOf(b.get('conversation_id'));
            if (conv.startsWith('{{')) conv = '';
            if (String.isNotBlank(conv) && conv != conversationId) continue;
            return new Map<String, Object>{
                'Contact Reason' => b.get('contact_reason'), 'Churn Risk' => b.get('churn_risk'),
                'Sentiment' => b.get('sentiment'), 'Expansion Signal' => b.get('expansion_signal'), 'Title' => b.get('title'), 'Email' => b.get('email')
            };
        }
        return null;
    }

    // The open handoff case for a Fin conversation (or, without its ID, the contact's newest one from the last 2 hours)
    public static Case openHandoffCase(Id contactId, String conversationId) {
        if (String.isNotBlank(conversationId)) {
            String key = '%/' + conversationId;
            for (MessagingSession m : [SELECT CaseId FROM MessagingSession WHERE MessagingEndUser.MessagingPlatformKey LIKE :key
                    AND CaseId != null ORDER BY CreatedDate DESC LIMIT 1]) {
                return [SELECT Id, CaseNumber, Subject, Fin_Contact_Reason__c, Churn_Risk__c, Fin_Sentiment__c, Expansion_Signal__c FROM Case WHERE Id = :m.CaseId];
            }
        }
        Datetime since = Datetime.now().addHours(-2);
        List<Case> cs = [SELECT Id, CaseNumber, Subject, Fin_Contact_Reason__c, Churn_Risk__c, Fin_Sentiment__c, Expansion_Signal__c
            FROM Case WHERE ContactId = :contactId AND Subject LIKE 'Fin handoff%' AND IsClosed = false AND CreatedDate >= :since
            ORDER BY CreatedDate DESC LIMIT 1];
        return cs.isEmpty() ? null : cs[0];
    }

    public static void apply(Case c, String contactReason, String churnRisk, String sentiment, String expansionSignal, String title) {
        // Subject: Fin's AI Title if there is one, otherwise the contact reason (only replaces the routing Flow's placeholder)
        Boolean placeholder = c.Subject == null || c.Subject.startsWith('Fin handoff');
        if (String.isNotBlank(contactReason)) {
            c.Fin_Contact_Reason__c = contactReason;
            if (placeholder) c.Subject = 'Fin handoff: ' + contactReason;
        }
        if (String.isNotBlank(title) && placeholder) c.Subject = title.left(255);
        if (String.isNotBlank(churnRisk)) c.Churn_Risk__c = churnRisk;
        if (String.isNotBlank(sentiment)) c.Fin_Sentiment__c = sentiment;
        if (String.isNotBlank(expansionSignal) && expansionSignal.toLowerCase() != 'none') c.Expansion_Signal__c = expansionSignal;
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
            String v = attrs.get(k) == null ? null : String.valueOf(attrs.get(k)).trim();
            if (k.equalsIgnoreCase(name) && String.isNotBlank(v) && !v.startsWith('{{')) return v;
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
