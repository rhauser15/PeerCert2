"""Generates the Keep & Grow reports and Alisha's CS dashboard (Fin conversations synced to Salesforce)."""
import os

BASE = os.path.join(os.path.dirname(__file__), "..", "force-app", "main", "default")
FOLDER = "Yelp_Keep_and_Grow"
RUNNING_USER = "trailsignup.429cdfd78ec835@salesforce.com"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n' + text.strip() + "\n")


def crit(col, op, val):
    return (f"<criteriaItems><column>{col}</column><columnToColumn>false</columnToColumn><isUnlocked>true</isUnlocked>"
            f"<operator>{op}</operator><value>{val}</value></criteriaItems>")


def report(name, label, rtype, cols, criteria, group, date_col="CREATED_DATE", desc="", formulas=(),
           granularity="Day", logic=None, fmt="Summary", sort=None):
    columns = "".join(
        f"<columns>{''.join(f'<aggregateTypes>{a}</aggregateTypes>' for a in aggs)}<field>{c}</field></columns>"
        for c, aggs in cols)
    aggs = "".join(
        f"<aggregates><calculatedFormula>{f}</calculatedFormula><datatype>percent</datatype><developerName>{dev}</developerName>"
        f"<isActive>true</isActive><isCrossBlock>false</isCrossBlock><masterLabel>{lbl}</masterLabel><scale>0</scale></aggregates>"
        for dev, lbl, f in formulas)
    grouping = (f"<groupingsDown><dateGranularity>{granularity}</dateGranularity><field>{group}</field>"
                f"<sortOrder>Asc</sortOrder></groupingsDown>") if group else ""
    timeframe = (f"<timeFrameFilter><dateColumn>{date_col}</dateColumn><interval>INTERVAL_CUSTOM</interval></timeFrameFilter>"
                 if date_col else "")
    boolean = f"<booleanFilter>{logic}</booleanFilter>" if logic else ""
    sorting = f"<sortColumn>{sort}</sortColumn><sortOrder>Desc</sortOrder>" if sort else ""
    write(os.path.join(BASE, "reports", FOLDER, f"{name}.report-meta.xml"), f"""
<Report xmlns="http://soap.sforce.com/2006/04/metadata">
    {aggs}
    {columns}
    <description>{desc}</description>
    <filter>{boolean}{''.join(crit(*c) for c in criteria)}</filter>
    <format>{fmt}</format>
    {grouping}
    <name>{label}</name>
    <params><name>units</name><value>h</value></params>
    <reportType>{rtype}</reportType>
    <scope>organization</scope>
    <showDetails>true</showDetails>
    <showGrandTotal>true</showGrandTotal>
    <showSubTotals>true</showSubTotals>
    {sorting}
    {timeframe}
</Report>""")


FIN = [("Case.FinInvolved__c", "equals", "1")]
RATE = [("FORMULA1", "Fin Resolution Rate", "Case.Fin_Resolved__c:SUM/RowCount")]
report("Fin_Resolution_Rate", "Fin: Resolution Rate", "CaseList",
       [("Case.Fin_Resolved__c", ["Sum"]), ("SUBJECT", []), ("ACCOUNT.NAME", [])], FIN, "Case.Conversation_Date__c",
       desc="Share of Fin conversations Fin resolved (hard or soft), by week.", formulas=RATE, granularity="Week")
report("Fin_Resolution_State", "Fin: How Conversations Ended", "CaseList",
       [("SUBJECT", []), ("ACCOUNT.NAME", [])], FIN, "Case.FinResolutionState__c",
       desc="Fin conversations by resolution state.")
report("Fin_CSAT_Trend", "Fin: CSAT by Week", "CaseList",
       [("Case.Fin_CSAT_Positive__c", ["Average"]), ("Case.Fin_CSAT__c", ["Average"]), ("SUBJECT", [])],
       FIN + [("Case.Fin_CSAT__c", "notEqual", "")], "Case.Conversation_Date__c",
       desc="Share of rated conversations that scored 4 or 5, by week.", granularity="Week",
       formulas=[("FORMULA1", "CSAT (4 or 5)", "Case.Fin_CSAT_Positive__c:AVG")])
