xquery version "3.0";
(: Currently still used by 'schema.xql' for displaying the schema-paths page.  :)
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
        
    It's apparent that this needs a little work.
    
:)

module namespace lw = "http://pekoe.io/list/wrapper";


declare variable $lw:action := request:get-parameter("action","list"); (: Must have useful default for when activated by browse-list:)
declare variable $lw:method := request:get-method();
declare variable $lw:path-to-me := request:get-servlet-path();
declare variable $lw:aust-date-picture :=  "[D01] [M01] [Y0001] [H01]:[m01]:[s01]";

(:~
: @param $params - the static uri parameters for the breadcrumb link
: @items - the sequence of things that will be paginated. Expected to be nodes of some kind.
: also expects to find a request parameter "p" for the current page number and "rpp" for the items per page.
:)
declare function lw:pagination-map($params, $items) {
(:  This should serve a dual purpose: provide the info for procesing the items
    and then sufficient data for the pagination code in the list-wrapper.
    TODO allow user to set RPP per list. 
    (See querytools.xqm )
    :)
(: items, rpp, start, end, current, total, params :)
    let $records-per-page := local:get-request-as-number("rpp",20)
    let $current-page := local:get-request-as-number("p",1)
    let $count := count($items)
    let $total-pages := xs:integer(ceiling($count div $records-per-page))
    let $start-index := xs:integer(($current-page - 1) * $records-per-page + 1 )
    let $end-index := xs:integer($start-index + $records-per-page - 1)
    
    
    let $pages-map := map { 
        "items" := $count,
        "rpp" := $records-per-page,
        "start" := $start-index,
        "end" := $end-index,
        "current" := $current-page,
        "total" := $total-pages,
        "params" := $params
    }
    return $pages-map
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
let $path-params := if ($pagination-map('params')) then  $pagination-map('params') || '&amp;' else ""

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
            (: Go Last:)<li>{if ($current eq $total) then attribute class {'disabled'} else ()}<a title='Last' href="?{$path-params}p={$total}"><i class='fa fa-angle-double-right'></i> ({$total})</a></li>
            
            )
        )
        }
    </ul></nav>
};

declare function local:get-request-as-number($param as xs:string, $default as xs:integer) as xs:integer {
    let $requested := request:get-parameter($param, "")
    return if ($requested castable as xs:integer) then xs:integer($requested) else $default 
};




declare function lw:wrap($content) {

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



</head>
<body>
    <div class='btn-toolbar' role='toolbar' aria-label="List controls">
        <div class='btn-group' role='group' aria-label='Breadcrumbs'>
            <ol class='breadcrumb'>{$content('breadcrumbs')}</ol>
        </div>
        
        <div class='pull-right' role='group' aria-label='Open actions'>
            <button id='openItem' type='button' class='btn p-needs-selection btn-default'><i class='glyphicon glyphicon-folder-open'></i>Open</button>
            <button id='openItemTab' type='button' class='btn p-needs-selection btn-default'><i class='glyphicon glyphicon-share-alt'></i>Open in new tab</button> 
            <button id='refresh' type='button' class='btn btn-default'><i class='glyphicon glyphicon-refresh'></i>Refresh</button>  
        </div>
        <div class='pull-left' style='margin-left:1em'>{$content('pagination')}</div>
    </div>

<div class='table-responsive'>

{$content('body')}

</div>
</body>
</html>

};