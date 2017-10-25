xquery version "3.0";
(: get-permissions doesn't record whether setUID is in effect . Some of these files should be rwsr---  :)
declare function local:resource-permissions($base) {
    for $r in xmldb:get-child-resources($base)
    let $path := $base || '/' || $r
    let $p := sm:get-permissions(xs:anyURI($path))//sm:permission
    return <r base='{$base}' name='{$r}' path='{$path}' type='{substring-after($r,".")}' owner='{$p/@owner/string()}' group='{$p/@group/string()}' mode='{$p/@mode/string()}'/>
};

declare function local:collection-permissions($base) {
    for $r in xmldb:get-child-collections($base)
    let $path := $base || '/' || $r
    let $p := sm:get-permissions(xs:anyURI($path))//sm:permission
    return (<collection base='{$base}' name='{$r}' path='{$path}' owner='{$p/@owner/string()}' group='{$p/@group/string()}' mode='{$p/@mode/string()}' />, local:resource-permissions($path))    
};

let $base := '/db/apps/pekoe'
let $permissions := <permissions update-time='{current-dateTime()}' >{local:collection-permissions($base), local:resource-permissions($base)}</permissions>
return xmldb:store($base,'permissions.xml',$permissions)