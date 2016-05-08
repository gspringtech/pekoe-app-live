(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(:
    Top-level query manages access to files. 
    Manage Capture and Release
    Access only via controller (how can I prevent other access?)
:)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
xquery version "3.0"; 


import module namespace rp = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";


declare variable $local:basepath := ""; (: must end with slash :)

declare variable $local:method := request:get-method();
declare variable $local:action := request:get-parameter("action","");
declare variable $local:path := request:get-parameter("realpath",""); (: Comes from the controller. :)
declare variable $local:tenant-files := "/db/pekoe/" || request:get-parameter("tenant-path","") || "/files";
(:declare variable $local:res := rp:resource-permissions($local:path);:)
(:declare variable $local:is-closed-and-available := $local:res('mode') eq $rp:closed-and-available;:)

(: To be "closed" a file must be rw-r------ and 
   have the same owner and group as its collection.
   Maybe.
   
   What is the advantage of this over just having rw-r-----?
   
   The main advantage is that I don't have to remember who owned the file before it is opened. 
   2016-01-12. Hmmmm. Doesn't sound so good now.
   
   The advantage of using the collection-owner and -group is that the -owner should be a group-user and will determine 
   who can edit the file, while the -group determines who can read the file.
   
   The collection will by inherit its parent-collection owner and group, but it can be modified as needed.
   However, files within a collection are either "open" or "closed".
   
   ------- 2016-01-12
   What about the Editors/Viewers approach? 
   Members of the eponymous owner-group are Editors, members of the file's group are Viewers. 
   Then - an Edit check becomes simpler. Is the user a member of the owner-group?
   -------
   
   :)


(:  LOCK a resource - making it OPEN for editing.
    First - is the file already locked?
    First, is the current user able to edit the file?
    current-user has group eq collection-owner's group
    e.g if the current collection is owned by tdbg_admin then the current user must be in that group. 
    Also, the file should be rw-r-----
:)
declare function local:lock-file() { (: ------------- CAPTURE ------------- :)
    let $res := rp:resource-permissions($local:path)
(:   If the user is the owner OR... :)
(:   if the file is closed-and-available AND the user-can-edit, then lock the file. :)
    return 
        if ($res?user-is-owner or ($res?closed-and-available and $res?user-can-edit)) 
        then local:capture-file($res)
        (:   Otherwise, report the error. :)
        else local:report-capture-problem($res)

};

declare function local:capture-file($res) {
    let $doc := doc($local:path)
    let $local:action :=  util:exclusive-lock($doc, local:really-lock-file($local:path, $res))
    let $new-res := rp:resource-permissions($local:path)
    return if (local:confirm-my-lock($new-res)) 
        then $doc
        else (util:log('warn','--------------------- File cannot be captured for UNKNOWN REASONS: '),
            map:for-each-entry($res, function ($k,$v) { util:log('info','----------------------- ' || $k || ' - ' || $v) }),
            response:set-status-code(404),
            response:set-header("Content-type","application/xml"),
            <result status="fail" >{sm:get-permissions(xs:anyURI($local:path))}</result>) 
};

declare function local:report-capture-problem($res) {
    (:   You are not allowed to edit. user-can-edit is false :)
    if ($res?user-can-edit eq false()) then 
    (  
        util:log('warn','--------------------- User tried to capture file when user-can-edit is false. '),
        map:for-each-entry($res, function ($k,$v) { util:log('info','----------------------- ' || $k || ' - ' || $v) }),
        response:set-status-code(404),
        response:set-header("Content-type","application/xml"),
        <result status="fail" >You are not allowed to edit this file.</result>
    )
    (:   Someone else is editing it - locked-for-editing :)
    else if ($res?locked-for-editing) then 
    (  
        response:set-status-code(404),
        response:set-header("Content-type","application/xml"),
        <result status="fail" >File is currently being edited by {$res?owner}.</result>
    ) 
    else if (not($res?closed-and-available)) then
    (  
        util:log('warn','--------------------- File has wrong permissions for editing: '),
        map:for-each-entry($res, function ($k,$v) { util:log('info','----------------------- ' || $k || ' - ' || $v) }),
        response:set-status-code(404),
        response:set-header("Content-type","application/xml"),
        <result status="fail" >File has incorrect permissions for editing {$res?mode}.</result>
    )
    else (
        util:log('warn','--------------------- File cannot be captured for UNKNOWN REASONS: '),
        map:for-each-entry($res, function ($k,$v) { util:log('info','----------------------- ' || $k || ' - ' || $v) }),
        response:set-status-code(404),
        response:set-header("Content-type","application/xml"),
        <result status="fail">An error has occurred</result>
        )
};

declare function local:confirm-my-lock($res) { (: Am I now the owner of the file? :)
    ($res('owner') eq $res('username')) and ($res('mode') eq $rp:open-for-editing)
};

(: NOTE: This MUST be performed within an exclusive-lock.  :)
declare function local:really-lock-file($href, $res) {
    let $uri := xs:anyURI($href)
    let $locked := xmldb:document-has-lock($res('collection'), $res('docname')) (: Checking to see if someone else has just locked it. :)
    let $is-closed-and-available := $res('mode') eq $rp:closed-and-available 
    return if (not($locked) and $is-closed-and-available)
    then local:set-open-for-editing($uri)
    else 
        (: Usually this is because the user already has the file open.   :)
        util:log("warn", "NOT ABLE TO CAPTURE FILE. SYSTEM-LOCKED? " 
        || (if ($locked) then 'YES' else 'NO') 
        || ', AVAILABLE? ' 
        || (if ($is-closed-and-available) 
            then 'YES'
            else ('NO because:' || $res('mode'))) )            
};



(: this should be okay - only the owner can modify :)
(: THIS IS A TERRIBLE FUNCTION NAME. :)
declare function local:set-open-for-editing($uri) {
    let $res := rp:resource-permissions($local:path)
    let $log := util:log('info','          +++++++++++ USER '  || $res?username || ' CAPTURED ' || $uri)
    return    (
    sm:chown($uri,$res?username), 
    (: DON'T CHANGE THE GROUP. The Group determines who can READ the file, which can be different to who can EDIT. :)
    sm:chmod($uri, $rp:open-for-editing))
};

(: Some basic parameter checking might be a good idea!! file path, for starters :)
(:This is the "save" function end-point. :)

declare function local:store-post() {
    (: Client sends path (eg. /db/pekoe/config/template-meta/CM/Residential-Cover.xml) and action if any :)
    (: Obviously depends on the user having write permission on the file - only possible if they are the owner and have "opened" the file. :)
    let $data := request:get-data()
    return 
        local:store($data, $local:path)
};

(: This is a "save" of an open file. :)
declare function local:store($data, $fullpath) {
    let $collection-path := util:collection-name($fullpath) (: collection-name must refer to an existing item. It isn't a string-function. :)
    (:    THIS WON'T WORK IF THERE'S NO EXISTING CONTENT. HALF A DAY :)
    let $resource-name := if (doc-available(xs:anyURI($fullpath))) then util:document-name($fullpath) else tokenize($fullpath,'/')[last()]
    let $local-part := substring-after($collection-path,$local:tenant-files)
    let $local-path := if (starts-with($local-part, '/')) then substring-after($local-part,'/') else $local-part
    let $goodCollection := if (not(xmldb:collection-available($collection-path))) then rp:create-collection($local:tenant-files,$local-path) else $collection-path
    let $result := xmldb:store($goodCollection,$resource-name, $data)
    let $update-permissions :=   local:set-open-for-editing(xs:anyURI($fullpath))
    return if ($result) then
             <result status="okay" >{$result}</result>
             else <result status='fail' />
    }; 
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)

(: -----------------------------------  MAIN TRANSACTION QUERY --------------------- :)
if ($local:method eq "GET") then 
    if ($local:path eq "") then                         (response:set-status-code(400), <result status='error'>GET missing $path</result>)
    else if (not(doc-available($local:path))) then      (response:set-status-code(404), <result status='error' path='{$local:path}'>Resource not found - has it moved?</result>)
    else if ($local:action eq 'capture') then	        local:lock-file()
    else if ($local:action eq 'release') then           rp:release-job($local:path)
    else                                                (response:set-status-code(400), <result status='error'>GET Action { if ($local:action eq "") then "missing" else concat("unknown: ", $local:action) }</result>)
else if ($local:method eq "POST") then                  local:store-post()
else                                                    (response:set-status-code(405), <result status='error'>Method not recognised: {$local:method}</result>)


