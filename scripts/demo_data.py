"""Demo data for the Keep & Grow (Fin) demo. The site's Fin Messenger quotes the same numbers (site/data.js)."""

SAM = {
    "first": "Sam", "last": "Whitaker", "title": "Owner / Franchisee",
    "email": "sam@whitakerhospitality.example.com", "phone": "(720) 555-0142",
}
COMPANY = "Whitaker Hospitality Group"

# (brand, location, monthly cap, spent MTD, leads last 30 days, cost per lead, status)
LOCATIONS = [
    ("Dave's Hot Chicken", "Aurora", 900, 900, 14, 64, "Paused - Budget Cap Reached"),
    ("Dave's Hot Chicken", "Lakewood", 1000, 812, 41, 24, "Active"),
    ("Dave's Hot Chicken", "Denver (Colfax)", 1100, 905, 44, 25, "Active"),
    ("Dave's Hot Chicken", "Westminster", 1200, 980, 39, 31, "Active"),
    ("Dave's Hot Chicken", "Littleton", 900, 730, 31, 29, "Active"),
    ("Dave's Hot Chicken", "Colorado Springs (Powers)", 1000, 801, 36, 28, "Active"),
    ("Dave's Hot Chicken", "Colorado Springs (North)", 800, 655, 27, 30, "Active"),
    ("Jersey Mike's Subs", "Lakewood", 700, 570, 30, 23, "Active"),
    ("Jersey Mike's Subs", "Arvada", 650, 520, 26, 25, "Active"),
    ("Jersey Mike's Subs", "Highlands Ranch", 700, 560, 28, 25, "Active"),
    ("Jersey Mike's Subs", "Colorado Springs", 600, 488, 22, 27, "Active"),
    ("Smoothie King", "Lakewood (Belmar)", 300, 245, 12, 25, "Active"),
]

RENEWAL = {"name": f"{COMPANY} - Annual Renewal", "amount": 119760, "close": "2026-12-31", "stage": "Discovery"}

# Other multi-location customers. (name, city, locations, churn risk, churn reason, expansion signal, sentiment)
CUSTOMERS = [
    ("Front Range Burger Co.", "Fort Collins", 8, "High", "Cost per lead up 40% at 3 locations; asked how to cancel", "", "Negative"),
    ("Summit Auto Spa", "Colorado Springs", 4, "High", "Disputed September invoice; mentioned a competitor", "", "Negative"),
    ("Mile High Fitness Group", "Denver", 6, "Medium", "Paused ads at 2 studios for the winter", "", "Neutral"),
    ("Rocky Mountain Pet Care", "Boulder", 5, "Low", "", "Opening a 6th clinic in Longmont in spring", "Positive"),
    ("Cherry Creek Salon Collective", "Denver", 3, "Low", "", "", "Positive"),
    ("Golden Hour Yoga", "Golden", 4, "Low", "", "", "Neutral"),
    ("Pikes Peak Plumbing & Air", "Colorado Springs", 3, "Medium", "Asked to lower budgets at every location", "", "Neutral"),
    ("Alpine Bagel Works", "Fort Collins", 5, "Low", "", "Adding catering to 3 locations", "Positive"),
    ("Tejon Street Tacos", "Colorado Springs", 4, "Low", "", "", "Positive"),
    ("Platte River Physical Therapy", "Littleton", 6, "Low", "", "", "Neutral"),
    ("Mountain View Car Wash", "Aurora", 7, "High", "Ads not showing for 2 weeks; frustrated with support", "", "Negative"),
    ("Highline Coffee Roasters", "Englewood", 4, "Low", "", "", "Positive"),
]

# Share of Fin conversations by contact reason (illustrative).
REASONS = [("Budget and billing", 28), ("Ad not showing", 22), ("Invoice question", 15), ("Ad performance", 14),
           ("Account access", 9), ("Add a location", 5), ("Cancel a location", 4), ("Other", 3)]

# Whitaker's open case Tom sees in the renewal brief.
OPEN_CASE = ("Photo removal request: Denver (Colfax)", "Ad performance")
