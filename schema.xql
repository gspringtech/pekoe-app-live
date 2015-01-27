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
    let $local-schema := collection($pekoe-schema:tenant-path)/schema[@for eq $for][1]
    
    return 
        if (not(empty($local-schema)))
        then  $local-schema
        else 
            let $default-schema := collection($pekoe-schema:common)/schema[@for eq $for]
            return
                if (not(empty($default-schema))) then $default-schema
                else                
                (<rest:response>
                     <http:response status="{$pekoe-http:HTTP-404-NOTFOUND}"/>
                 </rest:response>,
                 <result>No schema found</result>
                 )
};

(: Rather than having to create a list of paths every time, why don't I store them somewhere? Config? Next to the schema?
:)
(: Probably should use the schema path to determine the 'tenant' because it could be a 'common' schema. :)
declare function pekoe-schema:make-paths($link-path, $pekoe-schema) {
    let $hide-outputs := request:get-parameter('hide-outputs','') eq '1'

    for $f in $pekoe-schema/(field,fragment-ref)[starts-with(@path,'/')]

    let $path := string($f/@path)
    let $full-path := $link-path || $path
(:    If this is a fragment-ref then its possible that there are outputs defined on the fragment. 
      These outputs can be overriden by one of the same name defined on the fragment-ref. (The fragment-ref being an "instance".) 
:)
(:    let $outputs := $f/output[@name ne '']:)
    let $outputs := pekoe-schema:output-functions($f)
    order by $path
    return (<tr><td><a href='{$full-path}'>{$path}</a></td><td>{if ($hide-outputs or empty($outputs)) then '...' else '&#160;' }</td></tr>,
    if ($hide-outputs) then () else
            for $o in $outputs
(:            let $output-name := $o/string(@name):)
            order by $o
            return <tr><td>&#160;</td><td><a href='{$full-path || '#' || $o}'>{$o}</a></td></tr>
            )
};

declare function pekoe-schema:output-functions($f) {
    if ($f instance of element(field)) then 
        if ($f/input/@type ne 'field-choice') then $f/output/string(@name)[. ne '']
        else pekoe-schema:field-choice-outputs($f)
    else 
        let $fragref := string($f/@path)
        let $fragment-name := tokenize($fragref,'/')[last()]
        let $debug := util:log('debug','WANT OUTPUTS FROM FRAGMENT NAMED ' || $fragment-name)
        let $fragment-outputs := $f/../fragment[@name eq $fragment-name]/output/string(@name)[. ne '']
        let $debug := util:log('debug',//fragment[@name eq $fragment-name])
        let $frag-ref-outputs := $f/output/string(@name)
        return distinct-values(($fragment-outputs,$frag-ref-outputs)[. ne ''])
};

declare function pekoe-schema:field-choice-outputs($f) {
    let $root := root($f)
    let $frags := tokenize(($f/input/list),'\n')[. ne '']
    for $frag in $frags
    return $root//fragment[@name eq $frag]/output/string(@name)[. ne '']
};


declare function pekoe-schema:schema-page($schema) {
   let $link-path := 'http://pekoe.io/' || $pekoe-schema:tenant 

   let $page := 
     <div class='container-fluid'>
       <div class='row'>
           <div class='btn-toolbar' role='toolbar' aria-label="List controls">        </div>
       </div>
       <h1>Paths in the schema for {$schema/schema/string(@for)}</h1>
         <div>Path to schema : {document-uri(root($schema))}</div>
       <div>Note: <em>the links are not active</em>. Right-click on them to copy and then paste into your template as a Hyperlink.</div>
       <div><input type='checkbox' id='hideOutputs'  name='hide-outputs'>{if (request:get-parameter('hide-outputs','') eq '1') then attribute checked {"checked"} else () }</input>Hide outputs
            <script>$(function(){{
                $('#hideOutputs').on('change',function(){{
                    var search = location.search.substring(1);
                    var params = JSON.parse('{{"' + decodeURI(search).replace(/"/g, '\\"').replace(/&amp;/g, '","').replace(/=/g,'":"') + '"}}');
                    params["hide-outputs"] = $(this).is(':checked') ? '0' : '1';
                    console.log($.param(params),$(this).is(':checked'));
                    console.log($.param(params));
                    //location.search = '?' + $.param(params);
                }});
            }});
            </script>
       </div>
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
                let $doctype := $schema//string(@for)
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
   
   