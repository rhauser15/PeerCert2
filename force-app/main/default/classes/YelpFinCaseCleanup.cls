/**
 * Keep and Grow demo: the org's SDO "Messaging Session - On Create" automation opens a generic
 * "Support ... Conversation" case for every chat, and Omni routes it. For Fin chats, the handoff routing Flow
 * already made Fin's case (MessagingSession.Fin_Case__c), so the generic one is deleted.
 * Works in either order: runs when a generic case is created for a Fin chat, and when Fin's case is linked.
 * Async (Queueable) because the generic case can't be deleted inside its own insert.
 */
public without sharing class YelpFinCaseCleanup implements Queueable {
    Set<Id> sessionIds;
    public YelpFinCaseCleanup(Set<Id> sessionIds) { this.sessionIds = sessionIds; }

    // Case after insert: generic cases whose source is a chat
    public static void onCasesCreated(List<Case> cases) {
        Set<Id> sessions = new Set<Id>();
        for (Case c : cases) {
            if (c.SourceId != null && String.valueOf(c.SourceId).startsWith('0Mw') && c.Subject != null && c.Subject.startsWith('Support ')) {
                sessions.add(c.SourceId);
            }
        }
        enqueue(sessions);
    }

    // MessagingSession after update: Fin's case was just linked
    public static void onSessionsUpdated(List<MessagingSession> sessions, Map<Id, MessagingSession> previous) {
        Set<Id> ids = new Set<Id>();
        for (MessagingSession s : sessions) {
            if (s.Fin_Case__c != null && s.Fin_Case__c != previous.get(s.Id).Fin_Case__c) ids.add(s.Id);
        }
        enqueue(ids);
    }

    static void enqueue(Set<Id> ids) {
        if (!ids.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) System.enqueueJob(new YelpFinCaseCleanup(ids));
    }

    public void execute(QueueableContext ctx) {
        Map<Id, Id> finCase = new Map<Id, Id>();
        for (MessagingSession s : [SELECT Id, Fin_Case__c FROM MessagingSession WHERE Id IN :sessionIds AND Fin_Case__c != null]) {
            finCase.put(s.Id, s.Fin_Case__c);
        }
        if (finCase.isEmpty()) return;
        List<Case> extra = [SELECT Id FROM Case WHERE SourceId IN :finCase.keySet() AND Subject LIKE 'Support %'
                            AND Id NOT IN :finCase.values()];
        // Keep each chat on Fin's case
        List<MessagingSession> relink = new List<MessagingSession>();
        for (MessagingSession s : [SELECT Id, CaseId, Fin_Case__c FROM MessagingSession WHERE Id IN :finCase.keySet()]) {
            if (s.CaseId != s.Fin_Case__c) relink.add(new MessagingSession(Id = s.Id, CaseId = s.Fin_Case__c));
        }
        if (!relink.isEmpty()) Database.update(relink, false);
        if (!extra.isEmpty()) Database.delete(extra, false);
    }
}
