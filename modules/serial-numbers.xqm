xquery version "3.0";

(:
    TODO - Fix permissions on newly created files. 
:)

module namespace sn = "http://gspring.com.au/pekoe/serial-numbers";

import module namespace tenant = "http://pekoe.io/tenant" at "tenant.xqm";
import module namespace rp = "http://pekoe.io/resource-permissions" at "resource-permissions.xqm";

declare variable $sn:collection := $tenant:tenant-path || "/config/serial-numbers";

(:
provides sn:pad-number, sn:get-next, sn:return

pad-number is messy - it only exists because when getting the id, I need an integer.
If get-next ($for,$padding) worked, and so did sn:return($for, $padding, $id) then it wouldn't be needed.
I'm calling it every time  Iwant to checck a numeb.r
:)

(: NOT ABLE TO replace with format-number BECAUSE MY PADDING STRING DOESNT MATCH. :)
(: SEE http://www.w3.org/TR/xpath-functions-31/#func-format-number :)

(:
I want the ID to be a string and I don't want to mess with padding other than to provide a 'picture' as part of the config for 'this' serial-number.
This suggests that creating a serial-number counter should be separate to using it. But the current system is EASY to use

So get-next($config)

1) Is it reasonable to change a serial-number picture? Probably. Why fuss? I'm not keeping a record of them.
2) Is there any way to guarantee that the ID hasn't been used before ? NOT HERE. That's up to YOU, the CALLER.

<serial-numbers for="/member">
    <next>32</next>
    <recycled>31</recycled>
</serial-numbers>



:)
(: Requires a config map  'item-id-name' : 'receipt_number' and 'id-picture' : 'AA000000' :)
declare function sn:get-next-padded-id($config as map(*)) {
    let $next-id := sn:get-next($config?item-id-name)
    return sn:pad-number($config, $next-id)   
};

declare function sn:recycle-padded-id($config, $id) {
    sn:return($config?item-id-name, number(substring-after($id,$config?id-prefix) ))
};

declare function sn:get-next($for) as xs:integer { 
      xs:integer( util:exclusive-lock(sn:check-file($for), sn:safe-get-next($for))) 
};

declare function sn:safe-get-next($for) {
    
    let $serial-numbers := sn:check-file($for)
    let $next := 
        if ($serial-numbers/recycled) 
        then 
            let $this := $serial-numbers/recycled[1]/string()
            let $update := update delete $serial-numbers/recycled[1]
            return $this
        else
            let $this := $serial-numbers/next/string()
            let $update := update value $serial-numbers/next with xs:integer($this) + 1
            return $this
    return if (empty($next)) then <result status='error'>No numbers found</result> else $next
};

declare function sn:return($for, $sn) {
    util:exclusive-lock(collection($sn:collection)/serial-numbers[@for eq $for], sn:safe-return($for,$sn))
};


declare function sn:safe-return($for,$padded-sn) {
    let $sn := xs:integer(replace($padded-sn,'\D',''))
    let $serial-numbers := collection($sn:collection)/serial-numbers[@for eq $for]
    let $update := update insert <recycled>{$sn}</recycled> into $serial-numbers
    return <result status='okay'>recycled</result>
};

declare function sn:check-file($for) {
    let $f := collection($sn:collection)/serial-numbers[@for eq $for]
    return 
        if (empty($f)) 
        then 
(:  TODO - throw a warning because this can only be performed by ADMIN          :)
            let $new-coll := sn:check-serial-numbers-collection($sn:collection)
            let $new := <serial-numbers for='{$for}'><next>1</next></serial-numbers>
            let $good-name := concat(replace($for, "[\W]","_"),".xml")
            let $file := xmldb:store($sn:collection, $good-name, $new)
            let $permissions := tenant:serial-number-file($tenant:tenant, xs:anyURI($file))
            return collection($sn:collection)/serial-numbers[@for eq $for]
        else $f
};

declare function sn:pad-number($config, $n as xs:integer) {
    let $picture := $config?id-number-picture (:This should be a standard number picture see http://www.w3.org/TR/xpath-functions-30/#func-format-number :)
    let $prefix := $config?id-prefix
    return $prefix || format-number($n, $picture)
};

(:declare function sn:pad-number($padding, $n) as xs:string {
    let $wanted-length := string-length($padding)
    let $n-string := string($n)
    let $over-stuffed := concat($padding,$n-string)
    return 
    if (string-length($n-string) ge $wanted-length) then $n-string
    else 
        let $excess := string-length($over-stuffed) - $wanted-length
        return substring($over-stuffed, $excess + 1)
};:)

declare function sn:check-serial-numbers-collection($col)  {
    if (not(exists(collection($col)))) then 
    (    rp:create-collection($tenant:tenant-path || "/config", "serial-numbers")
    )
    else ()
};