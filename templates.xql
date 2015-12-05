xquery version "3.1"; 

import module namespace tmpl     ="http://www.gspring.com.au/pekoe/admin-interface/templates" at "modules/templates.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

declare variable $local:include-defaults := true();
(:TODO fix this tenant access... :)
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant ;
declare variable $local:templates-path := $local:tenant-path || "/templates";
declare variable $local:common-templates-path := "/db/pekoe/common/templates";
declare variable $local:defaults := collection($local:tenant-path || "/templates-meta")/default-links;

(: I want to find collection('templates-meta')/default-links and then for each Template, check its '@for' and compare it with the '@default-template' for that doctype.

:)

declare function local:list() as element() {
    let $default-templates := map:new(for $default-link in $local:defaults return map{$default-link/string(@for) : $default-link/string(@default-template) })
    let $debug := for $k in map:keys($default-templates) return util:log('info','KEY: ' || $k || ': ' || $default-templates($k) )
    let $common-templates := tmpl:get-simple-listing($local:common-templates-path,$default-templates)
    let $simple-listing := tmpl:get-simple-listing($local:templates-path, $default-templates)
    return <ul class='hiernav'>{$common-templates,$simple-listing}</ul> 
}; 


(: --------------------------------------------------      MAIN QUERY      ------------------------- :)

let $requestFor := request:get-parameter("get", "list")
return
        if ($requestFor eq "list") then  (: called by /pekoe-form/index :)
            local:list()
        else if ($requestFor eq "links") then 
            tmpl:get-phlinks(request:get-parameter("template",""), $local:tenant-path)
        else ()
