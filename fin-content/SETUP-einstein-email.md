# Einstein email: "Yelp - Ads Optimization Review invite" (Tom, renewal opportunity)

The email Tom sends from the renewal opportunity (**Activity → Email → Einstein / Draft with Einstein**). Sam Whitaker is the recipient.

## Option A: a saved prompt template (one time, about 5 minutes)
Pasting merge fields as text cuts the prompt off, so paste the plain text below, then add four fields with **Insert Resource**.
1. Setup → **Prompt Builder** → **New Prompt Template**.
2. **Type:** *Sales Email*. **Name:** `Yelp - Ads Optimization Review invite`. **Recipient:** Contact. (If *Sales Email* isn't in the list, use option B.)
3. Paste this into the prompt:

```
You are a Yelp account manager. Write a short, warm email to the customer contact inviting them to a free 30-minute Ads Optimization Review with you and a Yelp Ads specialist.

Contact first name: FIRSTNAME
Business: ACCOUNTNAME
Active Yelp locations: LOCATIONS
Renewal date: RENEWAL

What you know: in a recent Yelp support conversation the customer said they're opening 4 new locations in January and want to see the new locations perform before investing more. They're enrolled in the New Location Launch Program ($500 in ad credit for each new location in its first 60 days).

The email must:
1. Congratulate them on the new locations and mention the New Location Launch Program.
2. Explain the review covers three things: aligning on monthly budget across their current locations, launch budgets for the new locations, and right-sizing their spend commitment for next year so it matches what's paying off.
3. Say you'll bring leads and cost per lead by location, so they can see the performance proof they asked for.
4. Tie it to the renewal date, so the 2027 plan is agreed before the renewal.
5. Ask whether Tuesday or Thursday next week works.

Keep it under 150 words, plain and friendly. No placeholders or brackets. Don't invent numbers that aren't above.
```

4. Replace each capitalized word with a field: select the word, then **Insert Resource** → **Recipient** →
   - `FIRSTNAME` → **First Name**
   - `ACCOUNTNAME` → **Yelp Account Name**
   - `LOCATIONS` → **Yelp Locations**
   - `RENEWAL` → **Yelp Renewal Date**
5. In the preview pane, pick **Sam Whitaker** as the recipient and click **Preview** to check the draft. Then **Save** and **Activate**.
6. In the email composer, click **Einstein**, pick the template and click **Draft**.

The signature comes from the sender automatically, so the prompt doesn't need the sender's name.

## Option B: no template (works now)
In the email composer, click **Einstein** (Draft with Einstein), choose the purpose closest to *Request a meeting* / *Follow up*, and paste this into the instructions:

```
Invite Sam to a free 30-minute Ads Optimization Review. Congratulate him on the 4 new locations opening in January and the New Location Launch Program ($500 ad credit per new location for 60 days). The review aligns on monthly budget across his 12 locations, sets launch budgets for the new ones, and right-sizes his spend commitment for next year so it matches what's paying off. I'll bring leads and cost per lead by location as the performance proof he asked for. Tie it to his December 31 renewal so the 2027 plan is agreed first. Ask if Tuesday or Thursday next week works. Under 150 words, friendly.
```
