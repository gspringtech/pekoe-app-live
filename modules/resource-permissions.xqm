xquery version "3.0";

module namespace rp = "http://pekoe.io/resource-permissions";

declare variable $rp:open-for-editing :=       "rwxr-----";
declare variable $rp:locked-for-editing :=     "rwxr-----";
declare variable $rp:closed-and-available :=   "rw-r-----"; 
declare variable $rp:xquery-permissions :=     "rwxr-x---";
declare variable $rp:collection-permissions := "rwxrwx---";
declare variable $rp:template-permissions :=   "rwxrwx---";
declare variable $rp:merge-permissions :=      "rwxr-x---"; (: will be owned by admin :)

(: ------------------------------------------------------------------------------  The RULES:
    A user can READ a resource by being in the GROUP
    A user can EDIT a resource 
        - if the resource is CLOSED (owned by the collection-owner and r--r-----) AND
            - if they belong to the collection-owner's group 
            OR
            - they ARE the collection owner.
    To CLOSE a resource
        - the USER must be the current owner 
        - change the resource owner to that of the Collection
        - change the permissions back to r--r-----
:)

declare function rp:collection-permissions($col) {
    let $uri := xs:anyURI($col)
    
    let $current-user := sm:id()//sm:real
    let $current-username := $current-user/sm:username/text()
    let $users-groups := $current-user//sm:group/text()
    let $collection-permissions := sm:get-permissions($uri)
    let $eponymous-owner-group := $collection-permissions/sm:permission/@owner
    let $owner-group-exists := sm:group-exists($eponymous-owner-group)
    let $user-can-edit := $owner-group-exists and ($users-groups = $eponymous-owner-group) (: collection-owner must also be a group-name and user must belong to that group :)

    let $permissions := map { 
        "col-owner"     : string($collection-permissions/sm:permission/@owner),
        "col-group"     : string($collection-permissions/sm:permission/@group),
        "mode"          : string($collection-permissions/sm:permission/@mode),
        "editor"        : $user-can-edit  or sm:is-dba($current-username),
        "user"          : $current-user,
        "username"      : $current-username
    }
    
    return $permissions      
};


(:
    Here is the rational AGAIN:
    Must be able to decide:
    (- can YOU read the file)
    - can YOU edit the file?
    - when YOU close the file, who does it belong to?
    
    I am a member of _staff and the collection and file are owned by _staff: I can read it.
    I am a member of _staff and the collection and file are owned by _admin: I can't read it.
    
    -- Now obviously if you don't belong to the collection group, you probably can't see the file. But you might be able to read it. 

    A resource can be edited by YOU IF
    - it is owned by the collection-group or owner?
    - YOU belong to the resource's GROUP
    
    THE REASON why a file is r--r-- is because I don't want anyone to WRITE to it unless they have LOCKED it.
    If I used the standard rw-rw- approach to INDICATE that the file is editable by YOU (owner or group-member), then you can write it any old time.
    TO INDICATE that the file is AVAILABLE, I set it to r--r-- and make sure the files OWNER is the COLLECTION-OWNER
    YOU can EDIT if you belong to the eponymous OWNER-GROUP
    
    collection _staff _staff
    file1 _staff _staff r--r-----       A _staff member CAN EDIT (file is closed and available and user belongs to _staff)
    file2 ryan   _staff rwxr-----       Ryan is editing. members of _staff can read. When closed, ownership will revert to _staff
    
    collection _admin _staff
    file3 _admin _staff r--r-----       A _staff member can READ this file, but NOT EDIT. Only members of _admin can edit.
    file4 _admin _admin r--r-----       Only _admin members can read or edit.
    file5 admin  _staff rwxr-----       "admin" is editing the file.
    
    A file can have different group to its parent collection (e.g. file3 above). IF this file needs to be unlocked , only the 
    owner will be changed. (Presumably only an _admin user can do this). 
    
:)

(:
    What do I need to know?
    - read permission is a given. Should not even be calling this without read-permission.
    
    I want to show that YOU CANNOT edit.                -> not user-can-edit  (should be disabled)                  -> user-can-edit eq false
    I want to show that it is closed-and-available      -> user-can-edit and closed-and-available                   -> 
    I want to show that someone (not YOU) is editing    -> user-can-edit and locked-for-editing and not owner-is-me -> locked-for-editing eq true
    I want to show that YOU are editing.                -> user-can-edit and locked-for-editing and owner-is-me

    This currently only applies to XML resources. And specifically those with a Pekoe Schema
:)

