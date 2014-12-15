import module namespace v="http://gspring.com.au/pekoe/validator" at "validator.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "../modules/tenant.xqm";

declare function local:fix-path($p) {
    (: GOT job = 	    /exist/pekoe-files/files/education/bookings/2014/11/booking-00885/data.xml:)
    (: WANT path   '/db/pekoe/tenants/tdbg/files/education/bookings/2014/11/booking-00885/data.xml':)
    concat($tenant:tenant-path, substring-after($p, "/exist/pekoe-files"))
};

(:
    The path to the schematron must be provided as a parameter...
:)

let $schematron-path := local:fix-path(request:get-parameter('schematron',()))


let $job-path := local:fix-path(request:get-parameter("job",()) )
let $job-doc := doc($job-path)
return 
if (not(doc-available($schematron-path))) then <result status='error'>No Schematron schema found</result>
else if (empty($job-doc))   then <result status='error'>No Job document at {$job-path}</result>
else v:validate($job-doc, xs:anyURI($schematron-path) )