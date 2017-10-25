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


(: Rather than having to create a list of paths every time, why don't I store them somewhere? Config? Next to the schema?
:)
(: Probably should use the schema path to determine the 'tenant' because it could be a 'common' schema. :)
declare 
function pekoe-schema:make-paths($link-path, $pekoe-schema) {
    
    for $f in $pekoe-schema/(field,fragment-ref)[starts-with(@path,'/')]

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

declare function pekoe-schema:schema-page($schema) {
   let $link-path := 'http://pekoe.io/' || $pekoe-schema:tenant || $schema/@for

   let $page := 
     <div class='container-fluid'>
       <div class='row'>
           <div class='btn-toolbar' role='toolbar' aria-label="List controls">        </div>
       </div>
       <h1>Paths in the schema for {$schema/schema/string(@for)}</h1>
         <div>Path to schema : {document-uri(root($schema))}</div>
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
           'path' := '',
           'body' := $page,
           'pagination' := (),
           'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/schema.xqm', '')
           }
    return
   list-wrapper:wrap($results)
};

declare function pekoe-schema:available-schemas() {
    collection("/db/pekoe/common/schemas")/schema,collection($pekoe-schema:tenant-path)/schema
};

declare function pekoe-schema:list-schemas() {

   let $page := 
     <div class='container-fluid'>
       <div class='row'>
           <div class='btn-toolbar' role='toolbar' aria-label="List controls">        </div>
       </div>
       <h1>Available schemas for {$pekoe-schema:tenant}</h1>
      
       <table class='table'>
           <tr>
               <th>Schema doctype</th><th>&#160;</th>
           </tr>
               { for $schema in pekoe-schema:available-schemas()
                let $doctype := $schema/data(@for)
                return <tr><td><a href='?for={$doctype}'>{$doctype}</a></td></tr>
                }
           </table>
       </div>
   let $results := map {
           'title' := "Schema paths",
           'path' := '',
           'body' := $page,
           'pagination' := (),
           'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/schema.xqm', '')
           }
    return
   list-wrapper:wrap($results)
};

(: ************************* List the schemas and then their fields and outputs in the selected schema **************** :)

   let $for := request:get-parameter("for","")
    let $available := pekoe-schema:available-schemas()
   let $schema := $available[@for eq $for]
   return if (exists($schema)) then pekoe-schema:schema-page($schema) else pekoe-schema:list-schemas()
   
   