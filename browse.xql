xquery version "3.0";
(: 
    Top-level List View: browse files, xqueries and collections.
:)


module namespace browse = "http://www.gspring.com.au/file-browser";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:import module namespace permissions = "http://www.gspring.com.au/pekoe/admin-interface/permissions"  at "admin/permissions.xqm";:)



declare variable $browse:default-user := "pekoe-staff";
declare variable $browse:default-group := "staff";
declare variable $browse:default-pass := "staffer";
declare variable $browse:open-for-editing :=       sm:mode-to-octal("rwxr-----");
declare variable $browse:closed-and-available :=   sm:mode-to-octal("r--r-----"); 
declare variable $browse:xquery-permissions :=     sm:mode-to-octal("rwxr-xr--");
declare variable $browse:collection-permissions := sm:mode-to-octal("rwxrwx---");

declare variable $browse:root-collection := "/db/pekoe";
declare variable $browse:base-collection := "/db/pekoe/files";
declare variable $browse:filter-out := ("xqm","xsl");
declare variable $browse:action := "browse"; (:request:get-parameter("action","browse");:)
 

(: Doctypes are provided by the schema@for attributes. :)
declare function local:doctype-options() {
    let $general-doctypes := collection("/db/pekoe/files/schemas")/schema/@for/data(.) 
    let $current-col := request:get-parameter("collection",())
    let $local-doctypes := collection($current-col)/schema/@for/data(.)
    for $dt in ($general-doctypes, $local-doctypes)
    order by $dt
    return <option>{$dt}</option>
};

(:declare function local:get-request-as-number($param as xs:string, $default as xs:integer) as xs:integer {
    let $requested := request:get-parameter($param, "")
    return if ($requested castable as xs:integer) then xs:integer($requested) else $default 
};:)

declare function local:get-paged-items($items) {
    
    let $rp := local:get-request-as-number("rp",10)
    let $cp := local:get-request-as-number("p",1)
    let $count := count($items)
    let $total-pages := ceiling($count div $rp)
    let $start-index := ($cp - 1) * $rp + 1 
    let $end-index := $start-index + $rp - 1
    return  
    <page>
        <start>{$start-index}</start>
        <end>{$end-index}</end>
        <rp>{$rp}</rp>
        <current>{$cp}</current>
        <pages>{$total-pages}</pages>
        <count>{$count}</count>
    </page>
};

(:
    Display the contents of a collection in a table view.
:)

declare  
%rest:GET
%rest:path("/pekoe/tenant/{$tenant}/browse")
%rest:query-param("collection","{$colpath}", "/files")
%rest:query-param("search","{$searchstr}","")
%output:media-type("text/html")
%output:method("html5")
function browse:display-collection($tenant, $colpath,$searchstr) 
{
    let $colName := "/db/pekoe/tenants/" || $tenant || $colpath
    let $paging := local:get-paged-items((xmldb:get-child-collections($colName),xmldb:get-child-resources($colName))) 
    let $callback-name := util:uuid()
    let $parent-col := browse:get-parent-collection($colName)
(:    let $searchstr := request:get-parameter("searchstr",""):)
    let $xpath := request:get-parameter("xpath","")
    return
        (response:set-header("Content-type","text/html"),
        <div>
            <div title="collection:{$colName}" class='action search'>
                <input type='text' name='searchstr' value='{$searchstr}' />
                <input type="submit" value="Search" name="action" />
            </div>
            <div title="collection:{$colName}" class='action xpath'>
                <input type='text' name='xpath' value='{$xpath}' id='xpath{$callback-name}' size='60'/>
                <input type="submit" value="XPath Search" name="action" />
            </div>
            {
            (: 
            Regarding the XPath (above). If I can somehow attach an autocomplete on this how should it work?
            from my perspective, I'd want the smallest significant path - eg 
            //meeting[contains(., 'Ruth')]
            
            but from a user perspective, with no knowledge of XPath,
            they want a guided tour: show me the Start (root elements)
            (and you could stop at that point too - /meeting[contains(., 'Ruth')] is fine )
            but they might want the next level 
            /meeting ???
            PLUS this helps to distinguish between /school/id and /school-booking/id or one of the many "name" elements. 
            
            (regarding the "new" below)
            Here's where I'd like an ACL:
                I'd like to say "Does the user have create-permissions in this directory? 
                Better still, WHAT can they create?
                
                So - i want the person to be an Admin member AND a member of the current group
                OR
                Maybe I want to limit the schemas according to type. 
                Perhaps the schemas have permissions?
                
            :)
            
            if (xmldb:is-admin-user(xmldb:get-current-user()) ) then 
               <div title="collection:{$colName}" class='action new'>
                 Make a new:  
                    <select name='doctype' >
                        <option></option>
                        <option value="collection">Folder</option>
                        <option disabled="disabled" style='color:#AAAAAA; background-color:#EEEEEE;padding-top:3px;'>Schemas:</option>
                    {
(: What if the schemas were collection-dependant. So schemas defined in files/schemas could be "global" and 
   schemas defined elsewhere would be only available to the collection and sub-collections. 
   That would mean the schema would be sitting in the top-level which might not be so good. 
   But it would also ensure that group A Admins could only see group A schemas. 
   
   :)
                       local:doctype-options()
                    }
                    </select> named: <input type='text' name='file-name' />
                    <input type='submit' class='list' name='action' value='New' /> (in {$colName})
               </div> 
            else () }
            
            <table id='{$callback-name}'>
                <tr>
                    <th>Name</th>
                    <th>Permissions</th>
                    <th>Owner</th>
                    <th>Group</th>
                    <th>Created</th>
                    <th>Modified</th>
                    <th>Size (KB)</th>
                </tr>
            
            {
(:  **** Here's where the paging doesn't work: there's no single batch of items. NOTE: A little re-writing would help!   ***   
    This approach doesn't match the "selected-resources first" method I use in custom XQueries. Perhaps it should. 
    The advantage of the other approach is that displaying search results is easy and requires little change to the
    output process.
:)
                browse:display-child-collections($colName),
                browse:display-child-resources($colName)
            }
        </table>

    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:false 
    }};
     gs["f:{$callback-name}"] = function () {{
            console.log('apply autocmplete to ',jQuery("#xpath{$callback-name}"));
            // or don't
            // jQuery("#xpath{$callback-name}").autocomplete({{"source":"browse.xql?action=JSON", minLength:3}});
        }};
    </script>
    </div>
    )
};
(: //gs["{$callback-name}"] = {{cp: {$paged-items[4]}, rp:{$paged-items[3]}, page:{$paged-items[4]}, pages:{$paged-items[5]}, usepager:false }}; :)

declare function browse:display-child-collections($colName as xs:string)
as element()* {
    for $child in xmldb:get-child-collections($colName)
    let $path := concat($colName,"/", $child),
        $created := xmldb:created($path) 
    order by $child
    return
        <tr title='collection:{$path}' class='collection'>
            <td class='tablabel'>{$child}</td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($path))}</td>
            <td>{xmldb:get-owner($path)}</td>
            <td>{xmldb:get-group($path)}</td>
            <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
            <td/>
            <td/>
        </tr>
};

