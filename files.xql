xquery version "3.0";
(: 
    Top-level List View: browse files, xqueries and collections.
    This file has setUid applied. It will run as admin.
    THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN.
:)

(:
    Need to rethink this - XQuery/XPath 3 is composable and has higher-order functions. 
    
    And here's another think to think about.
    Because the 'list' is NOT XHR, I can't perform those simple XHR actions like
    create, delete, move 
    without a page-refresh and redirect after post.
    
    Unless somehow I use the XHR and refresh
    Instead of POST and redirect, use XHR and refresh.
    
    Or even, XHR and then go to the location returned
    $.post(files.xql, data, function(response) { if (response.href) location.href = response.href; })
:)


(:declare namespace browse = "http://www.gspring.com.au/file-browser";:)

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

(:import module namespace permissions = "http://www.gspring.com.au/pekoe/admin-interface/permissions"  at "admin/permissions.xqm";:)
import module namespace list-wrapper = "http://pekoe.io/list/wrapper" at "list-wrapper.xqm";

declare variable $local:default-pass := "staffer";
declare variable $local:open-for-editing :=       "rwxr-----";
declare variable $local:closed-and-available :=   "r--r-----"; 
declare variable $local:xquery-permissions :=     "rwxr-x---";
declare variable $local:collection-permissions := "rwxrwx---";

declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:filter-out := ("xqm","xsl");
declare variable $local:action := request:get-parameter("action","browse");
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;
declare variable $local:current-user := sm:id()//sm:real;
declare variable $local:tenant-admin-group := "admin_" || $local:tenant;
declare variable $local:user-is-admin-for-tenant := local:user-is-admin-for-tenant();



(:
<sm:id xmlns:sm="http://exist-db.org/xquery/securitymanager">
    <sm:real>
        <sm:username>admin</sm:username>
        <sm:groups>
            <sm:group>perskin@conveyancingmatters.com.au</sm:group>
            <sm:group>tdbg@thedatabaseguy.com.au</sm:group>
            <sm:group>jerskine@conveyancingmatters.com.au</sm:group>
            <sm:group>dba</sm:group>
        </sm:groups>
    </sm:real>
</sm:id>
:)
 

(: Doctypes are provided by the schema@for attributes. :)
declare function local:doctype-options() {
    let $general-doctypes := collection("/db/pekoe/common/schemas")/schema/@for/data(.) 
    let $current-col := request:get-parameter("collection",())
(:  maybe this should be specific to the tenant rather than the current collection? :)
    let $local-doctypes := collection($local:tenant-path)/schema/@for/data(.)
    for $dt in ($general-doctypes, $local-doctypes)
    order by $dt
    return <option>{$dt}</option>
};

(:
    Display the contents of a collection in a table view.
:)

declare function local:quarantined-path($real-path) {
    substring-after($real-path, $local:tenant-path)
};

declare function local:user-is-admin-for-tenant() {
sm:is-dba($local:current-user/sm:username) or sm:get-user-groups($local:current-user/sm:username) = $local:tenant-admin-group

};

