# Live Fin setup: page 2 (issue 1, Westminster)

Page: `https://rhauser15.github.io/PeerCert2/help-fin.html`. The Messenger signs in as Sam, and the "Your locations" panel reads Westminster's real status from Salesforce every 5 seconds.

API base (the "Yelp Fin API" Salesforce Site):
`https://trailsignup-429cdfd78ec835.my.salesforce-sites.com/yelpfin/services/apexrest/yelp`

The data connector key is in **`.fin-api.local`** in the repo folder on your Mac. It's not committed. Paste its value wherever this guide says *(key)*.

---

## 0. Sign Sam in (Fin requires signed-in users for data connectors)
1. In Fin, go to **Settings → Workspace → Security** and copy the Messenger **identity verification / JWT secret** for Web.
2. In Salesforce, go to **Setup → Custom Metadata Types → Yelp Fin API → Manage Records → Default → Edit**, paste the secret into **Messenger Secret**, and save.
3. Back in Fin, turn on JWT authentication for Web (customer authentication) if it isn't already. Leave enforcement for unverified users off for this demo workspace.

## 1. Data connectors (Settings → Integrations → Data connectors → + New)

### A. Get Yelp ad account
- **Description:** Gets the customer's Yelp Ads account: every location with its monthly budget cap, spend this month, leads, cost per lead and whether its ads are running or paused (and why). Use it when a customer asks why an ad isn't showing, how a location is doing, or about budgets. Example questions: "Why isn't my Westminster ad showing?", "Are all my ads running?", "What's my budget for Lakewood?"
- **Method/URL:** `GET {API base}/account?email={{user email}}` (insert the user's Email attribute).
- **Headers:** `X-Yelp-Fin-Key: (key)`, `Accept: application/json`
- **Fin tab:** Enabled (direct trigger). **Security:** Customer authentication on.

### B. Raise a location's budget cap
- **Description:** Changes the monthly budget cap for one location. Only use it after the customer has confirmed the location and the new cap amount.
- **Data inputs:** `location` (text, the location name, e.g. "Westminster") and `monthly_cap` (number, the new monthly cap in dollars).
- **Method/URL:** `POST {API base}/budget`
- **Headers:** `X-Yelp-Fin-Key: (key)`, `Content-Type: application/json`
- **Body:** `{"email": "{{user email}}", "location": "{{location}}", "monthly_cap": {{monthly_cap}}}`
- **Fin tab:** Disabled (manual trigger, used by the Procedure). **Security:** Customer authentication on.

### C. Get latest invoice
- **Description:** Gets the customer's latest Yelp invoice: total, previous month's total, and what changed by location. Use it for "why was my invoice higher?" questions.
- **Method/URL:** `GET {API base}/invoice?email={{user email}}`
- **Headers:** `X-Yelp-Fin-Key: (key)`, `Accept: application/json`
- **Fin tab:** Enabled. **Security:** Customer authentication on.

Test each with **Live response**. Running B for real changes Salesforce; afterwards, run `python3 scripts/seed.py --live` to reset.

## 2. Procedure (Train → Procedures → New): "Ad not showing"
**When to use:** the customer asks why an ad isn't showing, running, or getting views for a location.

Steps (paste, then attach the connectors where noted):
1. Use **Get Yelp ad account** to find the customer's locations and their ad status.
2. If the customer named a location, find it. Otherwise ask which location they mean.
3. If that location's ad status is "Paused: monthly budget cap reached":
   a. Tell them when it paused and that it reached its monthly cap (say the cap amount). Mention when the cap resets (`budget_cap_resets_on`). If it's their busiest location by leads, say so.
   b. Say the other locations are running normally if they are.
   c. Offer to raise the cap so the ad runs again tonight. Suggest about 25% higher (for a $1,200 cap, suggest $1,500), and offer $1,400 or keeping it paused as alternatives.
   d. When the customer confirms an amount, use **Raise a location's budget cap** with that location and amount. Then confirm the new cap, that ads resume within 15 minutes, and that they're only charged for what the location spends.
4. Otherwise, explain the ad's status from the account data.

## 3. Messenger workflow (Deploy → Fin Messenger → your workflow → Let Fin answer)
- **Ask for conversation rating (CSAT):** on, when the customer replies positively.
- **Create Salesforce case on resolution:** on. Case owner: any user or queue.
- (Optional) Set data: Contact reason = "Ad not showing".

## 4. Try it (page 2)
1. Open help-fin.html and open the Messenger (bottom right).
2. "Why isn't my Westminster ad showing?" Fin should say it hit its $1,200 cap and offer to raise it.
3. "Raise it to $1,500." In Salesforce, Westminster changes to Active at $1,500, and the page's "Your locations" panel switches to Running within about 5 seconds.
4. "Also, why was my last invoice higher than usual?" Fin should give the $530 explanation.
5. "Nope, that's everything. Thanks, that fixed it!" The CSAT survey follows. Rate it.
6. In Salesforce, Sam's new Fin case appears (Fin Involved, Hard Resolution). It counts on Alisha's dashboard.

Reset afterwards: `python3 scripts/seed.py --live`. This puts Westminster back to paused at $1,200 and deletes the cases Fin created for Sam.