report("Fin_Contact_Reasons", "Fin: Top Contact Reasons", "CaseList",
       [("SUBJECT", []), ("ACCOUNT.NAME", [])], FIN, "Case.Fin_Contact_Reason__c",
       desc="What customers contact Yelp about, as tagged by Fin.")
report("Fin_Flagged_Accounts", "Fin: Accounts Flagged in Conversations", "AccountList",
       [("ACCOUNT.NAME", []), ("Account.Churn_Risk_Reason__c", []), ("Account.Expansion_Signal__c", []),
        ("Account.Last_Fin_Conversation__c", []), ("USERS.NAME", [])],
       [("Account.Part2_Demo__c", "equals", "1"), ("Account.Churn_Risk__c", "equals", "High,Medium"),
        ("Account.Expansion_Signal__c", "notEqual", "")],
       "Account.Churn_Risk__c", date_col=None, logic="1 AND (2 OR 3)",
       desc="Customers Fin flagged for churn risk or expansion from their conversations.")

report("Fin_Retention_Offers", "Fin Handoffs: Retention Offers Accepted", "CaseList",
       [("SUBJECT", []), ("ACCOUNT.NAME", [])], FIN + [("Case.Retention_Offer__c", "notEqual", "")], "Case.Retention_Offer__c",
       desc="How agents resolved the cancel and performance cases Fin handed off.")

write(os.path.join(BASE, "reports", f"{FOLDER}.reportFolder-meta.xml"), """
<ReportFolder xmlns="http://soap.sforce.com/2006/04/metadata">
    <accessType>Public</accessType><name>Yelp Keep and Grow</name><publicFolderAccess>ReadWrite</publicFolderAccess>
</ReportFolder>""")
write(os.path.join(BASE, "dashboards", f"{FOLDER}_Dashboards.dashboardFolder-meta.xml"), """
<DashboardFolder xmlns="http://soap.sforce.com/2006/04/metadata">
    <accessType>Public</accessType><name>Yelp Keep and Grow Dashboards</name><publicFolderAccess>ReadWrite</publicFolderAccess>
</DashboardFolder>""")


def comp(ctype, rep, title, header, col, row, cs, rs, extra=""):
    units = "" if ctype == "FlexTable" else "<displayUnits>Auto</displayUnits>"
    return f"""
        <dashboardGridComponents>
            <colSpan>{cs}</colSpan><columnIndex>{col}</columnIndex>
            <dashboardComponent>
                <autoselectColumnsFromReport>false</autoselectColumnsFromReport>
                {extra}
                <componentType>{ctype}</componentType>
                {units}
                <groupingSortProperties/>
                <header>{header}</header>
                <report>{FOLDER}/{rep}</report>
                <showRange>false</showRange>
                <title>{title}</title>
            </dashboardComponent>
            <rowIndex>{row}</rowIndex><rowSpan>{rs}</rowSpan>
        </dashboardGridComponents>"""


CHART = ("<chartAxisRange>Auto</chartAxisRange><enableHover>true</enableHover><legendPosition>Bottom</legendPosition>"
         "<showPercentage>false</showPercentage><showValues>true</showValues><useReportChart>false</useReportChart>")
GREEN = ("<indicatorBreakpoint1>1.0</indicatorBreakpoint1><indicatorBreakpoint2>2.0</indicatorBreakpoint2>"
         "<indicatorHighColor>#04844B</indicatorHighColor><indicatorLowColor>#04844B</indicatorLowColor>"
         "<indicatorMiddleColor>#04844B</indicatorMiddleColor>")