(:
    The other side to this is the new CUSTOM META files that I want to use.
    Firstly, this will determine whether certain files are visible (e.g. 'content.xml', 'merge.xql' 'word-links.xml' 
    and also the possibly custom url for the file (e.g. instead of /exist/pekoe-files/files/Example-report.xql it will be /exist/pekoe-files/report/files/Example-report.xql )
    So the general idea is that this custom meta file will be checked to see if the resource in question is listed and has special permissions.
    
    The aim is to resolve issues with permissions and ownership.
    COLLECTION-OWNER-group are EDITORS
    COLLECTION-GROUP-members are VIEWERS
    
    I need to create a special user and group
    
:)

declare function rp:resource-permissions($resource as xs:string) {
    let $uri := xs:anyURI($resource)
    let $file-permissions := sm:get-permissions($uri)
    let $parent := util:collection-name($resource)
    
    let $current-user := sm:id()//sm:real
    let $current-username := $current-user/sm:username/text()
    let $users-groups := $current-user//sm:group/text()
    
    let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
    let $eponymous-owner-group := $collection-permissions/sm:permission/@owner                  (: the collection owner :)
    let $owner-group-exists := sm:group-exists($eponymous-owner-group)                          (: a personal group :)
    let $user-can-edit := $owner-group-exists and ($users-groups = $eponymous-owner-group)      (: current-user belongs to that personal-group :)

    
    let $permissions := map { 
        "collection" : $parent,
        "docname"       : util:document-name($resource),
        "owner"         : string($file-permissions/sm:permission/@owner),
        "group"         : string($file-permissions/sm:permission/@group),
        "col-owner"     : string($collection-permissions/sm:permission/@owner),
        "col-group"     : string($collection-permissions/sm:permission/@group),
        "mode"          : string($file-permissions/sm:permission/@mode),
        "user-can-edit"         : sm:is-dba($current-username) or $user-can-edit,
        "locked-for-editing"    : $file-permissions/sm:permission/@mode eq $rp:locked-for-editing,
        "user-is-owner"         : $file-permissions/sm:permission/@owner eq $current-username,
        "closed-and-available"  : $file-permissions/sm:permission/@mode eq $rp:closed-and-available,
        "user"          : $current-user,
        "username"      : $current-username
    }
    return $permissions      
};

declare function rp:release-job($file) {
    if ($file eq "") then <result status='fail'>No file</result>
    else 
        let $done := rp:unlock-file($file)
        return <result status="okay" />
};

(: User has the file open and now wants to close it. :)

declare function rp:unlock-file($path) { 
    if (util:is-binary-doc($path)) then rp:template-permissions($path)
    else
    let $doc := doc($path)
    return util:exclusive-lock($doc, rp:really-unlock-file($path))
};


declare function rp:really-unlock-file($path) {     (: NOTE: This MUST be performed within the lock above:)
    let $uri := xs:anyURI($path)
    let $res := rp:resource-permissions($path)
    return if ($res('owner') eq $res('username')) (: and $is-open-for-editing)  -- this caused problems with files that didn't close correctly initially.:) 
        then (
        sm:chown($uri, $res?col-owner), 
(:      Back to this discussion again. The Collection-group determines who can VIEW the files in the collection.
        So each file in the collection must be ...r----- for that group.
        Sometimes files are created with the wrong group (not sure why - perhaps Admin's fault). 
        So these files should be moved into the collection-group.
        WHEN would a FILE (a Job file - not Binary or Collection) ever need to belong to a DIFFERENT GROUP?
:)
        sm:chgrp($uri, $res?col-group),      
        sm:chmod($uri,$rp:closed-and-available), 
            <result>success</result>)
        else <result>fail</result>
};

(:
    Binary Resource Permissions. 
    Template - if binary then it will be an ODT, DOCX, ODS (for example)
    These types of files must have GROUP RWX so they can be edited using WebDAV.
    In this case, the GROUP determines who can edit the file. That's awkward.

    However, I will be building a custom List for Templates - so it should be manageable. 
    
    The other place where binary files need to be editable is in the Job folder when a Letter has been saved.
    In this case - the option is to save it for the current User - but again, it should be rwxrwx---
    
    The other binary resources are Queries like Lists and Reports.
    Queries should not (normally) be editable by Users (but again, Templates are an awkward case).
    
    Lists and Reports should be owned by pekoe-system:xxx_staff with rwxr-x--- permission. 
    pekoe-system is a disabled account with a password - so no-one should be able to edit these files except the DBA.
    (the Report XML should also be owned by pekoe-system - but that's a function of the Collection.)
    
    Finally, there are the modules - which should also never be directly editable by users.
    
:)

declare function rp:template-permissions($path) {
    let $res := rp:resource-permissions($path)   (: DOESN'T APPLY :)
    let $uri := xs:anyURI($path)
    return (
        sm:chown($uri, $res?col-owner),
        sm:chgrp($uri, $res?col-owner),
        sm:chmod($uri, $rp:template-permissions)    
    )
};

declare function rp:set-default-permissions($resource) {
    util:log('info', 'SET DEFAULT PERMISSIONS ON ' || $resource)
(:  first - what kind of file is it?   :)
(:  second - are there special permissions for this collection? :)
(:  third what are the general permissions for this collection and type of file :)
};

declare function rp:using-parent-permissions($basepath, $subdirname) {
    let $base-permissions :=  rp:collection-permissions($basepath)
    let $newcoll := xmldb:create-collection($basepath, $subdirname) (: Returns the path to the new collection as a string - or the empty sequence :)
    let $uri := xs:anyURI($newcoll)
    let $chown := sm:chown($uri,$base-permissions?col-owner)
    let $chgrp := sm:chgrp($uri, $base-permissions?col-group)
    let $chmod := sm:chmod($uri, $base-permissions?mode)
    return $newcoll
};

(: Create a sub-directory - possibly a hierarchy - taking the same ownership and permissions as the base directory. Return the full path.
:)
declare function rp:create-collection($basepath as xs:string, $subpath as xs:string) as xs:string {
    (: Assume base path doesn't end with a slash and $subpath doesn't start with one. 
    start with /db/pekoe/tenants/bkfa/files, members/2015/02/member-00015
    :)
    if ( $subpath = ("","/" ) ) 
    then $basepath (: We're already there. No need to create :)
    else 
        let $subdirname := tokenize($subpath,'/')[1] (: e.g. 2009/2 -> 2009 :)
        let $subdir := $basepath || '/' || $subdirname (: e.g. /db/pekoe/files/education/bookings/2012 :)
    
        let $newcoll :=
            if (xmldb:collection-available($subdir)) then () (: then continue down the path to the next subdir:)
            else rp:using-parent-permissions($basepath, $subdirname)                    
               
        return rp:create-collection($subdir, string-join(tokenize($subpath,'/')[position() gt 1],'/'))    
};




