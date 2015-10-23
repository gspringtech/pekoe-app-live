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

 declare function tenant:fix-serial-numbers($tenant) {
    let $collection := '/db/pekoe/tenants/' || $tenant || '/config/serial-numbers'
    
    for $r in xmldb:get-child-resources($collection)
    let $resource := xs:anyURI($collection || "/" || $r)
    return tenant:serial-number-file($tenant, $resource)
 };
 
 declare function tenant:serial-number-file($tenant, $resource as xs:anyURI) {
    let $user := 'admin'
    let $group := $tenant || '_staff'
    let $xml-permissions := 'rw-rw----'
    return (
        sm:chown($resource,$user),
        sm:chgrp($resource,$group),
        sm:chmod($resource,$xml-permissions)
    )
 };
 
 declare function tenant:fix-templates($collection, $owner-name, $group-name) {
    sm:chown($collection,$owner-name),
    sm:chgrp($collection,$group-name),
    sm:chmod($collection, 'rwxrwx---'),
    for $r in xmldb:get-child-resources(string($collection))
    let $resource := xs:anyURI($collection || "/" || $r)
    return (
        sm:chown($resource,$owner-name),
        sm:chgrp($resource,$group-name),
        if (util:is-binary-doc($resource)) then (sm:chmod(xs:anyURI($resource),'rw-rw----')) else  (sm:chmod(xs:anyURI($resource),'rw-r-----'))
        
    ),
    for $c in xmldb:get-child-collections(string($collection))
        let $coll := xs:anyURI($collection || "/" || $c)
        return tenant:fix-templates($coll,$owner-name,$group-name)
     
 };

(: Recursively apply ownership to a collection hierarchy :)
declare function tenant:fix-ownership($collection, $owner-name, $group-name) {
    sm:chown($collection,$owner-name),
    sm:chgrp($collection,$group-name),
    sm:chmod($collection, 'rwxrwx---'),
    for $r in xmldb:get-child-resources(string($collection))
    let $resource := xs:anyURI($collection || "/" || $r)
    return (
        sm:chown($resource,$owner-name),
        sm:chgrp($resource,$group-name),
        if (util:is-binary-doc($resource)) then (sm:chmod(xs:anyURI($resource),'rwxr-x---')) else  (sm:chmod(xs:anyURI($resource),'rw-r-----'))
        
    ),
    for $c in xmldb:get-child-collections(string($collection))
        let $coll := xs:anyURI($collection || "/" || $c)
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

declare function tenant:local-path($real-path) {
    substring-after($real-path, $tenant:tenant-path)
};


declare function tenant:quarantined-path($real-path) {
    '/exist/pekoe-files' || substring-after($real-path, $tenant:tenant-path)
};

declare function tenant:real-path($quarantined-path) {
    $tenant:tenant-path || substring-after($quarantined-path, '/exist/pekoe-files')
};

declare function tenant:get-tenant(){
    ()
};