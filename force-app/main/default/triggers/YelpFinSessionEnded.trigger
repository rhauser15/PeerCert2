// Keep and Grow demo: when a Fin Messenger chat ends, close the Fin conversation; when Fin's case is linked,
// remove the org's generic case
trigger YelpFinSessionEnded on MessagingSession (after update) {
    YelpFinClose.onSessionsEnded(Trigger.new, Trigger.oldMap);
    YelpFinCaseCleanup.onSessionsUpdated(Trigger.new, Trigger.oldMap);
}
