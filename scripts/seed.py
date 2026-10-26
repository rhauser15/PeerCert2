"""Seed (or reset) the Keep & Grow (Fin) demo records in the Salesforce org.

  python3 scripts/seed.py           # reset, then load Whitaker Hospitality Group, other customers and Fin history
  python3 scripts/seed.py --reset   # delete demo records only
  python3 scripts/seed.py --live    # delete only what the live demo run created (handoff case, opportunity, brief)
                                    # and put Aurora back to paused, so you can run the demo again

Every record is tagged Part2_Demo__c (contacts by their demo account), and reset deletes only tagged records.
"""
import argparse
import datetime as dt
import json
import os
import random
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import demo_data as D  # noqa: E402

ORG = os.environ.get("SF_ORG", "trailsignup-429cdf")
TODAY = dt.date.today()


def sf(*args, check=True):
    r = subprocess.run(["sf", *args, "-o", ORG, "--json"], capture_output=True, text=True)
    out = json.loads(r.stdout or "{}")
    if check and out.get("status") not in (0, None):
        sys.exit(f"sf {' '.join(args[:3])} failed:\n{json.dumps(out, indent=1)[:3000]}")
    return out


def query(soql):
    return sf("data", "query", "-q", soql)["result"]["records"]


def apex(code):
    with tempfile.NamedTemporaryFile("w", suffix=".apex", delete=False) as f:
        f.write(code)
    out = sf("apex", "run", "--file", f.name)
    os.unlink(f.name)
    if not out["result"].get("success"):
        sys.exit(out["result"].get("exceptionMessage") or out["result"].get("compileProblem"))


def reset_live():
    """Undo one live run: the handoff case and what the write-back Flow created; Aurora back to paused."""
    print("Clearing the live demo run...")
    apex(f"""
delete [SELECT Id FROM Task WHERE Subject LIKE 'Renewal brief:%' AND What.Name LIKE '{D.COMPANY}%'];
delete [SELECT Id FROM Opportunity WHERE Part2_Demo__c = true AND Account.Name = '{D.COMPANY}' AND Type = 'Add-On Business'];
delete [SELECT Id FROM Case WHERE Part2_Demo__c = true AND Origin = 'Chat' AND Account.Name = '{D.COMPANY}'];
Account a = [SELECT Id FROM Account WHERE Name = '{D.COMPANY}' AND Part2_Demo__c = true LIMIT 1];
a.Churn_Risk__c = 'Low'; a.Churn_Risk_Reason__c = null; a.Expansion_Signal__c = null; a.Fin_Sentiment__c = 'Positive';
a.Last_Fin_Conversation__c = DateTime.newInstance(Date.today().addDays(-19), Time.newInstance(14, 5, 0, 0));
update a;
Account aurora = [SELECT Id FROM Account WHERE ParentId = :a.Id AND Name LIKE '%Aurora' LIMIT 1];
aurora.Monthly_Budget_Cap__c = 900; aurora.Budget_Spent_MTD__c = 900; aurora.Budget_Status__c = 'Paused - Budget Cap Reached';
update aurora;
""")


def reset():
    print("Deleting existing demo records...")
    apex("""
delete [SELECT Id FROM Task WHERE Subject LIKE 'Renewal brief:%' AND WhatId IN (SELECT Id FROM Account WHERE Part2_Demo__c = true)];
delete [SELECT Id FROM Case WHERE Part2_Demo__c = true];
delete [SELECT Id FROM Opportunity WHERE Part2_Demo__c = true];
delete [SELECT Id FROM Contact WHERE Account.Part2_Demo__c = true];
delete [SELECT Id FROM Account WHERE Part2_Demo__c = true AND ParentId != null];
delete [SELECT Id FROM Account WHERE Part2_Demo__c = true];
""")


def rec(sobject, ref, **fields):
    return {"attributes": {"type": sobject, "referenceId": ref}, **fields}


