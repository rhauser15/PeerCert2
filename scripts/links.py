"""Rewrite the direct-links block in DEMO_SCRIPT.md (and site/links.js for the launcher) with current record IDs.

  python3 scripts/links.py

seed.py runs this automatically, because reseeding gives the demo records new IDs.
"""
import json
import os
import re
import subprocess

ORG = os.environ.get("SF_ORG", "trailsignup-429cdf")
BASE = "https://trailsignup-429cdfd78ec835.lightning.force.com"
SITE = "https://rhauser15.github.io/PeerCert2"
FIN_TEST = "?intercomTest=true&messenger_environment=limwmcawd3"  # the Fin Messenger is live in test mode only
APP_ID = "06mg800000AlQvzAAF"  # Service Console for Tech (Tech_Service_Console)
SALES_APP_ID = "06mg800000AlQvwAAF"  # Sales for Tech (Tom's view)
ROOT = os.path.join(os.path.dirname(__file__), "..")
SCRIPT = os.path.join(ROOT, "DEMO_SCRIPT.md")
LINKS_JS = os.path.join(ROOT, "site", "links.js")
START, END = "<!-- links:start -->", "<!-- links:end -->"


def first(soql, tooling=False):
    args = ["sf", "data", "query", "-o", ORG, "-q", soql, "--json"] + (["--use-tooling-api"] if tooling else [])
    out = json.loads(subprocess.run(args, capture_output=True, text=True).stdout or "{}")
    recs = out.get("result", {}).get("records", [])
    return recs[0] if recs else None


def rec(label, obj, soql, app=None):
    r = first(soql)
    path = f"/lightning/app/{app}/r/{obj}/{r['Id']}/view" if r and app else (f"/lightning/r/{obj}/{r['Id']}/view" if r else None)
    return (label, BASE + path if path else None)


def flow(label, name):
    f = first(f"SELECT ActiveVersionId FROM FlowDefinition WHERE DeveloperName = '{name}'", tooling=True)
    return (label, f"{BASE}/builder_platform_interaction/flowBuilder.app?flowId={f['ActiveVersionId']}" if f else None)


def build():
    acct = "SELECT Id FROM Account WHERE Name = 'Whitaker Hospitality Group' AND Part2_Demo__c = true LIMIT 1"
    return [
        ("Mockups", [
            ("Launcher", f"{SITE}/"),
            ("Slides: set the scene and close", f"{SITE}/slides.html"),
            ("Yelp for Business help center with Fin Messenger (live handoff)", f"{SITE}/help.html"),
            ("Fin: Performance, Topics Explorer, Procedure", f"{SITE}/fin.html"),
        ]),
        ("Live Fin (real workspace; same browser you're signed in to Fin with, blockers off)", [
            ("Issue 1 live: Westminster, data connectors", f"{SITE}/help-fin.html{FIN_TEST}"),
            ("Issue 2 live: handoff to John", f"{SITE}/help-fin-handoff.html{FIN_TEST}"),
        ]),
        ("Start here", [
            ("Open the Yelp Support Console", f"{BASE}/lightning/app/{APP_ID}"),
        ]),
        ("Sections 1 and 2 · Handoff and Copilot", [
            ("Messaging Sessions", f"{BASE}/lightning/o/MessagingSession/list?filterName=Recent"),
            rec("Sam Whitaker (contact)", "Contact", "SELECT Id FROM Contact WHERE Email = 'sam@whitakerhospitality.example.com' LIMIT 1"),
            flow("Fin handoff routing Flow", "Yelp_Fin_Handoff_Routing"),
        ]),
        ("Section 3 · Tom's view", [
            rec("Whitaker Hospitality Group (account, Yelp Sales)", "Account", acct, SALES_APP_ID),
            rec("Renewal opportunity", "Opportunity",
                "SELECT Id FROM Opportunity WHERE Part2_Demo__c = true AND Name LIKE '%Annual Renewal' LIMIT 1", SALES_APP_ID),
            flow("Fin write-back Flow (account, expansion opportunity, renewal brief)", "Yelp_Fin_Case_Writeback"),
            rec("Next Best Action: Ads Optimization Review (Recommendation)", "Recommendation",
                "SELECT Id FROM Recommendation WHERE Category__c = 'Yelp Keep and Grow' LIMIT 1"),
            flow("Next Best Action: Book Ads Optimization Review Flow", "Yelp_Book_Ads_Optimization_Review"),
            ("Next Best Action strategies (Setup → Quick Find: Next Best Action → Yelp Keep and Grow)", f"{BASE}/lightning/setup/SetupOneHome/home"),
            ("Sales Engagement: Cadences (Cadence Builder: Yelp - New location launch follow-up)", f"{BASE}/lightning/o/ActionCadence/list"),
            ("Sales Engagement: Work Queue (App Launcher → Work Queue)", f"{BASE}/lightning/page/home"),
            ("Email templates: Yelp Keep and Grow folder", f"{BASE}/lightning/o/EmailTemplate/home"),
            ("Einstein Prediction Builder (Setup)", f"{BASE}/lightning/setup/EinsteinBuilder/home"),
            ("Einstein Opportunity Scoring (Setup → Quick Find: Einstein Opportunity Scoring)", f"{BASE}/lightning/setup/SetupOneHome/home"),
            ("Slack #sales-account-health (Tom's alert)", "https://app.slack.com/client/T0C4N1TMPN3/C0CCHSXG9D5"),
        ]),
        ("Section 4 · Alisha's view", [
            rec("Customer Success dashboard", "Dashboard",
                "SELECT Id FROM Dashboard WHERE DeveloperName = 'Keep_and_Grow_CS' LIMIT 1"),
            rec("Fin: Accounts Flagged in Conversations (report)", "Report",
                "SELECT Id FROM Report WHERE DeveloperName = 'Fin_Flagged_Accounts' LIMIT 1"),
        ]),
    ]


def main():
    rows = build()
    lines = [START, "", "*Auto-generated by `scripts/links.py` (runs after every `seed.py`). Sign in as Rob first.*", ""]
    for title, links in rows:
        lines.append(f"**{title}**")
        lines += [f"- [{label}]({url})" if url else f"- {label} (not found; run seed.py)" for label, url in links]
        lines.append("")
    lines.append(END)
    block = "\n".join(lines)
    if os.path.exists(SCRIPT):
        text = open(SCRIPT).read()
        if START in text:
            text = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
            open(SCRIPT, "w").write(text)
            print("Updated links in DEMO_SCRIPT.md")
    sf_rows = [(t, [(l, u) for l, u in links if u and u.startswith(BASE)]) for t, links in rows]
    with open(LINKS_JS, "w") as f:
        f.write("// Generated by scripts/links.py\nwindow.SF_LINKS = " + json.dumps([r for r in sf_rows if r[1]], indent=1) + ";\n")
    print("Updated site/links.js")


if __name__ == "__main__":
    main()
