# Sales Engagement setup: "Yelp - New location launch follow-up" cadence (one time, about 10 minutes)

Salesforce side is done:
- **Email templates** (folder *Yelp Keep and Grow*): *Yelp K&G 1 - Let's plan 2027 together*, *Yelp K&G 2 - Ads Optimization Review agenda*, *Yelp K&G 3 - 2027 game plan before your renewal*. They merge Sam's first name, the account name, the location count and the renewal date.
- **Enrollment:** accepting the Next Best Action (**Book the review**) on Whitaker books the review task and adds Sam to this cadence for the signed-in user. If the cadence doesn't exist yet, the review is still booked.
- **Reset:** `python3 scripts/seed.py --live` takes Sam out of the cadence.

The cadence itself is built in Cadence Builder. Name it **exactly** as below, because the Flow finds it by name.

## Build it
1. App Launcher → **Sales Engagement** (or **Cadences**) → **New Cadence**.
   - **Name:** `Yelp - New location launch follow-up`
   - **Description:** `Keep and Grow: follow up after Fin hears growth. Ads Optimization Review, then the 2027 plan before the renewal.`
   - **Target type:** Contacts and leads (default).
2. Add the steps, in order:

| # | Step type | Settings |
|---|---|---|
| 1 | **Send an email** | Name: `Email: Let's plan 2027 together` · Template: *Yelp K&G 1 - Let's plan 2027 together* · Manual (the rep reviews and sends from the Work Queue) |
| 2 | **Wait** | 2 days |
| 3 | **Make a call** | Name: `Call: Ads Optimization Review` · Call script: paste the talk track below |
| 4 | **Wait** | 2 days |
| 5 | **Send an email** | Name: `Email: Review agenda` · Template: *Yelp K&G 2 - Ads Optimization Review agenda* |
| 6 | **Wait** | 5 days |
| 7 | **Send an email** | Name: `Email: 2027 game plan` · Template: *Yelp K&G 3 - 2027 game plan before your renewal* |
| 8 | **Create a task** (Custom step) | Name: `Prepare the 2027 launch scorecard and renewal options` |

3. **Save**, then **Activate**.

### Call script (step 3)
```
Hi Sam, it's Tom from Yelp. Congrats on the four new locations, and I saw you enrolled in the New Location Launch Program, so each new spot gets $500 in ad credit for its first 60 days.

I'd love 30 minutes for a free Ads Optimization Review with one of our Ads specialists:
1. Set launch budgets for the new locations so they ramp up quickly without overspending.
2. Look at cost per lead across your 12 current locations. Aurora is running higher than the rest, so we'll start there.
3. Agree on how we'll measure the new locations, so you have the performance proof you asked for.

With your renewal coming up on December 31, it's a good time to make sure we're aligned on the best game plan for 2027 together. Does Tuesday or Thursday work?

If they push back on value: "That's exactly what the review is for. We'll show you leads and cost per lead by location side by side, and only adjust spend where it's paying off."
```

## Try it
1. Reset: `python3 scripts/seed.py --live`, then run the handoff so Fin writes the expansion signal (or set *Expansion Signal* on Whitaker by hand to test).
2. On Whitaker (Yelp Sales), Next Best Action → **Book the review**. The confirmation says Sam is in the cadence.
3. App Launcher → **Work Queue**: *Email: Let's plan 2027 together* for Sam is due now.

## Optional
- **Branching:** after step 1, add a branch on "Email opened / not opened" (Cadence Builder → Branch), for example a quicker call when Sam opens it.
- **Einstein Sales Emails:** in the email step, **Draft with Einstein** personalizes the template from the record.
