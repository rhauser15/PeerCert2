// Keep and Grow demo: removes the org's generic case for Fin Messenger chats (see YelpFinCaseCleanup)
trigger YelpFinGenericCase on Case (after insert) {
    YelpFinCaseCleanup.onCasesCreated(Trigger.new);
}