declare function local:table-wrapper($path, $colName, $rows) {
    let $searchstr := request:get-parameter("searchstr", ())
    let $xpath := request:get-parameter("xpath","")
    return
  <div class='container-fluid'>
    <div class='row'>
        <div class='btn-toolbar' role='toolbar' aria-label="List controls">
            
            {
            (: If the user is dba or is the admin user for the current tenant then show the Delete and New buttons and Rename :)
                if ($local:user-is-admin-for-tenant) then
            
            <div class="dropdown btn-group">
              <button class="btn btn-default dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">
                File
                <span class="caret"></span>
              </button>
              <ul class="dropdown-menu  p-needs-selection" role="menu" aria-labelledby="dropdownMenu1">
                <li role="presentation"><a class='menuitem' role='menuitem' tabidndex='-' href='#'>New</a></li>
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="#">Rename</a></li>
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="#">Delete</a></li>
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="#">Unlock</a></li>
              </ul>
            </div>
           (:<!-- <div class='btn-group' role='group' aria-label='Other actions'>
                <!--button id='bookmarkItem' type='button' class='btn btn-default p-needs-selection'>Bookmark</button
               <button id='newItem' type='button' class='btn btn-default p-needs-selection'>New</button>
                <button id='unlockItem' type='button' class='btn btn-default'>Unlock</button>
                <button id='deleteItem' type='button' class='btn btn-default p-needs-selection'>Delete</button>
                <button id='renameItem' type='button' class='btn btn-default p-needs-selection'>Rename</button>
            </div> --> :)
            else ()
            }
            <div class='btn-group'>
                 <form method="POST" enctype="multipart/form-data" class='form-inline'>
                    <span class="btn btn-default btn-file"><input type="file" name="fname"/></span>
                    <button type="submit" value="upload" name="action"  class='btn btn-default'><i class='glyphicon glyphicon-upload'></i>Upload</button>                                                          
                 </form>            
            </div>
            <div class='btn-group'>
                 <form method="GET" class='form-inline'><input type='hidden' name='collection' value='{$path}' />
                      
                    <select name='doctype' id='doctype' class='form-control'>   
                        <option disabled='disabled' selected='selected'>make new item...</option>   
                        <option value="collection">Folder</option>
                        <optgroup label='Schemas:'>
                    {
                       local:doctype-options()
                    }
                    </optgroup>
                    </select> 
                    <input id='filename' type='text' name='file-name'  class='form-control' placeholder='with name'/>
                    <button type='submit' class='btn btn-default' name='action' value='create' >New</button> (in {$path})
                    </form>
               </div> 
               <div class='btn-group'>
                <form method="GET" class='form-inline'>
                    
                    <input type='hidden' name='collection' value='{$path}' />
                    <input type='text' name='searchstr' value='{$searchstr}' class='form-control'/>
                    <button type="submit" value="Search" name="action" class='btn btn-default'>Search all text</button>
                    <span data-href='/exist/pekoe-app/files.xql?action=Search&amp;collection={$path}' 
                    data-title='Search {$path}' 
                    data-type='search'
                    data-params='searchstr'><i class='glyphicon glyphicon-bookmark'/></span>
                </form>
            </div>
             <div  class='btn-group' >
                     <form method='get' class='form-inline'>

                         <input type='hidden' name='collection' value='{$path}'/>
                         <input type='text' name='xpath' value='{$xpath}' id='xpath' class='form-control'/>
                         <button type="submit" value="xpath" name="action"  class='btn btn-default'>XPath Search</button>
                     </form>
                 </div>
            </div>
         </div>
            { ()
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
            }
            
            <table class='table'>
                <thead>
                <tr>
                    <th>Name</th>
                    <th>Permissions</th>
                    <th>Owner</th>
                    <th>Group</th>
                    <th>Created</th>
                    <th>Modified</th>
                    <th>Size/Nodes*</th>
                </tr>
                </thead>
                <tbody>
            { $rows }
            </tbody>
        </table>
    </div>
    
};
  
declare function local:get-ordered-items($items) {
    for $c in $items
    order by $c
    return $c
};

(:
    This is the main list query.
    Currently, it lacks SORTING and should incorporate the Text and XPath searches
:)