def import_plan(steps):
    """steps: list of (sobject, [records]). Inserts in order through the Composite API, resolving "@ref" lookups.

    Uses the duplicate-rule header so the org's duplicate rules don't block demo locations that share a
    name with other accounts (e.g. Find & Win's Dave's Hot Chicken locations)."""
    ids, total = {}, 0
    for sobject, records in steps:
        for c in range(0, len(records), 200):
            chunk = records[c:c + 200]
            body = {"allOrNone": True, "records": []}
            for r in chunk:
                fields = {k: (ids[v[1:]] if isinstance(v, str) and v.startswith("@") else v)
                          for k, v in r.items() if k != "attributes" and v is not None}
                body["records"].append({"attributes": {"type": sobject}, **fields})
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(body, f)
            r = subprocess.run(["sf", "api", "request", "rest", "/services/data/v64.0/composite/sobjects", "-X", "POST",
                                "-H", "Content-Type:application/json", "-H", "Sforce-Duplicate-Rule-Header:allowSave=true",
                                "-b", "@" + f.name, "-o", ORG], capture_output=True, text=True)
            os.unlink(f.name)
            try:
                res = json.loads(r.stdout)
            except json.JSONDecodeError:
                sys.exit(f"{sobject} insert failed:\n{r.stdout[:2000]}{r.stderr[:2000]}")
            bad = [x for x in res if not x.get("success")]
            if bad:
                sys.exit(f"{sobject} insert failed:\n{json.dumps(bad[:3], indent=1)}")
            for rec_, out in zip(chunk, res):
                ids[rec_["attributes"]["referenceId"]] = out["id"]
            total += len(res)
    print(f"  imported {total} records")


def user_id(name):
    r = query(f"SELECT Id FROM User WHERE Name = '{name}' AND IsActive = true LIMIT 1")
    return r[0]["Id"] if r else None


def ref(name):
    return "".join(ch for ch in name if ch.isalnum())[:60]


