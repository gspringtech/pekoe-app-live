xquery version "3.1";

import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:collection-path := $tenant:tenant-path || "/files/issues";
declare variable $local:items := collection($local:collection-path)/issue;
declare variable $local:doctype := "issue";

declare variable $local:current-collection := request:get-parameter('collection','/files/issues');
declare variable $local:view := request:get-parameter('view','all');

(:  ----------------------------------------------------   MAIN QUERY ---------------------------------------- :)


(: While it might be possible to put the fields into an array,
   the advantage of the explicit array is that re-ordering the fields is much easier. 
   It potentially allows the user to set a field order.
:)

let $conf := map {
    'doctype' : function ($item) { $local:doctype } ,
    'display-title' : function ($item) { $item/title/tokenize(.,' ')[position() le 3] }
    }
let $default-content := lw:configure-content-map($conf)


let $content :=  map:new(($default-content,  map {
    'title' : 'Issues and Requests',
    'allow-export' : true(),
    'column-headings': ['Title', 'Reporter', 'Applies to', 'Last Comment', 'Created', 'Resolved'], 
    'doctype' : $local:doctype,
    'path-to-me' : '/exist/pekoe-app/Issues.xql',
    'breadcrumbs' : lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/Issues'),
    'fields' : map {
        'mod date' : map {
            'value': function ($item,$row-data) {                
                pqt:format-as-aust-date(xmldb:last-modified(util:collection-name($item), util:document-name($item)))
                },
            'sort-key' : 'mod-date',
            'sort' : function ($direction, $items) { (: This should be in the list module. :)
                if ($direction eq "ascending") then 
                    for $item in $items
                    let $date := xmldb:last-modified(util:collection-name($item), util:document-name($item))
                    order by $date 
                    return $item
                else 
                    for $item in $items
                    let $date := xmldb:last-modified(util:collection-name($item), util:document-name($item))
                    order by $date descending
                    return $item
             }
        },
        'Title' : map {
            'value':function($row, $row-data) {$row/string(title)},
            'sort-key' : 'title',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/title ascending return $item 
                else for $item in $items order by $item/title descending return $item }
        },
        'Applies to' : map {
            'value': function ($item,$row-data) { $item/applies-to/string() }
            
        },
        'Reporter' : map {
            'value': function ($item,$row-data) { attribute title {$item/@created-dateTime/format-dateTime(.,"[h].[m01][Pn] on [FNn], [D1o] [MNn]") }, $item/@created-by/string() }            
        },
        'Created' : map {
            'value': function ($item,$row-data) { $item/@created-dateTime/format-dateTime(.,'[Y0001]-[M01]-[D01]') },
            'sort-key' : 'created-date',
            'sort' : function ($direction, $items) { 
                if ($direction eq "ascending") then 
                    for $item in $items
                    order by $item/@created-dateTime ascending
                    return $item
                else 
                    for $item in $items
                    order by $item/@created-dateTime descending
                    return $item
             }            
        },
        'Last Comment' : map {
            'value': function ($item,$row-data) { 
                let $last-comment := ($item/comment)[last()] 
                return 
                (attribute title {$last-comment/@date-stamp/string()}, $last-comment/string() )
                }
        },
        'Resolved' : map {
             'value' : function ($row, $row-data) {
                $row/resolution-date/string()
             }
             
        }
    }, (: End of fields map :)
    
    
    'order-by' : request:get-parameter('order-by','descending-mod-date'),
(:  
This approach to 'filters' is working very nicely!
Need some more examples to test.
:)
    'items' :  switch ($lw:action) 
                case "list" return $local:items
                case "Search" return $local:items[contains(., request:get-parameter('search',''))]
                case "xpath" return lw:xpath-search()
                default return $local:items
                
})) (: end of map:new :)

return lw:process($content)


