xquery version "3.1";

import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:collection-path := $tenant:tenant-path || "/files";
declare variable $local:items := collection($local:collection-path)/report;

declare variable $local:doctype := "report";

declare variable $local:view := request:get-parameter('view','');
declare variable $local:current-collection := request:get-parameter('collection','/files');

(:  ----------------------------------------------------   MAIN QUERY ---------------------------------------- :)


declare function local:date-or-button($field, $action, $path) {
    if ($field castable as xs:date) then $field/format-date(., '[D1]-[MN,*-3]')
    else <button class='date-action' data-action='{$action}' data-path='{$path}' title="Insert today's date"><i class="fa fa-calendar fa-stack"></i></button>
};

declare function local:value-or-input($field, $action, $path) {
    if ($field ne '') then $field/string()
    else <input type='text' data-action='{$action}' class='value-input' data-path='{$path}' title="press Enter to update"/>
};

let $conf := map {
    'doctype' : function ($item) { $local:doctype } ,
    'display-title' : function ($item) { util:document-name($item) }
    }
let $default-content := lw:configure-content-map($conf)


let $content :=  map:new(($default-content,  map {
    'title' : 'Assembly Days',
    'path-to-me' : '/exist/pekoe-app/Reports.xql',
    'breadcrumbs' : lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/Reports'),
    
    (:if ($lw:action eq 'Search')       then  lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/search')
                    else if ($lw:action eq 'xpath')   then  lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/XQuery')
                    else                                    lw:breadcrumbs('/exist/pekoe-app/Reports.xql?collection=', $local:current-collection || '/Reports'),
                    :)
(:  Note: this could be a function based on a parameter or even make the whole thing a module and then create different versions that return different field sets.
    So the Supplies List and the Kits-due list could all come from here with some variations.
    Even variations in presentation of a field can be handled by simply defining a new column-heading and field?name.
:)
    'column-headings': 
         ['Report Title', 'Applies to', 'Last Mod', 'File','Parameters']
    ,
    'doctype' : $local:doctype,
    'row-attributes' : function ($item, $row-data) {
        let $quarantined-path := substring-after(base-uri($item), $tenant:tenant-path)    
        let $safe-path := '/exist/pekoe-files' || $quarantined-path
        return (
        (: Required attributes: class title data-title data-type data-path data-href  :)
        attribute class {'other'},
        attribute title {$safe-path || ' Report'},
        attribute data-title {substring-before(util:document-name($item),'.') || ' report'},
        attribute data-type {'report'},
        attribute data-path {$safe-path},   
        attribute data-href {'/exist/pekoe-files/report/' || $quarantined-path}
        )
    },
    'fields' : map {
        'example parameter' : map {
             'value' : function ($row, $row-data) {
                local:value-or-input($row/supplies/invoice-number,'set-invoice-number',$row-data?quarantined-path)
             }
        },
        
        'File' : map {
            'value' : function ($item, $row-data) {
                substring-before(util:document-name($item),'.')
            },
            'sort-key' : 'file-name',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by util:document-name($item) ascending return $item 
                else for $item in $items order by util:document-name($item) descending return $item 
            }
        },
        
        'Report Title' : map {
            'value':function($row, $row-data) {$row/title/string()},
            'sort-key' : 'title',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/title ascending return $item 
                else for $item in $items order by $item/title descending return $item 
            }
        },
        
        'Last Mod' : map {
            'value': function ($item,$row-data) {                
                pqt:format-as-aust-date(pqt:mod-date($item))
                },
            'sort-key' : 'mod-date',
            'sort' : function ($direction, $items) {
                
                if ($direction eq "descending") then
                      for $item in $items
                      
                      order by pqt:mod-date($item) descending
                      return  $item
                  else
                      for $item in $items
                      order by pqt:mod-date($item) ascending
                      return  $item
                     }
        
        },
        'date example' : map {
            'value': function ($item,$row-data) {                
                pqt:format-as-aust-date($item/ad-date[. castable as xs:date])
                },
            'sort-key' : 'ad-date',
            'sort' : function ($direction, $items) {
                
                if ($direction eq "descending") then
                      for $day in $items
                      
                      order by $day/ad-date descending
                      return  $day
                  else
                      for $day in $items
                      order by $day/ad-date ascending
                      return  $day
                     }
        },
        'Applies to' : map {
             'value' : function ($row, $row-data) {
                $row/applies-to/string()
             },
            'sort-key' : 'doctype',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/applies-to ascending return $item 
                else for $item in $items order by $item/applies-to descending return $item 
            }
        }
    }, (: End of fields map :)
    'custom-script' : function ($content) { (: This script will be loaded at the end of the page. :)
        <script>
        // <![CDATA[
        $(function () {
            $('.value-input').on('keypress', function (e) {
              if (e.which == 13) {
                   var $this = $(this);                
                   $this.replaceWith($this.val());
                   $.post('/exist/pekoe-files/config/ajaxions.xql', {'path':$this.data('path'), 'action':$this.data('action'), 'val': $this.val()});
                   return false;  
             }
           });
            
            $('.date-action').on('click', function () {
                var $this = $(this);
                var d = new Date();

                var iso = d.toISOString().split('T').shift();
                var aust = iso.split('-').reverse().join('-');
                
                $this.replaceWith(aust);
                console.log('path', $this.data('path'));
                $.post('/exist/pekoe-files/config/ajaxions.xql', {'path':$this.data('path'), 'action':$this.data('action')});
            });
            $('.set-instructions-date button').on('click',function () {
                var $this = $(this);
                var d = new Date();

                var iso = d.toISOString().split('T').shift();
                var aust = iso.split('-').reverse().join('-');
 
                var path = $($this.parent()).data('path');
                //console.log('at',$this.parent(),'found path' , path);
                $this.replaceWith(aust);
                $.post('/exist/pekoe-files/config/ajaxions.xql', {'path':path, 'action':'set-instructions-sent-date'});
           });
           
            $('.set-supplies-date button').on('click',function () {
                var $this = $(this);
                var d = new Date();

                var iso = d.toISOString().split('T').shift();
                var aust = iso.split('-').reverse().join('-');
 
                var path = $($this.parent()).data('path');
                //console.log('at',$this.parent(),'found path' , path);
                $this.replaceWith(aust);
                $.post('/exist/pekoe-files/config/ajaxions.xql', {'path':path, 'action':'set-supplies-sent-date'});
           });
        });
        // ]]>
        </script>
    },
    (:    to add params that aren't in the query-string , add them as a sequence of maps :)
    'order-by' : request:get-parameter('order-by','ascending-title'),
    'custom-row-parts' : ['list-all',  'text-search'],
    'custom-row' : map:new(($default-content?custom-row,  map {
        'Accounts' : function ($conf) {
            <div class='btn-group'>
                    <form method='get' action=''>
                        <input type='hidden' name='view' value='supplies'/>
                        <button class='btn' type='submit' name='action' value='List'>Payments</button>
                    </form>
                </div>
        }
    
    })),

    'items' :  switch ($lw:action) 
                case "list" return $local:items
                case "Search" return $local:items[contains(., request:get-parameter('search',''))]
                case "xpath" return lw:xpath-search()   (: This query is dependent on the collection path parameter and so will default to collection() :)
                default return $local:items
                
})) (: end of map:new :)

return lw:list-page($content)


