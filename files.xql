xquery version "3.1";
(: Files list. 
    Don't use this as an example 'list'. Better to visit one of the Client lists like AD-Bookings or Distribution
:)

(: TODO - fix the XQuery so that the Breadcrumbs work and the full path is not included in the result. 
    ALSO - breadcrumbs and collection path have been modified to work with this TDBG version. They will need fixing. Search for pekoe-files (but DON'T REPLACE ALL)
:)

import module namespace rp = "http://pekoe.io/resource-permissions" at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";
import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";

(: Need the s3 namespace because this Files query lists s3:toc/file entries. :)
import module namespace s3="http://pekoe.io/s3";
import module namespace ps3="http://pekoe.io/pekoe-s3" at "modules/s3-toc.xqm"; 

(: TODO
    Now that I've made this work, I need to add the significant new feature: the _pekoe.xml configuration file.
    This file (which should have a schema) will tell me things like
    'monthly-bookings.xql' is a report
    
    Add "kind" and make it sortable.
    How do I achieve a secondary sort? (Sort by kind and File name)
:)

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:current-collection := request:get-parameter('collection','/files');     (:  This should be used when constructing paths for the children.:)
declare variable $local:collection-path := $tenant:tenant-path || $local:current-collection;    (:  This should be used when querying the db.:)
declare variable $local:schemas := (collection("/db/pekoe/common/schemas")/schema,collection($tenant:tenant-path)/schema);
(: Don't show xquery modules or dbu- backup files  unless user is DBA. NOTE: re can't be "" :)
declare variable $local:filtered-files-re := if (sm:is-dba(sm:id()//sm:real/sm:username)) then "$\." else "\.xqm$|^dbu-|S3-TOC.xml";

(: NOTE: To process this by type (collection, query, Job), create a sequence of map {name: , type: }  - 
    BUT these ITEMS will be processed by the LIST.xqm. Can it handle a sequence of Maps?
    Will need to do this because currently the processing is based on extension. When the extension is missing, it's assumed to be a Collection which may be WRONG.
:)
declare variable $local:all-items := (    
    (: To prevent the s3:toc from appearing in the list, filter it out here    :)
    (: Don't show xquery modules or dbu- backup files   :)
    for $f in xmldb:get-child-resources($local:collection-path)[not(matches(., $local:filtered-files-re))] order by $f return $f,
    for $f in xmldb:get-child-collections($local:collection-path) order by $f return $f
   ,for $f in xmldb:xcollection($local:collection-path)/s3:toc/s3:file[not(matches(., $local:filtered-files-re))] order by $f return $f );         (: LIST THE S3 TOC Files :)


declare variable $local:date-time-format := "[D01]/[M01]/[Y0001] [H01]:[m01]";
    
declare variable $local:view := request:get-parameter('view','');                               (: Provides the option of changing the list of displayed fields. :)

declare variable $local:custom-config := local:get-relevant-config();
declare variable $local:s3-config := ps3:config($tenant:tenant-path);

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
    'report'        : <i class='fa fa-table-o'></i>,
    'png'           : <i class='fa fa-file-image-o' ></i>,
    'jpg'           : <i class='fa fa-file-image-o' ></i>
    
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

declare variable $local:editor-link-protocol := map {
    'odt' : '/exist/pekoe-app/Letter-opener.xql?file=', 
    'ods' : '/exist/pekoe-app/Letter-opener.xql?file=', 
    'docx' : '/exist/pekoe-app/Letter-opener.xql?file=',
    'eml':'message://'};

(: This function simply checks user-access to the items in the current collection - to avoid permissions errors. :)
declare function local:filtered-items() {
    (: all-items is only used here - so can ditch it above. Need to make it a map so as to capture Collection or Resource:)
    for $c in ($local:all-items)
    return
        if ($c instance of element (s3:file)) then $c  
        else if (not(sm:has-access(xs:anyURI($local:collection-path || '/' || $c),'r'))) then ()
        else $c
};


(: SEE local:get-relevant-config() BELOW  :)
declare function local:f($parts, $count, $index, $parent-path, $collector) {
    if ($index le $count) then (
            let $current-collection := string-join(($parent-path, $parts[$index]),'/')
            let $config-doc-path := $current-collection || '/_pekoe.xml'
            let $config := doc($config-doc-path)/pekoe-config
            let $m := if (exists($config)) 
                    then map:new(   ($collector, 
                                    for $e in $config/* return map:entry(name($e),$e))
                    )
                    else $collector
            return local:f($parts, $count, $index + 1, $current-collection, $m)
        ) else (
            $collector
        )
};

(:  Find all config files from the root to here. Convert them to maps. use the map generation feature to override keys. ---------------- CONFIG
    Use the config to determine which files should be visible and how they should respond to Activate requests.
    Also determines special permissions.
:)
declare function local:get-relevant-config() {
    let $parts := tokenize($local:collection-path,'/')[position() gt 1]
    let $count := count($parts)
    return local:f($parts, $count, 1, '', map:new()) 
};


(: TODO - collect the common features of the three doctypes ------------------------ TODO :)
declare function local:common-features($item) {
    (: TODO - consider whether this is a good place to work out the _type_ of document - e.g. JOB, xql, REPORT, TABULAR-DATA etc - 
        instead of relying on the file extension.
        Is this where I decide on the Bundle?
   :)
    map {
    
    }
};

(: List entry for Collection :)
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
(:        'data-href' : '/exist/pekoe-app/files.xql?collection=' || $safe-path:)
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
    'created' : format-dateTime(xmldb:created($path),$local:date-time-format)
    }
};

declare function local:format-xml($common, $item) {
        
(:  NOT every XML file is a Job or Editable content. Some must be treated differently - but HOW?
    First option is to switch here .
    
    One way to handle non-job items is to use a custom List. See Read-mail.
    
    It should be easy enough to see if there's a SCHEMA/@for 
:)
    let $path := $local:collection-path || '/' || $item
    let $doc := if (doc-available($path)) then doc($path) else ()
    return 
        if ($doc/*/@tabular-data) then local:tabular-data-file($common, $item, $path, $doc) 
        else if ($local:schemas[@for eq name($doc/*)]) then local:format-job-file($common, $item, $path, $doc)
        else if ($doc/name(*) eq 'mail:message') then local:mail-message-file($common, $item, $path, $doc)
        else local:other-xml-file($common,$item, $path, $doc)
};

(: I really don't like this - need a pluggable mechanism :)
(: List entry for mail-message xml file :)
declare function local:mail-message-file($common, $item, $path, $doc) {
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission  (: <sm:permission owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">    :)
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    let $attributes := map { 
        'title' : $safe-path || ' list',
        'class' : 'other',
        'data-type' : 'report',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-app/Read-mail.xql?action=view&amp;message=' || $path
        }
             
    return map {
        'path' : $path, 
        'quarantined-path' : $safe-path,
        'name' : $short-name,           
        'attributes' :   $attributes,
        'icon' : $local:type-icon('xql'),
        'permissions' : $smp/@mode/string(),
        'owner'   : $smp/@owner/string(),
        'group' : $smp/@group/string(),
        'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
        'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
        }

};

(: List entry for non-editable XML data :)
declare function local:other-xml-file($common, $item, $path, $doc) {
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission  (: <sm:permission owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">    :)
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    let $attributes := map { 
        'title' : $safe-path || ' data',
        'class' : 'xml',
        'data-type' : 'other',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-files' || $local:current-collection || '/' || $item  
        }
             
    return map {
        'path' : $path, 
        'quarantined-path' : $safe-path,
        'name' : $short-name,           
        'attributes' :   $attributes,
        'icon' : $local:type-icon('xql'),
        'permissions' : $smp/@mode/string(),
        'owner'   : $smp/@owner/string(),
        'group' : $smp/@group/string(),
        'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
        'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
        }

};

(: List entry for custom Tabular-data XML file:)
declare function local:tabular-data-file($common, $item, $path, $doc) {
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission  (: <sm:permission owner="tdbg_staff" group="tdbg_staff" mode="r-xr-x---">    :)
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    let $attributes := map { 
        'title' : $safe-path || ' list',
        'class' : 'xml',
        'data-type' : 'report',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : '/exist/pekoe-app/Tabular-data.xql?collection=' || $local:current-collection || '&amp;file=/exist/pekoe-files' || $safe-path 
        }
             
    return map {
        'path' : $path, 
        'quarantined-path' : $safe-path,
        'name' : $short-name,           
        'attributes' :   $attributes,
        'icon' : $local:type-icon('xql'),
        'permissions' : $smp/@mode/string(),
        'owner'   : $smp/@owner/string(),
        'group' : $smp/@group/string(),
        'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
        'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
        }

};

(: List entry for XML file:)
declare function local:format-job-file($common, $item, $path, $doc) {


    let $doctype := $doc/name(*)
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := substring-before($item,'.')
    
    
    return     
    let $permissions := rp:resource-permissions($path)
    let $owner-is-me := $permissions?user-is-owner
    (: Option 1: clicking the TR does nothing - it is disabled (not user-can-edit)
       Option 2: it's closed and available and you are allowed to edit (got here - so must be able to edit
       Option 3: it's Owned by you - so you can edit it
       Option 4: it's owned by someone else so you can close it if you're an admin user
    
    
    The options are: you are NOT allowed to edit. You ARE allowed, but someone else is editing,  YOU are editing  :)
    let $attributes := 
        if (not($permissions?user-can-edit)) then 
        map {
            'class' : 'disabled'        
        }
        else if ($permissions?closed-and-available or $permissions?user-is-owner) then 
        map { 
        'title' : $safe-path,
        'class' : if ($owner-is-me) then "locked-by-me xml" else "xml",
        'data-type' : 'form',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : $doctype || ':/exist/pekoe-files' || $local:current-collection || '/' || $item 
        } 
        else 
        map { 
        'title' : 'locked by ' || $permissions?owner,
        'class' : 'locked xml',
        'data-href' : '',
        'data-path' : $safe-path        
        }
        
   
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'name' : $short-name,
    'doctype' : $doctype,
    'permissions' : $permissions?mode,
    'owner'   : $permissions?owner,
    'group' : $permissions?group,
    'icon' : $local:type-icon("xml"),
    'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
    'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
    }
};

(: List entry for S3 file  ----------------------------------------- S3 File ***************:)
declare function local:format-s3($item) {
    let $path := $local:collection-path || '/' || $item
    let $short-name := tokenize($item, '\.')[1] 
    let $extension := substring-after($item, '.')
    
    let $link := s3:make-download-link($item, $local:s3-config)
    
    
    let $attributes := map { 
        'title' : 's3://' || $item/@key,
        'class' : $extension,
        'data-type' : 'other',
        'data-title' : $short-name,
        'data-path' : 's3://' || $item/@key,
        'data-href' : $link
        }
     
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'quarantined-path' : tenant:quarantined-path($path),
    'name' : $short-name,
    'type' : $extension,
    'permissions' : 'read-only',
    'owner'   : $item/@user/string(),
    'group' : $tenant:tenant || '_staff',
    'icon' : $local:type-icon($extension),
    'created' : format-dateTime($item/@created-date,$local:date-time-format),
    'modified' : if ($item/@created-date eq $item/@modified-date) then "---" else format-dateTime($item/@modified-date,$local:date-time-format)
    }

};

(:
I want to change the binary so that - for user-editable files - the file goes to the Letter-opener
var t = {
  path: p, 
  href: "/exist/pekoe-app/Letter-opener.xql?file=neo:https://cm.pekoe.io/exist/webdav" + p, 
  type: "report", 
  title: title
}
:)
(: List entry for Binary file :)
declare function local:format-binary($common, $item) {    
    let $path := $local:collection-path || '/' || $item
    let $safe-path := $local:current-collection || '/' || $item
    let $short-name := tokenize($item, '\.')[1] 
(:    substring-before($item,'.'):)
    let $smp := sm:get-permissions(xs:anyURI($path))/sm:permission
    let $extension := substring-after($item, '.')
    (:  +++ How do I change this so that ODT and ODS (initially) cause a File-handler to run? +++++   :)
    let $edit-link := if ($local:editor-link-protocol($extension) and sm:has-access(xs:anyURI($path), 'rw')) 
        then $local:editor-link-protocol($extension)  || $path 
        else '/exist/pekoe-files' || $safe-path
        
    let $attributes := map { 
        'title' : $safe-path,
        'class' : $extension,
        'data-type' : 'other',
        'data-title' : $short-name,
        'data-path' : $safe-path,
        'data-href' : $edit-link
        }
    
    return map { 
    'path' : $path, 
    'attributes' : $attributes,
    'quarantined-path' : tenant:quarantined-path($path),
    'name' : $short-name,
    'type' : $extension,
    'permissions' : $smp/@mode/string(),
    'owner'   : $smp/@owner/string(),
    'group' : $smp/@group/string(),
    'icon' : $local:type-icon($extension),
    'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
    'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
    }
};

(: List entry for XQuery file :)
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
             
    return map {
        'path' : $path, 
        'quarantined-path' : $safe-path,
        'name' : $short-name,           
        'attributes' :   $attributes,
        'icon' : $local:type-icon('xql'),
        'permissions' : $smp/@mode/string(),
        'owner'   : $smp/@owner/string(),
        'group' : $smp/@group/string(),
        'created' : format-dateTime(xmldb:created($local:collection-path, $item),$local:date-time-format),
        'modified' : format-dateTime(xmldb:last-modified($local:collection-path, $item),$local:date-time-format)
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





declare function local:date-or-button($field, $action, $path) {
    if ($field castable as xs:date) then $field/format-date(., '[D1]-[MN,*-3]')
    else <button class='date-action' data-action='{$action}' data-path='{$path}' title="Insert today's date"><i class="fa fa-calendar fa-stack"></i></button>
};

declare function local:value-or-input($field, $action, $path) {
    if ($field ne '') then $field/string()
    else <input type='text' data-action='{$action}' class='value-input' data-path='{$path}' title="press Enter to update"/>
};

(:  ----------------------------------------------------   MAIN QUERY ---------------------------------------- :)

let $conf := map {
    'doctype' : function ($item) { 'unknown' },
    'display-title' : function ($item) { $item }
} 
let $default-content := lw:configure-content-map($conf)


let $content :=  map:new(($default-content,  map {
    'title' : 'Files',
    'path-to-me' : '/exist/pekoe-app/files.xql',
    'breadcrumbs' : if ($lw:action eq 'Search') 
                    then lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/search')
                    else if ($lw:action eq 'xpath') 
                    then lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=', $local:current-collection || '/XQuery')
                    else lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=',$local:current-collection),
    'column-headings': 
        switch ($local:view)
        case 'supplies' return ['AD-Date','Org','Kits', 'Paid?', 'Invoice-number', 'Latest Note']
        default return ['Name','Permissions','Editors','Viewers','Created','Modified']
    ,
    'doctype' : '',
    'row-function' : function ($item) { (: ------------------------------------------------------------------------------ Used to generate the row-data map FOR EACH ITEM. :)
        (: Process according to the extension. Result is a map. :)
        let $common := local:common-features($item)
        return 
        (:        ************** S3 S3 S3 S3 S3 *************** :)
        if ($item instance of element (s3:file)) then (local:format-s3($item))
        else
        switch (substring-after($item,'.'))
        (:  WRONG - this doesn't handle files with NO EXTENSION.      ************************************************* :)
(:        case '' return if (xmldb:collection-available(util:collection-name($item))) then local:format-collection($common, $item) else local:format-binary($common, $item):)
        case '' return  local:format-collection($common, $item) 
        case 'xml' return local:format-xml($common, $item)
        case 'xql' return local:format-query($common, $item)
        default return local:format-binary($common, $item)        
    },
    'row-attributes' : function ($item, $row-data) {
        (: Attributes is now a map. This returns a sequence of html attributes to be added to the TR. In this case, the functions above are producing a map of attributes.  :)
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
            'value' : function($row, $row-data) { $row-data?modified },
            'sort-key' : 'mod-date',
            'sort' : function ($direction, $items) {
                if ($direction eq 'ascending') 
                then for $item in $items order by xmldb:last-modified($local:collection-path, $item) ascending  return $item 
                else for $item in $items order by xmldb:last-modified($local:collection-path, $item) descending empty least return $item 
            }
        },
        'admin-link' : map {
            'value' : function ($row, $row-data) {$row-data?admin-link} }
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
    'order-by' : request:get-parameter('order-by',''),
    
    'custom-row-parts' : ['list-all', 'new-item', 'text-search', 'xquery-search'],                                   (: Array determines the features addad to the Custom Row :)
    'custom-row' : map:new(($default-content?custom-row,  map {                                         (: map of html fragments for non-standard parts of the Custom Row. Also allows override. :)
        'new-item' : function ($conf) {
        
        (: I think this is the first time I've used xcollection!  It will look for xml in the current collection,
           not in the children.
        :)
        if (exists(xmldb:xcollection($local:collection-path)/s3:toc)) then (: ---------------------------- S3 UPLOAD FORM ------------------- :)
            <div class='btn-group'>
                { 
                    s3:make-upload-form-partial-key(substring-after($local:current-collection,'/') , $local:s3-config) 
                }
                <form class='form-inline' id='s3uploadrequest'>
                    <input type='hidden' name='collection' value='{$local:current-collection}' id='s3collection' />   
                    <input type='hidden' name='partialKey' value='{substring-after($local:current-collection,'/') }' id='s3partialKey' />
                    <span class="btn btn-default btn-file"><input id='fname1' type="file" name="file" accept=".pdf,.jpg,.docx,.odt,.xslx,.ods,.txt" /></span>
                    <button id='upload1' type="submit" value="s3-upload" name="action"  class='btn btn-default'><i class='glyphicon glyphicon-upload'></i>S3 Upload</button>                                                          
                </form>    
                <xml id='toc' style='display:none'>
                   <toc>
                {for $file in xmldb:xcollection($local:collection-path)//s3:file return <file>{$file/@key}{$file/text()}</file>}
                </toc>
                </xml>
                <script>// <![CDATA[
                
                // HOW can I put the whole TOC here? If I had it, I could look up whether the file exists
                
                    
                    var fileSpec = {};
                    fileSpec.collection = $('#s3collection').val();
                    fileSpec.partialKey = $('#s3partialKey').val(); // why?
                    
                    $('#s3uploadrequest').on('submit', function (e){
                        e.preventDefault();
                        
                        var fn = $('#fname1').val(); // the raw File name
                        // I cannot FIX the filename here for security reasons. It gets fixed when I add it to the TOC
                        var $s3form = $('#s3form');
                        $('#fname1').appendTo($s3form);
                        $s3form.find('input[name="Content-Type"]').val(fileSpec.type); // Otherwise it gets binary/octet-stream
                                                             
                        $.ajax({
                            url: $s3form.attr("action"),
                            type: $s3form.attr("method"),
                            dataType: "XML",
                            data: new FormData($s3form.get(0)),
                            processData: false,
                            contentType: false,
                            success: function (data, status) {
                                var etag = $(data).find('ETag').text().replace('"','');
                                var key = $(data).find('Key').text();
                                var bucket = $(data).find('Bucket').text();
                                                                
                                // file has been uploaded to AWS S3, but now need to add it to TOC
                                fileSpec = Object.assign(fileSpec, {etag, key, bucket}); // add these props to the fileSpec
                                //fileSpec.display = description; // the display name
                                fileSpec.collection = $('#s3collection').val();
                                console.log('filespec', fileSpec);
                                $.ajax({
                                    url: '/exist/pekoe-app/manage-files.xql',
                                    data: {action: 's3-success', fileSpec : JSON.stringify(fileSpec)},
                                    success: function (d) {
                                        document.location.reload(); // needed because this is an Ajax call - not a real form post
                                 }});

                            },
                            error: function (xhr, desc, err) {
                                alert("Upload failed - please report " + err);                                
                            }
                        }); 
                    });
                    
                    var $up = $('#upload1');
                    $up.attr('disabled', 'disabled');
                    $('#fname1').on('change', function (e) {
                        let {type, lastModified, size, name} = e.target.files[0]; 
                        let $file = $('file[key$="' + name + '"]');
                        if ($file.length !== 0) { 
                            alert('This file exists as "' + $file.text() + '" - ' + name);
                        } 
                        else {
                        
                            let description = prompt('Upload as', name);
                            if (!description) { console.log('no name or cancelled'); return;}
                          else {
                                  let tz = new Date(lastModified).getTimezoneOffset(); // offset in seconds of the file's tz AT THE TIME AND DATE IT WAS MODIFIED
                                  let adjusted = new Date(lastModified - (tz * 60 * 1000)).toISOString(); // which INCLUDES Daylight Saving adjustment
                                  let tzStr = (tz < 0) ? "+": "-";
                                  tz = Math.abs(tz);
                                  tzStr += ("00" + Math.floor(tz / 60)).substr(-2) + ":";
                                  tzStr += ("00" + tz % 60).substr(-2);
                                  adjusted = adjusted.replace(/Z$/,tzStr);
                                  fileSpec["modified"] = adjusted;
                                  fileSpec["created"] = adjusted; // need to have a date here
                                  fileSpec["mime"] = type;
                                  fileSpec["size"] = size;
                                  fileSpec["display"] = description;
                                  
                                  $('#s3uploadrequest').submit();
                                  
                                  /*
                                  if ($(this).val() !== '') { // No need for a check now - using the "accept" attribute in the file input
                                      $up.removeAttr('disabled');
                                  } else {
                                      $up.attr('disabled', 'disabled');
                                  }
                                  */
                              }
                        }
                    });
                 // ]]>
                 </script>
            </div>
        else 
        if (false()) then
            <div class='btn-group'>
                 <form action='/exist/pekoe-app/manage-files.xql' method="get" class='form-inline' id='s3uploadrequest'>
                    <input type='hidden' name='collection' value='{$local:current-collection}' id='s3collection' />                    
                    <span class="btn btn-default btn-file"><input id='fname1' type="file" name="file" /></span>
                    <button id='upload1' type="submit" value="s3-upload" name="action"  class='btn btn-default'><i class='glyphicon glyphicon-upload'></i>Upload</button>                                                          
                 </form>            
                 <script src="/exist/pekoe-app/resources/s3-simple-upload.js"></script>
            </div>
        else (: ----- NOT an S3 Upload  ----- :)
             <div class='btn-group'>
                 <form action='/exist/pekoe-app/manage-files.xql' method="POST" enctype="multipart/form-data" class='form-inline'>
                    <input type='hidden' name='collection' value='{$local:current-collection}' />                    
                    <span class="btn btn-default btn-file"><input id='fname1' type="file" name="fname" /></span>
                    <button id='upload1' type="submit" value="upload" name="action"  class='btn btn-default'><i class='glyphicon glyphicon-upload'></i>Upload</button>                                                          
                 </form>            
                 <script>// <![CDATA[
 // Normal UPLOAD
  $(function() {
    var $up = $('#upload1');
    $up.attr('disabled','disabled');
    $('#fname1').on('change', function () {
        if ($(this).val() !== '') {
            var reCheck = /.+\.(pdf|odt|ods|docx|txt|zip)$/;
            // only allow .docx .txt, .odt .pdf 
            // check the name for bad chars
            if ($(this).val().search(reCheck) !== -1) {
                $up.removeAttr('disabled');
            } else {
                alert('File must be a docx, .odt, .ods, .pdf or .txt');
                $up.attr('disabled','disabled');
            }
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
                        { (: This is good! Only show the S3 TOC menu if the tenant has the appropriate Config.
                            ONLY SHOW IT TO ADMIN
                        :)
                        if ((sm:is-dba(sm:id()//sm:real/sm:username)) and ps3:config($tenant:tenant-path)) 
                        then 
                            if (empty(xmldb:xcollection($local:collection-path)/s3:toc)) then <option value="s3:toc" title='add Table of Contents for S3 Uploads'>S3 Upload</option>
                            else <option disabled='disabled'>S3 TOC exists</option>
                         else ()    
                        }
                        
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
                case "list" return local:filtered-items() (: Items are filtered to avoid permission errors.:)
                (:  The searches return nodes. But this List needs a path. :)
                case "Search" return for $n in collection($local:collection-path)/*[contains(., request:get-parameter('search',''))]    return substring-after(base-uri($n), $local:collection-path)
                case "xpath"  return for $n in lw:xpath-search()                                                                        return substring-after(base-uri($n), $local:collection-path)
                default return local:filtered-items()
                
})) (: end of map:new :)

return lw:process($content)