declare function local:display-collection() 
{
    let $logical-path := request:get-parameter("collection",$local:base-collection)
    
    let $real-collection-path := $local:tenant-path || $logical-path (: $colpath is expected to start with a slash :)

    
    let $collections := xmldb:get-child-collections($real-collection-path)
    let $queries := xmldb:get-child-resources($real-collection-path)[substring-after(.,".") eq 'xql']
(:    NOTE - IF  I want to display BINARY files I'll have to modify the script on line 217 ************************************  :)
    
    let $jobs := xmldb:get-child-resources($real-collection-path)[substring-after(.,".") eq 'xml']
    let $other-docs := xmldb:get-child-resources($real-collection-path)[substring-after(.,".") = ('txt','docx','odt','ods','xsl')]
    let $params := "collection=" || $logical-path
    let $pagination-map := list-wrapper:pagination-map($params, ($collections,$queries,$other-docs,$jobs)) (: Count the items, work out start and end indices. :)
    let $debug := util:log('debug', 'GOT ITEMS ' || $pagination-map('items'))

    let $count := count($collections)
(:    NOTE this looks like a bug in eXist-db. In the first form, the ordering is all wrong when the position() is used before sorting. :)
(:    let $col-rows := for $c in $collections[position() = $pagination-map('start') to $pagination-map('end')] order by $c return local:format-collection($logical-path, $real-collection-path, $c):)
    let $col-rows := for $c in local:get-ordered-items($collections)[position() = $pagination-map('start') to $pagination-map('end')] return local:format-collection($logical-path, $real-collection-path, $c)
    
    let $start := $pagination-map('start') - $count ,
        $end := $pagination-map('end') - $count,
        $count := count($queries)
    let $query-rows := for $c in local:get-ordered-items($queries)[position() = $start to $end] order by $c return local:format-query($logical-path, $real-collection-path, $c)
    let $start := $start - $count,
        $end := $end - $count,
        $count := count($other-docs)
    let $doc-rows := for $c in local:get-ordered-items($other-docs)[position() = $start to $end] order by $c return local:format-binary-resource($logical-path, $real-collection-path, $c)
    
    let $start := $start - $count ,
        $end := $end - $count,
        $count := count($jobs)
    let $resource-rows := for $c in local:get-ordered-items($jobs)[position() = $start to $end] order by $c return local:format-resource($logical-path, $real-collection-path, $c)
    let $results := map {
        'title' := $logical-path,
        'path' := $logical-path,
        'body' := local:table-wrapper($logical-path, $real-collection-path, ($col-rows,$query-rows,$doc-rows,$resource-rows)),
        'pagination' := list-wrapper:pagination($pagination-map),
        'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $logical-path)
        }
    return
       list-wrapper:wrap($results)
};

declare function local:format-collection($logical-path, $real-collection-path, $child) {
    let $path := $real-collection-path || '/' || $child
    let $child-path := $logical-path || '/' || $child
    let $permissions := sm:get-permissions(xs:anyURI($path)),
        $created := xmldb:created($path) 
    return
    <tr class='collection' data-href='/exist/pekoe-app/files.xql?collection={$child-path}' data-title='{$child}' data-type='folder' data-path='{$child-path}'>
        <td><i class='glyphicon glyphicon-folder-close'></i>{$child}</td>
        <td class="perm">{string($permissions/sm:permission/@mode)}</td>
        <td>{string($permissions/sm:permission/@owner)}</td>
        <td>{string($permissions/sm:permission/@group)}</td>
        <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td/>
        <td/>
    </tr>
};


declare function local:format-query($logical-path, $real-collection-path, $child) as element()* {
    let $path := $real-collection-path || '/' || $child
    let $child-path := $logical-path || '/' || $child
    let $permissions := sm:get-permissions(xs:anyURI($path)),
        $created := xmldb:created($real-collection-path, $child),
        $modified := xmldb:last-modified($real-collection-path, $child)
    return
    <tr class='xql' data-href='/exist/pekoe-files/{$child-path}' data-title='{$child}' data-type='report' data-path='{$child-path}'>
        <td><i class='glyphicon glyphicon-list'></i>{$child}</td>
        <td class="perm">{string($permissions/sm:permission/@mode)}</td>
        <td>{string($permissions/sm:permission/@owner)}</td>
        <td>{string($permissions/sm:permission/@group)}</td>
        <td>{format-dateTime($created,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td>{format-dateTime($modified,"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
        <td/>
    </tr>
};

declare function local:format-resource($logical-path, $real-collection-path, $child as xs:string) {
    
    let $file-path := concat($real-collection-path,"/",$child) (: This is the real path in the /db :)
(:    let $log := util:log('warn', "FORMAT RESOURCE FOR " || $child || " at PATH " || $file-path):)
        return if (not(sm:has-access(xs:anyURI($file-path),'r'))) then ()
        else 
        let $safe-path := local:quarantined-path($file-path)

        (:  Owner and permissions      :)
        let $smp := sm:get-permissions(xs:anyURI($file-path))
        
        (:        <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">
                    <sm:acl entries="0"/>
                </sm:permission>
        :)
        
        let $owner := string($smp//@owner)
        let $current-user := string($local:current-user/sm:username)
        let $owner-is-me := $owner eq $current-user

        let $permission-to-open := $smp//@mode eq $local:closed-and-available

    
        let $short-name := substring-before($child, ".")
        let $doctype := name(doc($file-path)/*) 
        let $href := $doctype || ":/exist/pekoe-files" || $safe-path
        let $size-indicator := string(count(doc($file-path)/descendant-or-self::node())) || "*"

        order by lower-case($child)
        return
            <tr>
               {
                if ($owner-is-me or $permission-to-open) 
                then (
                    attribute title {$href},
                    attribute class {if ($owner-is-me) then "locked-by-me xml" else "xml"},
                    attribute data-href {$href},
                    attribute data-path {$safe-path},
                    attribute data-title {$short-name},
                    attribute data-type {'form'},
                    attribute data-target {'other'}
                )
                else (
                    attribute title {$owner},
                    attribute class {"locked xml"}
                )
               
               }
                <td class='tablabel'><i class='glyphicon glyphicon-list-alt'></i>{$short-name}</td>
                <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($real-collection-path, $child))}</td>
                <td>{$owner}</td>
                <td>{xmldb:get-group($real-collection-path, $child)}</td>
                <td>{format-dateTime(xmldb:created($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>{format-dateTime(xmldb:last-modified($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>{$size-indicator}</td>
            </tr>
};


declare function local:format-binary-resource($logical-path, $real-collection-path, $child) {
    let $file-path := concat($real-collection-path,"/",$child) (: This is the real path in the /db :)
        return if (not(sm:has-access(xs:anyURI($file-path),'r'))) then ()
        else 
        let $safe-path := local:quarantined-path($file-path)

        (:  Owner and permissions      :)
        let $smp := sm:get-permissions(xs:anyURI($file-path))
        
        (:        <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">
                    <sm:acl entries="0"/>
                </sm:permission>
        :)
        
        let $owner := string($smp//@owner)
        let $current-user := string($local:current-user/sm:username)
        let $owner-is-me := $owner eq $current-user

        let $permission-to-open := true() (:$smp//@mode eq $local:closed-and-available:)

    
        let $short-name := substring-before($child, ".")
        let $doctype := substring-after($child,".")
        let $href := $doctype || ":/exist/pekoe-files" || $safe-path
        (:let $size-indicator := string(count(doc($file-path)/descendant-or-self::node())) || "*":)

        order by lower-case($child)
        return
            <tr>
               {
                if ($owner-is-me or $permission-to-open) 
                then (
                    attribute title {$href},
                    attribute class {$doctype},
                    attribute data-href {$href},
                    attribute data-path {$safe-path},
                    attribute data-title {$short-name},
                    attribute data-type {'other'},
                    attribute data-target {'other'}
                )
                else (
                    attribute title {$owner},
                    attribute class {"locked xml"}
                )
               
               }
                <td class='tablabel'>{
                switch ($doctype) 
                    case "odt" return <i class='fa fa-file-code-o'></i>
                    case "docx" return <i class='fa fa-file-word-o'></i>
                    case "ods" return <i class='fa fa-file-code-o'></i>
                    case "xlxs" return <i class='fa fa-file-excel-o'></i>
                    case "txt" return <i class='fa fa-file-text-o'></i>
                    default return <i class='fa fa-file-o'></i>
                }{$short-name}</td>
                <td class="perm">{xmldb:permissions-to-string(xmldb:get-permissions($real-collection-path, $child))}</td>
                <td>{$owner}</td>
                <td>{xmldb:get-group($real-collection-path, $child)}</td>
                <td>{format-dateTime(xmldb:created($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>{format-dateTime(xmldb:last-modified($real-collection-path, $child),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")}</td>
                <td>&#160;</td>
            </tr>
};

    
declare function local:json-xpath-lookup() {

    '[',string-join(
    let $col := request:get-parameter("collection", $local:base-collection)
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
declare function local:xpath-search() {
    let $logical-path := request:get-parameter("collection",$local:base-collection)
    let $col := $local:tenant-path || $logical-path (: $colpath is expected to start with a slash :)
    let $search := request:get-parameter("xpath",())
    let $xpathsearch := concat("collection('",$col,"')", $search)
    
    let $results  := util:eval($xpathsearch) (: get all the result nodes :)
    let $jobs := for $f in $results return root($f)
    let $params := "collection=" || $logical-path || "&amp;action=xpath&amp;xpath=" || $search 
    let $pagination-map := list-wrapper:pagination-map($params, $jobs)
    let $count := $pagination-map('items')
(:    let $log := util:log("debug", concat("################################### XPATH Search: ",$xpathsearch, " got COUNT  ",$count) ):)
    let $start := $pagination-map('start'),
        $end := $pagination-map('end')
(:    let $log := util:log("warn", "START " || $start || " END " || $end):)
    let $resource-rows := for $c in $jobs[position() = $start to $end] order by $c return local:format-resource(util:collection-name($c), $col, util:document-name($c))

(:    results required for the wrapper..:)
     let $results := map {
        'title' := $logical-path,
        'path' := $logical-path,
        'body' := local:table-wrapper($logical-path, $col, $resource-rows),
        'pagination' := list-wrapper:pagination($pagination-map),
        'breadcrumbs' := list-wrapper:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $logical-path)
        }
    return
       list-wrapper:wrap($results)
       
       
};

(:let $page := 
    <div>
    <table id='{$callback-name}' class='table'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging('start') to $paging('end')]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
            let $file-type := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq sm:id()//sm:username
            
(\:            Most of this is replication of code in resource-management - but it can't be imported because it uses sm:id :\)
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (\:if (not($read-permissions)) then "locked" else ():\)
                if ($read-permissions) then $file-type
                else if ($owner-is-me) then concat($file-type, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($file-type eq "xml"))
                then name($f/*)
                else $file-type
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
    </div>:)
    

declare function local:display-search-results() {
    let $path := request:get-parameter("collection",$local:base-collection)
    let $colpath := $local:tenant-path ||  $path
    let $col := collection($colpath ) (:Base collection for search:)
    let $callback-name := util:uuid()
(:    Note: a range index will be used if defined - otherwise brute force. This one should probably be a full-text index. But it would need to be defined. 
        The NEW range index supports general comparisons (eq etc), plus starts-with, ends-with and contains. Not matches. Matches requires the old range index.
        New index is
        <range>
            <create qname="mods:namePart" type="xs:string" case="no"/>
            <create qname="mods:dateIssued" type="xs:string"/>
            <create qname="@ID" type="xs:string"/>
        </range>
        
        old index is without the <range>
:)
    let $searchString := request:get-parameter("searchstr",())
    let $debug := util:log('debug', 'SEARCH FOR STRING ' || $searchString || ' IN COLLECTION ' || $colpath)
    let $files := for $n in $col/*[contains(., $searchString)] return root($n)
    let $paging := list-wrapper:pagination-map("collection=" || $path, $files) 
    return
   
    <div>
    <table class='table'>
        <tr><th>Path</th><th>Doctype</th><th>Field</th><th>Context</th></tr>
        {
            for $f in $files[position() = $paging('start') to $paging('end')]
            let $f-col := util:collection-name($f)
            let $f-name := util:document-name($f)
            let $file-path := document-uri($f)
            
(:          This is fairly common for all lists. Pagination, Ownership, File type 
            What changes is the initial SELECTION, and the FIELDS. 
            So Ideally I would be passing a SELECTION function and a FORMAT RESULTS function
            The FORMAT RESULTS function would be some kind of map or XML structure that provides the TH info
            including SORTing 
            
            In this query, I have about 3 instances of the same code with minor variations. The booking-list is similar.
            Not Identical, but similar.
            The only other major change is that sometimes the "files" are "records" in a single file.
:)
            let $file-type := "xml"
            
            let $owner := xmldb:get-owner($f-col, $f-name)
            let $owner-is-me := $owner eq sm:id()//sm:username
            
            let $smp := sm:get-permissions(xs:anyURI($file-path))
            let $read-permissions := $smp//@mode = ($local:closed-and-available, $local:xquery-permissions)
            let $locked-class :=  (:if (not($read-permissions)) then "locked" else ():)
                if ($read-permissions) then $file-type
                else if ($owner-is-me) then concat($file-type, " locked-by-me") 
                else " locked"
        
            let $short-name := substring-before($f-name,'.')
            let $available := if (util:is-binary-doc($file-path)) then util:binary-doc-available($file-path) else doc-available($file-path)
            let $doctype := if ($available and ($file-type eq "xml"))
                then name($f/*)
                else $file-type
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

    </script>
    </div>
};

(:
    Get the name of the parent collection from a specified collection path.
:)
declare function local:get-parent-collection($path as xs:string) as xs:string {
    if($path eq "/db") then
        $path
    else
        replace($path, "/[^/]*$", "")
};

(: ***************************************     FILE UPLOAD ***********************************  :)
declare function local:file-upload() {
    let $safe-collection := request:get-parameter("collection", ())
    let $collection := $local:tenant-path || $safe-collection
    let $name := request:get-uploaded-file-name("fname")
    let $file := request:get-uploaded-file-data("fname")
    let $log := util:log("debug", "GOING TO STORE " || $name || " INTO COLLECTION " || $collection)
    let $stored := xmldb:store($collection, xmldb:encode-uri($name), $file)
    return response:redirect-to(xs:anyURI(request:get-url() || '?collection=' || $safe-collection))
};


(:  This is nice, but doesn't add an ID and allows creation of fragment-elements (like "item" which is a child of ca-resources) :)
declare function local:new-file($doctype, $colname,$file-name, $group-user) {
    let $new-file := element {$doctype} {
    attribute created-dateTime {current-dateTime()},
    attribute created-by {$local:current-user/sm:username/text()}
        
        }
    let $new := xmldb:store($colname, $file-name, $new-file)
    let $uri := xs:anyURI($new)
    let $chown := sm:chown($uri, $group-user)
    let $chgrp := sm:chgrp($uri,$group-user)
    let $chmod := sm:chmod($uri,'r--r-----')
    return $new 
};

declare function local:good-file-name($n,$type) {
    if ($type ne 'collection') 
    then concat(replace(tokenize($n,"\.")[1],"[\W]+","-"), ".xml")
    else replace(tokenize($n,"\.")[1],"[\W]+","-")
};

(:
    So for functions inside /db/apps/pekoe - which are common for all tenants - it might be 
    useful to setUid as admin (or another specific dba user) on those scripts
    so that the script can execute system:as-user(group-user, standard-password, code-block)
    Then, any resources will be owned by the group-user.
    setGid will ensure that all collections and resources in a tenancy will belong to the group-user.

:)

(: Such good code. I have just accidently deleted my test /files directory.  20141213.
    
    Can I do a backup prior to deletion?
    Only admin can do a backup. 
    Option 1: set this file as admin setUid (bad idea)
    Option 2: use compression to backup the directory instead
    Option 3: use a pipeline in the controller to handle this 
    Option 4: send delete to a different xql with setUid
    
    Problem with setUid is that it will override the permissions that should be checked prior to a deletion.
    
    AND this file ALREADY has setUID - which is possibly why my files were trashed.
    
    Why do I have setUid enabled on this file?
    
    :)
declare function local:do-delete() {
    let $path := request:get-parameter("path","")
    return if ($path eq $local:base-collection) then (response:set-status-code(304),response:set-header("Location", request:get-url()))
    else
    let $real-path := $local:tenant-path || $path
    let $export := system:export-silently($real-path, false(),true())
    let $parent-collection := util:collection-name($real-path)
    let $quarantined := local:quarantined-path($parent-collection)
    let $delete-log:= if (xmldb:collection-available($real-path)) 
                    then util:log("warn", "GOING TO DELETE COLLECTION (real-path)" || $real-path || " (path)" || $path )
                    else util:log("warn", "GOING TO DELETE " || util:document-name($real-path) || " FROM COLLECTION " || $parent-collection )
    let $delete:= if (xmldb:collection-available($real-path)) 
                    then xmldb:remove($real-path)
                    else xmldb:remove($parent-collection, util:document-name($real-path))
                    
    return (response:set-status-code(205),response:set-header("Location", request:get-url() || "?collection=" || $quarantined))
   (: let $resource := util:document-name($path)
    let $collection := util:collection-name($path)
    let $log := util:log("DELETE " || $resource || " FROM " || $collection)
    
    let $delete := ():)
(:        if (empty($resource))  (\: must be a collection. BE VERY CAREFUL. $collection is the PARENT!!! I inadvertently removed ALL /db/pekoe/files !!! :\)
        then xmldb:remove($local:path)
        else xmldb:remove($collection,$resource):)
    
};

declare function local:unlock-file() {
    let $path := request:get-parameter("path","") (: /files/schemas/trimmed-txo-schema.xml :)
    return if ($path eq "" ) then (response:set-status-code(304),response:set-header("Location", request:get-uri()))
    else
        let $real-path := $local:tenant-path || $path 
        let $uri := xs:anyURI($real-path)
(:        let $log := util:log("warn", "URI: " || request:get-uri()      || " VS URL: " || request:get-url()):)
(:                                      URI:      /exist/pekoe-app/files.xql  VS URL:      http://owl.local/exist/pekoe-app/files.xql:)
        let $parent := util:collection-name($real-path)
        let $quarantined := local:quarantined-path($parent)
        let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
        let $group-owner := $collection-permissions/sm:permission/data(@group)
        return 
            if (not(doc-available($real-path))) then (response:set-status-code(304),response:set-header("Location", request:get-uri()))
            else (
            util:exclusive-lock(doc($real-path), (sm:chown($uri, $group-owner), sm:chgrp($uri, $group-owner), sm:chmod($uri, "r--r-----"))),
            (response:set-status-code(205),response:set-header("Location", request:get-uri() || "?collection=" || $quarantined ))
            )
};


declare function local:do-new() {
    let $path := request:get-parameter("collection",$local:base-collection)
    let $full-path := $local:tenant-path || $path
    let $log := util:log("warn","FULL PATH IS " || $full-path)
    let $item-type := request:get-parameter("doctype","") 
    let $group-user := sm:get-permissions(xs:anyURI($full-path))//@group/string()   
    let $file-name := local:good-file-name(request:get-parameter("file-name",""),$item-type)
    let $debug := util:log('debug', 'GOING TO CREATE ' || $full-path || ' / ' || $file-name)
(:    NOTE: must find a way to redirect after this. Perhaps this should be a POST anyway - as we are 
creating a resource. The automatic RELOAD is causing this action to run again. :)
    (:let $redirect-path := response:set-header("RESET_PARAMS","action=browse"):) (:The header MUST have a value or it won't be received by the client:)
    return 
        if ($item-type eq "" or $file-name eq "") then local:display-collection()
        else 
        let $result :=  
            if ($item-type eq "collection")            
            then (
            let $new := xmldb:create-collection($full-path,$file-name)
            let $uri := xs:anyURI($new)
            let $chown := sm:chown($uri, $group-user)
            let $chgrp := sm:chgrp($uri, $group-user)
            let $chmod := sm:chmod($uri,'rwxrwx---')
            return $new 
            (: TODO fix permissions and ownership :)
            )
            else local:new-file($item-type,$full-path,$file-name, $group-user)
(:            https://owl.local/exist/rest/db/apps/pekoe/files.xql?collection=%2Ffiles&doctype=todo&file-name=test&action=New
:)
        return response:redirect-to(xs:anyURI(request:get-url() || '?collection=' || $path))
};

declare function local:title($path-parts) {
    let $t := $path-parts[position() eq last()]
    return concat(upper-case(substring($t,1,1)), substring($t,2))
};

(: ************************** MAIN QUERY *********************** :)

        
(:        try {:)
    (: browse is the default action :)
         if ($local:action eq "browse") then local:display-collection()
    else if ($local:action eq "Search") then local:display-search-results()
    else if ($local:action eq "xpath")  then local:xpath-search()
    else if ($local:action eq "JSON")   then local:json-xpath-lookup()
    
    else if ($local:action eq "unlock") then local:unlock-file()
    else if ($local:action eq "upload") then local:file-upload()
    else if ($local:action eq "create")    then local:do-new()
    else if ($local:action eq "delete") then local:do-delete()
    else <result status='error'>Unknown action {$local:action} </result>
    
(:    } catch * { "CAUGHT ERROR " || $err:code || ": " || $err:description || " " || $local:action }:)
            