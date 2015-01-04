xquery version "3.0";

module namespace rp = "http://pekoe.io/resource-permissions";

declare variable $rp:open-for-editing :=       "rwxr-----";
declare variable $rp:closed-and-available :=   "r--r-----"; 
declare variable $rp:xquery-permissions :=     "rwxr-x---";
declare variable $rp:collection-permissions := "rwxrwx---";

(:
declare function rp:permissions($href) {
    let $uri := xs:anyURI($href)
    let $permissions := sm:get-permissions($uri)
    
    let $parent := util:collection-name($href)
    let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
    

    let $current-user := sm:id()//sm:real/sm:username/text()
    let $permissions := map { 
        "collection" := util:collection-name($href),
        "docname" := util:document-name($href),
        "owner" := string($permissions/@owner),
        "group" := string($permissions/@group),
        "parent-group" := string($collection-permissions/@group),
        "mode" := string($permissions//@mode),
        "user" := $current-user
    }
    return $permissions      
};:)
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
        "col-owner" := string($collection-permissions/sm:permission/@owner),
        "col-group" := string($collection-permissions/sm:permission/@group),
        "mode" := string($collection-permissions/sm:permission/@mode),
        "editor" := $user-can-edit  or sm:is-dba($current-username),
        "user" := $current-user,
        "username" := $current-username
    }
    return $permissions      
};

declare function rp:resource-permissions($resource) {
    let $uri := xs:anyURI($resource)
    let $file-permissions := sm:get-permissions($uri)
    
    let $parent := util:collection-name($resource)
    let $current-user := sm:id()//sm:real
    let $current-username := $current-user/sm:username/text()
    let $users-groups := $current-user//sm:group/text()
    let $collection-permissions := sm:get-permissions(xs:anyURI($parent))
    let $eponymous-owner-group := $collection-permissions/sm:permission/@owner
    let $owner-group-exists := sm:group-exists($eponymous-owner-group)
    let $user-can-edit := $owner-group-exists and ($users-groups = $eponymous-owner-group) (: collection-owner must also be a group-name and user must belong to that group :)

    
    let $permissions := map { 
        "collection" := $parent,
        "docname" := util:document-name($resource),
        "owner" := string($file-permissions/sm:permission/@owner),
        "group" := string($file-permissions/sm:permission/@group),
        "col-owner" := string($collection-permissions/sm:permission/@owner),
        "col-group" := string($collection-permissions/sm:permission/@group),
        "mode" := string($file-permissions/sm:permission/@mode),
        "editor" := $user-can-edit or sm:is-dba($current-username),
        "user" := $current-user,
        "username" := $current-username
    }
    return $permissions      
};