xquery version "3.1";
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: 
    THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN.
    
    Manage files and collections. Close, Upload, Create, Delete.
    This file has setUid applied. It will run as admin.
    THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN.
    
    NOTE: Capture and Release are performed by the Controller forwarding to modules/resource-managment.xql
    
    Why can't UNLOCK be performed the same way?
    
:)


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

import module namespace rp = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";
import module namespace s3="http://pekoe.io/s3"; (: upload and download from AWS S3 :)
import module namespace ps3="http://pekoe.io/pekoe-s3" at "modules/s3-toc.xqm"; (: manage the config and table-of-contents (TOC) for AWS S3 :)

declare variable $local:root-collection := "/db/pekoe";
declare variable $local:base-collection := "/files";
declare variable $local:filter-out := ("xqm","xsl");
declare variable $local:action := request:get-parameter("action","");
declare variable $local:tenant := replace(request:get-cookie-value("tenant"),"%22","");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;
declare variable $local:current-user := sm:id()//sm:real;
declare variable $local:tenant-admin-group :=  $local:tenant || "_admin";
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
    util:log('debug','CURRENT USER ' || $local:current-user/sm:username || ' IS DBA? ' || sm:is-dba($local:current-user/sm:username)),
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

(: ***************************************   Pekoe-S3 - AWS S3 FILE UPLOAD ***********************************  :)

