xquery version "3.1";

import module namespace rp = "http://pekoe.io/resource-permissions" at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";
import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";

(: TODO
    Now that I've made this work, I need to add the significant new feature: the _pekoe.xml configuration file.
    This file (which should have a schema) will tell me things like
    'monthly-bookings.xql' is a report
    
    Add "kind" and make it sortable.
    How do I achieve a secondary sort?
:)

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:current-collection := request:get-parameter('collection','/files');     (:  This should be used when constructing paths for the children.:)
declare variable $local:collection-path := $tenant:tenant-path || $local:current-collection;    (:  This should be used when querying the db.:)
(: NOTE: To process this by type (collection, query, Job), create a sequence of map {name: , type: }    :)
declare variable $local:all-items := (
    xmldb:get-child-collections($local:collection-path),
    xmldb:get-child-resources($local:collection-path));
declare variable $local:view := request:get-parameter('view','');                               (: Provides the option of changing the list of displayed fields. :)


declare variable $local:type-icon := map {
    'collection'    : <i class="fa fa-folder-o"></i>,
    'xql'           : <i class="fa fa-list-ul"></i>,
    'xqm'           : <i class='fa fa-file-o'></i>,
    'xml'           : <i class="fa fa-list-alt"></i>,
    'odt'           : <i class='fa fa-file-code-o'></i>,
    'docx'          : <i class='fa fa-file-word-o'></i>,
    'ods'           : <i class='fa fa-file-code-o'></i>,
    'xlxs'          : <i class='fa fa-file-excel-o'></i>,
    'txt'           : <i class='fa fa-file-text-o'></i>,
    'pdf'           : <i class='fa fa-file-pdf-o'></i>,
    'file'          : <i class='fa fa-file-o'></i>,
    'report'        : <i class='fa fa-table-o'></i>
};

declare variable $local:workspace-type := map {
    'collection'    : 'folder',
    'xql'           : 'report',
    'xml'           : 'form',
    'odt'           : 'other',
    'docx'          : 'other',
    'ods'           : 'other',
    'xlxs'          : 'other',
    'txt'           : 'other',
    'pdf'           : 'other',
    'file'          : 'other',
    'report'        : 'report'
};

declare variable $local:editor-link-protocol := map {'odt' := 'neo', 'docx':= 'ms-word'};

declare function local:filtered-items() {
    for $c in ($local:all-items)
    return
        if (not(sm:has-access(xs:anyURI($local:collection-path || '/' || $c),'r'))) then ()
        else $c
};

declare function local:common-features($item) {
    map {
    
    }
};

declare function local:format-collection($common, $item) {
    let $path := $local:collection-path || '/' || $item
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission
    let $safe-path := $local:current-collection || '/' || $item
    let $attributes := map { 
        'title' : $safe-path || ' folder',
        'class' : 'collection',
        'data-type' : 'folder',
        'data-title' : $item,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-app/files.xql?collection=' || $safe-path
        }
        (:(
        attribute title {$safe-path || ' folder'},
        attribute class {'collection'},
        attribute data-type {'folder'},
        attribute data-title {$item}, (\: Used as the Tab title :\)
        attribute data-path {$safe-path},   (\: the resource path - for move/delete/rename :\)
        attribute data-href {'/exist/pekoe-app/files.xql?collection=' || $safe-path}
    ):)
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'name' : $item,
    'permissions' : $smp/@mode/string(),
    'owner'   : $smp/@owner/string(),
    'group' : $smp/@group/string(),
    'icon' : $local:type-icon('collection'),
    'created' : format-dateTime(xmldb:created($local:collection-path),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")
    }
};

declare function local:format-xml($common, $item) {
        
    let $path := $local:collection-path || '/' || $item
    let $safe-path := $local:current-collection || '/' || $item
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission
    let $short-name := substring-before($item,'.')
    let $doctype := doc($path)/name(*)
    let $permissions := rp:resource-permissions($path)
    let $owner-is-me := $permissions?owner eq $permissions?username
    let $attributes := if ($permissions("locked-for-editing") and not($permissions("user-is-owner"))) 
        then map { 
        'title' : 'locked by ' || $permissions?owner,
        'class' : 'locked xml',
        'data-href' : '',
        'data-path' : $safe-path        
        }
        else map { 
        'title' : $safe-path,
        'class' : if ($owner-is-me) then "locked-by-me xml" else "xml",
        'data-type' : 'form',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : $doctype || ':/exist/pekoe-files' || $local:current-collection || '/' || $item 
        } 
    
(:     "user-can-edit"          : $user-can-edit,
        "locked-for-editing"    : $file-permissions/sm:permission/@mode eq $rp:locked-for-editing,
        "user-is-owner"         : $file-permissions/sm:permission/@owner eq $current-username,
        "closed-and-available"  : $file-permissions/sm:permission/@mode eq $rp:closed-and-available,
:)
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'name' : $short-name,
    'doctype' : $doctype,
    'permissions' : $smp/@mode/string(),
    'owner'   : $smp/@owner/string(),
    'group' : $smp/@group/string(),
    'icon' : $local:type-icon("xml"),
    'created' : format-dateTime(xmldb:created($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]"),
    'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")
    }
};

