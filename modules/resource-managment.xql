(:
    Top-level query manages access to files. 
    Manage Capture and Release
    Access only via controller (how can I prevent other access?)
:)
xquery version "3.0"; 


import module namespace resource-permissions = "http://pekoe.io/resource-permissions" at "resource-permissions.xqm";


declare variable $local:basepath := ""; (: must end with slash :)

declare variable $local:method := request:get-method();
declare variable $local:action := request:get-parameter("action","");
declare variable $local:path := request:get-parameter("realpath",""); (: Comes from the controller. :)
declare variable $local:res := resource-permissions:resource-permissions($local:path);
declare variable $local:is-closed-and-available := $local:res('mode') eq $resource-permissions:closed-and-available;

(: To be "closed" a file must be r--r------ and 
   have the same owner and group as its collection.
   Maybe.
   
   What is the advantage of this over just having r--r-----?
   
   The main advantage is that I don't have to remember who owned the file before it is opened.
   
   The advantage of using the collection-owner and -group is that the -owner should be a group-user and will determine 
   who can edit the file, while the -group determines who can read the file.
   
   The collection will by default inherit its parent-collection owner and group, but it can be modified as needed.
   However, files within a collection are either "open" or "closed".
   
   So - the check for "available" is simply "is it r--r-----"?
   And then to close it, set it back to collection-owner, collection-group, r--r-----
   
   Are there any reasons I might want a different group on the file? Because then I could leave the Group alone - whatever is set, 
   and simply set the owner and permissions.
   :)

(:declare variable $local:test := resource-permissions:test('/db');:)


(: What is the desired behaviour?
    Want to lock a file and return it.
    If we can't lock the file, what do we return? 
    Nothing?
    A message?
    An error?
    
    Should either return a 403 "Forbidden" or 409 "Conflict"
    both can contain an explanation document (body)
    
    
<sm:id xmlns:sm="http://exist-db.org/xquery/securitymanager">
    <sm:real>
        <sm:username>tdbg@thedatabaseguy.com.au</sm:username>
        <sm:groups>
            <sm:group>tdbg@thedatabaseguy.com.au</sm:group>
            <sm:group>tdbg_admin</sm:group>
            <sm:group>tdbg_staff</sm:group>
            <sm:group>pekoe-staff</sm:group>
        </sm:groups>
    </sm:real>
    <sm:effective>
        <sm:username>admin</sm:username>
        <sm:groups>
            <sm:group>pekoe-staff</sm:group>
            <sm:group>perskin@conveyancingmatters.com.au</sm:group>
            <sm:group>tdbg@thedatabaseguy.com.au</sm:group>
            <sm:group>jerskine@conveyancingmatters.com.au</sm:group>
            <sm:group>barry</sm:group>
            <sm:group>dba</sm:group>
        </sm:groups>
    </sm:effective>
</sm:id>

<sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="tdbg@thedatabaseguy.com.au" group="tdbg_staff" mode="rwxr-----">
    <sm:acl entries="0"/>
</sm:permission>
    
:)


(:declare function local:permissions($href) {
    let $uri := xs:anyURI($href)
    let $file-permissions := sm:get-permissions($uri)
    
    let $parent := util:collection-name($href)
    let $current-user := sm:id()//sm:real
    let $current-username := $current-user/sm:username/text()
    let $users-groups := $current-user//sm:group/text()
    let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
    let $eponymous-owner-group := $collection-permissions/sm:permission/@owner
    let $user-can-edit := $users-groups = $eponymous-owner-group (\: collection-owner must also be a group-name and user must belong to that group :\)

    
    let $permissions := map { 
        "collection" := util:collection-name($href),
        "docname" := util:document-name($href),
        "owner" := string($file-permissions/sm:permission/@owner),
        "group" := string($file-permissions/sm:permission/@group),
        "col-owner" := string($collection-permissions/sm:permission/@owner),
        "col-group" := string($collection-permissions/sm:permission/@group),
        "mode" := string($file-permissions/sm:permission/@mode),
        "editor" := $user-can-edit,
        "user" := $current-user,
        "username" := $current-username
    }
    return $permissions      
};:)

(: User has the file open and now wants to close it. :)
declare function local:unlock-file() { 
    let $doc := doc($local:path)
    return util:exclusive-lock($doc, local:really-unlock-file($local:path))
};

(: NOTE: This MUST be performed within the lock above:)
declare function local:really-unlock-file($href) {
    let $uri := xs:anyURI($href)
    return if ($local:res('owner') eq $local:res('username')) (: and $is-open-for-editing)  -- this caused problems with files that didn't close correctly initially.:) 
        then (sm:chown($uri, $local:res('col-owner')), sm:chmod($uri,$resource-permissions:closed-and-available), <result>success</result>)
        else <result>fail</result>
};

