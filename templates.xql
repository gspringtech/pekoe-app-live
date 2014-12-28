xquery version "3.0"; 

import module namespace tmpl     ="http://www.gspring.com.au/pekoe/admin-interface/templates" at "modules/templates.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

declare variable $local:include-defaults := true();

declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant ;
declare variable $local:templates-path := $local:tenant-path || "/templates";
declare variable $local:common-templates-path := "/db/pekoe/common/templates";


declare function local:list() as element() {
    let $common-templates := tmpl:get-simple-listing($local:common-templates-path)
    let $simple-listing := tmpl:get-simple-listing($local:templates-path)
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
