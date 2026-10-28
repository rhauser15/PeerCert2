// Keep and Grow demo: closes the Fin conversation when a Fin Messenger handoff chat ends in Salesforce
trigger YelpFinSessionEnded on MessagingSession (after update) {
    YelpFinClose.onSessionsEnded(Trigger.new, Trigger.oldMap);
}
