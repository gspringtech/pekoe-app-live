xquery version "3.0";
(:
For JSON see p123 of the book (pdf 146)
<container json:array="true"><thing>a</thing></container>
[{thing : 'a'}]

    Multi-tenancy.
    http://docs.stormpath.com/guides/multi-tenant/
    "   So if an application needs this identifier with every request, how do you ensure it is transmitted
        to the application in the easiest possible way for your end users?
        The three most common ways are to use one or more of the following:
       
        Subdomain Name
        Tenant Selection After Login
        Login Form Field
    "
    I'd like to use the first one - but use the second two for special users such as myself
    or other Admin staff.
    
    The first approach is easy:
    cm.pekoe.io -> /db/pekoe/clients/cm
    bkfa.pekoe.io -> /db/pekoe/clients/bkfa
    
    OR 
    cm.pekoe.io -> 
    
    The next step with this is to ensure that a user-group is created for the tenant 
    cm-staff
    cm-admin
    or staff-cm, admin-cm
    
    Get domain (or selected tenant)
    Current user must belong to one of the groups.
    
    Make sure this doesn't conflict with my namespaces. e.g. http://pekoe.io/user-prefs
    
    "If a user from a customer organization ever accesses your app directly (https://mycompany.io) 
    instead of using their subdomain (https://customerA.mycompany.io), 
    you still might need to provide a tenant-aware login form (described below). 
    After login, you can redirect them to their tenant-specific url for all subsequent requests."
    
    They recommend using surrogate and natural KEYs e.g. customerA -> 19C2C28D-0CC6-4FD1-B5BC-84F8E7A8E92D (an UUID)
    to allow the customer name to be changed. 
    I'm using collections - so the advantage of this is limited. 
    /db/pekoe/clients/cm
    /db/pekoe/clients/bkfa
    
    pekoe-user -> CAN LOGIN
    <uuid>-staff -> member of /tenants/tenant[@id = <uuid>] group
    
    If I use a surrogate key, I'll have to look it up all the time to perform any under-the-hood actions. Plus they're long and ugly.
    However, in my CODE, the tenant-id should be abstract and not concern me. 
    
    I'd rather NOT use a surrogate in the User database.
    
    Content will need to be owned by the tenant
    group cm-staff
    
    see http://expath.org/spec/http-client for info on http:response
    
    <http:response status = integer
                  message = string>
   (http:header*,
     (http:multipart |
      http:body)?)
</http:response>                                                                                                                                                                                                                                                                                                                                                                                                                             
    
:)

module namespace prefs = "http://pekoe.io/user-prefs";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "tenants.xql";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(: If you get here and there's no subdomain that's an error:)
declare variable $prefs:selected-tenant := req:header("tenant");
declare variable $prefs:tenant-path := "/db/pekoe/tenants/" || $prefs:selected-tenant ;


declare 
%rest:GET
%rest:path("/pekoe/user/bookmarks")
%output:media-type("application/xml")
function prefs:get-bookmarks() {
    (:    if there's no tenant set, return a tenant list    :)
    if (sm:has-access(xs:anyURI($prefs:tenant-path),'r--')) then prefs:bookmarks-for-user()
    else <rest:response>
            <http:response status="{$pekoe-http:HTTP-412-PRECONDITIONFAILED}">
                <http:header name="Location" value="/exist/restxq/pekoe/tenant"/>
            </http:response>
        </rest:response>
        
};

declare function prefs:bookmarks-for-user() {
    let $prefs-path := $prefs:tenant-path || "/config/users" (: e.g. /db/pekoe/cm/config/users :)
    let $default := doc($prefs-path || "/default.xml")//bookmarks
    let $current-user := xmldb:get-current-user()
    let $user := collection($prefs-path)/prefs[@for eq $current-user]/bookmarks
    
    let $prefs := ($user,$default)[1]
    let $debug := util:log("warn", concat("PREFS FOR USER: def",$default))
    return (<bookmarks for="{$current-user}" tenant="{$prefs:selected-tenant}">{$prefs/group}</bookmarks>)
};
