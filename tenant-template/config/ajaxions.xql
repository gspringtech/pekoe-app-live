import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace rp = "http://pekoe.io/resource-permissions" at "xmldb:exist:///db/apps/pekoe/modules/resource-permissions.xqm"; 

(:
    This script works because it is owned by <tenant>_staff with setUId applied.
    Consequently, it can write to any file also owned by <tenant>_staff OR with rw-rw and <tenant>_staff group.
    
    CHANGE to <tenant>_staff ******
:)

declare variable $local:action := request:get-parameter('action','');



declare function local:get-params($pmap) {
    map:new(
        for $k in map:keys($pmap)  (: This could be extended to include default values in the original map :)
        return map:entry($k,request:get-parameter($k,''))
    )
};

declare function local:convert-to-pdf() {
    let $params := local:get-params(map{
        'jobid':'', 
        'attachment':''})
    let $doc := collection('/db/pekoe/tenants/cm/files/jobs')/residential[our-ref eq $params?jobid]
    
    return if ($doc) then (
        let $path := util:collection-name($doc)
        let $binary-path := string-join(($path,$params?attachment),"/")
        let $attachment := util:binary-doc($binary-path)
        return if (util:binary-doc-available($binary-path))
         then <result>{substring-before($params?attachment,".")}.pdf</result> 
         else <result>No Binary {$binary-path}</result>
    
    ) else <result>No Residential job {$params?jobid}</result>
};

declare function local:deduct-supplies-from-stock() {
    (:I think maybe this function should be given the params - the booking ID, bkfa-return-number, sent-date:)
    let $params := local:get-params(map{
        'jobid':'', 
        'sent':'',
        'returnNumber':'',
        'kits':''})
    
    let $doc := collection('/db/pekoe/tenants/bkfa/files/assembly-days')/ad-booking[id eq $params?jobid]
    return if ($doc) then (
         (# exist:batch-transaction #) {
            let $supplies := collection('/db/pekoe/tenants/bkfa/files/supplies')
            let $stock-items := $supplies/stock-item[file-is-closed eq '']
            let $kit-items := $supplies/kit-contents/item
            
            for $item in $kit-items
            let $stock-item := $stock-items[name eq $item/name]
            let $last-entry := $stock-item/(in | out)[last()]
            let $current-stock := number($last-entry/current-stock[. castable as xs:integer])
            let $single-unit-name := $stock-item/unit[contains eq '1']/name/string()
            let $pieces-out := number($item/batch-size-variant[batch-size eq $params?kits]/pieces)
            let $out :=  
            <out>
                <date date='{$params?sent}'>{$params?sent}</date>
                <consignment-number>{$params?returnNumber}</consignment-number>
                <detail>For AD-Booking {$params?jobid}</detail>
                <units>{$single-unit-name}</units>
                <qty>{$pieces-out}</qty>
                <current-stock>{$current-stock - $pieces-out}</current-stock>
                </out>
(:            let $log := util:log('info','000000000 DEDUCT FROM STOCK ' )
            let $log1 := util:log('info',$out):)
            return update insert $out following $last-entry
        },
        <result>okay</result>
        )
    else <result>No booking {$params?jobid}</result>
};



declare function local:set-instructions-sent-date() {
    let $log := util:log('info','@@@@@@@@@@@@@@@ SET INSTRUCTIONS @@@@@@@@@@@@@@@')
    let $quarantined-path := request:get-parameter('path','')
    let $path := tenant:real-path($quarantined-path)
    return if (doc-available($path)) then (
        update value doc($path)//supplies/transport-instructions-sent-date with adjust-date-to-timezone(current-date(),()),<result>okay</result>)
    else <result>No document at {$path}</result>
};

declare function local:set-invoice-number() {
    let $quarantined-path := request:get-parameter('path','')
    let $inv := request:get-parameter('val','')
    let $path := tenant:real-path($quarantined-path)
    return if ($inv ne '' and doc-available($path)) then 
        (update replace doc($path)//supplies/invoice-number with element invoice-number {attribute date-stamp {adjust-date-to-timezone(current-date(),())}, $inv},
        <result>okay</result>)
    else <result>No document at {$path} or no invoice-number inv.</result>
};

(: **************************  NOTE:
    Some of these will fail if there's no PARENT.
    e.g. supplies/paid-for-date or kits/returned-date
    There will usually be a kits element, but maybe not a supplies element.
    It would be better to ensure that the parent exists.
    
    Also, this approach feels clumsy. Should be better somehow. 

:)

declare function local:set-date($field) {
    let $quarantined-path := request:get-parameter('path','')
    let $path := tenant:real-path($quarantined-path)
    let $doc := doc($path)
    return if (doc-available($path)) then (
        switch ($field)
        case 'set-paid-date' return 
            if (exists($doc//paid-for-date)) then (update value $doc//paid-for-date with adjust-date-to-timezone(current-date(),()),<result>okay - set existing date field</result>)
            else (update insert <paid-for-date>{adjust-date-to-timezone(current-date(),())}</paid-for-date> into $doc//supplies, <result>okay</result>)
        case 'set-pre-ad-letter' return 
            if (exists($doc//pre-ad-letter)) then (update value $doc//pre-ad-letter with adjust-date-to-timezone(current-date(),()),<result>okay - set existing date field</result>)
            else (update insert <pre-ad-letter>{adjust-date-to-timezone(current-date(),())}</pre-ad-letter> following $doc//ad-date, <result>created okay</result>)
        case 'kits-returned-date' return 
            if (exists($doc//kits/returned-date)) then (update value $doc//kits/returned-date with adjust-date-to-timezone(current-date(),()),<result>okay - set existing date field</result>)
            else (update insert <returned-date>{adjust-date-to-timezone(current-date(),())}</returned-date> following $doc//kits, <result>created okay</result>)
        default return <result>Unknown field {$field}</result>
        )
    else <result>No document at {$path}</result>
};

(: I need to spend some time thinking about this - it should be much easier and it will be frequently used. :)

declare function local:set-value($f,$v) {
    let $quarantined-path := request:get-parameter('path','')
    let $path := tenant:real-path($quarantined-path)
    return if (doc-available($path)) then 
        switch ($f) 
        case 'okay-to-send' return
            let $doc := doc($path)
            return 
            if (exists($doc//supplies/okay-to-send)) then (update value $doc//supplies/okay-to-send with $v,<result>okay</result>)
            else (update insert element okay-to-send {'1'} following $doc//supplies/send-after-date,<result>okay</result>)
    case 'post-ad-letter' return
            let $doc := doc($path)
            return 
            if (exists($doc//post-ad-letter)) then (update value $doc//post-ad-letter with $v,<result>okay</result>)
            else (update insert element post-ad-letter {'1'} following $doc//whs-confirmation,<result>okay</result>)
        default return <result>Unknown value to update: {$f}</result>
    else <result>No document at {$path}.</result>
};

(: ******************************************   MAIN QUERY ***************************** :)
try {
if (request:get-method() eq 'POST') then 
    switch ($local:action)
    case 'convert-to-pdf' return local:convert-to-pdf()
    default return <result status='error'>No handler for action {$local:action}</result>
else <result status='error'>Unhandled method</result>

} catch * {
(response:set-status-code(403),<result status='error'>Could not update value</result>)
}