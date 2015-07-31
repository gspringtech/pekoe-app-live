xquery version "3.1";

import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

(: I fdinding it hard to decide what bookmarks should appear here. 
    Options:
    -- all bookmarks except "mine"
    -- a custom collection of bookmarks
    -- some other kind of list - perhaps stored in config.
:)
declare variable $local:collection-path := $tenant:tenant-path || "/config/user";

declare variable $local:all-prefs :=     doc('/db/pekoe/common/common-bookmarks.xml')//item;
declare variable $local:admin-prefs :=   $local:all-prefs except $local:all-prefs[@for eq 'dba'];
declare variable $local:common-prefs :=  $local:admin-prefs except $local:admin-prefs[@for eq "pekoe-tenant-admins"];

declare variable $local:items := (collection($local:collection-path)/bookmarks/item);
declare variable $local:tenant-admin-group := $tenant:tenant || '_admin';

declare variable $local:doctype := "bookmarks";

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

let $user := sm:id()//sm:real/sm:username/text()
let $common-prefs := if (sm:is-dba($user)) then $local:all-prefs else if (sm:get-user-groups($user) = $local:tenant-admin-group) then $local:admin-prefs else $local:common-prefs
let $items := ($local:items)
let $conf := map {
    'doctype' : function ($item) { $local:doctype } ,
    'display-title' : function ($item) { $item/title || ' bookmark' }
    }
let $default-content := lw:configure-content-map($conf)

let $content :=  map:new(($default-content,  map {
    'title' : 'Bookmarks',
    'path-to-me' : '/exist/pekoe-app/Bookmarks.xql',
    'breadcrumbs' : lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/Bookmarks'),
(:  Note: this could be a function based on a parameter or even make the whole thing a module and then create different versions that return different field sets.
    So the Supplies List and the Kits-due list could all come from here with some variations.
    Even variations in presentation of a field can be handled by simply defining a new column-heading and field?name.
:)
    'column-headings': 
         ['Title', 'Type','Parameters', 'Description']
    ,
    'doctype' : $local:doctype,
    'row-attributes' : function ($item, $row-data) {
         (
        (: Required attributes: class title data-title data-type data-path data-href  :)
        attribute class {$item/type/string()},
        attribute title {$item/title/string()},
        attribute data-title {$item/title/string()},
        attribute data-type {$item/type/string()},
        attribute data-path {$item/href/string()},   
        attribute data-href {$item/href/string()}
        )
    },
    'fields' : map {
        'example parameter' : map {
             'value' : function ($row, $row-data) {
                local:value-or-input($row/supplies/invoice-number,'set-invoice-number',$row-data?quarantined-path)
             }
        },
        
        'Title' : map {
            'value' : function ($item, $row-data) {
                $item/title/string()
            },
            'sort-key' : 'title',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/title ascending return $item 
                else for $item in $items order by $item/title descending return $item 
            }
        },
        
        'Type' : map {
            'value':function($row, $row-data) {$row/type/string()},
            'sort-key' : 'type',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by $item/type ascending return $item 
                else for $item in $items order by $item/type descending return $item 
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
        'Description' : map {
             'value' : function ($row, $row-data) {
                $row/description/string()
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
    'custom-row-parts' : ['Files', 'list-all','text-search'],
    'custom-row' : map:new(($default-content?custom-row,  map {
        'Files' : function ($conf) {
            <div class='btn-group'>
                    <form method='get' action='/exist/pekoe-app/files.xql'>
                        <button class='btn' type='submit' name='action' value='List'>Files</button>
                    </form>
                </div>
        }
    
    })),

    'items' :  switch ($lw:action) 
                case "list" return ($items)
                case "Search" return $items[contains(., request:get-parameter('search',''))]
                case "xpath" return lw:xpath-search()   (: This query is dependent on the collection path parameter and so will default to collection() :)
                default return $items
                
})) (: end of map:new :)

return lw:list-page($content)


