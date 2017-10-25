xquery version "3.0";

declare namespace repo="http://exist-db.org/xquery/repo";

(: The following external variables are set by the repo:deploy function :)

(: the target collection into which the app is deployed :)
declare variable $target external;

(: Modify so that it uses the $target instead of hard-coded permissions.xml
 : :)

declare function local:set-collection-permissions(){
    for $r in doc('permissions.xml')//collection
    let $path := $r/@path/string()
    let $uri := xs:anyURI($path)
    return if (xmldb:collection-available($path)) then
        ( sm:chown($uri, $r/@owner)
        , sm:chgrp($uri, $r/@group)
        , sm:chmod($uri, $r/@mode)
        ) else ("Missing collection " || $path)
};

(: There are only a few :)
declare function local:set-document-permissions(){
    for $r in doc('permissions.xml')//r[@type eq 'xml'] 
    let $path := $r/@path/string()
    let $uri := xs:anyURI($path)
    return if (doc-available($path)) then
        ( sm:chown($uri, $r/@owner)
        , sm:chgrp($uri, $r/@group)
        , sm:chmod($uri, $r/@mode)
        ) else ("Missing document " || $path)
};

(: There are only a few :)
declare function local:set-resource-permissions(){
    for $r in doc('permissions.xml')//r[not(@type eq 'xml')] 
    let $path := $r/@path/string()
    let $uri := xs:anyURI($path)
    return if (util:binary-doc-available($path)) then
        ( sm:chown($uri, $r/@owner)
        , sm:chgrp($uri, $r/@group)
        , sm:chmod($uri, $r/@mode)
        ) else ("Missing resource " || $path)
};


declare function local:set-app-permissions(){
    local:set-collection-permissions(),
    local:set-document-permissions(),
    local:set-resource-permissions()
};



local:set-app-permissions()

(:
Use this example to set the permissions.
One way to achieve this would be to run a query over the whole app and collect the owner and permissions.


let $data := xmldb:create-collection($target, "data")
return (
    sm:chown($data, "monex"),
    sm:chgrp($data, "monex"),
    sm:chmod($data, "rw-rw----")
),
for $name in ("instances.xml", "notifications.xml")
let $res := xs:anyURI($target || "/" || $name)
return (
    sm:chown($res, "admin"),
    sm:chgrp($res, "dba"),
    sm:chmod($res, "rw-rw----")
):)