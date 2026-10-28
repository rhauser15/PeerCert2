# Live Fin setup: page 3 (issue 2, handoff to John)

Salesforce side is done: the "Yelp - Fin Messenger" channel (Bring Your Own Channel) is active, mapped to the routing Flow, and the Event Relay is running. Do these four parts in Fin and Salesforce, in order.

---

## Part 1 · Fin attributes (Fin → Train → Attributes → New attribute)

Create four attributes. For each: choose **Use a list**, type the name **exactly** (Salesforce receives `conversation_custom_data_<Name>`), add the values and descriptions below, and save. If there's an option to make them available to **Conversations**, keep it on.

### Attribute 1 · `Contact Reason`
Description:
```
What the customer contacted Yelp about in this conversation.
```
| Value | Description |
|---|---|
| `Ad not showing` | `The customer's ad isn't showing, stopped, or is paused for a location.` |
| `Budget and billing` | `Questions about budgets, budget caps or spend.` |
| `Invoice question` | `Questions about an invoice or a charge.` |
| `Add a location` | `The customer is opening, adding or planning new locations, or wants to move budget to new locations.` |
| `Cancel a location` | `The customer wants to cancel or stop ads for a location.` |
| `Ad performance` | `Questions about leads, cost per lead or whether ads are working.` |
| `Other` | `Anything else.` |

### Attribute 2 · `Churn Risk`
Description:
```
How likely this customer is to cancel or reduce spend, based on what they said in this conversation.
```
| Value | Description |
|---|---|
| `Low` | `Engaged customer with a concern about value or performance, but not asking to cancel or reduce spend. For example: wants to see results before investing more.` |
| `Medium` | `Customer is considering reducing spend or pausing, or is frustrated with results.` |
| `High` | `Customer asks to cancel, says they will leave, or mentions a competitor.` |

### Attribute 3 · `Sentiment`
Description:
```
The customer's overall sentiment in this conversation.
```
| Value | Description |
|---|---|
| `Positive` | `Happy or appreciative.` |
| `Neutral` | `Matter-of-fact, no strong feeling.` |
| `Slightly Negative` | `Mildly skeptical or concerned, for example doubting that new locations will perform, but still constructive.` |
| `Negative` | `Frustrated, upset or angry.` |

### Attribute 4 · `Expansion Signal`
Description:
```
Whether the customer mentioned growing their business with Yelp in this conversation.
```
| Value | Description |
|---|---|
| `None` | `No mention of growth.` |
| `New locations` | `The customer is opening or planning new locations.` |
| `More budget` | `The customer wants to increase spend or add products.` |

---

## Part 2 · Procedure for issue 2 (Fin → Train → Procedures → New) — recommended
Makes Fin hand off reliably instead of trying to answer.

**Name**
```
New locations or redirecting spend
```
**When to use**
```
The customer is opening new locations, or asks to move, redirect or shift budget from existing locations to new ones, or wants to test new locations before investing more.
```
**Instructions** (paste; then insert the handoff where it says "hand off")
```
1. Acknowledge the new locations and the customer's concern about performance. Don't quote numbers or promise credits.
2. Set the attributes from the conversation: Contact Reason, Churn Risk, Sentiment and Expansion Signal.
3. Tell the customer a Multi-Location specialist can go over options for moving budget and planning the launch, and that you've passed along a summary so they won't need to repeat anything.
4. Hand off to the team (Salesforce).
```
Use the procedure's handoff option at step 4 (for example **@handoff** / **Hand off to team**), then **Publish to main**.

---

## Part 2b · Escalation guidance and rule (Fin → Train → Guidance → Escalation): makes the handoff reliable
Procedures are matched by AI. An escalation **rule** is checked every turn, so it's the closest thing to a guaranteed handoff.

**Escalation guidance** (paste as a new guidance item)
```
Escalate to the team, without asking follow-up questions, only when the customer says they are opening or planning NEW locations, or asks to move or redirect spend from existing locations to new ones. These are budget decisions a Multi-Location specialist must handle. Before escalating, tell the customer a specialist will help and that you've passed along a summary.
Do NOT escalate questions about an ad that isn't showing, a paused location, raising or changing one existing location's budget cap, or invoices. Handle those yourself with the "Ad not showing" Procedure and the data connectors.
```
**Escalation rule** (if your workspace shows Rules): **When** `Expansion Signal` **is** `New locations` → **Escalate**. Use only this one condition. Don't add Contact Reason or other budget conditions, because those also match issue 1.

Save and set live. Test mode uses the latest settings.

---

## Part 2d · Data connector D: "Log handoff signals" (gets Fin's attributes onto the case)
Fin's "Hand off to Salesforce agent" doesn't send custom attributes with the chat, so Fin posts them to Salesforce with a data connector. Order doesn't matter: if the chat hasn't reached Salesforce yet, the routing Flow picks them up; if the case already exists, it's filled in right away and Tom's write-back runs.

