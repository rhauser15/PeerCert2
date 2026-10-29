# Einstein email: Ads Optimization Review invite (Tom, renewal opportunity)

Nothing to set up. This org has no Einstein Sales Emails (no *Draft with Einstein* in the email composer, no *Sales Email* prompt type), so the demo uses the same generative AI through Prompt Builder and a Flow:

- **Prompt template:** *Yelp - Ads Optimization Review invite* (`Yelp_Ads_Review_Invite`, Flex type, Setup → Prompt Builder). Inputs: the opportunity and the contact. It's grounded on the account's real fields: locations, Fin's expansion signal, what the customer wants before investing more, annual ad spend, and the renewal date.
- **Flow:** *Yelp - Email with Einstein* (`Yelp_Draft_Review_Invite`), a screen flow at the top of the renewal opportunity's right column (Part 2 records only). **Draft with Einstein** runs the template, the rep edits the subject and body, and **Send** emails the account's main contact and logs it on the opportunity.
- **Reset:** `python3 scripts/seed.py --live` deletes the logged email.

In an org with Einstein Sales Emails, the same prompt can be a *Sales Email* template and used straight from the email composer.
