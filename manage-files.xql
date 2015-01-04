xquery version "3.0";
(: 
    Manage files and collections. Close, Upload, Create, Delete.
    This file has setUid applied. It will run as admin.
    THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN.
    
    NOTE: Capture and Release are performed by the Controller forwarding to modules/resource-managment.xql
    
    Why can't UNLOCK be performed the same way?
    
    
:)




declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

import module namespace resource-permissions = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";
import module namespace list-wrapper = "http://pekoe.io/list/wrapper" at "list-wrapper.xqm";


declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:filter-out := ("xqm","xsl");
declare variable $local:action := request:get-parameter("action","");
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
 


(:
    Display the contents of a collection in a table view.
:)

declare function local:quarantined-path($real-path) {
    substring-after($real-path, $local:tenant-path)
};

declare function local:user-is-admin-for-tenant() {
sm:is-dba($local:current-user/sm:username) or sm:get-user-groups($local:current-user/sm:username) = $local:tenant-admin-group

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
                    
    return (local:redirect-to-browse($quarantined, 'browse','deleted the file'))    
};

(:A change-owner or change-group function would be useful. Like 'new' these need params. A modal would be nice. :)

(: BOTH unlock and delete need to have checks to ensure that the user is the correct owner.:)
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
(:        The file needs to have the same owner and group as its parent-collection. This should be the rule. Thus
If the parent-coll is owned by :)
        return 
            if (not(doc-available($real-path))) then (response:set-status-code(304),response:set-header("Location", request:get-uri()))
            else (
            util:exclusive-lock(doc($real-path), (sm:chown($uri, $group-owner), sm:chgrp($uri, $group-owner), sm:chmod($uri, "r--r-----"))),
            (response:set-status-code(205),response:set-header("Location", request:get-uri() || "?collection=" || $quarantined ))
            )
};

declare function local:redirect-to-browse($path, $action,$message) {
    util:log('info',$message),
    response:redirect-to(xs:anyURI("/exist/pekoe-app/files.xql" || '?collection=' || $path))
};


(:  This is nice, but doesn't add an ID and allows creation of fragment-elements (like "item" which is a child of ca-resources) HUH? Why? :)
declare function local:new-file($doctype, $colname,$file-name, $permissions) {
    if (doc-available($colname || '/' || $file-name)) then 'file exists at ' || $colname || '/' || $file-name
    else
    let $new-file := element {$doctype} {
                         attribute created-dateTime {current-dateTime()},
                         attribute created-by {$local:current-user/sm:username/text()}
                     }
    let $new := xmldb:store($colname, $file-name, $new-file)
    let $uri := xs:anyURI($new)
    let $chown := sm:chown($uri, $permissions('col-owner'))
    let $chgrp := sm:chgrp($uri, $permissions('col-group'))
    let $chmod := sm:chmod($uri, $resource-permissions:closed-and-available)
    return 'created file ' || $new 
};

(:Need to incorporate checks for WRITE and EDIT - does the current-user belong to the collection-owner's group? 
  Alternative is to respect the permissions on the collection. e.g. tdbg_staff rwxr-x--- means that I can't write. But really, NOBODY can write
  because tdbg_staff is not a login-user. 
  So - stick with the plan. The collection-owner's group determines who can WRITE and EDIT. The collection-group and/or file-group determines who can READ.
  :)

declare function local:do-new() {
(:  Must have a $path and a $file-name and a doctype  :)
    let $path := request:get-parameter("collection",$local:base-collection)
    let $full-path := $local:tenant-path || $path
    let $item-type := request:get-parameter("doctype","") 
    let $file-name := local:good-file-name(request:get-parameter("file-name",""),$item-type)
    let $permissions := resource-permissions:collection-permissions($full-path)
    
    return if ($item-type eq '' or $file-name eq '' or not($permissions('editor'))) then local:redirect-to-browse($path,"browse","missing information or incorrect permissions")
    else 
        let $result :=  
            if ($item-type eq "collection") then (
               let $new := xmldb:create-collection($full-path,$file-name)
               let $uri := xs:anyURI($new)
               let $chown := sm:chown($uri, $permissions('col-owner'))
               let $chgrp := sm:chgrp($uri, $permissions('col-group'))
               let $chmod := sm:chmod($uri, $resource-permissions:collection-permissions)
               return 'created collection ' || $new )
            else local:new-file($item-type,$full-path,$file-name, $permissions)

        return local:redirect-to-browse($path, "browse", $result )
};

declare function local:title($path-parts) {
    let $t := $path-parts[position() eq last()]
    return concat(upper-case(substring($t,1,1)), substring($t,2))
};

(: ************************** MAIN QUERY *********************** :)


        
(:        try {:)
    (: NO default action :)
         if ($local:action eq "unlock") then local:unlock-file()
    else if ($local:action eq "upload") then local:file-upload()
    else if ($local:action eq "create")    then local:do-new()
    else if ($local:action eq "delete") then local:do-delete()
    else <result status='error'>Unknown action {$local:action} </result>
    
(:    } catch * { "CAUGHT ERROR " || $err:code || ": " || $err:description || " " || $local:action }:)
            