- **Name:** `Log handoff signals`
- **Description:**
```
Saves this conversation's Contact Reason, Churn Risk, Sentiment and Expansion Signal to Salesforce so the Multi-Location specialist sees them. Always use it right before handing the conversation off to the team.
```
- **Method/URL:** `POST https://trailsignup-429cdfd78ec835.my.salesforce-sites.com/yelpfin/services/apexrest/yelp/signals`
- **Headers:** `X-Yelp-Fin-Key: (key from .fin-api.local)`, `Content-Type: application/json`
- **Body:** insert each `{{…}}` with the attribute picker (People: Email; Conversation: ID, ContactReason, ChurnRisk, Sentiment, ExpansionSignal):
```
{"email": "{{email}}", "conversation_id": "{{conversation id}}", "contact_reason": "{{ContactReason}}", "churn_risk": "{{ChurnRisk}}", "sentiment": "{{Sentiment}}", "expansion_signal": "{{ExpansionSignal}}", "title": "{{AI Title}}"}
```
  `title` (Fin's AI Title) becomes the case subject, for example "Spend Redirection Question". Without it, the subject is "Fin handoff: <contact reason>".
  If the picker doesn't offer conversation attributes, add **data inputs** instead (text: `contact_reason`, `churn_risk`, `sentiment`, `expansion_signal`, each described as "the value of the <name> attribute in this conversation") and insert those. `conversation_id` is optional.
- **Fin tab:** enabled. **Security:** customer authentication on. Set live.
- **Make Fin call it before the handoff**, using whichever your workspace offers:
  - Workflow path C: add a data connector or action step for **Log handoff signals** before **Hand-off to Salesforce agent**, or
  - add to the escalation guidance: `Before escalating, use the Log handoff signals data connector.`
- **Check:** *Yelp Fin API Logs* shows a `signals` row for each call. Also fix the Sentiment value typo in Fin: `Slighly Negative` → `Slightly Negative`.

---

## Part 2c · Fin access token for the handoff signals (one time)
Fin's handoff brings Sam's email into Salesforce, but not the conversation attributes. The routing Flow reads them from Fin's API instead (Apex `YelpFinSignals`), using the Fin conversation ID on the chat.
1. In Fin: **Settings → Integrations → Developer Hub → New app**. Name it `Salesforce handoff signals`, pick this workspace, and create it.
2. Open the app's **Authentication** page and copy the **Access token**.
3. In Salesforce: **Setup → Custom Metadata Types → Yelp Fin API → Manage Records → Default → Edit**, paste the token into **Fin Access Token**, and save. If only the field's default value can be edited, paste it there; that works too.
4. After the next handoff, *Yelp Fin API Logs* shows a `fin-signals` row with the attributes Fin returned, or the error.

---

## Part 3 · Messenger workflow handoff (Fin → Deploy → Fin Messenger → your workflow)
1. Click **Edit** (or open the draft).
2. On the **Let Fin answer** step, find the branch **If escalated to a team** (also used when the Procedure hands off).
3. Under that branch, click **+ Add step → Hand off to Salesforce agent**.
4. In the step's settings, leave "Create a case when no agent picks up in time" **off** for the demo.
5. Click **Set live** (or keep testing with the test link — test mode uses the draft).

---

## Part 4 · Salesforce, before each test
1. **Yelp Support Console → Omni-Channel** (bottom bar): end any leftover test chat in your inbox (open it → **End Chat**).
2. Set status to **Messaging - Available**.
3. Reset the demo data if you've run the demo since: `python3 scripts/seed.py --live`.

---

## Test (page 3)
Open in the browser you're signed in to Fin with, blockers off:
`https://rhauser15.github.io/PeerCert2/help-fin-handoff.html?intercomTest=true&messenger_environment=limwmcawd3`

1. Open the Messenger → **Send us a message** (new conversation).
2. Send:
```
I'm planning to open 4 new locations in January. Can I temporarily redirect a portion of my existing spend to the new locations? I want to see performance before investing more. New locations don't always perform as expected.
```
3. If Fin doesn't hand off: `I'd like to talk to a person`
4. Expect: the chat rings in Omni-Channel. Accept it. The Case shows Contact Reason = Add a location, Churn Risk = Low, Sentiment = Slightly Negative, Expansion Signal = New locations.
5. Continue as in the script: Copilot → Draft a reply → Support tools → End Chat → Case resolved → Tom's Slack alert.

Troubleshooting: Fin → Analyze → Conversations → the conversation → event "Handed off to Salesforce In App Messaging" shows the payload Fin sent.
