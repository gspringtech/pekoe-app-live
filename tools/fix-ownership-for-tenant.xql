xquery version "3.0";
import module namespace tenant="http://pekoe.io/tenant" at "/db/apps/pekoe/modules/tenant.xqm";
(:let $staff-user := tenant:create-tenant-user('bkfa'):)
(:return tenant:fix-ownership('/db/pekoe/tenants/bkfa',$staff-user,$staff-user):)
(: 2015-02-09 PERMISSIONS ON Collections NOT RIGHT :)

let $tenant := 'cm' (: ---------------------------- CHANGE THIS ------------ :)
let $staffer := $tenant || '_staff'

let $target-path := '/db/pekoe/tenants/' || $tenant || '/files' (: ------------ AND THIS --------- :)
return 
tenant:fix-ownership($target-path, $staffer, $staffer)
 
(: tenant:serial-numbers('cm'):)