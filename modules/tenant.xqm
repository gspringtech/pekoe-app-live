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


(: Recursively apply ownership to a collection hierarchy :)
declare function tenant:fix-ownership($collection, $owner-name, $group-name) {
    sm:chown($collection,$owner-name),
    sm:chgrp($collection,$group-name),
    for $r in xmldb:get-child-resources($collection)
    let $resource := $collection || "/" || $r
    return (sm:chown($resource,$owner-name),sm:chgrp($resource,$group-name)),
    for $c in xmldb:get-child-collections($collection)
    let $coll := $collection || "/" || $c
    return tenant:fix-ownership($coll,$owner-name,$group-name)
};

(:(\: Recursively apply ownership to a collection hierarchy :\)
declare function tenant:fix-ownership($collection, $staff-name) {
    sm:chown($collection,$staff-name),
    sm:chgrp($collection,$staff-name),
    for $r in xmldb:get-child-resources($collection)
    let $resource := $collection || "/" || $r
    return (sm:chown($resource,$staff-name),sm:chgrp($resource,$staff-name)),
    for $c in xmldb:get-child-collections($collection)
    let $coll := $collection || "/" || $c
    return tenant:fix-ownership($coll,$staff-name)
};:)


declare function tenant:create-tenant-user($key) as xs:string { (: returns $key_staff :)
    let $admin-group-name := $key || "_admin" 
    let $admin-users := if (not(sm:user-exists($admin-group-name))) then sm:create-account($admin-group-name, "staffer",()) else ()
    let $tenant-staff-name := $key || "_staff" 
    let $tenant-owner := if (not(sm:user-exists($tenant-staff-name))) then sm:create-account($tenant-staff-name,"staffer",()) else ()
    return $tenant-staff-name
};


declare function tenant:copy-template($new-tenant, $key) {
    if (not(exists(collection($new-tenant)))) then
        (
            xmldb:copy("/db/apps/pekoe/tenant-template","/db/pekoe/tenants"),
            sm:chmod(xs:anyURI("/db/pekoe/tenants/tenant-template"), 'rwxrwx---'),
            xmldb:rename("/db/pekoe/tenants/tenant-template", $key)
        )
    else ()
};

declare function tenant:create($key, $client-name){

(:    Use a tenant-template. Only have to reset ownership.     :)
    let $tenant-staff-name := tenant:create-tenant-user($key)
    let $new-tenant := "/db/pekoe/tenants/" || $key
    let $make-tenant-coll := tenant:copy-template($new-tenant,$key)
    
(:    let $permissions := xmldb:set-collection-permissions($new-tenant,$tenant-staff-name,$tenant-staff-name,sm:mode-to-octal('rwxrwx---')):)
    let $permissions := tenant:fix-ownership($new-tenant, $tenant-staff-name,$tenant-staff-name)
    let $conf := doc($new-tenant || "/config/tenant.xml")/tenant
    let $conf-id := update value $conf/@id  with $key
    let $conf-name := update value $conf/name with $client-name
    return 
    
    $new-tenant
};