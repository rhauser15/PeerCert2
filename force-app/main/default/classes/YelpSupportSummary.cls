/**
 * Keep and Grow demo: the "recent support" part of the account owner's Slack brief (Yelp - Fin Case Resolved Alert).
 * Summarizes the account's last 90 days of support instead of the one case: volume, how much Fin resolved, top
 * topics, positive signals (budget increases through Fin, growth) and what to watch (value concerns).
 */
public without sharing class YelpSupportSummary {
    public class Request {
        @InvocableVariable(label='Case ID' required=true)
        public Id caseId;
    }
    public class Result {
        @InvocableVariable(label='Recent support summary (Slack formatting)')
        public String summary;
    }

    @InvocableMethod(label='Summarize recent support' description='Recent support, positive signals and watch-outs for the account owner brief.')
    public static List<Result> summarize(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            try {
                res.summary = build(r.caseId);
            } catch (Exception e) {
                res.summary = '- (Recent support summary unavailable: ' + e.getMessage() + ')';
            }
            out.add(res);
        }
        return out;
    }

    @TestVisible
    static String build(Id caseId) {
        Case c = [SELECT AccountId, Contact.FirstName, Contact.Email, Expansion_Signal__c, Churn_Risk__c, Churn_Risk_Reason__c,
                         Fin_Sentiment__c, Fin_Contact_Reason__c FROM Case WHERE Id = :caseId];
        String first = c.Contact == null || c.Contact.FirstName == null ? 'The customer' : c.Contact.FirstName;
        Datetime since = Datetime.now().addDays(-90);
        Integer total = 0, byFin = 0, byTeam = 0, open = 0;
        Map<String, Integer> topics = new Map<String, Integer>();
        for (Case k : [SELECT IsClosed, FinResolutionState__c, Fin_Contact_Reason__c FROM Case
                       WHERE AccountId = :c.AccountId AND CreatedDate >= :since]) {
            total++;
            if (!k.IsClosed) open++;
            if (k.FinResolutionState__c == 'Hard Resolution' || k.FinResolutionState__c == 'Soft Resolution') byFin++;
            else byTeam++;
            String t = String.isBlank(k.Fin_Contact_Reason__c) ? 'Other' : k.Fin_Contact_Reason__c;
            topics.put(t, topics.containsKey(t) ? topics.get(t) + 1 : 1);
        }

        List<String> lines = new List<String>{ ':clipboard: *Support Summary (last 90 days)*' };
        lines.add('• :speech_balloon: *' + total + ' conversations:* ' + byFin + ' resolved by Fin' + (total > 0 ? ' (' + Math.round(100.0 * byFin / total) + '%)' : '')
            + ', ' + byTeam + ' handled by the team' + (open > 0 ? ', ' + open + ' still open' : ''));
        lines.add('• :label: *Top topics:* ' + topTopics(topics, 3));

        List<String> positives = budgetIncreases(c.Contact == null ? null : c.Contact.Email);
        if (String.isNotBlank(c.Expansion_Signal__c) && c.Expansion_Signal__c.toLowerCase() != 'none') {
            positives.add(':rocket: *Growth:* ' + first + ' flagged *' + c.Expansion_Signal__c.toLowerCase() + '* in tonight\'s conversation');
        }
        if (!positives.isEmpty()) {
            lines.add('');
            lines.add(':white_check_mark: *Positive signals*');
            for (String p : positives) lines.add('• ' + p);
        }

        List<String> watch = new List<String>();
        Boolean negative = c.Fin_Sentiment__c != null && c.Fin_Sentiment__c.containsIgnoreCase('negative');
        if (c.Fin_Contact_Reason__c == 'Add a location' && negative) {
            watch.add(first + ' isn\'t sure the new locations will pay off and wants to see performance before investing more');
        } else if (negative) {
            watch.add('Sentiment was ' + c.Fin_Sentiment__c.toLowerCase() + ' in tonight\'s conversation');
        }
        if (String.isNotBlank(c.Churn_Risk__c)) {
            // The routing Flow's default reason adds nothing here
            Boolean genericReason = String.isBlank(c.Churn_Risk_Reason__c) || c.Churn_Risk_Reason__c.startsWith('Flagged by Fin');
            watch.add('Churn risk: ' + c.Churn_Risk__c + (genericReason ? '' : ' (' + c.Churn_Risk_Reason__c + ')'));
        }
        if (!watch.isEmpty()) {
            lines.add('');
            lines.add(':warning: *Watch*');
            for (String w : watch) lines.add('• ' + w);
        }
        return String.join(lines, '\n');
    }

    static String topTopics(Map<String, Integer> topics, Integer n) {
        List<String> keys = new List<String>(topics.keySet());
        List<String> parts = new List<String>();
        for (Integer i = 0; i < n && !keys.isEmpty(); i++) {
            String best = keys[0];
            for (String k : keys) if (topics.get(k) > topics.get(best)) best = k;
            parts.add(best + ' (' + topics.get(best) + ')');
            keys.remove(keys.indexOf(best));
        }
        return parts.isEmpty() ? 'none' : String.join(parts, ', ');
    }

    // Budget caps the customer raised through Fin in the last 7 days (Yelp Fin API log of the budget data connector)
    static List<String> budgetIncreases(String email) {
        List<String> out = new List<String>();
        if (String.isBlank(email)) return out;
        Datetime since = Datetime.now().addDays(-7);
        Set<String> seen = new Set<String>();
        for (Yelp_Fin_Api_Log__c l : [SELECT Detail__c, CreatedDate FROM Yelp_Fin_Api_Log__c WHERE Endpoint__c = 'budget'
                AND Status__c = 200 AND CreatedDate >= :since ORDER BY CreatedDate DESC LIMIT 20]) {
            if (l.Detail__c == null || !l.Detail__c.containsIgnoreCase(email)) continue;
            Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(l.Detail__c.substringAfter('response='));
            String loc = String.valueOf(r.get('location')).substringAfterLast(' - ');
            Decimal prev = (Decimal) r.get('previous_monthly_cap'), next = (Decimal) r.get('new_monthly_cap');
            if (prev == null || next == null || next <= prev || seen.contains(loc)) continue;
            seen.add(loc);
            out.add(':moneybag: *Budget up:* ' + loc + ' monthly cap raised from $' + prev.format() + ' to $' + next.format() + ' through Fin');
        }
        return out;
    }
}