(: When an S3 upload completes successfully, store the file-data in a TOC. This is called by an Ajax request in Files.xql :)
declare function local:s3-register-file() {
    let $s3-config := ps3:config($local:tenant-path)   
    (: **** See modules/s3-toc.xqm for the structure of the file Spec.  **** :)
    (: The fileSpec is constructed as an object in the Javascript, then stringified before being posted here   :)
    let $fileSpec := parse-json(request:get-parameter("fileSpec",()))
    let $toc := doc(ps3:create-toc($local:tenant-path || $fileSpec?collection, $ps3:default-toc-name))/s3:toc
    
    (: Add the missing pieces: toc, config, user   :)
    let $fullSpec := map:new(($fileSpec, map{'toc': $toc, 'config': $s3-config, 'user':$local:current-user//sm:username/string() }))
    let $s3-file := ps3:create-file($fullSpec)
    let $update := ps3:update-toc($toc, $s3-file)
    return local:redirect-to-browse("", "", "User " || $fullSpec?user || " uploaded " || $fullSpec?key || " to S3 " || $fullSpec?bucket)

};

declare function local:move-all-to-s3() {
    let $safe-collection := request:get-parameter("path", ())
    let $s3-config := ps3:config($local:tenant-path)
    let $collection := util:collection-name($local:tenant-path || $safe-collection)
    let $uploaded := for $f in  ps3:upload-binaries-from-collection($s3-config, $local:tenant-path, $collection) return util:log-app('warn','pekoe.io',$local:current-user/sm:username/string() || ' Uploaded to S3 ' || $f) 
    (: Permissions not working here   :)
    let $s3-toc := doc($collection || "/" || $ps3:default-toc-name)/s3:toc
    let $deleted := 
        for $f in $s3-toc/s3:file
            let $is-available := util:binary-doc-available($collection || '/' || $f/string())
            let $remove := 
                if ($is-available) then (
(:                    util:log('warn', 'going to delete file ' || $f) ):)
                                    xmldb:remove($collection, $f/string()))
                                    
            else (util:log('warn',"CAN'T DELETE UPLOADED FILE " || $f))
            return (util:log('warn','Deleting ' || $f || ' after upload to s3'))
    return local:redirect-to-browse($safe-collection, 'browse', $local:current-user/sm:username/string() || ' UPLOADED FILES TO S3 FROM ' || $collection)
};

(: get a file back from s3 and store in this collection:)
declare function local:retrieve-from-s3() {
    let $path := request:get-parameter("path","")
    let $safe-collection := request:get-parameter("path", ())
    let $s3-config := ps3:config($local:tenant-path)
    let $collection := util:collection-name($local:tenant-path || $safe-collection)
    let $parent-collection := util:collection-name($path)
    let $quarantined := local:quarantined-path($parent-collection)
    
    return local:redirect-to-browse($quarantined, 'browse', $local:current-user/sm:username/string() || ' RETRIEVED FROM S3' || $path)
};

declare function local:mark-as-deleted($path) {
    (:<s3:toc xmlns:s3="http://pekoe.io/s3" created-dateTime="2017-06-05T11:18:49.363+09:30" created-by="admin">
    <s3:file key="files/test-jobs/Res-test/Cheque-request-BankSA.ods" user="admin" created-date="2017-06-02T10:29:30.000+09:30" modified-date="2017-06-02T10:29:30.000+09:30" size="108148" etag="908bda83ef56a2c2831223ac90c9f958&#34;" mime-type="application/vnd.oasis.opendocument.spreadsheet" bucket="cmpekoe" region="ap-southeast-2">Cheque-request-BankSA.ods</s3:file>
</s3:toc>

    path is s3://files/test-jobs/Res-test/Cheque-request-BankSA.ods"
    so s3:file should be 
    let $key := substring-after($path, "s3://")
    let $quarantined-collection := string-join(tokenize($key,"/")[position() ne last()],'/')
    
    and thus collection($local:tenant-path || '/' || string-join(tokenize(substring-after($path, "s3:/"),"/")[position() ne last()],'/'))//s3:file[@key eq 
:)
    let $key := substring-after($path, "s3://")
    let $quarantined-collection := string-join(tokenize($key,"/")[position() ne last()],'/')
    let $file := collection($local:tenant-path || '/' || $quarantined-collection)//s3:file[@key eq $key]
    let $replacement := element s3:deleted {
                                           $file/@*,
                                           attribute deleted-by {$local:current-user/sm:username/string()},
                                           attribute deleted-date {adjust-dateTime-to-timezone(current-dateTime(),())},
                                           $file/string()
                                       }
    let $mark-deleted := update replace $file with $replacement
    
    return $quarantined-collection
}; 

(: ***************************************     FILE UPLOAD ***********************************  :)
declare function local:file-upload() {
    let $safe-collection := request:get-parameter("collection", ())
    let $collection := $local:tenant-path || $safe-collection
    let $name := replace(request:get-uploaded-file-name("fname"),'\C|:','_') (: replace \C "A character that cannot be part of an XML name" :)
    let $file := request:get-uploaded-file-data("fname")
    let $log := util:log("debug", "GOING TO STORE " || $name || " INTO COLLECTION " || $collection)
    let $stored := xmldb:store($collection, xmldb:encode-uri($name), $file)
    let $permissions := rp:set-default-permissions($stored)
    return local:redirect-to-browse($safe-collection, 'browse',$local:current-user/sm:username/string() || ' UPLOADED FILE ' || $name || ' TO ' || $safe-collection) 
    
    (:response:redirect-to(xs:anyURI(request:get-url() || '?collection=' || $safe-collection)):)
};

declare function local:file-upload-to-job() {
    let $job := request:get-parameter("job",()) (:"car:/exist/pekoe-files/files/cars/2015/06/000001.xml":)
    let $job-path := $local:tenant-path || substring-after($job, '/exist/pekoe-files')
    let $collection := util:collection-name($job-path)
    let $log := util:log('info','UPLOAD TO JOB ' || $collection)
    
(:    let $safe-collection := request:get-parameter("collection", ()):)
(:    let $collection := $local:tenant-path || $safe-collection:)
    let $name := request:get-uploaded-file-name("file")
    let $file := request:get-uploaded-file-data("file")
    let $log := util:log("debug", "GOING TO STORE " || $name || " INTO COLLECTION " || $collection)
    let $stored := xmldb:store($collection, xmldb:encode-uri($name), $file)
    let $permissions := rp:set-default-permissions($stored)
    return <result>Stored {$name} in {$collection}</result>
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
(:    let $export := system:export-silently($real-path, false(),true()) 
    DOCS for this function are wrong and also requires dba. 
    :)
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

(: Are there special cases? e.g. Templates Bundles.???  Template needs a special handle anyway. :)
declare function local:is-bundle($path) as xs:boolean {
    (doc-available($path) and doc($path)/@bundled eq '1')
};

declare function local:trash-file-or-collection($path) as xs:string {
    let $real-path := $local:tenant-path || $path
    let $parent-collection := util:collection-name($real-path)
    let $delete-log:= if (xmldb:collection-available($real-path)) 
                    then util:log("warn", "GOING TO DELETE COLLECTION (real-path)" || $real-path || " (path)" || $path )
                    else util:log("warn", "GOING TO DELETE " || util:document-name($real-path) || " FROM COLLECTION " || $parent-collection )
                    
    let $z := compression:zip(xs:anyURI($real-path),true())
    let $trash-path := $local:tenant-path || '/trash'
    let $name := local:good-trash-name($path)
    let $stored := xmldb:store($trash-path,$name,$z)
    (: REALLY DELETE IT :)
    let $delete := if (xmldb:collection-available($real-path)) 
        then xmldb:remove($real-path) 
        else xmldb:remove($parent-collection, util:document-name($real-path))
    return 'Deleted file ' || $path

};  

declare function local:good-trash-name($path) {
    let $n := local:good-file-name($path,'collection') (: 'files/jobs/2015/11/RT-000066' -> 'files-jobs-2015-11-RT-000066' :)
    let $trash := $local:tenant-path || '/Trash/'
    let $ds := format-date(current-date(), '[Y][M][D]')
(:    let $exists := util:binary-doc-available($trash || $n):)
    (: at the moment I'm not going to allow multiple deleted versions per day :)
    return  $n || "-" || $ds || ".zip"
    
};

declare function local:trash-bundle($path) as xs:string {
    (: $path points to a Job file where @bundle=1. The 'name' is that of the parent collection   :)
    let $r := util:collection-name($path)
    let $local-p := substring-after($r,$local:tenant-path || '/')
    let $name := local:good-trash-name($local-p)
    (: This zip file will contain the full folder-path from /db to the file.   :)
    let $z := compression:zip(xs:anyURI($r),true()) (: Use Hierarchy is true so that path-to-collection AND path-within-bundle are captured. :)
    
    let $stored := xmldb:store($local:tenant-path, $name,$z)
    
    (: now - really DELETE the bundle...    :)
    
    return "Trashed bundle " || $name

};  

(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)

(: Zip the target and move to the tenant's Deleted collection. If the target is a bundle-doc, then the target is its parent. :)
(:  THIS IS THE ENTRY POINT :)
declare function local:do-trash() {
    let $path := request:get-parameter("path","")
    return if ($path eq $local:base-collection) 
    then (response:set-status-code(304),response:set-header("Location", request:get-url()))
    else if (starts-with($path, "s3:")) then 
        let $quarantined := local:mark-as-deleted($path)
        let $log := util:log("warn", "attempt to delete s3 " || $path)
        return local:redirect-to-browse($quarantined,'browse', $path)
    else
    let $trash-can := xmldb:create-collection($local:tenant-path, "trash")
(:  A USER CAN DELETE AN ADMIN FILE - WHY??? WHERE ARE THE CHECKS?   :)
    let $real-path := $local:tenant-path || $path
    let $parent-collection := util:collection-name($real-path)
    let $quarantined := local:quarantined-path($parent-collection)
    let $pekoe-log := util:log-app('warn', 'login.pekoe.io','********* NOTE: ' || $local:current-user/sm:username/string() || ' DELETED ' || $real-path)
    let $delete := if (local:is-bundle($path)) 
        then local:trash-bundle($path) 
        else local:trash-file-or-collection($path)
                    
    return (local:redirect-to-browse($quarantined, 'browse',$delete))   
};

(:
    The biggest hassle with a BUNDLE is knowing whether the data is IN ONE.
    A better way to write that is ...
    
    So how can I decide if the user is referring to the data of a BUNDLE?
    - The file name is data.xml
    - The collection has the same name as the job/id (too hard to check and not guaranteed)
    - The data file has an attribute (means remembering to include it for every 'new' file)
    
    I suppose the first option is the best because I can easily make a RULE that files should only be called 'data.xml' if they're stored in a bundle.
    (Enforcing that rule is difficult)
    
:)

(:declare function local:trash() {
    let $path := request:get-parameter("path","")
    return if ($path eq $local:base-collection) then  (response:set-status-code(304),response:set-header("Location", request:get-url()))
    else
    let $real-path := $local:tenant-path || $path
    let $parent-collection := util:collection-name($real-path)
    (\: First issue - how to handle BUNDLEs    :\)
    (\: Second issue - remember to COPY and DELETE - don't use MOVE as its flawed.   :\)
    let $quarantined := local:quarantined-path($parent-collection)
    let $delete-log:= if (xmldb:collection-available($real-path)) 
                    then util:log("warn", "GOING TO TRASH COLLECTION (real-path)" || $real-path || " (path)" || $path )
                    else util:log("warn", "GOING TO TRASH " || util:document-name($real-path) || " FROM COLLECTION " || $parent-collection )
    let $delete:= if (xmldb:collection-available($real-path)) 
                    then xmldb:remove($real-path)
                    else xmldb:remove($parent-collection, util:document-name($real-path))
                    
    return (local:redirect-to-browse($quarantined, 'browse','deleted the file'))   
    
};:)



(:A change-owner or change-group function would be useful. Like 'new' these need params. A modal would be nice. :)

(: BOTH unlock and delete need to have checks to ensure that the user is the correct owner.
    BUT Unlock _should_ only set the file to the 'correct' state - based on the current collection and rules.
:)
declare function local:unlock-file() {
    let $path := request:get-parameter("path","") (: /files/schemas/trimmed-txo-schema.xml :)
    return if ($path eq "" ) then (response:set-status-code(304),response:set-header("Location", request:get-uri()))
    else
        let $real-path := $local:tenant-path || $path 
        let $quarantined := local:quarantined-path(util:collection-name($real-path))
        return (rp:unlock-file($real-path),local:redirect-to-browse($quarantined, 'browse','UNLOCK FILE COMMAND'))
        
(:        let $permissions := rp:resource-permissions($real-path)
        let $uri := xs:anyURI($real-path)
(\:        let $parent := util:collection-name($real-path):\)
(\:        TODO - use mime type and/or check for binary or collection to handle XQuery, Collection or other data types. :\)
        let $quarantined := local:quarantined-path(util:collection-name($real-path))
(\:        let $collection-permissions := sm:get-permissions(xs:anyURI($parent)):\)
(\:        let $group-owner := $collection-permissions/sm:permission/data(@group):\)
           (\:        The file needs to have the same owner and group as its parent-collection. This should be the rule. Thus
           If the parent-coll is owned by :\)
        return 
            if (not(doc-available($real-path))) then (local:redirect-to-browse($quarantined, 'browse','could not unlock the file'))
            else (
            (\:util:exclusive-lock(doc($real-path), (sm:chown($uri, $group-owner), sm:chgrp($uri, $group-owner), sm:chmod($uri, "rw-r-----"))),:\) 
            util:exclusive-lock(doc($real-path), (sm:chown($uri, $permissions?col-owner), sm:chgrp($uri, $permissions?col-group), sm:chmod($uri, $rp:closed-and-available))),
            (local:redirect-to-browse($quarantined, 'browse','unlocked the file'))
            ):)
};

declare function local:redirect-to-browse($path, $action,$message) {
    util:log('info',$message), response:redirect-to(xs:anyURI(request:get-header('Referer')))  (: Beautiful :)
};

declare function local:do-data() {
(:  /db/pekoe/tenants/bkfa/exist/pekoe-files/files/members/2015/member-000002.xml.  :)
    let $resource := request:get-parameter("path",())
    let $resource-full-path :=  '/exist/pekoe-files' || $resource
    return response:redirect-to(xs:anyURI($resource-full-path))
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
    let $chmod := sm:chmod($uri, $rp:closed-and-available)
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
    let $fn := request:get-parameter("file-name","")
    let $file-name := if ($item-type eq 's3:toc') then 'S3-TOC.xml' else local:good-file-name($fn,$item-type)
    let $permissions := rp:collection-permissions($full-path)
    
    return if ($item-type eq '') then local:redirect-to-browse($path,"browse","missing item-type")
    else if ($fn eq '') then local:redirect-to-browse($path,"browse","missing file-name")
    else if (not($permissions('editor'))) then local:redirect-to-browse($path,"browse","user is not editor")
    else 
        let $result :=  
            if ($item-type eq "collection") then (
               let $new := xmldb:create-collection($full-path,$file-name)
               let $uri := xs:anyURI($new)
               let $chown := sm:chown($uri, $permissions('col-owner'))
               let $chgrp := sm:chgrp($uri, $permissions('col-group'))
               let $chmod := sm:chmod($uri, $rp:collection-permissions)
               return 'created collection ' || $new )
            else local:new-file($item-type,$full-path,$file-name, $permissions)

        return local:redirect-to-browse($path, "browse", $result )
};

declare function local:copy-move($collection, $parent-collection) {
    (:xmldb:move($resource-full-path, $parent-collection) - causes a database error :)
    if (xmldb:collection-available($collection)) then (
    xmldb:copy($collection, $parent-collection),
    xmldb:remove($collection))
    else util:log('warn', '>>>>>>>>>>>>>>>>>>>>> UNABLE TO Copy/REMOVE COLLECTION ' || $collection) 
};

(: Copy move results in WRONG PERMISSIONS :)
declare function local:copy-move($collection, $parent-collection, $resource-doc) {
    (:    xmldb:move($collection, $parent-collection, $resource-doc):)
    xmldb:copy($collection,$parent-collection, $resource-doc),
    xmldb:remove($collection, $resource-doc)
};

declare function local:do-move-up(){
    let $resource := request:get-parameter("path",())
    let $resource-full-path := $local:tenant-path || $resource
    let $collection := util:collection-name($resource-full-path)
    let $parent-collection := util:collection-name($collection)
    
    (: ************* TODO - replace xmldb:move with store and remove. Add check for existing file ******************    :)
    
    let $resource-doc := util:document-name($resource-full-path)
    let $original-collection := substring-after($collection,$local:tenant-path)
    
    let $log: = util:log('debug', '*************** MOVE ' || $resource || ' UP TO ' || $parent-collection || ' and redirect to ' || $original-collection)
    let $move := if ($resource-doc) 
        then local:copy-move($collection, $parent-collection, $resource-doc)
        else if ($parent-collection ne $local:tenant-path) 
            then local:copy-move($resource-full-path, $parent-collection)
            else ()
    return local:redirect-to-browse($original-collection, "browse", "moved")
};

declare function local:do-move(){
    let $target := request:get-parameter("collection",())
    let $target-full-path := $local:tenant-path || $target
    let $resource := request:get-parameter("resource",())
    let $resource-full-path := $local:tenant-path || $resource
    let $resource-doc := util:document-name($resource-full-path)
    let $original-collection := util:collection-name($resource)
    (: ************* TODO - replace xmldb:move with store and remove. Add check for existing file ******************    :)    
    
    let $log: = util:log('info', '*************** MOVE ' || $resource || ' INTO ' || $target || ' by USER ' || $local:current-user/sm:username/string())
    let $move := if ($resource-doc) 
        then xmldb:move(util:collection-name($resource-full-path), $target-full-path, $resource-doc)
        else if ($resource-full-path ne $target-full-path) then xmldb:move($resource-full-path,$target-full-path)
        else ()
    return local:redirect-to-browse($original-collection, "browse", "moved")
};

declare function local:title($path-parts) {
    let $t := $path-parts[position() eq last()]
    return concat(upper-case(substring($t,1,1)), substring($t,2))
};

(: TODO: WRITE AND TEST THE JAVASCRIPT - NEEDS A PROMPT FOR NEW-NAME :)
declare function local:do-rename(){
    let $target := request:get-parameter("collection",())
    let $target-full-path := $local:tenant-path || $target
    let $resource := request:get-parameter("resource",())
    let $new-name := request:get-parameter("new-name",())
    let $resource-old-name := $local:tenant-path || $resource
    let $resource-new-name := $local:tenant-path || $new-name
    let $resource-doc := util:document-name($resource-old-name)
    let $conflicting-doc := util:document-name($resource-new-name)
    let $original-collection := util:collection-name($resource)
    
    let $log: = util:log('warn', '*************** RENAME ' || $resource-doc || ' TO ' || $new-name)
     (: let $move := if ($conflicting-doc) then local:redirect-to-browse($original-collection, "browse", "NOT MOVED - CONFLICT WITH EXISTING DOC " || $new-name)
        else if ($resource-doc) 
        then xmldb:rename($original-collection, $target-full-path, $resource-doc)
(\:      else rename collection  :\)
        else ():)
    return local:redirect-to-browse($original-collection, "browse", "renamed")
};

(: ************************** MAIN QUERY *********************** :)

(: THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
        
(:        try {:)
    (: NO default action :)
         if ($local:action eq "unlock")         then local:unlock-file()
    else if ($local:action eq "upload")         then local:file-upload()
    else if ($local:action eq "upload-to-job")  then local:file-upload-to-job()
    else if ($local:action eq "s3-success")     then local:s3-register-file()
    else if ($local:action eq "all-to-s3")      then local:move-all-to-s3()
    else if ($local:action eq "retrieve-from-s3")      then local:retrieve-from-s3()
    else if ($local:action eq "create")         then local:do-new()
    else if ($local:action eq "delete")         then local:do-trash()
    else if ($local:action eq "move")           then local:do-move()
    else if ($local:action eq "move-up")        then local:do-move-up()
    
    else if ($local:action eq "rename")         then local:do-rename()
    else if ($local:action eq "data")           then local:do-data()
    else <result status='error'>Unknown action {$local:action} </result>
    
(:    } catch * { "CAUGHT ERROR " || $err:code || ": " || $err:description || " " || $local:action }:)
            
(: THIS FILE HAS SETUID APPLIED. IT WILL RUN AS ADMIN. :)