ROWS = "<chartSummary><axisBinding>y</axisBinding><column>RowCount</column></chartSummary>"
F1 = "<chartSummary><axisBinding>y</axisBinding><column>FORMULA1</column></chartSummary>"
comps = "".join([
    comp("Metric", "Fin_Resolution_Rate", "Of all Fin conversations, last 8 weeks", "Fin resolution rate", 0, 0, 3, 6, F1 + GREEN),
    comp("Metric", "Fin_CSAT_Trend", "Rated 4 or 5, last 8 weeks", "CSAT", 3, 0, 3, 6, F1 + GREEN),
    comp("Metric", "Fin_Contact_Reasons", "Handled by Fin, last 8 weeks", "Fin conversations", 6, 0, 3, 6, ROWS + GREEN),
    comp("Metric", "Fin_Flagged_Accounts", "Churn risk or expansion signal", "Accounts flagged by Fin", 9, 0, 3, 6, ROWS + GREEN),
    comp("Line", "Fin_Resolution_Rate", "Conversations Fin resolved, by week", "Fin resolution rate trend", 0, 6, 6, 8,
         CHART + F1 + "<groupingColumn>Case.Conversation_Date__c</groupingColumn><sortBy>RowLabelAscending</sortBy>"),
    comp("Line", "Fin_CSAT_Trend", "Ratings of 4 or 5, by week", "CSAT trend", 6, 6, 6, 8,
         CHART + F1 + "<groupingColumn>Case.Conversation_Date__c</groupingColumn><sortBy>RowLabelAscending</sortBy>"),
    comp("Bar", "Fin_Contact_Reasons", "What customers ask Fin about", "Top contact reasons", 0, 14, 5, 9,
         CHART + ROWS + "<groupingColumn>Case.Fin_Contact_Reason__c</groupingColumn><sortBy>RowValueDescending</sortBy>"),
    comp("FlexTable", "Fin_Flagged_Accounts", "Churn risk and expansion, from Fin", "At-risk and growing accounts", 5, 14, 7, 9,
         "<flexComponentProperties><flexTableColumn><reportColumn>ACCOUNT.NAME</reportColumn><showSubTotal>false</showSubTotal><showTotal>false</showTotal><type>detail</type></flexTableColumn>"
         "<flexTableColumn><reportColumn>Account.Churn_Risk__c</reportColumn><showSubTotal>false</showSubTotal><showTotal>false</showTotal><type>grouping</type></flexTableColumn>"
         "<flexTableColumn><reportColumn>Account.Churn_Risk_Reason__c</reportColumn><showSubTotal>false</showSubTotal><showTotal>false</showTotal><type>detail</type></flexTableColumn>"
         "<flexTableColumn><reportColumn>Account.Expansion_Signal__c</reportColumn><showSubTotal>false</showSubTotal><showTotal>false</showTotal><type>detail</type></flexTableColumn>"
         "<flexTableColumn><reportColumn>USERS.NAME</reportColumn><showSubTotal>false</showSubTotal><showTotal>false</showTotal><type>detail</type></flexTableColumn>"
         "<flexTableSortInfo><sortColumn>Account.Churn_Risk__c</sortColumn><sortOrder>1</sortOrder></flexTableSortInfo><hideChatterPhotos>true</hideChatterPhotos></flexComponentProperties>"),
    comp("Donut", "Fin_Retention_Offers", "How agents resolved Fin handoffs", "Retention offers accepted", 0, 23, 5, 9,
         CHART + ROWS + "<groupingColumn>Case.Retention_Offer__c</groupingColumn><sortBy>RowValueDescending</sortBy>"),
])
write(os.path.join(BASE, "dashboards", f"{FOLDER}_Dashboards", "Keep_and_Grow_CS.dashboard-meta.xml"), f"""
<Dashboard xmlns="http://soap.sforce.com/2006/04/metadata">
    <backgroundEndColor>#FFFFFF</backgroundEndColor>
    <backgroundFadeDirection>Diagonal</backgroundFadeDirection>
    <backgroundStartColor>#FFFFFF</backgroundStartColor>
    <chartTheme>light</chartTheme>
    <colorPalette>unity</colorPalette>
    <dashboardChartTheme>light</dashboardChartTheme>
    <dashboardColorPalette>unity</dashboardColorPalette>
    <dashboardGridLayout>{comps}
        <numberOfColumns>12</numberOfColumns>
        <rowHeight>36</rowHeight>
    </dashboardGridLayout>
    <dashboardType>SpecifiedUser</dashboardType>
    <description>Alisha's view: how Fin is resolving, how customers rate it, what they ask about, and which accounts Fin flagged.</description>
    <isGridLayout>true</isGridLayout>
    <runningUser>{RUNNING_USER}</runningUser>
    <textColor>#000000</textColor>
    <title>Customer Success: Fin Conversations</title>
    <titleColor>#000000</titleColor>
    <titleSize>12</titleSize>
</Dashboard>""")
print("ok")
