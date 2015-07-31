xquery version "3.1";

module namespace properties="http://pekoe.io/properties";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "application/json";

declare variable $properties:selected-tenant := req:header("tenant");
declare variable $properties:tenant-path := '/db/pekoe/tenants/' || $properties:selected-tenant;

declare 
%rest:GET
%rest:path("/pekoe/properties/{$prop-name}")
%rest:produces("application/json")
%output:method("json")
function properties:get-json($prop-name) {
    if ($properties:tenant-path ne '/db/pekoe/tenants/' and sm:has-access(xs:anyURI($properties:tenant-path),'r')) then
    collection($properties:tenant-path)//property[@name eq $prop-name]
    else ()
};