(: The quarantine model sucks. It means that all the queries must know the collection-root.
   It will be better to simply check for an xquery. 
:)
declare function browse:display-child-resources($colName as xs:string) (: /db/pekoe/files :)
as element()* {
    let $children := xmldb:get-child-resources($colName)
    let $collection-owner := xmldb:get-group($colName)
    
    (:  A general comparison = must return false for every item to be false. Conversely, != only needs to be true of one item  :)
    for $child in $children[not(substring-after(.,".") = $browse:filter-out)]
    
    let $file-path := concat($colName,"/",$child)
    let $names := tokenize($child,"\.")
    let $class := ($names[2], "unknown")[1] (: failsafe :)
    
    let $owner := xmldb:get-owner($colName, $child)
    let $owner-is-me := $owner eq xmldb:get-current-user()
    let $read-permissions := xmldb:get-permissions($colName,$child) = ($browse:closed-and-available, $browse:xquery-permissions)
    let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
        if ($read-permissions) then $class
        else if ($owner-is-me) then concat($class, " locked-by-me") 
        else " locked"

    let $short-name := $names[1]
    let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
    let $doctype := if ($available and ($class eq "xml"))
        then name(doc($file-path)/*)
        else $class
    let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
    order by index-of(("xql","xml","unknown"),$class),  lower-case($child)
    return
        if (not($available)) then () else
       
        <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
            <td class='tablabel'>{$short-name}</td>
            <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($colName, $child))}</td>
            <td>{$owner}</td>
            <td>{xmldb:get-group($colName, $child)}</td>
            <td>{if ($available) then format-dateTime(xmldb:created($colName, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]") else ()}</td>
            <td>{if ($available) then format-dateTime(xmldb:last-modified($colName, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]") else ()}</td>
            <td>{if ($available) then (ceiling(xmldb:size($colName, $child) div 1024)) else ()}</td>
        </tr>
};

(:
    What I really want here is a TAG type behaviour. 
    But not quite - because if this is going to start at "whatever roots" 
    then the user shouldn't type anything. In fact, on FOCUS, 
    I should show the roots. On selection 
    
    Better still, what if the Javascript constructed the XPath
    //meeting[contains(.,'Ruth')]
    Then, the XPath could be handled by the controller, and sent back to the browser in a paged set like the Sandbox does.  
    :)
declare function browse:json-xpath-lookup() {

    '[',string-join(
    let $col := request:get-parameter("collection", $browse:base-collection)
    let $roots := for $n in distinct-values(collection($col)/*/name(.))
order by $n
return $n

for $r in $roots
let $path := concat('distinct-values(collection("', $col, '")/',$r, '/*/name(.))')
let $children := util:eval($path)
let $results :=  for $c in $children return concat($r,'/',$c)
return 
concat('["',string-join($results,'", "'),'"]')
, ",")
   ,']'

};


