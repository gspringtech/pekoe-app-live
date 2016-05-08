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

module namespace lw = "http://pekoe.io/list/wrapper";
import module namespace resource-permissions = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace lt = "http://pekoe.io/list-tools" at "modules/list-tools.xqm"; (: can be used in queries and reports :)

declare variable $lw:screen := request:get-cookie-value('screenx') || 'x' || request:get-cookie-value('screeny'); 
declare variable $lw:action := request:get-parameter("action","List"); (: Must have useful default for when activated by browse-list:)
declare variable $lw:method := request:get-method();
declare variable $lw:server := "https://" || request:get-server-name();

declare variable $lw:DEFAULT-LIST-SIZE := 20;

declare variable $lw:aust-dateTime-picture :=  "[D01] [M01] [Y0001] [H01]:[m01]:[s01]";
declare variable $lw:aust-date-picture :=   "[D01]/[M01]/[Y0001]";

(:declare variable $lw:current-user := sm:id()//sm:real;  -- CURRENTLY UNSAFE - will cause SERVER 500 error. :)
declare variable $lw:tenant-admin-group := "pekoe-tenant-admins";
declare variable $lw:user-is-admin-for-tenant := true(); (:lw:user-is-admin(); :)
declare variable $lw:user-is-dba := false(); (:sm:is-dba(sm:id()//sm:real/sm:username/string());:)

declare variable $lw:path-to-me := request:get-servlet-path(); (:Perfect!:)
(: The quarantined path assumes that the query is tenant-based. But pekoe-app/files.xql is a special case. 
    Instead of setting this here - it should be part of the conf. It can USE this variable, but must be overridden for this special case.
:)
declare variable $lw:quarantined-path := substring-after($lw:path-to-me, $tenant:tenant-path); (: DOESN'T WORK WITH pekoe-app/files.xql   /files/AD-Bookings.xql  :)
(:declare variable $lw:collection-path := $tenant:tenant-path || "/files"; :)
declare variable $lw:base-collection-path := '/files';

(: -------------------------------  EVERY LIST SHOULD USE THIS to create the base content-map. --------------------- :)
declare function lw:configure-content-map($config-map) {
    (: Must provide defaults for these. These are not included in the final content map - they are for configuring it.   :)
    let $base-map := map {
        'show-footer' : false(),
        'allow-export' : false(),                                       (: Default prevents the button from appearing and also prevents user from trying ?download :)
        'doctype' : function ($item) { () },                            (: a default returning empty must be provided because it's a function. :)
        'display-title' : function($item) { $item/*[1]/string() }       (: the string-value of the first child element will be the default title of a new Tab for 'this item'. :)
    }
    let $custom-conf := map:new (($base-map,$config-map))               (: Now override that base-map with your List config. :)
    
    (: This main map will have access to the intial $custom-conf. By adding things to the base-map above, I can guarantee that the functions will be available.
        The following items can all be overridden by your List. 
    :)
    return 
        map {
        (: For each restricted menu item or other action, add a key. These can be overriden by the query.       :)
        'hidden-menus' : map {
            'rename': true(), 
            'move-up' : not(sm:is-dba(sm:id()//sm:real/sm:username/string())) , 
            'delete' : false(), (:not(sm:is-dba(sm:id()//sm:real/sm:username/string())) ,:) 
            'unlock':  false() (:not(sm:is-dba(sm:id()//sm:real/sm:username/string())):)
            
        },
        'breadcrumbs' : lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=',$lw:quarantined-path),
        'path' : request:get-parameter("collection", $lw:base-collection-path),  (: default is /files. Override this. :)
        'path-to-me' : '/exist/pekoe-files/' || $lw:quarantined-path, (: overridden by /exist/pekoe-app/files.xql ONLY :)
        
    (:   TODO - it would be useful to make the attributes into a MAP so that a List can override ONE - rather than the whole lot.      ****************************************** TODO ***************   :)
        'row-attributes' : function ($item, $row-data) {  (: The HTML attributes for this table-row. :)
            let $colName := util:collection-name($item)
            let $child := util:document-name($item)
            let $quarantined-path := substring-after($colName || '/' || $child, $tenant:tenant-path)    
            let $path := '/exist/pekoe-files' || $quarantined-path
            let $display-title := $custom-conf?display-title($item)           
            let $permissions := lw:doc-permissions($colName || '/' || $child)
            let $doctype := $custom-conf?doctype($item)
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
        'extra-content-url' : '/exist/pekoe-app/Associated-files.xql',
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
(:    util:log('warn', 'KEYS IN CONF ' || string-join(map:keys($conf),', ') ),:)

    <div class='btn-group' ><!-- XQuery search -->
        <form method='get' class='form-inline' action=''>
           <input type='hidden' name='collection' value='{$conf?path}'/>
           { if (map:contains($conf,'params')) then map:for-each-entry($conf?params ,function ($k,$v) {<input type='hidden' name='{$k}' value='{$v}' /> })   else ()        }
           <input type='text' placeholder='/{$conf?doctype}[...]' name='xpath' value='{$conf?xpath}' id='xpath' class='form-control'/>
           <button type="submit" value="xpath" name="action"  class='btn btn-default'>XQuery</button>
            {
           (: If the xquery contains a parameter then the bookmark should be a search.  - e.g. /annual-distribution[financial-year eq $text]  :)
            if ($conf?xpath eq '') then ()
            else if (contains($conf?xpath, '$')) then (
               (: This is for the SEARCH param :)
               let $parts := analyze-string($conf?xpath, '\$\w+')  
               let $params := map:new(($conf?params,map{'action':'xpath', 'collection': $conf?path, 'xpath': $conf?xpath}))
               let $path-params := string-join(map:for-each-entry($params, function ($k,$v){ $k || '=' || $v }), '&amp;')
               return 
               <span style='cursor:move' title='Bookmark for XQuery with parameter in {$conf?path}'
                   data-href='{$conf?path-to-me}?{$path-params}'
                   data-title='' 
                   data-type='search'
                   data-param='{substring-after($parts//fn:match,'$')}'><i class='glyphicon glyphicon-bookmark'/></span>
            )
            else (
               (: This is a standard bookmark. :)
               let $params := map:new(($conf?params,map{'action':'xpath', 'collection': $conf?path, 'xpath': $conf?xpath}))
               let $path-params := string-join(map:for-each-entry($params, function ($k,$v){ $k || '=' || $v }), '&amp;')
               return
                <span draggable='true' title='Bookmark for XQuery in {$conf?path}' 
                   data-href='{$conf?path-to-me}?{$path-params}'        
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
                   $f.on('submit', function(e){ // Does the query contain a $param? If so, show an additional INPUT
                        if ($x.val() === '') { return false; }
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
    let $check := if (matches($search,'util:eval|update|system|xmldb')) 
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


declare function lw:update-list-pref($user, $list, $name, $value, $element) {
    (:  *** PUT THE SCREEN SIZE INTO the LIST PREF - so it can be different on different screens. :)
    if ($element) then update value $element with $value
    else 
        
        let $config-path := $tenant:tenant-path || '/config/users'
        let $conf := collection($config-path)/config[@for eq $user]
        return
            if ($conf//list[@eff-uri eq $list]) (: the element doesn't exist so look for its list       :)
            then (update insert element {$name} {$value} into $conf//list[@eff-uri eq $list] ) 
            else (: the list doesn't exist so look for its pref :)
                if ($conf/pref[@for eq 'lists']) 
                then update insert <list eff-uri='{$list}'>{element {$name} {$value}}</list> into $conf/pref[@for eq 'lists']
                else 
                    if ($conf) then update insert <pref for='lists'>{<list eff-uri='{$list}'>{element {$name} {$value}}</list>}</pref> into $conf
                    else 
                        xmldb:store($config-path, replace($user, "[\W]+","_") || '.xml', <config for='{$user}'>{ <pref for='lists'>{<list eff-uri='{$list}'>{element {$name} {$value}}</list>}</pref>}</config>)

};


(: See *** below.:)
declare function lw:preferred-list-rpp() { 
    let $eff-uri := request:get-effective-uri() || $lw:screen
    let $current-rpp := request:get-parameter('rpp','')
    let $current-user := sm:id()//sm:real/sm:username/string()
    let $config-path := $tenant:tenant-path || '/config/users'
    let $stored-pref := collection($config-path)/config[@for eq $current-user]/pref[@for eq 'lists']/list[@eff-uri eq $eff-uri]/rpp 
    let $rpp := 
        if ($current-rpp ne '') then         (: Update the stored pref and return the value:) 
            let $update := if (string($stored-pref) ne $current-rpp) then (lw:update-list-pref($current-user, $eff-uri, 'rpp', $current-rpp, $stored-pref)) else ()
            return $current-rpp
        else if ($stored-pref ne '') then $stored-pref
        else $lw:DEFAULT-LIST-SIZE
    return xs:integer($rpp)
};


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
    
    let $records-per-page := lw:preferred-list-rpp() (: ***  It would be preferable to make this device dependent :)
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


(: '/exist/pekoe-app/files.xql?collection=', $lw:quarantined-path e.g. /files/AD-Bookings.xql :)
(: Note - See Tabular-data.xql for an alternative.   :)
declare function lw:breadcrumbs($base, $path) {
    let $path-parts := tokenize(substring-after($path,'/'),'/')
    let $last := count($path-parts)
    for $part at $i in $path-parts
    let $link := string-join($path-parts[position() le $i],'/')
    return <li>{if ($i eq $last) then $part else <a href='{$base}/{$link}'>{$part}</a>}</li>
};



declare function lw:pagination($pagination-map) {
    let $current := $pagination-map('current')
    
    let $disabled-fn := function ($n) { if ($current eq $n ) then attribute class {'disabled'} else () }
    
    let $total := $pagination-map('total')
    
    let $rpp := string($pagination-map?rpp)
    (: I want to store this rpp setting for the user but there are some unresolved issues.
        The BEST option would be to use LOCALSTORAGE ON THE CLIENT - and have a per-list setting.
            - would need pekoe-workspace to retrieve the parameter from LocalStorage AND 
            - pekoe-workspace would have to APPEND the parameter to each list view (based on the URL) - IFF not already SET.
            - pekoe-common/list would need to SET the value for the current list WHEN the value is CHANGED.
        The next option is to USE a COOKIE to store the value on the client 
            - but this would become cumbersome and care must be taken 
            - to avoid trashing the main cookie.
            - Awkward to overwrite
        Final possibility is to store the value per-list on the Server
            - possibily easiest to implement
            - no client-code javascript to mess with
            - BUT will be PER-USER and not per MACHINE - which means that a user selecting a large number (on a Desktop display)
              will see the same setting on their laptop. 
              UNLESS I can record USER, List, SCREEN (which I already have access to).
    :)
    
    let $p-map := map:remove($pagination-map?params,'p') (: Remove the current p= from the map - but leave other params like search, action and rpp :)
    let $p-items := map:for-each-entry($p-map,function($k,$v){if ($k ne '') then $k || '=' || $v else ()})
    
    let $rpp-map := map:remove($p-map,'rpp') (: also remove rpp - but leave the other params as above (p is automatically set back to 1 when rpp changes) :)
    let $rpp-items := map:for-each-entry($rpp-map,function($k,$v){if ($k ne '') then $k || '=' || $v else ()})
    
    let $p-fn := function ($n) { string-join(($p-items,'p=' || $n),'&amp;') }
    let $rpp-fn := function () { (10, 20, 25, 50, 100, 500) ! <li><a href='?{string-join(($rpp-items,'rpp=' || .),'&amp;')}'>{.}&#160;{if (string(.) eq $rpp) then <span class='glyphicon glyphicon-ok'/> else ()}</a></li>   }
                                   
    return
    if ($total eq 1) then 
        <nav><ul class='pagination' style='margin-top:0'>
            <li class='dropdown'>
                <a class='dropdown-toggle' id='rppSelect' data-toggle='dropdown'>({$pagination-map?items} items) <span class='caret'></span></a>
                <ul class="dropdown-menu" role="menu" aria-labelledby="rppSelect">
                    <li class='dropdown-header'>Items per page</li>
                    {   $rpp-fn()    }
                </ul>
            </li></ul></nav>
    else 
        <nav><ul class='pagination' style='margin-top:0'>
            {
            if ($total lt 5) then (
                for $n in 1 to $total return <li>{if ($n eq $current) then attribute class {'active'} else () }<a href='?{$p-fn($n)}'>{$n}</a></li>
            )
            else (
                let $first := max((1,$current - 2)) 
                (: first is also either $first or ($total - 4) whichever is least :)
                let $first := min(($first, $total - 4))
                let $last := min(($total, $first + 4))
                return (
                (: Go First :)                    <li>{$disabled-fn(1)     }<a title='First'    href="?{$p-fn(1)     }"><i class='fa fa-angle-double-left'></i></a></li>,
                (: Go Prev :)                     <li>{$disabled-fn(1)     }<a title='Previous' href="?{$p-fn(if ($current ne 1) then $current - 1 else ())}"><i class='fa fa-angle-left'></i></a></li>,
                                            (for $n in $first to $last return 
                                                  <li>{if ($n eq $current) then attribute class {'active'} else () }<a href='?{$p-fn($n)}'>{$n}</a></li>
                                            ),
                (: Go Next :)                     <li>{$disabled-fn($total)}<a title='Next'     href="?{$p-fn(if ($current eq $total) then $current else $current + 1)}"><i class='fa fa-angle-right'></i></a></li>,
                (: Go Last :)                     <li>{$disabled-fn($total)}<a title='Last'     href="?{$p-fn($total)}"><i class='fa fa-angle-double-right'></i> ({$total} pages)</a></li>
                )
            )
            }
            <li class='dropdown'>
                <a class='dropdown-toggle' id='rppSelect' data-toggle='dropdown'>({$pagination-map?items} items) <span class='caret'></span></a>
                <ul class="dropdown-menu" role="menu" aria-labelledby="rppSelect">
                    <li class='dropdown-header'>Items per page</li>
                    {    $rpp-fn()   }
                </ul>
            </li>
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
    if (map:contains($content, "order-by") and $content?order-by ne '') then (
    
        let $sort-key := substring-after($content?order-by, '-')
        let $direction := substring-before($content?order-by, '-')
        let $order-by-field := map:for-each-entry($content?fields, function ($k,$v) {$v})[?sort-key = $sort-key]
        return 
            if ($order-by-field instance of map(*) and map:contains($order-by-field,"sort")) 
            then $order-by-field?sort($direction, $content?items)
            else (
                util:log('info','%%%%%%%%%%%%%%%%% SORT NOT FOUND in ' || $lw:path-to-me || '. sort-key:' || $sort-key || ' direction:' || $direction || ' count:' || count($order-by-field)) ,
                $content?items
                )
    )
    else $content?items
};


(:
    Ideally, there will be a simple parameter switch to get here rather than the list-page.
    $content?export
    view is already used
    ?download
    ?export
    
    But for the moment, I'll have change it in the original query
:)

(:------------------------------------------------------------- THE EXPORT FUNCTION ---------------------------------------------:)
declare function lw:export-csv($original-content as map(*)) {
    let $content := lw:pagination-map($original-content)

    let $fn := replace($content?title, "[\W]+","-") || "-" || format-dateTime(current-dateTime(), "[Y][m][d]-[h][m]") || ".txt"
    let $row-fn := if (map:contains($content, "row-function")) then $content?row-function else function ($row) {map {}}
    let $fields := $content?fields
    let $t := ','
    let $pm := $content?pagination-map
    let $header1 := response:set-header('Content-disposition', concat('attachment; filename=',$fn))
    let $header2 := response:set-header('Content-type','text/csv')
    let $serialization-parameters :=
        <serialization-parameters xmlns="http://www.w3.org/2010/xslt-xquery-serialization">
          <method>text</method>
          <item-separator>, </item-separator>
        </serialization-parameters>    
    
    let $header := array:fold-left($content('column-headings'), (), function ($x,$y) {string-join(($x,'"',$y,'"'), $t)})


    return (
        $header, $cr,
        for $row in lw:get-ordered-items($content)[position() = $pm?start to $pm?end]
        let $row-data := $row-fn($row) 
        return (
                array:fold-left(
                    $content('column-headings'), 
                    (),
                    function($x, $field) {
                        string-join(
                        ($x,
                        if (map:contains($fields, $field)) then 
                        try { replace(
                                serialize(<n>{$fields($field)?value($row, $row-data)}</n>,$serialization-parameters)
                            ,'\t|\n|&#160;',' ')
                            
                        
                        }                     
                        catch * { util:log('warn', '****************** EXPORT ERROR FOR ' || $field ||  " : "|| $err:description ) }
                        else ''), $t)
                        
                        }
                        ),$cr)
                        )
};

declare function lw:export-page($original-content as map(*)) {
    let $content := lw:pagination-map($original-content)
    let $cr := "&#13;"
    let $t := "&#9;"
    let $fn := replace($content?title, "[\W]+","-") || "-" || format-dateTime(current-dateTime(), "[Y][m][d]-[h][m]") || ".txt"
    let $row-fn := if (map:contains($content, "row-function")) then $content?row-function else function ($row) {map {}}
    let $fields := $content?fields
    let $pm := $content?pagination-map
    let $header1 := response:set-header('Content-disposition', concat('attachment; filename=',$fn))
    let $header2 := response:set-header('Content-type','text/tab-separated-values')
    let $serialization-parameters :=
        <serialization-parameters xmlns="http://www.w3.org/2010/xslt-xquery-serialization">
          <method>text</method>
          <item-separator>, </item-separator>
        </serialization-parameters>    
    
    let $header := array:fold-left($content('column-headings'), (), function ($x,$y) {string-join(($x,$y), $t)})


    return (
        $header, $cr,
        for $row in lw:get-ordered-items($content)[position() = $pm?start to $pm?end]
        let $row-data := $row-fn($row) 
        return (
                array:fold-left(
                    $content('column-headings'), 
                    (),
                    function($x, $field) {
                        string-join(
                        ($x,
                        if (map:contains($fields, $field)) then 
                        try { replace(
                                serialize(<n>{$fields($field)?value($row, $row-data)}</n>,$serialization-parameters)
                            ,'\t|\n|&#160;',' ')
                            
                        
                        }                     
                        catch * { util:log('warn', '****************** EXPORT ERROR FOR ' || $field ||  " : "|| $err:description ) }
                        else ''), $t)
                        
                        }
                        ),$cr)
                        )
};

declare function lw:associated-content($content) {
<html><head><title>Associated</title></head><body>Got here</body></html>
};

declare function lw:process($original-content as map(*)) {
    if ($original-content?allow-export and (request:get-parameter-names() = 'download')) then lw:export-page($original-content)
    else if (request:get-parameter-names() = 'associated-content') then lw:associated-content($original-content)
    else lw:list-page($original-content)
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
let $hide-menu := $original-content('hidden-menus')
    
(:let $log :=  if (map:contains($original-content,'hidden-menus')) then () else util:log('warn','M%%%%%%%%%%%%%%%%% NO MESUS'):)



return

<html>
<meta charset="utf-8"></meta>
    <head>
        <title>{$content('title')}</title>
        <link rel='stylesheet'        href='/pekoe-common/jquery-ui-1.11.0/jquery-ui.css' />
        <link rel='stylesheet'        href='/pekoe-common/dist/css/bootstrap.css' />
        <link rel='stylesheet'        href='/pekoe-common/list/list-items.css' />
        <link rel='stylesheet'        href='/pekoe-common/dist/font-awesome/css/font-awesome.min.css' />
        <style>/* <![CDATA[ */
        @media print { 
            .row, .glyphicon { display: none } 
            body, td { font-size: 8pt !important; }
            td { padding : 2px !important; }
            a[href]::before, a[href]::after { content : "" !important; }
            button { display: none; }
        }
        /* ]]> */
        </style>
        <script type='text/javascript' src='/pekoe-common/jquery/dist/jquery.js' ></script>
        <script type='text/javascript' src="/pekoe-common/jquery-ui-1.11.0/jquery-ui.js" ></script>
        <script type='text/javascript' src='/pekoe-common/dist/js/bootstrap.min.js' ></script>
        <script type='text/javascript' src='/pekoe-common/list/pekoe-list-widget.js'></script>
        { comment { 'path:' || $original-content?path } }
        { comment { 
            for $k in map:keys($original-content) return concat('&#10;', $k)
        }}
        {if ($content?style) then $content?style else () }
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
              <button class="btn btn-default dropdown-toggle   p-needs-selection" type="button" 
              id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">
                File menu
                <span class="caret"></span>
              </button>
              <ul class="dropdown-menu" role="menu" aria-labelledby="dropdownMenu1">
              {
              ()
              (:
              TODO  - make File Edit and View menus
                    - provide means of opening item in new Tab. DONE
                    - provide better distinction between 'menuitem' and 'actionitem'
                    
                Current items are: 
                    
                View menu - opens new tab     BUT THESE ARE BOOKMARKS in the Pekoe section.
                
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
                
             
              
          what's wrong with this?????? This would be neater and easier to test 
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
                    
                    Menu Items:
                    - Show data
                    - Rename
                    - Move to parent folder
                    - Delete
                    - Open
                    - Open in new Tab
                    - Unlock
                    
                    Plus buttons
                    - Print
                    - Export
                    
                    (A) default "hide"? 
                    (B) default "show"?
                    
                    Choose default show - on the basis that I'm creating menu items for users and so why wouldn't I want them to see it?
                    But default show will be an empty map key
                    if ($params?unlock) then 'only if true' else 'either false or missing' - so this is a "hide" option
                    if ($hide?unlock) then 
                    
                    AHH - but that means that EVERY menu that needs to be hidden must be explicitly hidden. Okay - I can do that above.
                    that means that an default hidden menu must be overridden in a query. That sounds okay.
                    
                    if ($hide-menu?delete eq true()) then 'hide it' else 'show it' - it will be shown unless explicitly hidden.
                    What are the use-cases?
                    Delete might be an admin function - I should be able to set it here. Show delete if admin otherwise hide.
                    
                    Delete is a good example. I only want to show it to Editors in Tabular-data. So by default it should be hidden - that means a config item
                    It should also be shown to Admin (me). So the default is $hide-menu-item {'delete' : not((sm:is-dba(sm:id()//sm:real/sm:username/string()))) } 
                    and 
                    if ($hide-menu-item?delete) then () else <li>...</li>
                    if ($hide-menu-item?open) then () else 'missing means false which means 'show''.
                    
                    $disabled?unlock = true() and missing from the list means NOT DISABLED. It's a little awkward but it works.
                    If there's no config, then show the item if ($disabled?unlock) then () else 'show the menu'
                    If there's a setting, $conf?disabled{'unlock', true()} then if ($disabled?unlock) then () else 'show the menu'
                    If there's a setting and an override, then i$conf?disabled{'unlock', false()} - then 'show the menu'
                    OTHERWISE EVERY menu item will need a config setting. (Not so bad, really - except I'll want to set it here and not above.)
                    
                    let $menu-item-fn := function($params-map) {
                        <li role="presentation"><a class='menuitem' role='menuitem' tabindex='-1' href="$params-map?href" data-action='$params-map?action' data-type='{$params-map?type}' data-title='{$params-map?title}'>{$params-map?text}</a></li>
                        <li role="presentation"><a class='menuitem'                 tabindex="-1" href='#'                id='openItemTab'   >Open in new tab</a></li>
                    }
                    
                    *** This whole List thing should be Ajax driven and "live" rather than old-style http. ***
                    

              
              
                <!--li role="presentation"><a class='menuitem' role='menuitem' tabidndex='-' href='/exist/pekoe-app/manage-files.xql'>New</a></li-->
                <!-- ADD OPEN JOB FOLDER
                    Modify ACCESS to commands based on a CONFIG item. This will allow me to enable some functions for specific Lists (e.g. Tabular-data or Files.)
                    
                   Use config to hide for non-dba
                   rename, move-up, delete, unlock 
            -->    
            :)
              }
              
            {if ($hide-menu('show-data')) then () else 
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='data' data-type='other' data-title='Raw XML'>Show data</a></li>}
            {if ($hide-menu('rename')) then () else 
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='rename' data-params='name'>Rename</a></li> }
            {if ($hide-menu('move-up')) then () else 
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='move-up' data-confirm='yes'>Move to parent folder</a></li>}
            {if ($hide-menu('delete')) then () else 
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='delete' data-confirm='yes'>Delete</a></li>}
                 
                <li role="presentation"><a class='menuitem  p-needs-selection' tabindex="-1" href='#' id='openItem'>Open</a></li>
                <li role="presentation"><a class='menuitem' tabindex="-1"                 href='#' id='openItemTab'   >Open in new tab</a></li>                
            {if ($hide-menu('unlock')) then () else 
                <li role="presentation"><a class='menuitem' role="menuitem" tabindex="-1" href="/exist/pekoe-app/manage-files.xql" data-action='unlock'>Unlock</a></li>}
              </ul>
            </div>            
            <button onclick='window.print();' id='printBtn' type='button' class='btn btn-default'><i class='glyphicon glyphicon-print'></i> Print</button>
            {if ($content?allow-export eq true()) then 
            <button onclick='location.href="{request:get-uri()}?{string-join(("download", request:get-query-string()),'&amp;')}"' id='exportBtn' type='button' class='btn btn-default'><i class='glyphicon glyphicon-download-alt'></i> Export</button>
            else ()
            }
            <button id='refresh' type='button' class='btn btn-default'><i class='glyphicon glyphicon-refresh'></i> Refresh</button>  
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
            
            
            {
            (: Two ways to enable/disable... either have a flag like $content?show-footer OR remove the footer from the map - or somehow don't include it.       
            
            ALSO
                it would be great to be able to merge table cells that are empty - using some kind of rule. typically there will only be one or two Grand-Total footer cells - 
            :)
            if ($content?show-footer and map:contains($content,'footer')) then 
            <tfoot>
            {
            let $footer-fields := $content?footer
            return
            array:for-each($content('column-headings'),function($field) {
                if (map:contains($footer-fields, $field)) then 
                
                 <td>{try { $footer-fields($field)?value($content?items)} catch * { util:log('warn', '****************** FIELD ERROR FOR ' || $field || $err:description ) }}</td>
                else <td>&#160;</td>
            })
            }
            </tfoot>
            else ()
            }
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
        <button type="button" class="btn" id="modalDeleteBtn">Delete</button>
        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
        <button type="button" class="btn btn-primary">Save changes</button>
      </div>
    </div>
  </div>
</div>
{if (map:contains($content, 'custom-script') and $content?custom-script instance of function(*)) then $content?custom-script($content) else ()}

{
(:  I want to generalise this but can't quite see what it would do other than display associated files.
    Also, this code should not be here. It is not fully abstracted.
    I'm saying "if there's an extra-content-url, look for a data('href') but that may not be the desired behaviour.
    However, this behaviour IS common to all bundled Jobs - so I'll want to include it in the List Module.
    
    The other issue is more specific. Here, I'm generating the content-url with XQuery AND Javascript.     
:)

if (map:contains($content, 'extra-content-url')) then <script>
    $(function (){{
        if ( gs.scope) {{
            if (gs.scope.tab.extra === '') {{
                gs.scope.tab.extra = '{$content?extra-content-url}';
                gs.scope.$apply(); // this will force an update. 
            }}
            }}
    }});
</script> else () }
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
