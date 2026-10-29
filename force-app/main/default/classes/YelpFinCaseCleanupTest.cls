@IsTest
private class YelpFinCaseCleanupTest {
    @IsTest
    static void ignoresNonChatCasesAndUnlinkedSessions() {
        Case c = new Case(Subject = 'Support Custom Conversation');
        YelpFinCaseCleanup.onCasesCreated(new List<Case>{ c });
        MessagingSession s = new MessagingSession(Id = '0Mw000000000001AAA');
        YelpFinCaseCleanup.onSessionsUpdated(new List<MessagingSession>{ s }, new Map<Id, MessagingSession>{ s.Id => s });
        Test.startTest();
        new YelpFinCaseCleanup(new Set<Id>{ s.Id }).execute(null);
        Test.stopTest();
        System.assertEquals(0, Limits.getQueueableJobs());
    }
}