def build():
    tom = user_id("Tom Jones")
    owner = {"OwnerId": tom} if tom else {}
    accounts, children, contacts, cases, opps = [], [], [], [], []

    # Whitaker Hospitality Group: the parent customer account and its 12 locations
    caps = sum(l[2] for l in D.LOCATIONS)
    spent = sum(l[3] for l in D.LOCATIONS)
    leads = sum(l[4] for l in D.LOCATIONS)
    accounts.append(rec("Account", "whg", Name=D.COMPANY, Type="Customer", Industry="Hospitality", Phone=D.SAM["phone"],
                        BillingCity="Lakewood", BillingState="CO", Location_Count__c=len(D.LOCATIONS),
                        Brands_Operated__c="Dave's Hot Chicken; Jersey Mike's Subs; Smoothie King",
                        Monthly_Budget_Cap__c=caps, Budget_Spent_MTD__c=spent, Leads_Last_30_Days__c=leads,
                        Cost_Per_Lead__c=round(spent / leads), Budget_Status__c="Active", Churn_Risk__c="Low",
                        Fin_Sentiment__c="Positive",
                        Last_Fin_Conversation__c=f"{TODAY - dt.timedelta(days=19)}T20:05:00.000Z",
                        Description="Multi-location customer since 2024. 7 Dave's Hot Chicken, 4 Jersey Mike's, "
                                    "1 Smoothie King across Denver metro and Colorado Springs.",
                        Part2_Demo__c=True, **owner))
    for brand, loc, cap, mtd, lds, cpl, status in D.LOCATIONS:
        children.append(rec("Account", ref(brand + loc), Name=f"{brand} - {loc}", ParentId="@whg", Type="Customer",
                            Industry="Hospitality", Brand__c=brand, BillingState="CO",
                            BillingCity=loc.split(" (")[0], Monthly_Budget_Cap__c=cap, Budget_Spent_MTD__c=mtd,
                            Leads_Last_30_Days__c=lds, Cost_Per_Lead__c=cpl, Budget_Status__c=status,
                            Part2_Demo__c=True, **owner))
    contacts.append(rec("Contact", "sam", FirstName=D.SAM["first"], LastName=D.SAM["last"], Title=D.SAM["title"],
                        Email=D.SAM["email"], Phone=D.SAM["phone"], AccountId="@whg"))
    opps.append(rec("Opportunity", "renewal", Name=D.RENEWAL["name"], AccountId="@whg", StageName=D.RENEWAL["stage"],
                    CloseDate=D.RENEWAL["close"], Amount=D.RENEWAL["amount"], Part2_Demo__c=True,
                    Description="Annual renewal: 12 locations, Yelp Ads and Page Upgrades.", **owner))

    # Other multi-location customers in the book
    first = ["Maria", "Kevin", "Priya", "Luis", "Dana", "Chris", "Aisha", "Ben", "Rosa", "Tyler", "Grace", "Omar"]
    last = ["Alvarez", "Brooks", "Nair", "Ortega", "Kim", "Fowler", "Bello", "Hart", "Medina", "Shaw", "Lin", "Haddad"]
    for n, (name, city, locs, risk, reason, expansion, sentiment) in enumerate(D.CUSTOMERS):
        r = ref(name)
        accounts.append(rec("Account", r, Name=name, Type="Customer", BillingCity=city, BillingState="CO",
                            Location_Count__c=locs, Churn_Risk__c=risk, Churn_Risk_Reason__c=reason or None,
                            Expansion_Signal__c=expansion or None, Fin_Sentiment__c=sentiment,
                            Monthly_Budget_Cap__c=locs * 650, Budget_Spent_MTD__c=locs * 520,
                            Last_Fin_Conversation__c=f"{TODAY - dt.timedelta(days=1 + n % 9)}T17:30:00.000Z",
                            Part2_Demo__c=True, **owner))
        contacts.append(rec("Contact", "c" + r, FirstName=first[n], LastName=last[n], Title="Owner",
                            Email=f"{first[n].lower()}@{r.lower()}.example.com", AccountId="@" + r))

    # Eight full weeks of Fin conversations synced to Salesforce (Sunday to Saturday, ending last Saturday).
    # Resolution and CSAT climb as the team adds content and Procedures. Counts are exact so the trend is smooth.
    rnd = random.Random(42)
    reasons = [r for r, w in D.REASONS for _ in range(w)]
    who = [("@" + ref(c[0]), "@c" + ref(c[0])) for c in D.CUSTOMERS] + [("@whg", "@sam")]
    last_sunday = TODAY - dt.timedelta(days=(TODAY.weekday() + 1) % 7)
    start = last_sunday - dt.timedelta(weeks=8)
    n = 0
    for week in range(8):
        count = 26 + week * 2
        resolved = round(count * (0.48 + week * 0.026))            # 48% -> 66%
        states = (["Hard Resolution"] * round(resolved * 0.8) + ["Soft Resolution"] * (resolved - round(resolved * 0.8))
                  + ["Abandoned"] * 1)
        states += ["Routed to team"] * (count - len(states))
        rated = round(count * 0.45)
        positive = round(rated * (0.62 + week * 0.037))             # 62% -> 88%
        ratings = [rnd.choice([4, 5, 5]) for _ in range(positive)] + [rnd.choice([1, 2, 3, 3]) for _ in range(rated - positive)]
        ratings += [None] * (count - rated)
        rnd.shuffle(states)
        rnd.shuffle(ratings)
        for state, rating in zip(states, ratings):
            n += 1
            day = start + dt.timedelta(days=week * 7 + rnd.randrange(7))
            reason = rnd.choice(reasons)
            acct, contact = rnd.choice(who)
            cases.append(rec("Case", f"fin{n}", Subject=f"Fin conversation: {reason}", Origin="Website",
                             Status="Closed", Priority="Medium", Type="Account Support", AccountId=acct,
                             ContactId=contact, FinInvolved__c=True, FinResolutionState__c=state,
                             Fin_Contact_Reason__c=reason, Fin_CSAT__c=rating, Conversation_Date__c=str(day),
                             Fin_Sentiment__c=("Positive" if (rating or 4) >= 4 else "Neutral" if rating == 3 else "Negative"),
                             Fin_Summary__c=f"Customer asked about {reason.lower()}.", Part2_Demo__c=True))
    # Whitaker's open case (shows up in Tom's renewal brief)
    cases.append(rec("Case", "whgopen", Subject=D.OPEN_CASE[0], Origin="Website", Status="Working", Priority="Medium",
                     Type="Account Support", AccountId="@whg", ContactId="@sam", FinInvolved__c=True,
                     FinResolutionState__c="Routed to team", Fin_Contact_Reason__c=D.OPEN_CASE[1],
                     Conversation_Date__c=str(TODAY - dt.timedelta(days=6)), Fin_Sentiment__c="Neutral",
                     Fin_Summary__c="Sam asked to remove an outdated menu photo from the Denver (Colfax) page.",
                     Part2_Demo__c=True))
    return [("Account", accounts), ("Account", children), ("Contact", contacts), ("Opportunity", opps), ("Case", cases)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--reset", action="store_true")
    p.add_argument("--live", action="store_true")
    a = p.parse_args()
    if a.live:
        reset_live()
        return
    reset()
    if a.reset:
        return
    print("Loading demo records...")
    import_plan(build())
    links = os.path.join(os.path.dirname(__file__), "links.py")
    if os.path.exists(links):
        subprocess.run([sys.executable, links])


if __name__ == "__main__":
    main()
