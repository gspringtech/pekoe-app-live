xquery version "3.1";
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: 
    NOTE *********** SetUID is applied ************ NOTE SetUID is applied *************** NOTE 
    (see edit actions at start of main query)
    
    This is the new version of RLU Record-List-Update from Pekoe 1
    
    AND - it WORKS!
    
    One remaining task is to somehow jump to the last page after adding a new record. But that's a refinement for another day.
    (I've made this clear in the dialog title.)
    
    MAY want to LOCK the selected resource to prevent it being edited by someone else.
    
     tabular-data='1' sort='' edit='0'  
     Resources containing the tablular-data attribute will be selected.
     sort='' means don't sort at all
     sort='locality' means apply sort to that field only. space-delimited list.
     edit=true|false 1|0 
     
:)

import module namespace lw="http://pekoe.io/list/wrapper" at "/db/apps/pekoe/list.xqm";
import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";
import module namespace rp="http://pekoe.io/resource-permissions" at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:selected-file := request:get-parameter('file','');
declare variable $local:selected-resource := if ($local:selected-file ne '') then tenant:real-path($local:selected-file) else '';
(: Repair parameter for safe-path :)
declare variable $local:selected-doc := if ($local:selected-resource ne '') then doc($local:selected-resource) else ();
declare variable $local:current-collection := request:get-parameter('collection','/files');
declare variable $local:collection-path := $tenant:tenant-path || "/files"; (: Should be a param. :)
declare variable $local:today := adjust-date-to-timezone(current-date(), ());
declare variable $local:items := local:select-file();
declare variable $local:doctype := '';
declare variable $local:form-action := request:get-parameter("form-action",'');




declare function local:select-file() {
    if ($local:selected-resource eq '') then 
    for $f in collection($local:collection-path)/*[@tabular-data]
    return <item><name>{name($f)}</name><path>{tenant:quarantined-path(base-uri($f))}</path></item>
    else doc($local:selected-resource)/*/*
};

declare function local:generate-headings() {
    array {for $f in $local:items[1]/*
    return name($f)
    }
};

(: PERFECT! :)
declare function local:attributes-for-files($row,$row-data) { 
    attribute data-type {"report"}, attribute data-href {"?file=" || $row//path/string()}
};

declare function local:attributes-for-one-file($row,$row-data) { 
    attribute data-record {util:node-id($row)}
};

declare function local:fields-for-files-list() {
(: Change this to a simple map. Add sort fields. :)
    map:new(       
        for $f in $local:items[1]/*
        let $fname := name($f)
        return map:entry($fname, map {
            'value':function($row, $row-data) { $row/*[name(.) eq $fname]/string(.) }})
            )
};

declare function local:fields-for-one-file() {
    map:new(    
        (: Start with the document-order field for sorting       :)
        (
        
        map:entry( 'document-order' , map {
            'sort-key' : 'document-order',
            'sort' : function ($direction, $items) {
                $items/.
            }
        }), 
        
        
        (for $f in $local:items[1]/*
        let $fname := name($f)
        return map:entry($fname, map {
            'value':function($row, $row-data) { 
                attribute data-field {$fname},
                $row/*[name(.) eq $fname]/string(.)
                },
            'sort-key' : $fname,
    (: TODO - consider adding another attribute to the root element which contains sort items.    :)
            'sort' : function ($direction, $items) {
                let $log := util:log('info','ORDER BY ' || $fname || ' ' || $direction)
                return
                if ($direction eq 'ascending') then (
                    for $item in $items                      
                    order by $item/*[name(.) eq $fname] ascending
                    return  $item
                )
                else 
                    for $item in $items                      
                    order by $item/*[name(.) eq $fname] descending
                    return  $item
            }
            
            })
            )
            )
        )
};

declare function local:record-type($res) {
    doc($res)/*/*[1]/name(.)
};

(: PERMISSIONS 
    The files are currently owned by CM_ADMIN and CM_STAFF group
    This means that john@cm has no permission to modify.
    
    Options:
    A) Change the file owner
    B) Make the file group-writable
    C) Apply SetUid to this query and check the user's groups to see if they are in the "Editors" group.
    D) Apply a custom ACL 
    
    The problem with (A) is that only one person can be an editor.
    The problem with (B) is I'm using the Viewing group as an Editor - and can't restrict the Editors 
    The problem with (D) is that each file will need to be set - much the same as (A)
    
    So - SetUID?
    What could a user do with this query?
    This is only applied when an attribute is added to the file
    
    How do I check the user? Why don't I have a simple function for this?
    
    user-is-editor 
    user-belongs to group(file-owner)
    
    DELETE and other menu items - 
    these are currently disabled for non-dba users in list.xqm (~ L800)
    It might be better to enable them on a per-query basis - and for specific users or groups.
    
:)

