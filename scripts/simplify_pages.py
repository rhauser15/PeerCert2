"""Simplify the Part 2 (Keep and Grow) account and opportunity pages: hide components on Part 2 records only and
move the Yelp sections. Other records keep the original pages. Safe to run more than once."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from page_tools import only_when, PART2  # noqa: E402

BASE = os.path.join(os.path.dirname(__file__), "..", "force-app", "main", "default", "flexipages")


def item(s, ident):
    m = re.search(r"        <itemInstances>\n(?:(?!        </itemInstances>).)*?<identifier>" + re.escape(ident)
                  + r"</identifier>.*?        </itemInstances>\n", s, re.S)
    if not m:
        sys.exit(f"not found: {ident}")
    # Start at the last <itemInstances> before the identifier
    start = s.rfind("        <itemInstances>\n", 0, s.index(f"<identifier>{ident}</identifier>"))
    end = s.index("        </itemInstances>\n", start) + len("        </itemInstances>\n")
    return start, end


def hide_on_part2(s, ident):
    a, b = item(s, ident)
    return s[:a] + only_when(s[a:b], "false") + s[b:]


def move_after(s, ident, after_ident):
    """Move a component to just after another one in the same region (no-op if already there)."""
    a, b = item(s, ident)
    block = s[a:b]
    s = s[:a] + s[b:]
    x, y = item(s, after_ident)
    return s[:y] + block + s[y:]


def move_to_region_end(s, ident, region):
    a, b = item(s, ident)
    block = s[a:b]
    s = s[:a] + s[b:]
    r = s.index(f"        <name>{region}</name>")
    return s[:r] + block + s[r:]


def edit(name, fn):
    p = os.path.join(BASE, name)
    s = open(p).read()
    s = fn(s)
    open(p, "w").write(s)
    print("updated", name)


def account(s):
    # Details: Account Information first, then Fin Signals, then the Yelp Ads Performance card (both Part 2 only)
    s = move_after(s, "flexipage_fieldSection_fin", "flexipage_fieldSection")
    s = move_after(s, "c_yelpAccountMetrics", "flexipage_fieldSection_fin")
    for ident in ("flexipage_fieldSection4", "flexipage_fieldSection7", "flexipage_fieldSection8",  # FS, Prediction, Additional
                  "flexipage_tab5", "flexipage_tab13", "flexipage_tab10", "flexipage_tab14",  # Partners, Success, Service, Account Plan
                  "force_relatedListSingleContainer7", "force_relatedListSingleContainer5",  # Sales tab: Account Plans, Quotes
                  "force_relatedListSingleContainer6"):  # DSRs
        s = hide_on_part2(s, ident)
    return s


def opportunity(s):
    for ident in ("c_techSalesOsmiPanel1",  # Sales methodology panel (errors in this org: no OppSalesMethodology)
                  "flexipage_fieldSection2", "flexipage_fieldSection3", "flexipage_fieldSection5",  # Opp info, Marketing, Einstein
                  "flexipage_tab3", "flexipage_tab8", "flexipage_tab9",  # Predicted Win Rate, Predicted Upsell, Commission
                  "flexipage_tab11", "flexipage_tab12"):  # MEDDIC, Coach
        s = hide_on_part2(s, ident)
    # Locations (Yelp Ads Performance) at the bottom of the Details tab instead of under the path
    if "<name>subheader</name>" in s and s.index("<identifier>c_yelpAccountMetrics</identifier>") < s.index("<name>subheader</name>"):
        s = move_to_region_end(s, "c_yelpAccountMetrics", "Facet-16889563-b79e-48b7-8393-835e9332bac8")
    return s


if __name__ == "__main__":
    edit("Tech_Account_Data_Cloud_3_Panel.flexipage-meta.xml", account)
    edit("Tech_Opportunity_Default.flexipage-meta.xml", opportunity)
