xquery version "3.1";

(:
    Provides
    breadcrumbs($base, $path)
    pagination-map($path-params, $items)
    pagination($pagination-map)
    and wrap($content as map)
    where the map is {
        'title' := 'Browsing ' || $colName
        'path' := $logical-path,
        'body' := local:table-wrapper($logical-path, $real-collection-path, ($col-rows,$query-rows,$resource-rows)),
        'pagination' := lw:pagination($pagination-map),
        'breadcrumbs' := lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $logical-path)
        }
        

    I'm getting confused by the different paths being used.
    First there's the REAL path - starting with /db
    Then there's the Safe Path which starts after the tenant e.g. /db/pekoe/tenants/tdbg
    Then there's the base path which is usually '/files' 
    
    The old 'files.xql' used a 'logical-path' which is from the tenant - defaulting to /files
    safe-path
    quarantined-path - the path of 'the current query' (not this module)
    
:)

module namespace lw = "http://pekoe.io/report/wrapper";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";

declare variable $lw:action := request:get-parameter("action","list"); (: Must have useful default for when activated by browse-list:)
declare variable $lw:method := request:get-method();


declare variable $lw:aust-dateTime-picture :=  "[D01] [M01] [Y0001] [H01]:[m01]:[s01]";
declare variable $lw:aust-date-picture :=   "[D01]/[M01]/[Y0001]";

