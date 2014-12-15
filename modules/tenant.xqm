xquery version "3.0";

module namespace tenant = "http://pekoe.io/tenant";
(:import module namespace req = "http://exquery.org/ns/request";:)

(: The Tenant info should probably be in the session !!! :)
(:declare variable $tenant:cookie := req:cookie("tenant");:)
(:declare variable $tenant:standard-request-cookie := request:get-cookie-value("tenant");:)
(:declare variable $tenant:accessible-cookie := if ($tenant:cookie) then $tenant:cookie else ""; (\:$tenant:standard-request-cookie;:\):)
declare variable $tenant:accessible-cookie := request:get-cookie-value("tenant");
declare variable $tenant:tenant := replace($tenant:accessible-cookie,"%22","");
declare variable $tenant:tenant-path := "/db/pekoe/tenants/" || $tenant:tenant;
