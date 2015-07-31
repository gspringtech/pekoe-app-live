xquery version "3.0";

import module namespace dbutil="http://exist-db.org/xquery/dbutil" at "/db/apps/shared-resources/content/dbutils.xql";


declare function local:change-group() {
dbutil:scan(xs:anyURI('/db/pekoe/common'), function($col,$res) {
    if ($res) then
        sm:chgrp($res, "pekoe-tenants")
    else sm:chgrp($col,"pekoe-tenants")
    
})
};

declare function local:templates-meta-permissions() {
    dbutil:scan(xs:anyURI('/db/pekoe/tenants/cm/templates-meta'), function($col,$res) {
        if ($res) then
            sm:chmod($res, 'rwxrwx---')
        else ()
        
    })    
};

declare function local:closed-and-available($tenant_staff, $col) {
    dbutil:scan(xs:anyURI($col) , function ($col, $res) {
        if (ends-with($res,'.xml')) then 
            (sm:chown($res, $tenant_staff),
            sm:chmod($res, 'rw-r-----')
            )
        else ()
    })
    
};


local:closed-and-available('cm_staff', '/db/pekoe/tenants/cm/config/serial-numbers')
(:local:templates-meta-permissions():)