declare function local:new() {
    let $fields := map:new((map:entry('nodeid',''), for $f in $local:items[1]/* return  map:entry(name($f),'')))
    let $params := pqt:get-params($fields)
    let $node-name := local:record-type($local:selected-resource)
    let $selected-node := $local:selected-doc/*/*[1]
    let $replacement := element {$node-name} {
        attribute id {$selected-node/string(@id)},
        for $f in $selected-node/*/name(.)
        return element {$f} {$params($f)}
    }  
    return 
         update insert $replacement into $local:selected-doc/*
(: Note - 'New' should set the current page to the last page as it will be the last item. How?
:)
};

declare function local:update() {
    let $fields := map:new((map:entry('nodeid',''), for $f in $local:items[1]/* return  map:entry(name($f),'')))
    let $params := pqt:get-params($fields)
    let $node-name := local:record-type($local:selected-resource)
    let $selected-node := util:node-by-id($local:selected-doc,$params?nodeid)
    let $replacement := element {$node-name} {
        attribute id {$selected-node/string(@id)},
        for $f in $selected-node/*/name(.)
        return element {$f} {$params($f)}
    }  
    return 
        (
(:        util:log('info','>>>>>>>>>>>>>>>>>> UPDATE: ' || $node-name || ' with'),
        util:log('info',$selected-node),
        util:log('info','------------------- WITH: '),
        util:log('info',$replacement),
        util:log('info','<<<<<<<<<<<<<<<<<<< END '),:)
        
         update replace $selected-node with $replacement
         )
};

declare function local:delete() {
    
    let $nodeid := request:get-parameter('nodeid','')
    let $selected-node := util:node-by-id($local:selected-doc,$nodeid)
    let $log := util:log('info','>>>>>>>>>>>>>>>>>> USER ' || sm:id()//sm:real/sm:username/string() || ' IS DELETING from ' || $local:selected-file)
    let $log0 := util:log('info',$selected-node)
    let $log1 := util:log('info','<<<<<<<<<<<<<<<<<<< END ')
    return if ($selected-node) then update delete $selected-node else () 
};



(:  ----------------------------------------------------   MAIN QUERY **** SetUID applied **** ---------------------------------------- :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)

(: This is neat and tidy and should be safe. The edit functions depend on SetUID AND the User must be an Editor. BUT... :)
(: BUGGER - not quite right. The permissions are checked using the COLLECTION - just like I do for a normal resource. This means that the actual permissions of the resource
     are not considered. The only requirement is to be a member of the parent-collection's owner-group.
     :)
let $edits := if (rp:resource-permissions($local:selected-resource)?user-can-edit) 
                then (
                switch ($local:form-action)
                    case 'update' return local:update()
                    case 'new' return local:new()
                    case 'delete' return local:delete()
                    default return ()
                ) 
            else (util:log-app('warn','login.pekoe.io', '#### USER ' || sm:id()//sm:real//sm:username/string() || ' TRIED TO ' || $local:form-action || ' in ' || $local:selected-resource))
           

let $conf := map {
    'doctype' : function ($item) { $local:doctype } ,
    'display-title' : function ($item) { $item/org/string() }
    }
let $default-content := lw:configure-content-map($conf)



let $content :=  map:new(($default-content,  map {
    'title' : 'Tabular Data View',
    'column-headings': local:generate-headings(), 
    'path-to-me' : '/exist/pekoe-app/Tabular-data.xql',
    'breadcrumbs' :  lw:breadcrumbs('/exist/pekoe-app/files.xql?collection=',tenant:local-path($local:selected-resource)) ,
    'hidden-menus' : map:new(($default-content?hidden-menus, map {'delete': false()})),    
    'doctype' : $local:doctype,
    (: Row attributes will depend on whether this is a list of @tablular-data files, or one single file.   :)
    'row-attributes' : if ($local:selected-resource eq '') then local:attributes-for-files#2 else local:attributes-for-one-file#2 ,
    'fields' : if ($local:selected-resource eq '') then local:fields-for-files-list() else local:fields-for-one-file(),
    'custom-row-parts' : if ($local:selected-resource ne '') then ['list-all', 'new-xxx' , 'search'] else ['list-all', 'text-search'],
    'custom-row' : map:new(($default-content?custom-row,  map {  
    'list-all'      : function ($conf) {
             
                <div class='btn-group'>
                    <form>
                        <input type="hidden" name="order-by" value="ascending-document-order" />

                        {if ($local:selected-resource ne '') then <input type='hidden' name='file' value='/exist/pekoe-files{tenant:local-path($local:selected-resource)}' /> else () }
                        <button class='btn' type='submit'>List all</button>
                    </form>
                </div>
        },
        'new-xxx'       : function ($conf) {
            let $doctype := local:record-type($local:selected-resource)
            return
                <div class='btn-group'>
                    <button class='btn' id='pNewRecordBtn'>New {$doctype}</button>                        
                </div>
            },
        'search'   : function ($conf) {
                <div class='btn-group'>
                    <form method='get' class='form-inline'>
                        <input type='hidden' name='collection' value='{$local:current-collection}'/>
                        <input type='hidden' name='file' value='/exist/pekoe-files{tenant:local-path($local:selected-resource)}' />
                        <input type='text' name='search' value='{$conf?search}' id="search" placeholder='Any Text' class='form-control'/>
                        <input  class='btn' type='submit' name='action' value='Search' />
                    </form>
                </div>
        }
    }))
    ,
    'custom-script' : function ($content) {
        <script>
        // <![CDATA[
        
        // New, Update, Delete
        // show a modal dialog with a form input for each 'field'. If 'asNew === true' then the fields will be empty.
        function tdUpdate($tr, asNew) {
                var $modal = $('#pModal');
                var $modalbody = $modal.find('.modal-body');
                var $savebtn = $modal.find('.modal-footer .btn-primary');
                var $deleteBtn = $modal.find('#modalDeleteBtn'); //.hide();

                $('#myModalLabel').text( asNew ? 'New Entry -- at end of list' : 'Edit entry');
                var $form = $('<form method="POST"></form>');
                $form.attr('action',location.href);
                
                $modalbody.html($form); // clear
                var nid = $('<input type="hidden" name="nodeid" />').val($tr.data('record'));
                $form.append(nid);
                var $action = $('<input type="hidden" name="form-action"/>').val( asNew ? 'new' : 'update'); 
                $form.append($action);
                $tr.find('td').each(function () {
                    var fname = $(this).data('field');
                    var $fg = $('<div class="form-group"></div>');
                    $fg.append('<label></label>').attr('for', fname).text(fname);
                    var $dataType = "text"; // maybe add other things like password?
                    var $inp = $('<input type="text" class="form-control"/>').attr('id',fname).attr('name',fname);
                    if (!asNew) {$inp.val($(this).text());}
                    $fg.append($inp);
                    $form.append($fg);
                }); // it may be long but it WILL scroll
                
                $deleteBtn.on('click',function () {
                    if (confirm("Do you want to delete this record?")) {
                      $action.val('delete');
                      $form.submit();
                    }
                });
                
                $savebtn.on('click', function () {  
                    $form.submit();
                });
                $modal.modal();
                /*
                $form.on('submit',function() {
                    if (asNew) {
                        console.log('you want to submit a NEW RECORD');
                    } else {
                        console.log('you want to submit changes to ',$tr.data('record'));
                        $.post(location.href,{'nodeid': $tr.data('record'), $form. 
                    }
                    return false;
                });
                */
        
        
        }
        
        $(function () { // ON READY
           // $('.menuitem').off('click').parent('li').addClass('disabled'); // disable the common menu items
            //$('.menuitem').on('click',function (e) {e.preventDefault();});
            var $delete = $('.menuitem:contains(Delete)');
            var $delli = $delete.parent('li');
            
            $delete.on('click',function (e) {
              var $tr = $('.active');
              var nodeid = $tr.data('record');
              console.log('Delete nodeid', nodeid);
              if (confirm("Delete selected entry (" + $tr.find('td:first').text() + ")")) {
                var $form = $('<form method="POST"></form>');
                $form.attr('action',location.href);
                $form.append('<input type="hidden" name="form-action" value="delete" />');
                var nid = $('<input type="hidden" name="nodeid" />').val($tr.data('record'));
                $form.append(nid);
                $('body').append($form);
                console.log($form);
                try {
                $form.submit();
                } catch (e) {console.warn(e);}
                console.log('finished');
              }
              console.log('and after');
              // else...
              $('.active').removeClass('active'); // shouldn't be necessary if the item is deleted
              $delli.addClass('disabled'); // the button shouldn't work now nothing is selected. 
              
            });
            
            $('#pNewRecordBtn').on('click', function (e) {
                var $tr = $('tr[data-record]:first');
                console.log($tr);
                tdUpdate($tr,true); // NEW RECORD
            });

            $('tr[data-record]').on('dblclick', function (e) {
                // for each td containing a field name, create a matching INPUT and attach to the Modal.
                var $tr =  $(this);
                tdUpdate($tr, false);
            })
            .on('click', function () {
                var $tr =  $(this);
                $delli.removeClass('disabled');
                $('.active').removeClass('active');
                $tr.addClass('active');
                
            });
        });
        
        //        $.post('/exist/pekoe-files/config/ajaxions.xql', {'path':path, 'action':'set-instructions-sent-date'});

        

        // ]]>
        </script>
    },
    
    'order-by' : request:get-parameter('order-by','ascending-document-order'),
    'items' :  switch ($lw:action) 
    
                case "List" return $local:items
                case "Search" return $local:items[contains(., request:get-parameter('search',''))]
                case "xpath" return lw:xpath-search($local:items)
                default return $local:items
                
})) (: end of map:new :)

return lw:list-page($content)

(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)

