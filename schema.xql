(:
    Get the appropriate schema
:)
xquery version "3.0"; 
declare namespace pekoe-schema = "http://pekoe.io/schema";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http="http://expath.org/ns/http-client";

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
    for $f in $pekoe-schema/(field,fragment-ref)[starts-with(@path,'/')]

    let $path := string($f/@path)
    let $full-path := $link-path || $path
(:    If this is a fragment-ref then its possible that there are outputs defined on the fragment. 
      These outputs can be overriden by one of the same name defined on the fragment-ref. (The fragment-ref being an "instance".) 
:)

    let $outputs := pekoe-schema:output-functions($f)
(:    order by $path:)
    return 
    <tr>
        <td><a href='{$full-path}'>{$path}</a></td>
        <td>{if (empty($outputs)) then '&#160;' else  
            <table class='output'>
            {for $o in $outputs
             order by $o
             return <tr><td><a href='{$full-path || '?output=' || $o}'>{$o}</a></td></tr>
             }</table>
             }</td>
    </tr>
    
            
};

declare function pekoe-schema:output-functions($f) {
    if ($f instance of element(field)) then 
        if ($f/input/@type ne 'field-choice') then $f/output/string(@name)[. ne '']
        else pekoe-schema:field-choice-outputs($f)
    else 
        let $fragref := string($f/@path)
        let $fragment-name := tokenize($fragref,'/')[last()]
        
        let $fragment-outputs := root($f)//fragment[@name eq $fragment-name]/output/string(@name)[. ne '']
        
        let $frag-ref-outputs := $f/output/string(@name)
        return distinct-values(($fragment-outputs,$frag-ref-outputs)[. ne ''])
};

declare function pekoe-schema:field-choice-outputs($f) {
    let $root := root($f)
    let $frags := tokenize(($f/input/list),'\n')[. ne '']
    for $frag in $frags
    return $root//fragment[@name eq $frag]/output/string(@name)[. ne '']
};

declare
%rest:GET
%rest:path("/pekoe/schema/{$for}/text")
%rest:produces("application/xml")
%output:media-type("application/xml")
 function pekoe-schema:generate-text-template($for) {
   let $available := pekoe-schema:available-schemas()
   let $schema := $available[@for eq $for][1]
   return
    <text>
    {attribute created-dateTime {current-dateTime()} }
    <content>{
    for $f at $i in $schema/(field,fragment-ref)[starts-with(@path,'/')]
    return concat('{{f',$i,'}}&#10;')
    }</content>
    {
    for $f at $i in $schema/(field,fragment-ref)[starts-with(@path,'/')]
    return <link><placeholder>f{$i}</placeholder><path>http://pekoe.io/{$pekoe-schema:tenant}{$f/@path/string()}</path></link>
    }
    </text>
(:
Want this
<text created-dateTime="2015-05-11T09:39:44.867+09:30" created-by="admin" edited="2015-05-11T00:09:52.215Z">
    <content>Pekoe DOCUMENTATION Item {{id}}
Title: {{title}}
Applicable to: {{applies-to}}.

{{content}}
</content>
    <link>
        <placeholder>title</placeholder>
        <path>http://pekoe.io/common/documentation/title?uppercase</path>
    </link>
    <link>
        <placeholder>id</placeholder>
        <path>http://pekoe.io/common/documentation/id</path>
    </link>
    <link>
        <placeholder>applies-to</placeholder>
        <path>http://pekoe.io/common/documentation/applies-to</path>
    </link>
    <link>
        <placeholder>content</placeholder>
        <path>http://pekoe.io/common/documentation/content?limit-to-80</path>
    </link>
</text>

from this (not from the same schema - but the point is clear )
http://pekoe.io/bkfa/ad-booking/id
http://pekoe.io/bkfa/ad-booking/ad-date
http://pekoe.io/bkfa/ad-booking/earliest-date
http://pekoe.io/bkfa/ad-booking/org/@id
http://pekoe.io/bkfa/ad-booking/org
http://pekoe.io/bkfa/ad-booking/note
http://pekoe.io/bkfa/ad-booking/address
http://pekoe.io/bkfa/ad-booking/form-received-date
http://pekoe.io/bkfa/ad-booking/pre-ad-letter
http://pekoe.io/bkfa/ad-booking/coordinator
http://pekoe.io/bkfa/ad-booking/kits/promised
http://pekoe.io/bkfa/ad-booking/kits/made
http://pekoe.io/bkfa/ad-booking/kits/returned-date
http://pekoe.io/bkfa/ad-booking/recurring-booking
http://pekoe.io/bkfa/ad-booking/in-conjunction-with
http://pekoe.io/bkfa/ad-booking/theme
http://pekoe.io/bkfa/ad-booking/heard-of/source
http://pekoe.io/bkfa/ad-booking/heard-of/other
http://pekoe.io/bkfa/ad-booking/deliver-to/person
http://pekoe.io/bkfa/ad-booking/deliver-to/address
http://pekoe.io/bkfa/ad-booking/supplies
http://pekoe.io/bkfa/ad-booking/transport-register
http://pekoe.io/bkfa/ad-booking/email
http://pekoe.io/bkfa/ad-booking/task
http://pekoe.io/bkfa/ad-booking/deliver-to/notes



:)

};

