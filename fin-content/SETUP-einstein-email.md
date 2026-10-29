# Einstein email: "Yelp - Ads Optimization Review invite" (Tom, renewal opportunity)

The email Tom sends from the renewal opportunity (**Activity → Email → Einstein / Draft with Einstein**). Sam Whitaker is the recipient.

## Option A: a saved prompt template (one time, about 5 minutes)
This org rejects Sales Email prompt templates over the Metadata API ("Prompt Template Type is not valid"), so create it in the UI:
1. Setup → **Prompt Builder** → **New Prompt Template**.
2. **Type:** *Sales Email*. **Name:** `Yelp - Ads Optimization Review invite`. **Recipient:** Contact. (If *Sales Email* isn't in the list, use option B.)
3. Paste the prompt below. Then **Save**, **Activate**.
4. In the email composer, click **Einstein**, pick the template and **Draft**.

```
You are {!$Input:Sender.Name}, the Yelp account manager for {!$Input:Recipient.Account.Name}. Write a short, warm email to {!$Input:Recipient.FirstName} inviting them to a free 30-minute Ads Optimization Review with you and a Yelp Ads specialist.

What you know about the account:
- Active locations on Yelp: {!$Input:Recipient.Account.Location_Count__c}
- Growth Fin heard in a recent support conversation: {!$Input:Recipient.Account.Expansion_Signal__c}
- What they want before investing more: {!$Input:Recipient.Account.Churn_Risk_Reason__c}
- Annual Yelp ad spend: {!$Input:Recipient.Account.Annual_Ad_Spend__c}
- Monthly budget cap: {!$Input:Recipient.Account.Monthly_Budget_Cap__c}
- Renewal date: {!$Input:Recipient.Account.Renewal_Date__c}

The email must:
1. Congratulate them on the new locations and mention they're enrolled in the New Location Launch Program ($500 in ad credit per new location for its first 60 days).
2. Explain the review covers three things: aligning on monthly budget across the current locations, launch budgets for the new locations, and right-sizing their spend commitment for next year so it matches what's paying off.
3. Say you'll bring leads and cost per lead by location so they can see the performance proof they asked for.
4. Tie it to the renewal date, so the 2027 plan is agreed before the renewal.
5. Ask whether Tuesday or Thursday next week works.

Keep it under 150 words, plain and friendly, no bullet points longer than one line, no placeholders or brackets. Sign off with {!$Input:Sender.FirstName}. Don't invent numbers that aren't above.
```

To insert a merge field, use **Insert Resource** in Prompt Builder (Recipient → Account → field) rather than typing it, so the names match.

## Option B: no template (works now)
In the email composer, click **Einstein** (Draft with Einstein), choose the purpose closest to *Request a meeting* / *Follow up*, and paste this into the instructions:

```
Invite Sam to a free 30-minute Ads Optimization Review. Congratulate him on the 4 new locations opening in January and the New Location Launch Program ($500 ad credit per new location for 60 days). The review aligns on monthly budget across his 12 locations, sets launch budgets for the new ones, and right-sizes his spend commitment for next year so it matches what's paying off. I'll bring leads and cost per lead by location as the performance proof he asked for. Tie it to his December 31 renewal so the 2027 plan is agreed first. Ask if Tuesday or Thursday next week works. Under 150 words, friendly.
```
