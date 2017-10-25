import module namespace dbutil="http://exist-db.org/xquery/dbutil" at "/db/apps/shared-resources/content/dbutils.xql";

(:
    Scan a tenant's /files collection - looking for jobs which exist as files, but are not accessible as XML.
:)
declare variable $local:tenant-path-str := '/db/pekoe/tenants/';


(: This function and the next allowed me to check for missing sequence numbers - which returned two positives after looking through Files/jobs/2016/06.
    Missing 268 and 307
    Both created by jess
    One was yesterday morning
:)
declare function local:get-sequence() {
for $j in collection('/db/pekoe/tenants/cm/files/jobs/2016/06')/agency/our-ref
let $sn := number(substring-after($j,'-'))
order by $sn
return $sn
};

declare function local:scan-agency() {
    let $sequence := local:get-sequence()
    let $results := ($sequence[1],$sequence[last()], count($sequence), $sequence[last()] - $sequence[1])
    for $n at $i in $sequence[position() ne last()]
    let $next := $sequence[$i + 1]
    return if (($n + 1) ne $next) then ($n + 1) else ()
    (:return string-join($results,' '):)
};

declare function local:check-resource($r) {
    if (doc-available($r)) then doc($r)/name(*) else ()
};

(:<invisible-files>
    <r type="application/xml" created="2016-06-01T09:09:54.159+09:30"
        >/db/pekoe/tenants/cm/dead-letters/message-2016-06-01-09-09-1.xml</r>
    <r type="application/xml" created="2016-06-09T09:17:14.747+09:30"
        >/db/pekoe/tenants/cm/dead-letters/message-2016-06-09-09-17-1.xml</r>
    <r type="application/xml" created="2016-06-14T16:56:00.69+09:30"
        >/db/pekoe/tenants/cm/dead-letters/message-2016-06-14-16-56-1.xml</r>
</invisible-files>
:)

declare function local:scan($tenant) {
    let $tenant-path := $local:tenant-path-str || $tenant
    return
    dbutil:scan(xs:anyURI($tenant-path), function($col, $res) {
       if ($res and ends-with($res, '.xml')) then 
           if (local:check-resource($res)) then () else  
           <r type='{xmldb:get-mime-type(xs:anyURI($res))}' created='{xmldb:created($col,substring-after($res,$col || "/"))}' >{$res}</r>
        else ()
    })
};

<invisible-files>{
local:scan('cm')
}</invisible-files>