declare variable $lw:tenant-admin-group := "pekoe-tenant-admins";
declare variable $lw:user-is-admin-for-tenant := true(); (:lw:user-is-admin(); :)
declare variable $lw:user-is-dba := false(); (:sm:is-dba(sm:id()//sm:real/sm:username/string());:)

declare variable $lw:path-to-me := request:get-servlet-path(); (:Perfect!:)
(: The quarantined path assumes that the query is tenant-based. But pekoe-app/files.xql is a special case. 
    Instead of setting this here - it should be part of the conf. It can USE this variable, but must be overridden for this special case.
:)
declare variable $lw:quarantined-path := substring-after($lw:path-to-me, $tenant:tenant-path); (: DOESN'T WORK WITH pekoe-app/files.xql   /files/AD-Bookings.xql  :)
declare variable $lw:base-collection-path := '/files';

declare function lw:configure-content-map($config-map) {
    (: Must provide defaults for these.   :)
    let $base-map := map {
        'display-title' : function($item) { $item/*[1]/string() }       (: the string-value of the first child element will be the default title of a new Tab for 'this item'. :)
    }
    let $custom-conf := map:new (($base-map,$config-map))               (: Now override that base-map with your List config. :)
    
    (: This main map will have access to the intial $custom-conf. By adding things to the base-map above, I can guarantee that the functions will be available.
        The following items can all be overridden by your List. 
    :)
    return 
        map {
        'path' : request:get-parameter("collection", $lw:base-collection-path),  (: default is /files. Override this. :)
        'path-to-me' : '/exist/pekoe-files/' || $lw:quarantined-path, (: overridden by /exist/pekoe-app/files.xql ONLY :)
        
        'row-attributes' : function ($item, $row-data) {  (: The HTML attributes for this table-row. :)
            let $colName := util:collection-name($item)
            let $child := util:document-name($item)
            let $quarantined-path := substring-after($colName || '/' || $child, $tenant:tenant-path)    
            let $path := '/exist/pekoe-files' || $quarantined-path
            let $display-title := $custom-conf?display-title($item)           
            let $permissions := lw:doc-permissions($colName || '/' || $child)
            let $doctype := $custom-conf?doctype(())                            (:????:)
            return
            ( 
            if ($permissions?available) 
            then ( attribute title {$quarantined-path}, attribute class {if ($permissions?owner-is-me) then "locked-by-me xml" else "xml"})
            else (   attribute title {'locked by ' || $permissions?owner}, attribute class {'locked xml'}),
            attribute data-title {$display-title}, 
            attribute data-href {$doctype || ":" || $path },
            attribute data-path {$quarantined-path},
            attribute data-type {'form'})
        },
        
        'row-function' : function ($row) {
            let $path := document-uri($row/root()) 
            return map { 
                'path' : $path, 
                'quarantined-path' : tenant:quarantined-path($path),
                'doctype' : $custom-conf?doctype($row)
                }
        },
        'custom-row-parts' : ['list-all', 'new-xxx','text-search', 'xquery-search'],
        'search' :  request:get-parameter('search',''),
        'xpath' : request:get-parameter("xpath",""),
        'custom-row' : map { (: map of functions producing each item in the control row above the table :)
            'list-all'      : function ($conf) {
             
                <div class='btn-group'>
                    <form method='get' action=''>
                        <button class='btn' type='submit' name='action' value='List'>List all</button>
                    </form>
                </div>
                },
            'new-xxx'       : function ($conf) {
                <div class='btn-group'>
                    <button class='btn pekoeTabButton' data-title='New {$conf?doctype}' data-href='{$conf?doctype}:/exist/pekoe-files/config/new-job.xql?id=new' data-type='form'>New {$conf?doctype}</button>
                    <span title='drag me to your bookmarks'
                            data-href='{$conf?doctype}:/exist/pekoe-files/config/new-job.xql?id=new' 
                            data-title='New {$conf?doctype}' 
                            data-type='form'><i class='glyphicon glyphicon-bookmark'/></span>
                </div>
                },
            'text-search'   : function ($conf) {
                <div class='btn-group'>
                    <form method='get' action='' class='form-inline'>
                        <input type='hidden' name='collection' value='{$conf?path}'/>
                        <input type='text' name='search' value='{$conf?search}' id="search" placeholder='Any Text' class='form-control'/>
                        <input  class='btn' type='submit' name='action' value='Search' />
                    </form>
                </div>
                },
            'xquery-search' :  lw:xquery-search-btn#1
            } (: end of the custom-row map :)
        } 
};


declare function lw:xquery-search-btn($conf) {
    <div class='btn-group' ><!-- XQuery search -->
        <form method='get' class='form-inline' action=''>
           <input type='hidden' name='collection' value='{$conf?path}'/>
           <input type='text' placeholder='/{$conf?doctype}[...]' name='xpath' value='{$conf?xpath}' id='xpath' class='form-control'/>
           <button type="submit" value="xpath" name="action"  class='btn btn-default'>XQuery</button>
            {
           (: If the xquery contains a parameter then the bookmark should be a search.  :)
            if ($conf?xpath eq '') then ()
            else if (contains($conf?xpath, '$')) then (
               (: This is for the SEARCH param :)
               let $parts := analyze-string($conf?xpath, '\$\w+')  
               return 
               <span style='cursor:move' title='bookmark for XQuery with parameter in {$conf?path}'
                   data-href='{$conf?path-to-me}?action=xpath&amp;collection={$conf?path}&amp;xpath={$conf?xpath}'
                   data-title='' 
                   data-type='search'
                   data-param='{substring-after($parts//fn:match,'$')}'><i class='glyphicon glyphicon-bookmark'/></span>
            )
            else (
               (: This is a standard bookmark. :)
                <span draggable='true' title='bookmark for XQuery in {$conf?path}' 
                   data-href='{$conf?path-to-me}?action=xpath&amp;collection={$conf?path}&amp;xpath={$conf?xpath}' 
                   data-title='' 
                   data-type='report'><i class='glyphicon glyphicon-bookmark'/></span>
            )
           
           (:Probably should put this script into the list page instead of here. :)
            }
           <script>
             // <![CDATA[
               var f = function () {
                   var $x = $('#xpath');
                   $x.on('keyup',function () { // adjust the width of the input
                       var t = $x.val();
                       
                       var $s = $('<span></span>').css('display','none');
                       $x.after($s);
                       $s.text(t);
                       var w = $s.width() + 24;
                       if ($x.width() < w) {
                         $x.width(w);
                       }
                       $s.remove();
                   });
                   var $f = $x.parent('form');
                   $f.on('submit', function(e){
                       // to keep things simple, work on either $text or $date inputs.
                       // I want to allow more than one text entry and more than one date.
                       // $text1, $text2, $date, $date1 $date2
                       if ($x.val().indexOf('$date') > 0) { // does the xquery contain a date param?
                           if ($f.find('input[name=date]').length > 0) { // is there already an input for it?
                               //console.log('found an input');
                               return true; 
                           }
                           // no input - so add one and focus on it.
                           e.preventDefault();                                        
                           var input = $('<input type="date"  class="form-control" placeholder="yyyy-mm-dd"></input>').attr('name','date').datepicker({dateFormat:'yy-mm-dd'}); // HTML5 date picker not working
                           $x.after(input); // put it after the xquery, but before the buttton
                           input.focus();
                           return false;
                       } 
                       // I think maybe this should be an else with 'text' as the default. The param and placeholder should be named usefully - e.g. jobowner
                       else if ($x.val().indexOf('$text') > 0) { // does the xquery contain a text param?
                           if ($f.find('input[name=text]').length > 0) { // is there already an input for it?
                               //console.log('found an input');
                               return true; 
                           }
                           // no input - so add one and focus on it.
                           e.preventDefault();                                        
                           var input = $('<input type="text" class="form-control" placeholder="text"></input>').attr('name','text'); // HTML5 date picker not working
                           $x.after(input); // put it after the xquery, but before the buttton
                           input.focus();
                           return false;
                       } 
                       
                       else { return true; } 
                   });
               
               }();
               
               //]]>
           </script>
        </form>
    </div>
};


declare function lw:parse-xpath($xpath) {
    let $parts := analyze-string($xpath, '\$\w+')  (: pull out any $params in the string:)
    (:  Replace $param with $map?param in the xpath  :)
    let $modified-xpath:= string-join(for $e in $parts/* return typeswitch ($e) case element(fn:non-match) return $e/text() case element(fn:match) return replace($e, '\$','\$map?') default return '', '')
        
    return map:new(
        ( map {'xpath' := $modified-xpath},
          for $p in $parts//fn:match let $k := substring-after($p,'$') return map{ $k := request:get-parameter($k,()) } 
          )
    )
};

(: 

    NOTE that the 'collection' parameter IS used - but it's WRONG - it's the safe-path not the db path.
    The 'Issues' xquery works because the collection path is empty - collection()/query
    
    If I provides '$items' then my xpaths would probably be wrong as they are all top-level.
    So items is WRONG and the collection must be supplied.
    
    :)
declare function lw:xpath-search($items) { 
    util:log('warn', 'SCRIPT USING BAD XPathSearch with $items - ' || $lw:path-to-me),
    lw:xpath-search() 
};
declare function lw:xpath-search() {
(: I need to ensure that the correct collection is used.  :)
    
    let $search := request:get-parameter("xpath",())
    let $cu-name := sm:id()//sm:real/sm:username/string() (:$lw:current-user/sm:username/string():)
    let $check := if (matches($search,'util:eval|update')) 
        then (util:log-app('warn','login.pekoe.io','%%%%%%%%%%%% USER ' || $cu-name || ' ATTEMPTED UNSAFE SEARCH: ' || $search),
            error((),'User ' || $cu-name || ' attempted unsafe search. This has been reported.')) 
        else ()

    let $logical-path := request:get-parameter("collection",'/files')
    let $colpath := $tenant:tenant-path || $logical-path (: $colpath is expected to start with a slash :)
    
    let $map := lw:parse-xpath($search)
    
    let $xpathsearch := concat("collection('",$colpath,"')", $map?xpath )
    let $debug := util:log('info','XPATH SEARCH ' || $xpathsearch)
    let $results  := util:eval($xpathsearch) (: get all the result nodes :)
    return $results    
};


declare function lw:user-is-admin() {
    sm:is-dba(sm:id()//sm:real/sm:username/string()) or sm:get-user-groups(sm:id()//sm:real/sm:username/string()) = $lw:tenant-admin-group
};


declare function lw:doc-permissions($file-path) {
    (:  Owner and permissions      :)
    let $smp := sm:get-permissions($file-path)
    let $owner := $smp//@owner/string()
    let $current-user := sm:id()//sm:real/sm:username/string()   (: DON'T USE LW:CURRENT-USER:)
    let $owner-is-me := $owner eq $current-user
    let $permission-to-open := $smp//@mode eq $resource-permissions:closed-and-available
    return
         map {
            'available' : $owner-is-me or $permission-to-open,
            'owner-is-me': $owner-is-me, 
            'owner' : $owner 
        }
};

(: An array of divs for the list filters. Can be modified by each list:)
(:declare variable $lw:list-filters-array := [
    <div class='col-md-2'>
        <form method='get' action=''>
            <button class='btn' type='submit' name='action' value='List'>List all</button>
        </form>
    </div>,           
            
    <div class='col-md-5'>
        <form method='get' action=''>
            <input type='text' name='search' value='{$search}' id="search" placeholder='any text'/>
            <input  class='btn' type='submit' name='action' value='Search' />
        </form>
    </div>    
];:)

(:~
: @param $params - the static uri parameters for the breadcrumb link
: @items - the sequence of things that will be paginated. Expected to be nodes of some kind.
: also expects to find a request parameter "p" for the current page number and "rpp" for the items per page.
:)
declare function lw:pagination-map($content) {
(:  This should serve a dual purpose: provide the info for procesing the items
    and then sufficient data for the pagination code in the list-wrapper.
    TODO allow user to set RPP per list. 
    (See querytools.xqm )
    :)
    let $params :=  map:new(  
        (
        $content?params, (: I can't decide whether the content-map params should override the query-string or the reverse. :)
        for $p in tokenize(request:get-query-string(),'&amp;')
        return map:entry(substring-before($p,'='),substring-after($p,'='))
        ))
        
    let $items := $content?items
    
(: items, rpp, start, end, current, total, params :)
    let $records-per-page := local:get-request-as-number("rpp",20)
    let $current-page := local:get-request-as-number("p",1)
    let $count := count($items)
    let $total-pages := xs:integer(ceiling($count div $records-per-page))
    let $start-index := xs:integer(($current-page - 1) * $records-per-page + 1 )
    let $end-index := xs:integer($start-index + $records-per-page - 1)
    
    
    let $pages-map := map { 
        "items" : $count,
        "rpp" : $records-per-page,
        "start" : $start-index,
        "end" : $end-index,
        "current" : $current-page,
        "total" : $total-pages,
        "params" : $params
    }
    return map:new(($content, map {'pagination-map': $pages-map}))
};

declare function lw:breadcrumbs($base, $path) {
    let $path-parts := tokenize(substring-after($path,'/'),'/')
    let $last := count($path-parts)
    for $part at $i in $path-parts
    let $link := string-join($path-parts[position() le $i],'/')
    return <li>{if ($i eq $last) then $part else <a href='{$base}/{$link}'>{$part}</a>}</li>
};

declare function lw:pagination($pagination-map) {
    let $current := $pagination-map('current')
    let $total := $pagination-map('total')
    (: There are two ways to handle params.
        This approach - where I'm removing the param before adding it,
        and the other which requires map:merge - and is not yet available. 
        HOWEVER map:new() does the same thing:
        map:new((map:entry('a',1), map:entry('b',2), map:entry('a',3)))?a eq 3
    :)
    let $p := map:remove($pagination-map?params,'p')
    let $p-str := string-join(map:for-each-entry($p,function($k,$v){$k || '=' || $v}),'&amp;')
    let $path-params := if ($p-str ne '') then  $p-str || '&amp;' else ""
    
    return
    if ($total eq 1) then () 
    else 
        <nav><ul class='pagination' style='margin-top:0'>
            {
            if ($total lt 5) then (
                for $n in 1 to $total return <li>{if ($n eq $current) then attribute class {'active'} else () }<a href='?{$path-params}p={$n}'>{$n}</a></li>
            )
            else (
                let $first := max((1,$current - 2)) 
                (: first is also either $first or ($total - 4) whichever is least :)
                let $first := min(($first, $total - 4))
                let $last := min(($total, $first + 4))
                return
                
                ((:Go First:)<li>{if ($current eq 1) then attribute class {'disabled'} else ()}<a href="?{$path-params}p=1" title='First'><i class='fa fa-angle-double-left'></i></a></li>,
                (: Go Prev:)<li>{if ($current eq 1) then attribute class {'disabled'} else ()}<a title='Previous' href="?{$path-params}p={if ($current ne 1) then $current - 1 else ()}"><i class='fa fa-angle-left'></i></a></li>,
                (for $n in $first to $last return <li>{if ($n eq $current) then attribute class {'active'} else () }<a href='?{$path-params}p={$n}'>{$n}</a></li>),
                (: Go Next:)<li>{if ($current eq $total) then attribute class {'disabled'} else ()}<a title='Next' href="?{$path-params}p={if ($current eq $total) then $current else $current + 1}"><i class='fa fa-angle-right'></i></a></li>,
                (: Go Last:)<li>{if ($current eq $total) then attribute class {'disabled'} else ()}<a title='Last' href="?{$path-params}p={$total}"><i class='fa fa-angle-double-right'></i> ({$total} pages)</a></li>
                
                )
            )
            }
            <li class='disabled'><a >({$pagination-map?items} items)</a></li>
        </ul></nav>
};

declare function local:get-request-as-number($param as xs:string, $default as xs:integer) as xs:integer {
    let $requested := request:get-parameter($param, "")
    return if ($requested castable as xs:integer) then xs:integer($requested) else $default 
};

declare function lw:make-column-heading($colhead as xs:string, $content as map(*)) {
    (: Does this field have an ordering function? :)
     let $fields := $content?fields
     return
     if (not(map:contains($fields, $colhead)) or not(map:contains($fields($colhead), 'sort'))) then <th>{$colhead}</th>
     else 
     let $current-field := $content?fields($colhead)
     let $sort-key := $current-field("sort-key") (: e.g. mod-date or planet-name or discovered-date Something that can be easily passed in a query string :)
     
(:   Fix parameters. When re-ordering, the pagination is intentionally removed.  :)
     let $pm := $content?pagination-map
     let $p := map:remove($pm?params,'p')
     let $p := map:remove($p, 'order-by')
     let $p-str := string-join(map:for-each-entry($p,function($k,$v){$k || '=' || $v}),'&amp;')
     let $path-params := if ($p-str ne '') then  $p-str else ()
     let $full-params := string-join(($path-params,'order-by='),'&amp;')
     
     let $current-order-by-field := substring-after($content?order-by,'-') (: from  descending-mod-date, extract "descending" and "mod-date":)
     let $direction := substring-before($content?order-by,"-")
     let $glyphicon := if ($direction eq 'descending') then 'glyphicon-sort-by-attributes-alt' else 'glyphicon-sort-by-attributes'
     let $is-ordered := ($sort-key eq $current-order-by-field) (: Is THIS field the current 'order-by'?:)
     let $new-ordering := 
        if (not($is-ordered)) then 
            if (ends-with($sort-key,"date")) 
                then concat("descending-",$sort-key) (: The default ordering for a date field is descending :)
                else concat("ascending-",$sort-key)  (: whereas anything else will be ascending by default :)
        else if (starts-with($content?order-by,"ascending-")) (: Otherwise, reverse the current order :)
            then concat("descending-", $sort-key) 
            else concat("ascending-", $sort-key)
        
     return 
        (: The column-heading will have a link to either SET or REVERSE the current ordering. (SET if this is NOT the order-by field.) 
        /exist/pekoe-files//files/bookings.xql
        :)
    <th>{ if ($is-ordered) then (attribute class {concat("ordered ",$direction)}, <span style='margin-right:0.5em;' class="glyphicon {$glyphicon}"></span>) else ()  }<a href='{$content?path-to-me}?{$full-params}{$new-ordering}'>{$colhead}</a></th>
};

declare function lw:paginate($items) {
 $items
};

declare function lw:get-ordered-items($content as map(*) ) {
    if (map:contains($content, "order-by")) then (
        let $sort-key := substring-after($content?order-by, '-')
        let $direction := substring-before($content?order-by, '-')
        let $order-by-field := map:for-each-entry($content?fields, function ($k,$v) {$v})[?sort-key = $sort-key]
        return if ($order-by-field instance of map(*) and map:contains($order-by-field,"sort")) then $order-by-field?sort($direction, $content?items)
        else (
        util:log('info','%%%%%%%%%%%%%%%%% SORT NOT FOUND sort-key:' || $sort-key || ' direction:' || $direction || ' count:' || count($order-by-field)) ,
        $content?items
        )
    )
    else $content?items
};

(:
------------------------------------------------------------- THE MAIN FEATURE ---------------------------------------------
list-page requires a map of $content
$content:
- title
- breadcrumbs (generated using breadrumbs above)
- pagination (above)
- ordered-by (a string)
- column-headings NOTE that the keys of a map are not ordered. For column-headings I'm using an array. 
- fields - a map containing a map for each entry in column-headings. Each of these must have a 'value' function

:)
declare function lw:list-page($original-content as map(*)) {

let $content := lw:pagination-map($original-content)


return

<html>
<meta charset="utf-8"></meta>
    <head>
        <title>{$content('title')}</title>    
        <script type='text/javascript' src='/pekoe-common/jquery/dist/jquery.js' ></script>
        <link rel='stylesheet'        href='/pekoe-common/jquery-ui-1.11.0/jquery-ui.css' />
        <link rel='stylesheet'        href='/pekoe-common/dist/css/bootstrap.css' />
        <link rel='stylesheet'        href='/pekoe-common/list/list-items.css' />
        <link rel='stylesheet'        href='/pekoe-common/dist/font-awesome/css/font-awesome.min.css' />
        <script type='text/javascript' src="/pekoe-common/jquery-ui-1.11.0/jquery-ui.js" ></script>
        <script type='text/javascript' src='/pekoe-common/dist/js/bootstrap.min.js' ></script>
        <script type='text/javascript' src='/pekoe-common/list/pekoe-list-widget.js'></script>
        {
        comment {
        $original-content?path
        }
        }
        {
        
        (:
 items
 path-to-me
 path
 custom-script
 search
 column-headings
 row-attributes
 row-function
 breadcrumbs
 custom-row-parts
 doctype
 order-by
 title
 fields
 xpath
 custom-row:)
        
        comment {
            for $k in map:keys($original-content) return concat($k, '&#10;')
        }}
        
        
    </head>
<body>
 <div class='container-fluid'>
    <div class='row'>
    <div class='btn-toolbar' role='toolbar' aria-label="List controls">
        <div class='btn-group' role='group' aria-label='Breadcrumbs'>
            <ol class='breadcrumb'>{$content('breadcrumbs')}</ol>
        </div>
        
        <div class='pull-right' role='group' aria-label='Open actions'>
           
            <div class="dropdown btn-group"><!-- ##################### FILE MENU ################### -->
              <button class="btn btn-default dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">
                File menu
                <span class="caret"></span>
              </button>
              <ul class="dropdown-menu  p-needs-selection" role="menu" aria-labelledby="dropdownMenu1">
              {
              ()
              (:
              TODO  - make File Edit and View menus
                    - provide means of opening item in new Tab
                    - provide better distinction between 'menuitem' and 'actionitem'
                    
                Current items are: 
                    
                View menu - opens new tab     
                
                    Bookmarks - list -                          View
                    Reports - list                              View
                    Help - list                                 View
                    Issues - list                               View
                    Refresh - SAME TAB (and of less importance as eventually it will be redundant)
                    
                File menu - performs action on current item
                
                    Show data - selected file action - new tab
                    Rename - selected file action - refresh view 
                    Move to parent folder - selected file - refesh view
                    Delete - selected file - refresh view       
                    Unlock - selected file - refresh view       
                    
                    Open - selected item - same tab             
                    Open in new tab - selected item - new tab   
                    
                ** Strangely, the items with an data-action are 'menuitem's while those without are 'actionitems's.
                   I feel the need to fix this.
                   It will probably need to be fixed for the other Lists.
                   
                   Really, an 'actionitem' should perform an action on a file
                   They are all 'menuitem's because they're in a menu
                   So the others are what? Navigation? Links? (report, list, form?)
                   
                   The other things are:
                   
                   List all
                   (local) View menu: e.g. Payments, Bookings
                   New AD-Booking (new-xxx)
                   Refresh
                   TEXT Search
                   XQUERY Search
                   
                   New Item _type_ _name_
                   Upload
                   Add Selected Item to Bookmarks
                   Add this page to Bookmarks
                   *********** Add this page to Bookmarks List *************
                   
                   WHY AM I PUTTING BOOKMARKS INTO THIS MENU??????? ALL THE NAV ITEMS ABOVE SHOULD BE "COMMON" BOOKMARKS.
                   I think these things belong in the Pekoe bookmarks.
                   
                   THE FILE MENU SHOULD ONLY BE FOR FILE-ACTIONs
                   
                   THE VIEW MENU should be for ACTIONS ON THIS VIEW - e.g. Refresh, Search, Upload, 
                
             
              
                let $actionItem := function ($admin-only as xs:boolean, $href, $path, $type, $title, $text) {
                    if ($admin-only and lw:user-is-admin()) then
                    <li role="presentation"><a class='actionitem' role="menuitem" tabindex="-1" href="{$href}" path="{$path}" data-type='{$type}' data-title='{$title}'>{$text}</a></li>
                    else ()
                }
                let $menuItem := function ($admin-only as xs:boolean, $href, $path, $type, $title, $text) {
                    if ($admin-only and lw:user-is-admin()) then
                    <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="{$href}" path="{$path}" data-type='{$type}' data-title='{$title}'>{$text}</a></li>
                    else ()
                }
                return (
                    $actionItem(false(),    '/exist/pekoe-app/Bookmarks.xql', '/exist/pekoe-app/Bookmarks.xql','other',  'Show bookmarks list',   'Bookmarks'),
                    $actionItem(false(),   '/exist/pekoe-app/Reports.xql' ,  '/exist/pekoe-app/Reports.xql' , 'other' , 'Show reports list',     'Reports'),
                    $actionItem(false(),   '/exist/pekoe-app/Help.xql',      '/exist/pekoe-app/Help.xql',     'form',   'Show documentation list','Help'),
                    $actionItem(false(),   '/exist/pekoe-app/Issues.xql',    '/exist/pekoe-app/Issues.xql',    'other', 'Show Issues list',    'Issues'),
                    $menuItem(  false(),    '/exist/pekoe-app/manage-files.xql', '/exist/pekoe-app/manage-files.xql')
                    )
:)
              }
              
                <!--li role="presentation"><a class='menuitem' role='menuitem' tabidndex='-' href='/exist/pekoe-app/manage-files.xql'>New</a></li-->
                <!-- ADD OPEN JOB FOLDER -->
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='data' data-type='other' data-title='Raw XML'>Show data</a></li>
                {if (sm:is-dba(sm:id()//sm:real/sm:username/string())) then <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='rename' data-params='name'>Rename</a></li> else () }
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='move-up' data-confirm='yes'>Move to parent folder</a></li>
                {if (sm:is-dba(sm:id()//sm:real/sm:username/string())) then <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='delete' data-confirm='yes'>Delete</a></li> else ()}
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='unlock'>Unlock</a></li>
              </ul>
            </div>

            <button id='openItem' type='button' class='btn p-needs-selection btn-default'><i class='glyphicon glyphicon-folder-open'></i>Open</button>
            <button id='openItemTab' type='button' class='btn p-needs-selection btn-default'><i class='glyphicon glyphicon-share-alt'></i>Open in new tab</button> 
            <button id='refresh' type='button' class='btn btn-default'><i class='glyphicon glyphicon-refresh'></i>Refresh</button>  
        </div>
        <div class='pull-left' style='margin-left:1em'>{lw:pagination($content?pagination-map)}</div>
    </div>
    </div>
    

    <div class='row'>
    { 
    
    (:   In this custom-row, I want standard functions such as 'List all' , Text Search, XQuery Search.
    ALSO I want things like "New xxx", Upload File, "New item" and "Incomplete" - which are really CUSTOM.
    So the ORDER and content will need to be in an array
    and then I will just map the array to output
    But I need to have the default functions in the config, and then the custom bits are added by the calling query. How?
    
    Would each one be a function? an array of functions?
    or only some? (and so test?)
:)

        let $parts := $content?custom-row (: a map of functions, keyed by the strings in the custom-row-parts array... :)
        return array:for-each($content('custom-row-parts'), function($part) {
                    if (map:contains($parts, $part)) then $parts($part)($content) else ()
                })                         
    }
    </div>
    <div class='table-responsive'>
    {
    <table class='table'>
                <thead>
                <tr>{ array:for-each($content('column-headings'), lw:make-column-heading(?,$content)) }</tr>
                {if (map:contains($content,'new-item-tr')) then $content?new-item-tr else () }
                </thead>
                <tbody>
            { 
            let $row-fn := if (map:contains($content, "row-function")) then $content?row-function else function ($row) {map {}}
            let $fields := $content?fields
            let $pm := $content?pagination-map
            
(:            ------------------------ The main ROW LOOP ---------------------:)
            
            for $row at $i in lw:get-ordered-items($content)[position() = $pm?start to $pm?end]
            
            let $row-data := $row-fn($row) (: Row-data are the calculations and common values needed to present each row in the table. :)
(:          Consider using a merge here on row-attributes.  Which ones of these can always be calculated?   :)
(:  For most lists, I'll need attributes on the row:
    - data-title
    - class
    - data-path
    - data-href
    - draggable=true|false
    - target
    - title (not sure why both are needed)
:)
            let $row-attributes := if ($content?row-attributes instance of function(*)) then $content?row-attributes($row, $row-data) else (util:log('info', '################ NO ROW-ATTRIBUTES FN ###########'))
            (: each field in the row is should have a 'value($row,$row-data) function'
                This allows each cell to calculate any special attributes (classes etc) as well as the display value.
                I'm also going to assume that if there's a column heading but no field, you want an empty column.
            :)
            
            return 

            <tr>{$row-attributes}
                {array:for-each($content('column-headings'), function($field) {
                    if (map:contains($fields, $field)) then 
                         <td>{try { $fields($field)?value($row, $row-data)} catch * { util:log('warn', '****************** FIELD ERROR FOR ' || $field || ' of row ' || $i || " : "|| $err:description ) }}</td>
                    else <td>&#160;</td>
            })}</tr>
            
            }
            </tbody>
        </table>

}

</div>
</div>
<!-- Modal -->
<div class="modal fade" id="pModal" tabindex="-1" role="dialog" aria-labelledby="pModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal"><span ><i class="fa fa-icon-close"></i></span><span class="sr-only">Close</span></button>
        <h4 class="modal-title" id="myModalLabel">Modal title</h4>
      </div>
      <div class="modal-body">
        ...
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
        <button type="button" class="btn btn-primary">Save changes</button>
      </div>
    </div>
  </div>
</div>
{if (map:contains($content, 'custom-script') and $content?custom-script instance of function(*)) then $content?custom-script($content) else ()}
</body>
</html>

};

(:

xquery version "3.1";

import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";


let $content := map {
    'title' : 'Test List Page',
    'column-headings': ['Planets','Discovered'], 
    'fields' : map {
        'Planets' : map {
            'value':function($row, $row-data) {$row/string(name)},
            'sort-key' : 'planet-name',
            'sort' : function ($items, $direction) {if ($direction eq 'ascending') then for $item in $items order by $item/planet/name ascending return $item else for $item in $items order by $item/planet/name descending return $item }
        },
        'Discovered' : map {
            'value': function ($row,$row-data) {$row/discovered-date/string(.)},
            'sort-key' : 'discovered-date'
        }
    },
    'order-by' : 'descending-mod-date',
    'params' : ( a sequence of maps. Will be overridden by the query-string) 
    'items' : <planets><planet><name>Mars</name><discovered-date>1742</discovered-date></planet><planet><name>Pluto</name><discovered-date>1921</discovered-date></planet></planets>/planet
}
(\:for $th in $content?column-headings return <i>{$th}</i>:\)
return lw:list-page($content)

:)