(: the problem with this search at the moment is that it returns a file without showing where the result is.
    What Carolyn wants is a search that lets her double click to edit the specific meeting. 
:)
declare function browse:xpath-search() {
    let $col := request:get-parameter("collection", $browse:base-collection)
    let $search := request:get-parameter("xpath",())
    let $callback-name := util:uuid()
    let $xpathsearch := concat("collection('",$col,"')", $search)
    
    let $log := util:log("debug", concat("################################### XPATH Search: ",$xpathsearch) )
    (: why not iterate over the actual results? Probably will include parent elements. :)
    let $found  := util:eval($xpathsearch) (: get all the result nodes :)
    let $files := (for $f in $found return root($f))/.
    let $paging := local:get-paged-items($files) 
    let $response := response:set-header("Content-type","text/html")
    return 
    <div>
    <table id='{$callback-name}'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging/start to $paging/end]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $class := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq xmldb:get-current-user()
            let $read-permissions := xmldb:get-permissions($f-col, $f-name) = ($browse:closed-and-available,$browse:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $class
                else if ($owner-is-me) then concat($class, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($class eq "xml"))
                then name($f/*)
                else $class
            let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
            return if (not($available)) then () else
            <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
                <td class='tablabel'>{document-uri($f)}</td>
                <td>{name($f/*)}</td>
                <td>--</td>
                <td>--</td>
            </tr>
        }
    </table>
    
    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:true 
    }};
    </script>
    </div>
};

declare function browse:display-search-results($colName) {
    let $col := collection($colName) (:Base collection for search:)
    let $callback-name := util:uuid()
    let $searchString := request:get-parameter("searchstr",())
    let $files := for $n in $col/*[contains(., $searchString)] return root($n)
    let $paging := local:get-paged-items($files) 
    let $response := response:set-header("Content-type","text/html")
    return
   
    <div>
    <table id='{$callback-name}'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging/start to $paging/end]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $class := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq xmldb:get-current-user()
            let $read-permissions := xmldb:get-permissions($f-col, $f-name) = ($browse:closed-and-available,$browse:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $class
                else if ($owner-is-me) then concat($class, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($class eq "xml"))
                then name($f/*)
                else $class
            let $title := if ($read-permissions or $owner-is-me) then concat($doctype,":", $file-path) else $owner
            return if (not($available)) then () else
            <tr title='{$title}' class='{string-join(($locked-class,$doctype)," ")}'>
                <td class='tablabel'>{document-uri($f)}</td>
                <td>{name($f/*)}</td>
                <td>--</td>
                <td>--</td>
            </tr>
        }
    </table>
    
    <script type='text/javascript'> 
    gs["{$callback-name}"] = {{
        rp: {$paging/rp/text()},
		page: {$paging/current/text()},
		pages:{$paging/pages/text()},
		cp: {$paging/current/text()}, 
        usepager:true 
    }};
    </script>
    </div>
};

(:
    Get the name of the parent collection from a specified collection path.
:)
declare function browse:get-parent-collection($path as xs:string) as xs:string {
    if($path eq "/db") then
        $path
    else
        replace($path, "/[^/]*$", "")
};
(:  This is nice, but doesn't add an ID and allows creation of fragment-elements (like "item" which is a child of ca-resources) :)
declare function local:new-file($doctype, $colname,$file-name) {
    let $new-file := element {$doctype} {
        attribute created-by {xmldb:get-current-user()}, 
        attribute created-dateTime {current-dateTime()}
        }
    return xmldb:store($colname, $file-name, $new-file)
};

declare function local:good-file-name($n,$type) {
    if ($type ne 'collection') 
    then concat(replace(tokenize($n,"\.")[1],"[\W]+","-"), ".xml")
    else replace(tokenize($n,"\.")[1],"[\W]+","-")
};
(:
declare function browse:do-new() {
    let $colnameStr := request:get-parameter("collection","")
    let $colname := if ($colnameStr eq "") then $browse:base-collection else $colnameStr
    let $item-type := request:get-parameter("doctype","") 
    let $file-name := local:good-file-name(request:get-parameter("file-name",""),$item-type)
    let $redirect-path := response:set-header("RESET_PARAMS","action=browse") (\:The header MUST have a value or it won't be received by the client:\)
    return 
        if ($item-type eq "" or $file-name eq "") then browse:display-collection($colname)
        else 
        let $result :=  
            if ($item-type eq "collection")
            then xmldb:create-collection($colname,$file-name) (\: TODO fix permissions and ownership :\)
            else local:new-file($item-type,$colname,$file-name)
        return browse:display-collection($colname)
};:)


(: browse is the default action :)
(:     if ($browse:action eq "browse") then browse:display-collection(request:get-parameter("collection",$browse:base-collection))
else if ($browse:action eq "Search") then browse:display-search-results(request:get-parameter("collection",$browse:base-collection))
else if ($browse:action eq "XPath Search")  then browse:xpath-search()
else if ($browse:action eq "JSON")   then browse:json-xpath-lookup()
else if ($browse:action eq "New")    then browse:do-new()
else <result status='error'>Unknown action {$browse:action} </result>:)

