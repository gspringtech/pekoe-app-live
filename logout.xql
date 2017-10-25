xquery version "3.0";

declare option exist:serialize "method=html5 media-type=text/html";

import module namespace dbutil="http://exist-db.org/xquery/dbutil" at "/db/apps/shared-resources/content/dbutils.xql";
import module namespace rp = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";

declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;
declare variable $local:current-user := sm:id()//sm:real//sm:username/string(.);
(:declare variable $local:tenant-admin-group := "pekoe-tenant-admins";
declare variable $local:user-is-admin-for-tenant := local:user-is-admin(); :)

declare function local:find-my-files() {
(:    only want to close files for the currently selected tenant.
      NOTE - the collection() function returns ALL resources, not just xml. Use /* to ensure only XML docs are closed.
      
      It was suggested that I use collection and document traversal rather than this...
      See http://exist-db.org/exist/apps/wiki/blogs/eXist/HoF
      
      Another approach to this would be to LOG all the files this user opens,
      and delete from the log when they close the file.
      The remainder would be the files that need closing.
      
      THIS APPROACH (below) only closes XML files in tenant/files/...
      
:)
    for $doc in collection($local:tenant-path || "/files")/*[sm:get-permissions(xs:anyURI(document-uri(root(.))))/sm:permission/@owner eq $local:current-user]
    let $path := document-uri(root($doc))
    let $debug := util:log("WARN",  "LOGOUT CLOSING FILE " || $path)
    let $p := rp:resource-permissions(xs:string($path))
    let $chown := sm:chown($path, $p("col-owner"))
    let $chmod := sm:chmod($path, $rp:closed-and-available)
    return $p
};

declare function local:close-resource($col, $res) {
    let $p := rp:resource-permissions(xs:string($res))
    let $log := util:log-app("warn", "login.pekoe.io","USER " || $local:current-user || " did not close " || $res || " USING " || $p("col-owner"))
    return if ($p("col-owner") eq "admin") then util:log-app("warn","login.pekoe.io", "PEKOE ADMIN OWNS COLLECTION " || $col)
    else (
    let $chown := sm:chown($res, $p("col-owner"))
    let $chmod := sm:chmod($res, $rp:closed-and-available)
    return ()
    )
};

declare function local:close-all() {
dbutil:scan(xs:anyURI($local:tenant-path || '/files'), function($col, $res) {
   if ($res and ends-with($res, '.xml') and not($res eq 'S3-TOC.xml')) then 
       if (sm:get-permissions($res)/sm:permission/@owner eq $local:current-user)
       then local:close-resource($col, $res)
       else ()
    else ()
    
})
};

declare function local:close-open-files() {
    if ($local:tenant-path eq "/db/pekoe/tenants/") then ()
    else 
    local:close-all()
};

(: pre-validate user to ensure that they are a valid user. :)
util:log-app('info','login.pekoe.io', '     ' || $local:current-user || ' logged-OUT OF ' || $local:tenant || ' FROM ' || request:get-header('X-Real-IP')),
local:close-open-files(),
session:invalidate(),
<html><head><title>Goodbye</title></head>
<body>Goodbye. Have a rest.</body>
</html>