/**
 * Public API for the real Fin AI Agent (Keep and Grow demo), served from the "Yelp Fin API" Salesforce Site.
 *
 *   GET  /yelp/account?email=...                        locations, budgets, status, leads (data connector)
 *   POST /yelp/budget   {"email","location","monthly_cap"}  raise a location's monthly cap (data connector)
 *   GET  /yelp/invoice?email=...                        latest invoice and what changed (data connector)
 *   GET  /yelp/messenger-token                          signed Messenger JWT for the demo customer (help page)
 *   GET  /yelp/status                                   location ad status for the demo customer (help page panel)
 *   POST /yelp/signals  {"email","conversation_id","contact_reason","churn_risk","sentiment","expansion_signal"}
 *                       Fin's conversation attributes for a live handoff (data connector); fills the handoff case
 *
 * Data connector calls must send the X-Yelp-Fin-Key header (Yelp_Fin_Api__mdt.Default.Api_Key__c).
 * Only Keep and Grow demo accounts (Part2_Demo__c) are visible or editable.
 */
@RestResource(urlMapping='/yelp/*')
global without sharing class YelpFinApi {
    @TestVisible static final String DEMO_EMAIL = 'sam@whitakerhospitality.example.com';

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        String path = req.requestURI.substringAfter('/yelp/');
        try {
            if (path.startsWith('messenger-token')) {
                respond(200, messengerToken());
                return;
            }
            if (path.startsWith('status')) {
                respond(200, status());
                return;
            }
            requireKey(req);
            String email = req.params.get('email');
            if (path.startsWith('account')) {
                respond(200, account(email));
            } else if (path.startsWith('invoice')) {
                respond(200, invoice(email));
            } else {
                respond(404, new Map<String, Object>{ 'error' => 'Unknown endpoint' });
            }
        } catch (ApiException e) {
            respond(e.status, new Map<String, Object>{ 'error' => e.getMessage() });
        }
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        try {
            requireKey(req);
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            if (req.requestURI.substringAfter('/yelp/').startsWith('signals')) {
                respond(200, signals(body));
                return;
            }
            respond(200, raiseCap((String) body.get('email'), (String) body.get('location'), body.get('monthly_cap')));
        } catch (ApiException e) {
            respond(e.status, new Map<String, Object>{ 'error' => e.getMessage() });
        } catch (Exception e) {
            respond(400, new Map<String, Object>{ 'error' => 'Bad request: ' + e.getMessage() });
        }
    }

    // ---- Endpoints ----------------------------------------------------------------------------------------
    @TestVisible
    static Map<String, Object> account(String email) {
        Account a = parentFor(email);
        List<Map<String, Object>> locs = new List<Map<String, Object>>();
        for (Account l : locations(a.Id)) {
            locs.add(new Map<String, Object>{
                'location' => l.Name, 'brand' => l.Brand__c, 'monthly_cap' => l.Monthly_Budget_Cap__c,
                'spent_this_month' => l.Budget_Spent_MTD__c, 'leads_last_30_days' => l.Leads_Last_30_Days__c,
                'cost_per_lead' => l.Cost_Per_Lead__c, 'ad_status' => statusText(l),
                'paused_reason' => l.Budget_Status__c == 'Active' ? null : l.Budget_Status__c
            });
        }
        return new Map<String, Object>{
            'business' => a.Name, 'active_locations' => locs.size(), 'annual_ad_spend' => a.Annual_Ad_Spend__c,
            'renewal_date' => String.valueOf(a.Renewal_Date__c), 'locations' => locs,
            'budget_cap_resets_on' => String.valueOf(Date.today().toStartOfMonth().addMonths(1))
        };
    }

    @TestVisible
    static Map<String, Object> raiseCap(String email, String location, Object capValue) {
        Account a = parentFor(email);
        if (String.isBlank(location) || capValue == null) {
            throw new ApiException(400, 'location and monthly_cap are required');
        }
        Decimal cap = Decimal.valueOf(String.valueOf(capValue).replaceAll('[^0-9.]', ''));
        Account loc;
        for (Account l : locations(a.Id)) {
            if (l.Name.toLowerCase().contains(location.toLowerCase().trim())) {
                loc = l;
            }
        }
        if (loc == null) {
            throw new ApiException(404, 'No location matching "' + location + '" on this account');
        }
        Decimal previous = loc.Monthly_Budget_Cap__c;
        if (cap <= 0 || cap > 10000) {
            throw new ApiException(400, 'monthly_cap must be between 1 and 10,000');
        }
        loc.Monthly_Budget_Cap__c = cap;
        if (loc.Budget_Status__c == 'Paused - Budget Cap Reached' && cap > (loc.Budget_Spent_MTD__c == null ? 0 : loc.Budget_Spent_MTD__c)) {
            loc.Budget_Status__c = 'Active';
        }
        update loc;
        return new Map<String, Object>{
            'location' => loc.Name, 'previous_monthly_cap' => previous, 'new_monthly_cap' => cap,
            'ad_status' => statusText(loc), 'ads_resume' => loc.Budget_Status__c == 'Active' ? 'within 15 minutes' : null
        };
    }

    // Live handoff: Fin doesn't send its custom attributes with the chat, so a data connector posts them here.
    // The call is logged (Yelp_Fin_Api_Log__c, endpoint "signals"); the routing Flow reads that log when the chat
    // arrives later, and if the handoff case already exists, it's filled in now.
    @TestVisible
    static Map<String, Object> signals(Map<String, Object> body) {
        Contact c = demoContact((String) body.get('email'));
        Case cs = YelpFinSignals.openHandoffCase(c.Id, str(body.get('conversation_id')));
        if (cs != null) {
            YelpFinSignals.apply(cs, str(body.get('contact_reason')), str(body.get('churn_risk')), str(body.get('sentiment')), str(body.get('expansion_signal')));
            update cs;
        }
        return new Map<String, Object>{ 'received' => true, 'case' => cs == null ? null : cs.CaseNumber,
            'note' => cs == null ? 'Saved; applied when the chat reaches Salesforce' : 'Applied to the handoff case' };
    }

    static String str(Object o) {
        String s = o == null ? null : String.valueOf(o).trim();
        // Unfilled template placeholders count as blank
        return String.isBlank(s) || s.startsWith('{{') ? null : s;
    }

    @TestVisible
    static Map<String, Object> invoice(String email) {
        Account a = parentFor(email);
        // Demo billing data: the September invoice and what changed from August.
        return new Map<String, Object>{
            'business' => a.Name, 'invoice_number' => 'INV-2026-09-4471', 'period' => 'September 2026',
            'charged_on' => '2026-10-01', 'total' => 9980, 'previous_total' => 9450, 'change' => 530,
            'changes' => new List<Object>{
                new Map<String, Object>{ 'location' => 'Dave\'s Hot Chicken - Westminster', 'item' => 'Monthly ad budget cap raised from $800 to $1,200 on Sep 1', 'amount' => 400 },
                new Map<String, Object>{ 'location' => 'Dave\'s Hot Chicken - Colorado Springs (Powers)', 'item' => 'Yelp Page Upgrade added on Aug 29', 'amount' => 130 }
            },
            'note' => 'Everything else matched August.'
        };
    }

    // Public, demo customer only: location names and whether their ads are running (no budgets or leads).
    @TestVisible
    static Map<String, Object> status() {
        Account a = parentFor(DEMO_EMAIL);
        List<Map<String, Object>> locs = new List<Map<String, Object>>();
        for (Account l : locations(a.Id)) {
            locs.add(new Map<String, Object>{ 'location' => l.Name, 'running' => l.Budget_Status__c == null || l.Budget_Status__c == 'Active', 'ad_status' => statusText(l) });
        }
        return new Map<String, Object>{ 'business' => a.Name, 'locations' => locs };
    }

    @TestVisible
    static Map<String, Object> messengerToken() {
        Yelp_Fin_Api__mdt cfg = config();
        String secret = cfg == null ? null : cfg.Messenger_Secret__c;
        if (String.isBlank(secret)) {
            // Also accept the secret entered as the field's default value in Setup
            String dv = Yelp_Fin_Api__mdt.Messenger_Secret__c.getDescribe().getDefaultValueFormula();
            secret = dv == null ? null : dv.trim().removeStart('"').removeEnd('"').removeStart('\'').removeEnd('\'');
        }
        if (String.isBlank(secret)) {
            throw new ApiException(503, 'Messenger secret not set');
        }
        Contact c = demoContact(DEMO_EMAIL);
        // The demo reset sets a new user ID, so the Messenger opens with no past conversations
        String userId = String.isBlank(c.Fin_Messenger_User_Id__c) ? String.valueOf(c.Id) : c.Fin_Messenger_User_Id__c;
        Long exp = Datetime.now().addHours(4).getTime() / 1000;
        String header = b64url(Blob.valueOf('{"alg":"HS256","typ":"JWT"}'));
        String payload = b64url(Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'user_id' => userId, 'email' => c.Email, 'name' => c.FirstName + ' ' + c.LastName, 'exp' => exp
        })));
        String sig = b64url(Crypto.generateMac('HmacSHA256', Blob.valueOf(header + '.' + payload), Blob.valueOf(secret)));
        return new Map<String, Object>{
            'token' => header + '.' + payload + '.' + sig, 'user_id' => userId, 'email' => c.Email,
            'name' => c.FirstName + ' ' + c.LastName, 'company' => c.Account.Name
        };
    }

    // ---- Helpers ------------------------------------------------------------------------------------------
    static void requireKey(RestRequest req) {
        Yelp_Fin_Api__mdt cfg = config();
        String key;
        for (String h : req.headers.keySet()) {
            if (h.equalsIgnoreCase('X-Yelp-Fin-Key')) key = req.headers.get(h);
        }
        if (cfg == null || String.isBlank(cfg.Api_Key__c) || key != cfg.Api_Key__c) {
            throw new ApiException(401, 'Missing or invalid X-Yelp-Fin-Key');
        }
    }

    static Yelp_Fin_Api__mdt config() {
        List<Yelp_Fin_Api__mdt> rows = [SELECT Api_Key__c, Messenger_Secret__c FROM Yelp_Fin_Api__mdt WHERE DeveloperName = 'Default' LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    static Contact demoContact(String email) {
        if (String.isBlank(email)) {
            throw new ApiException(400, 'email is required');
        }
        List<Contact> cs = [
            SELECT Id, FirstName, LastName, Email, AccountId, Account.Name, Fin_Messenger_User_Id__c FROM Contact
            WHERE Email = :email.trim() AND Account.Part2_Demo__c = true LIMIT 1
        ];
        if (cs.isEmpty()) {
            throw new ApiException(404, 'No account found for ' + email);
        }
        return cs[0];
    }

    static Account parentFor(String email) {
        Contact c = demoContact(email);
        return [SELECT Id, Name, Annual_Ad_Spend__c, Renewal_Date__c FROM Account WHERE Id = :c.AccountId];
    }

    static List<Account> locations(Id parentId) {
        return [
            SELECT Id, Name, Brand__c, Monthly_Budget_Cap__c, Budget_Spent_MTD__c, Leads_Last_30_Days__c,
                   Cost_Per_Lead__c, Budget_Status__c
            FROM Account WHERE ParentId = :parentId ORDER BY Name
        ];
    }

    static String statusText(Account l) {
        if (l.Budget_Status__c == null || l.Budget_Status__c == 'Active') return 'Running';
        if (l.Budget_Status__c == 'Paused - Budget Cap Reached') return 'Paused: monthly budget cap reached';
        return l.Budget_Status__c;
    }

    // Troubleshooting: record each call (never the key or token)
    static void log(Integer status, Object body) {
        try {
            RestRequest req = RestContext.request;
            String path = req.requestURI == null ? '' : req.requestURI.substringAfter('/yelp/');
            if (path.startsWith('status') || path.startsWith('messenger-token')) return;
            String detail = 'params=' + JSON.serialize(req.params);
            if (req.requestBody != null && req.requestBody.size() > 0) detail += '\nbody=' + req.requestBody.toString().left(2000);
            detail += '\nresponse=' + JSON.serialize(body).left(4000);
            insert new Yelp_Fin_Api_Log__c(Endpoint__c = path.left(80), Method__c = req.httpMethod, Status__c = status, Detail__c = detail);
        } catch (Exception e) { /* logging must never break the API */ }
    }

    static String b64url(Blob b) {
        return EncodingUtil.base64Encode(b).replace('+', '-').replace('/', '_').replace('=', '');
    }

    static void respond(Integer status, Object body) {
        log(status, body);
        RestResponse res = RestContext.response;
        res.statusCode = status;
        res.addHeader('Content-Type', 'application/json');
        res.addHeader('Access-Control-Allow-Origin', '*');
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    public class ApiException extends Exception {
        public Integer status;
        public ApiException(Integer status, String message) {
            this(message);
            this.status = status;
        }
    }
}
