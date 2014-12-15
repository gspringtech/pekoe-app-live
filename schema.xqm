(:
    Get the appropriate schema
:)
xquery version "3.0"; 
declare namespace pekoe-schema = "http://pekoe.io/schema";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";
import module namespace list-wrapper = "http://pekoe.io/list/wrapper" at "list-wrapper.xqm";
declare option output:method "html5";
declare option output:media-type "text/html";

(:declare variable $schema:selected-tenant := req:header("tenant");:)
declare variable $pekoe-schema:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $pekoe-schema:tenant-path := "/db/pekoe/tenants/" || $pekoe-schema:tenant ;
declare variable $pekoe-schema:common := "/db/pekoe/common/schemas";

(:
    Not quite so simple.
    Will need to check the default schemas and then add the tenant's schemas


:)

declare
%rest:GET
%rest:path("/pekoe/schema/{$for}")
%rest:produces("application/xml")
%output:media-type("application/xml")
function pekoe-schema:get-schema($for) {
    let $local-schema := collection($pekoe-schema:tenant-path)/schema[@for eq $for]
    
    return 
        if (not(empty($local-schema)))
        then  $local-schema
        else 
            let $default-schema := collection($pekoe-schema:common)/schema[@for eq $for]
(:            let $log := util:log("debug", "SCHEMA FOR " || $for || " is " || $default-schema):)
            return
                if (not(empty($default-schema))) then $default-schema
                else                
                <rest:response>
                     <http:response status="{$pekoe-http:HTTP-404-NOTFOUND}"/>
                 </rest:response>

};

(: Rather than having to create a list of paths every time, why don't I store them somewhere? Config? Next to the schema?
:)
(: Probably should use the schema path to determine the 'tenant' because it could be a 'common' schema. :)
declare 
function pekoe-schema:make-paths($link-path, $pekoe-schema) {
    
    for $f in $pekoe-schema/schema/(field,fragment-ref)[starts-with(@path,'/')]
(:    order by $f:)
    let $path := string($f/@path)
    let $full-path := $link-path || $path
    let $outputs := $f/output[@name ne '']
    return (<tr><td><a href='{$full-path}'>{$path}</a></td><td>{if (empty($outputs)) then '&#160;' else (<em>output options for&#160;&#160;</em>,$path) }</td></tr>,
            for $o in $outputs
            let $output-name := $o/string(@name)
            order by $output-name
            return <tr><td>&#160;</td><td><a href='{$full-path || '?output=' || $output-name}'>{$output-name}</a></td></tr>
            )
    
    
};

(: ************************* List the fields in the selected schema **************** :)
(:I don't know how to do this for 'common' schemas. Perhaps it doesn't matter. :)
   let $path := request:get-parameter("path","")
   let $real-path := $pekoe-schema:tenant-path || $path
(:   let $local-path := substring-after($real-path, "/db/pekoe/tenants")
   let $tenant-name := tokenize($local-path,"/")[1]:)
   let $schema := doc($real-path)
   let $link-path := 'http://pekoe.io/' || $pekoe-schema:tenant || $schema/@for

   let $page := 
     <div class='container-fluid'>
       <div class='row'>
           <div class='btn-toolbar' role='toolbar' aria-label="List controls">        </div>
       </div>
       <h1>Paths in the schema for {$schema/schema/string(@for)}</h1>
       <div>Note: <em>the links are not active</em>. Right-click on them to copy and then paste into your template as a Hyperlink.</div>
       <table class='table'>
           <tr>
               <th>Field Path</th><th>&#160;</th>
           </tr>
               { pekoe-schema:make-paths($link-path, $schema) }
           </table>
       </div>
   let $results := map {
           'title' := "Schema paths",
           'path' := $path,
           'body' := $page,
           'pagination' := (),
           'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/schema.xqm?path=', $path)
           }
    return
   list-wrapper:wrap($results)