(:  LOCK a resource - making it OPEN for editing.
    First, is the current user able to edit the file?
    current-user has group eq collection-owner's group
    e.g if the current collection is owned by tdbg_admin then the current user must be in that group. 
    Also, the file should be r--r-----
:)
declare function local:lock-file() {
    if (not($local:res('editor'))) 
    then (  response:set-status-code(404),
            response:set-header("Content-type","application/xml"),
            <result status="fail" >You cannot edit. {$local:res('user')//sm:group/text()} {sm:get-permissions(xs:anyURI($local:path))}</result>
            )
    else
    let $doc := doc($local:path)
    let $local:action :=  util:exclusive-lock($doc, local:really-lock-file($local:path))
    let $res := resource-permissions:resource-permissions($local:path)
    return if (local:confirm-my-lock($res)) 
        then $doc   (: Try returning the document itself! :)
        else (
            response:set-status-code(404),
            response:set-header("Content-type","application/xml"),
            <result status="fail" >{sm:get-permissions(xs:anyURI($local:path))}</result>) 
};

declare function local:confirm-my-lock($res) { (: Am I now the owner of the file? :)
    util:log("debug","USER:" || $res('user')
            || ", OWNER:" || $res('owner') 
            || ", MODE:" || $res('mode')),
    ($res('owner') eq $res('username')) and ($res('mode') eq $resource-permissions:open-for-editing)
};

(: NOTE: This MUST be performed within an exclusive-lock.  :)
declare function local:really-lock-file($href) {
    let $uri := xs:anyURI($href)
    let $locked := xmldb:document-has-lock($local:res('collection'), $local:res('docname')) (: HUH? Didn't I just lock it? :)
    
    return if (not($locked) and $local:is-closed-and-available) 
    then local:set-open-for-editing($uri)
    else 
        util:log("warn", "NOT ABLE TO CAPTURE FILE. SYSTEM-LOCKED? " 
        || (if ($locked) then 'YES' else 'NO') 
        || ', AVAILABLE? ' 
        || (if ($local:is-closed-and-available) 
            then 'YES'
            else ('NO because:' || $local:res('mode'))) )            
};

declare function local:check-user-permissions($subdir) {
    sm:has-access(xs:anyURI($subdir), 'rwx')
};

(:/db/pekoe/files/test/testing   FN  /db/pekoe/files/2009/2/Tx-00037.xml  
:)
declare function local:get-good-transaction-directory($fullpath) { 
(: If the directory at $fullpath exists, return it. :)
    if (xmldb:collection-available($fullpath)) then $fullpath
    else 
    let $newcoll :=  local:create-collection($local:basepath,substring-after($fullpath,$local:basepath))
    return $newcoll
    (: create a collection within /db/pekoe/files/ :)
};

(: basepath must already exist (basepath: /db/pekoe/files/ subpath: test/testing )  :)
(: basepath is /db/pekoe/files/ subpath is 2009/2
 This recursive fn creates a subdir and its parents and sets correct permissions.
 I think it is probably obsolete.
:)
declare function local:create-collection($basepath as xs:string, $subpath as xs:string) as xs:string {
    if ( $subpath = ("","/" ) ) 
    then $basepath (: We're already there. No need to create :)
    else 
        let $subdirname := tokenize($subpath,'/')[1] (: e.g. 2009/2 -> 2009 :)
        let $subdir := concat($basepath, $subdirname,"/") (: e.g. /db/pekoe/files/2009/ :)
    
        let $newcoll :=
            if (xmldb:collection-available($subdir))  (: then continue down the path to the next subdir:)
            then () (: no need to make it :)
            else 
             let $newcoll := xmldb:create-collection($basepath,$subdirname) (: Returns the path to the new collection as a string - or the empty sequence :)
             let $group := xmldb:get-group($basepath)
             let $set-rules := xmldb:set-collection-permissions(
                        $subdir,
                        $group, 
                        $group, 
                        $resource-permissions:collection-permissions)
                    
            return ()   
        return local:create-collection($subdir, string-join(tokenize($subpath,'/')[position() gt 1],'/'))    
};

(:declare function local:check-name() {
    let $fn := concat($local:basepath,request:get-parameter("fn", ()))
    return
        if (exists(doc($fn))) 
            then 
                let $pathParts := local:split-into-coll-and-fn($fn)
                let $current-user := xmldb:get-current-user()
                let $valid-user := $current-user eq xmldb:get-owner($pathParts[1],$pathParts[2]) 
                let $current-permissions := xmldb:get-permissions($pathParts[1], $pathParts[2])
                let $available := if ($valid-user  and $current-permissions eq $local:open-for-editing) 
                    then "okay" else "fail"
                return <result status="{$available}">{$fn}</result>
            else 
                <result status="okay" />
   
(\:  If file doesn't exist then check the directory to see if we can write it. Return yes or no (??)
    If file does exist then check to see if we have it open and locked (for update). Return yes or no.
    :\)
};
:)


(: Some basic parameter checking might be a good idea!! file path, for starters :)
(:This is the "save" function end-point. :)
declare function local:store-post() {
(: Client sends path (eg. /db/pekoe/config/template-meta/CM/Residential-Cover.xml) and action if any :)
(: Obviously depends on the user having write permission on the file - only possible if they are the owner and have "opened" the file. :)

    let $data := request:get-data()
    return 
        local:store($data, $local:path)
};

(: this should be okay - only the owner can modify :)

declare function local:set-open-for-editing($uri) {
    sm:chown($uri,$local:res('username')), 
    sm:chgrp($uri, $local:res('collection')), 
    sm:chmod($uri, $resource-permissions:open-for-editing)
};

(: This is a "save" of an open file. :)
declare function local:store($data, $fullpath) {

    let $pathParts := (util:collection-name($fullpath),util:document-name($fullpath)) (: (/db/pekoe/files/test/testing, test1.xml) :)
(:  There's no dummy checking here - no security!!! ******************************************  :)
    let $goodCollection := local:get-good-transaction-directory($pathParts[1]) (: it's the full path to the dir : /db/... :)
    let $result := if (count(($data,$pathParts)) ge 2) 
        then xmldb:store($goodCollection,$pathParts[2], $data)
        else false()
    let $update-permissions :=   local:set-open-for-editing(xs:anyURI($fullpath))
    return if ($result) then
             <result status="okay" >{$result}</result>
             else <result status='fail' />
    }; 
    


(:declare function local:lookup() { (\: JESUS - What the hell am I doing here ************************************ :\)
    let $query := request:get-parameter('query',"")
    let $src := request:get-parameter('src',"")
 
    (\: This is a potentially unsafe action. !!!!!!!!!!!! It would be good to filter it first!:\)
    return util:eval-inline(xs:anyURI($src),$query)
};:)

(: List all the files associated with the selected transaction.
    This might be better in print-merge or some other module as it doesn't relate to files. :)
    
(:declare function local:list-associated-files() as element() 
{

    let $currentTx := request:get-parameter("transaction","") (\: Don't need the basepath here :\)
    (\: this ... is supposed to be customizable for each user (so - not config-default ) :\)
    let $userDirectory := doc('/db/pekoe/config/config-default.xml')/config/transaction-dir[@user='client']
    
    return 
    	<files txp="{$userDirectory}" txf="{$currentTx}">{
    
    	(\: get the files directory from pekoe/config :\)
    	let $goodDirectory := filestore:is-directory(doc('/db/pekoe/config/config-default.xml')/config/transaction-dir[@user='server']) 
    
    	let $transactionFiles := filestore:list-directory(concat($goodDirectory,'/',$currentTx)) 
    	let $transactionFolder := $transactionFiles[1]
    	let $files := remove($transactionFiles, 1)
        (\:	I'm filtering out the versioned copies in Javascript :\)
    	for $f in $files
        	let $mod-date := substring-after($f," mod:")
        	let $name := substring-before($f, " mod:")
        	return <file path="{concat($userDirectory,'/',$currentTx,'/',$name)}" 
        	        display-name="{$name}" mod-date="{$mod-date}" />
    	}</files>

};:)
(:
declare function local:count-items() {
    count(collection($local:path))
};

declare function local:delete-file($collection, $resource)  {
    let $doc := doc($local:path)
    let $lock := util:exclusive-lock($doc, local:really-lock-file($local:path))
    return (xmldb:remove($collection,$resource),concat("file: ",$local:path))
};



declare function local:delete() {
    let $resource := util:document-name($local:path)
    let $collection := util:collection-name($local:path)
    return 
        if (empty($resource))  (\: must be a collection. BE VERY CAREFUL. $collection is the PARENT!!! I inadvertently removed ALL /db/pekoe/files !!! :\)
        then (xmldb:remove($local:path),concat("collection: ",$local:path))
        else local:delete-file($collection, $resource)
};
:)


(: -----------------------------------  MAIN TRANSACTION QUERY --------------------- :)
if ($local:method eq "GET") then 
  if ($local:path eq "") then (response:set-status-code(400),<result status='error'>GET missing $path</result>)
    else if ($local:action eq 'capture') then	    
        local:lock-file()
    else if ($local:action eq 'release') then
        local:unlock-file()
(:            else if ($local:action eq 'lookup') then
        local:lookup():)
   (: else if ($local:action eq 'files') then
        local:list-associated-files():) (:'list-files' is not a transaction-list. It examines the transaction's folder.:)
(:            else if ($local:action eq 'delete') then 
        local:delete()
    else if ($local:action eq 'count') then 
        local:count-items():)

    else (response:set-status-code(400),<result>GET Action { if ($local:action eq "") then "missing" else concat("unknown: ", $local:action) }</result>)
else if ($local:method eq "POST") 
        then local:store-post()
        else (response:set-status-code(405),<result>Method not recognised: {$local:method}</result>)