declare function local:format-binary($common, $item) {    
    let $path := $local:collection-path || '/' || $item
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission
    let $extension := substring-after($item, '.')
    let $attributes := map { 
        'title' : $safe-path,
        'class' : $extension,
        'data-type' : 'other',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-files' || $safe-path
        }
    let $edit-link := if ($local:editor-link-protocol($extension) and sm:has-access(xs:anyURI($path), 'rw')) then $local:editor-link-protocol($extension) || ":https://" || $tenant:tenant || ".pekoe.io/exist/webdav" || $path else ()
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'quarantined-path' : tenant:quarantined-path($path),
    'name' : substring-before($item,'.'),
    'type' : $extension,
    'permissions' : $smp/@mode/string(),
    'owner'   : $smp/@owner/string(),
    'group' : $smp/@group/string(),
    'icon' : $local:type-icon($extension),
    'created' : format-dateTime(xmldb:created($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]"),
    'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")
    }
};

declare function local:format-query($common, $item) {
    let $path := $local:collection-path || '/' || $item
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission  (: <sm:permission owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">    :)
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    let $attributes := map { 
        'title' : $safe-path || ' list',
        'class' : 'xql',
        'data-type' : 'report',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-files' || $safe-path 
        }
    
   (: (
                attribute class {'xql'},
                attribute title {$safe-path || ' list'},
                attribute data-title {$short-name},
                attribute data-type {'report'},
                attribute data-path {$safe-path},   (\: the resource path - for move/delete/rename :\)
                attribute data-href {'/exist/pekoe-files' || $safe-path}
            ) :)           
    return map {
        'path' : $path, 
        'quarantined-path' : $safe-path,
        'name' : $short-name,           
        'attributes' :   $attributes,
        'icon' : $local:type-icon('xql'),
        'permissions' : $smp/@mode/string(),
        'owner'   : $smp/@owner/string(),
        'group' : $smp/@group/string(),
        'created' : format-dateTime(xmldb:created($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]"),
        'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),"[D01] [M01] [Y0001] [H01]:[m01]:[s01]")
        }
};

declare function local:doctype-options() {
    let $general-doctypes := collection("/db/pekoe/common/schemas")/schema/@for/data(.) 
    (:  maybe this should be specific to the tenant rather than the current collection? :)
    let $local-doctypes := collection($tenant:tenant-path)/schema/@for/data(.)
    for $dt in ($general-doctypes, $local-doctypes)
    order by $dt
    return <option>{$dt}</option>
};

(:In this case, the items are the children of the current collection. :)

(: TODO
    This List may need to be filtered according to a CUSTOM PEKOE CONFIG file.
    _pekoe.xml
    Which might tell me things like "Monthly-bookings.xql" is a /report
    (and Monthly-bookings.xml should be hidden)
    And new files here must have XXX perimssions or be owned by YYY

:)

(: The problem with this approach is that I'll need to work out whether the item is a collection or a resource.
    SO why don't I create the $items: as an ARRAY (or Sequence) of MAP
    map {'name': xxx, 'type': collection | xml | other-extension }
    
    The disadvantage with this is that I'll need to process ALL CHILDREN.
    But as collections don't normally have too much, this won't be a problem.
    And you can't sort without knowing the name.
    Perhaps this should be a map?
    Not an array, but a map where the key is the name and the value is the type.
    Only problem is that a Sequence is expected.
:)



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
    'doctype' : function ($item) { 'unknown' },
    'display-title' : function ($item) { $item }
} 
let $default-content := lw:configure-content-map($conf)


let $content :=  map:new(($default-content,  map {
    'title' : 'Files',
    'column-headings': 
        switch ($local:view)
        case 'supplies' return ['AD-Date','Org','Kits', 'Paid?', 'Invoice-number', 'Latest Note']
        default return ['Name','Permissions','Editors','Viewers','Created','Modified']
    ,
    'doctype' : '',
    'row-function' : function ($item) { (: Used to generate the row-data map for each item:)
        (: Process according to the extension. Result is a map. :)
        let $common := local:common-features($item)
        return 
        switch (substring-after($item,'.'))
        case '' return local:format-collection($common, $item)
        case 'xml' return local:format-xml($common, $item)
        case 'xql' return local:format-query($common, $item)
        default return local:format-binary($common, $item)        
    },
    'row-attributes' : function ($item, $row-data) {
        (: Attributes is now a map        :)
        map:for-each-entry($row-data?attributes, function ($k, $v) {
            attribute {$k} {$v}
        })
    },
    'fields' : map {
        'Name' : map {
             'value' : function ($row, $row-data) {
                ($row-data?icon, $row-data?name)
             },
             'sort-key' : 'name',
             'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by lower-case($item) ascending return $item 
                else for $item in $items order by lower-case($item) descending return $item }
        },
        'Permissions' : map {
            'value' : function($row, $row-data) { $row-data("permissions") }
        },
        'Editors' : map {
            'value' : function($row, $row-data) { $row-data?owner }
        },
        'Viewers' : map {
            'value' : function($row, $row-data) { $row-data?group }
        },
        'Created' : map {
            'value' : function($row, $row-data) { $row-data?created }
        },
        'Modified' : map {
            'value' : function($row, $row-data) { $row-data?modified }
        }
    }, (: End of fields map :)
    'custom-script' : function ($content) { (: This script will be loaded at the end of the page. :)
        <script>
        // <![CDATA[
        $(function () {
            // See AD-Bookings for an example. 
        });
        // ]]>
        </script>
    },
    (:    to add params that aren't in the query-string , add them as a sequence of maps :)
    'order-by' : request:get-parameter('order-by','ascending-name'),
    
    'custom-row-parts' : ['list-all', 'new-item', 'text-search', 'xquery-search'],                                   (: Array determines the features addad to the Custom Row :)
    'custom-row' : map:new(($default-content?custom-row,  map {                                         (: map of html fragments for non-standard parts of the Custom Row. Also allows override. :)
        'new-item' : function ($conf) {
             <div class='btn-group'>
                 <form action='/exist/pekoe-app/manage-files.xql' method="POST" enctype="multipart/form-data" class='form-inline'>
                    <input type='hidden' name='collection' value='{$local:current-collection}' />                    
                    <span class="btn btn-default btn-file"><input id='fname1' type="file" name="fname"/></span>
                    <button id='upload1' type="submit" value="upload" name="action"  class='btn btn-default'><i class='glyphicon glyphicon-upload'></i>Upload</button>                                                          
                 </form>            
                 <script>// <![CDATA[
  $(function() {
    var $up = $('#upload1');
    $up.attr('disabled','disabled');
    $('#fname1').on('change', function () {
        if ($(this).val() !== '') {
            var reCheck;
            // only allow .docx .txt, .odt .pdf 
            // check the name for bad chars
            $up.removeAttr('disabled');
        } else {
            $up.attr('disabled','disabled');
        }
    });
}); //]]>
                        </script>
            </div>,
            <div class='btn-group'>
                 <form action='/exist/pekoe-app/manage-files.xql' method="GET" class='form-inline'><input type='hidden' name='collection' value='{$local:current-collection}' />
                      
                    <select name='doctype' id='doctype' class='form-control'>   
                        <option disabled='disabled' selected='selected'>new item...</option>   
                        <option value="collection">Folder</option>
                        <optgroup label='Schemas:'>
                    {
                       local:doctype-options()
                    }
                    </optgroup>
                    </select> 
                    <input id='filename' type='text' name='file-name'  class='form-control' placeholder='in {tokenize($local:current-collection,'/')[last()]}/...'/>
                    <button type='submit' class='btn btn-default' name='action' value='create' >New</button>
                </form>
           </div> 
        }(:,
                                                                                            EXAMPLE of button used to switch VIEW
        'Accounts' : function ($conf) {
            <div class='btn-group'>
                    <form method='get' action=''>
                        <input type='hidden' name='view' value='supplies'/>
                        <button class='btn' type='submit' name='action' value='List'>Payments</button>
                    </form>
                </div>
        }:)
    
    })),

    'items' :  switch ($lw:action) 
                case "list" return local:filtered-items()
                case "Search" return local:filtered-items()[contains(., request:get-parameter('search',''))]
                case "xpath" return for $n in lw:xpath-search(local:filtered-items()) return substring-after(document-uri(root($n)), $local:collection-path)
                default return local:filtered-items()
                
})) (: end of map:new :)

return lw:list-page($content)


