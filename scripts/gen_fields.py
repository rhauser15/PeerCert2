"""Generates the custom fields and permission set for the Keep & Grow (Fin) demo."""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "force-app", "main", "default")


def num(label, desc, precision=8, scale=0):
    return f"<type>Number</type><precision>{precision}</precision><scale>{scale}</scale>", label, desc


def cur(label, desc):
    return "<type>Currency</type><precision>12</precision><scale>0</scale>", label, desc


def chk(label, desc):
    return "<type>Checkbox</type><defaultValue>false</defaultValue>", label, desc


def txt(label, desc, length=255):
    return f"<type>Text</type><length>{length}</length>", label, desc


def lta(label, desc, lines=8):
    return f"<type>LongTextArea</type><length>32768</length><visibleLines>{lines}</visibleLines>", label, desc


def date(label, desc):
    return "<type>Date</type>", label, desc


def dtm(label, desc):
    return "<type>DateTime</type>", label, desc


def pick(label, desc, values, restricted=True):
    vals = "".join(f"<value><fullName>{v}</fullName><default>false</default><label>{v}</label></value>" for v in values)
    return (f"<type>Picklist</type><valueSet><restricted>{str(restricted).lower()}</restricted>"
            f"<valueSetDefinition><sorted>false</sorted>{vals}</valueSetDefinition></valueSet>"), label, desc


RISK = ["High", "Medium", "Low"]
SENTIMENT = ["Positive", "Neutral", "Slightly Negative", "Negative"]
REASONS = ["Ad not showing", "Budget and billing", "Invoice question", "Ad performance", "Cancel a location",
           "Add a location", "Account access", "Other"]

FIELDS = {
    "Case": {
        # Fin writes these on the cases it creates (named after the Fin for Salesforce fields)
        "FinInvolved__c": chk("Fin Involved", "Fin handled this conversation before it reached the team."),
        "FinResolutionState__c": pick("Fin Resolution State", "How Fin's part of the conversation ended.",
                                      ["Hard Resolution", "Soft Resolution", "Routed to team", "Abandoned"]),
        "Fin_Summary__c": lta("Fin Summary", "Summary Fin wrote at handoff."),
        "Fin_Transcript__c": lta("Fin Transcript", "Transcript of the Fin conversation.", 14),
        # Mapped from Fin attributes by Flow
        "Fin_Contact_Reason__c": pick("Contact Reason", "Topic of the conversation, set by Fin.", REASONS, restricted=False),
        "Churn_Risk__c": pick("Churn Risk", "Churn risk Fin detected in the conversation.", RISK, restricted=False),
        "Churn_Risk_Reason__c": txt("Churn Risk Reason", "Why Fin flagged churn risk."),
        "Expansion_Signal__c": txt("Expansion Signal", "Growth the customer mentioned, e.g. a new location."),
        "Fin_Sentiment__c": pick("Sentiment", "Customer sentiment, set by Fin.", SENTIMENT, restricted=False),
        "Fin_Location__c": txt("Location", "Location the conversation was about."),
        "Fin_Actions_Taken__c": txt("Fin Actions Taken", "What Fin did for the customer before handoff, e.g. a Procedure it ran."),
        "Retention_Offer__c": pick("Offer Accepted", "Program or retention offer the customer accepted (set from Support Tools).",
                                   ["New Location Launch Program", "Budget shift", "90-day pause", "Performance credit",
                                    "Free ads review", "None - location cancelled"], restricted=False),
        "Resolution_Notes__c": lta("Resolution Notes", "How the agent resolved the case.", 4),
        "Fin_CSAT__c": num("CSAT", "Conversation rating, 1 to 5.", 1, 0),
        "Conversation_Date__c": date("Conversation Date", "Date of the Fin conversation."),
        "Part2_Demo__c": chk("Keep & Grow demo record", "Created by the Keep & Grow demo seed."),
    },
    "Account": {
        "Churn_Risk__c": pick("Churn Risk", "Latest churn risk Fin flagged for this account.", RISK, restricted=False),
        "Churn_Risk_Reason__c": txt("Churn Risk Reason", "Why Fin flagged churn risk."),
        "Expansion_Signal__c": txt("Expansion Signal", "Growth the customer mentioned to Fin."),
        "Fin_Sentiment__c": pick("Sentiment", "Sentiment in the latest Fin conversation.", SENTIMENT, restricted=False),
        "Last_Fin_Conversation__c": dtm("Last Fin Conversation", "When the customer last talked to Fin."),
        "Monthly_Budget_Cap__c": cur("Monthly Budget Cap", "Monthly ad budget cap for this location."),
        "Budget_Spent_MTD__c": cur("Budget Spent (MTD)", "Ad budget spent this month."),
        "Budget_Status__c": pick("Budget Status", "Whether this location's ads are running.",
                                 ["Active", "Paused - Budget Cap Reached", "Paused - Customer Request", "Cancelled"],
                                 restricted=False),  # not restricted: Account record types don't list the newer values
        "Paused_Until__c": date("Paused Until", "When a paused location's ads restart."),
        "Leads_Last_30_Days__c": num("Leads (Last 30 Days)", "Leads this location received in the last 30 days."),
        "Cost_Per_Lead__c": cur("Cost per Lead", "Ad spend divided by leads, last 30 days."),
        "Renewal_Date__c": date("Renewal Date", "When the customer's annual Yelp agreement renews."),
        "Annual_Ad_Spend__c": cur("Annual Ad Spend", "Ad spend across all locations over the last 12 months."),
        "Customer_Since__c": date("Customer Since", "When the account became a Yelp Ads customer."),
        "Part2_Demo__c": chk("Keep & Grow demo record", "Created by the Keep & Grow demo seed."),
    },
    "Opportunity": {
        "Part2_Demo__c": chk("Keep & Grow demo record", "Created by the Keep & Grow demo seed or Flow."),
    },
}

TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>{name}</fullName>
    <label>{label}</label>
    <description>{desc}</description>
    <inlineHelpText>{desc}</inlineHelpText>
    {body}
</CustomField>
"""

perms = []
for obj, fields in FIELDS.items():
    d = os.path.join(ROOT, "objects", obj, "fields")
    os.makedirs(d, exist_ok=True)
    for name, (body, label, desc) in fields.items():
        with open(os.path.join(d, f"{name}.field-meta.xml"), "w") as f:
            f.write(TEMPLATE.format(name=name, label=label, desc=desc, body=body))
        perms.append(f"    <fieldPermissions><editable>true</editable><field>{obj}.{name}</field>"
                     f"<readable>true</readable></fieldPermissions>")

# Formula fields (hand-written below and in objects/Case/fields) are read-only
perms += [f"    <fieldPermissions><editable>false</editable><field>Case.{f}</field><readable>true</readable></fieldPermissions>"
          for f in ("Fin_Resolved__c", "Fin_CSAT_Positive__c")]
FORMULAS = {
    "Renewal_Likelihood__c": ("Likelihood to Renew", "Renewal likelihood score (0-100), lowered by churn risk Fin flags.",
                              "<type>Number</type><precision>4</precision><scale>1</scale>",
                              "IF(ISPICKVAL(Churn_Risk__c, \"High\"), 58.4, IF(ISPICKVAL(Churn_Risk__c, \"Medium\"), 71.2, "
                              "IF(OR(ISPICKVAL(Fin_Sentiment__c, \"Slightly Negative\"), ISPICKVAL(Fin_Sentiment__c, \"Negative\")), 74.6, 79.5)))"),
    "Renewal_Outlook__c": ("Renewal Outlook", "Renewal outlook from the latest churn risk Fin flagged.",
                           "<type>Text</type>",
                           "IF(ISPICKVAL(Churn_Risk__c, \"High\"), \"At risk\", IF(ISPICKVAL(Churn_Risk__c, \"Medium\"), \"Watch\", "
                           "IF(OR(ISPICKVAL(Fin_Sentiment__c, \"Slightly Negative\"), ISPICKVAL(Fin_Sentiment__c, \"Negative\")), \"Likely, watch value\", \"Likely\")))"),
    "Budget_Used_Pct__c": ("Budget Used (MTD)", "Share of this month's ad budget spent, across all locations.",
                           "<type>Number</type><precision>3</precision><scale>0</scale>",
                           "IF(OR(ISBLANK(Monthly_Budget_Cap__c), Monthly_Budget_Cap__c = 0), 0, ROUND(Budget_Spent_MTD__c / Monthly_Budget_Cap__c * 100, 0))"),
}
for name, (label, desc, typ, formula) in FORMULAS.items():
    with open(os.path.join(ROOT, "objects", "Account", "fields", f"{name}.field-meta.xml"), "w") as f:
        f.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>{name}</fullName>
    <label>{label}</label>
    <description>{desc}</description>
    <formula>{formula.replace('"', '&quot;')}</formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
    {typ}
</CustomField>
""")
    perms.append(f"    <fieldPermissions><editable>false</editable><field>Account.{name}</field><readable>true</readable></fieldPermissions>")
perms.append("    <fieldPermissions><editable>true</editable><field>MessagingSession.Fin_Case__c</field><readable>true</readable></fieldPermissions>")
perms += [f"    <fieldPermissions><editable>true</editable><field>Yelp_Fin_Api_Log__c.{f}</field><readable>true</readable></fieldPermissions>"
          for f in ("Endpoint__c", "Method__c", "Status__c", "Detail__c")]
perms.append("    <objectPermissions><allowCreate>true</allowCreate><allowDelete>true</allowDelete><allowEdit>true</allowEdit>"
             "<allowRead>true</allowRead><modifyAllRecords>true</modifyAllRecords><object>Yelp_Fin_Api_Log__c</object>"
             "<viewAllRecords>true</viewAllRecords></objectPermissions>")

os.makedirs(os.path.join(ROOT, "permissionsets"), exist_ok=True)
with open(os.path.join(ROOT, "permissionsets", "Yelp_Keep_Grow.permissionset-meta.xml"), "w") as f:
    f.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Yelp Keep and Grow Demo</label>
    <description>Access to Fin handoff, churn and expansion fields for the Yelp Keep and Grow demo.</description>
    <hasActivationRequired>false</hasActivationRequired>
{chr(10).join(perms)}
</PermissionSet>
""")
print({k: len(v) for k, v in FIELDS.items()})