(:  ***************** This is the schema-paths page for a specific schema **************** :)
declare function pekoe-schema:schema-page($schema,$doctype) {
   let $link-path := 'http://pekoe.io/' || $pekoe-schema:tenant 
   let $page := 
     <div class='container-fluid'>
       <div class='row'>
           <div class='btn-toolbar' role='toolbar' aria-label="List controls">        </div>
       </div>
       <h1>Field paths in the <em>{$doctype}</em> schema</h1>
         <div>Path to schema : {document-uri(root($schema))}</div>
       <div>Note: <em>the links are not active</em>. Right-click on them to copy and then paste into your template as a Hyperlink.</div>
       <div>
            <input type='checkbox' id='hideOutputs'  name='hide-outputs'>{if (request:get-parameter('hide-outputs','') eq 'on') then attribute checked {"checked"} else () }</input><label for='hideOutputs'>Hide outputs</label>
            <label style='margin-left: 2em;'>Search field paths: <input type='text' id='filter' size='40'/></label> <button id='clear'>Clear</button>
            <script>$(function(){{
            // why don't i just hide the rows? much less complex.
                $('#hideOutputs').on('change',function(){{
                   $('.output').toggle();
                }});
                $('#clear').click(function () {{ $('#filter').val('');}})
                $('#filter').keyup(function () {{
                    var t = $(this).val();
                    $('#topt > tr').hide();
                    $('#topt > tr:contains("' + t + '")').show();
                    $('.textlink').hide();
                    $('.textlink:contains("' + t + '")').show();
                }});
            }});
            </script>
       </div>
       <table class='table' style='width: 50%'>
        <thead>
           <tr class='header'>
               <th>Field Path</th><th>Output functions</th>
           </tr>
           </thead>
           <tbody id='topt'>
               { pekoe-schema:make-paths($link-path, $schema) }
               </tbody>
           </table>
           <div>
{

for $f in $schema/(field,fragment-ref)[starts-with(@path,'/')]
return <div class='textlink'>{$link-path || $f/@path}</div>

}
{if (sm:is-dba(sm:id()//sm:username)) then <a href='/exist/restxq/pekoe/schema/{$schema/@for/string()}/text'>Generate Text Template</a> else ()}
           </div>
       </div>
   let $results := map {
           'title' := "Schema paths",
           'path' := '',
           'body' := $page,
           'pagination' := (),
           'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/schema.xql', '/Schema-paths/' || $doctype)
           }
    return
   list-wrapper:wrap($results)
};

declare
%rest:GET
%rest:path("/pekoe/schemas")
%rest:produces("application/xml")
%output:media-type("application/xml")
 function pekoe-schema:available-doctypes() {
    for $i in (collection("/db/pekoe/common/schemas")/schema,collection($pekoe-schema:tenant-path)/schema)
    let $doctype := $i/@for/string()
    order by $doctype
    return <doctype>{$doctype}</doctype>
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
        <thead>
           <tr class='header'>
               <th>Schema doctype</th>               
           </tr>
           </thead>
           <tbody>
               { for $schema in pekoe-schema:available-schemas()
                let $doctype := $schema//string(@for)
                order by $doctype
                return <tr><td><a href='?for={$doctype}'>{$doctype}</a></td></tr>
                }
                </tbody>
           </table>
       </div>
   let $results := map {
           'title' := "Schema paths",
           'path' := '',
           'body' := $page,
           'pagination' := (),
           'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/schema.xql', '/Schema-paths')
           }
    return
   list-wrapper:wrap($results)
};

(: ************************* List the schemas and then their fields and outputs in the selected schema **************** :)
   
   let $for := request:get-parameter("for",())
   let $available := pekoe-schema:available-schemas()
(:   let $log := util:log('info',$available):)
   let $schema := $available[@for eq $for][1]
   return if (exists($schema)) then pekoe-schema:schema-page($schema,$for) else pekoe-schema:list-schemas()
   
   