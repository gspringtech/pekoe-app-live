xquery version "3.0";
module namespace config="http://gspring.com.au/pekoe/user-prefs"; 

(: This is working for the Booking-List. Why?

I don't think I can use this because there's no cookie. why not? 
    The problem is that I'm using restxq and also standard xqueryservlet.
    So one has access to the request:header
    
    What that means is that either I have TWO modules for getting code - and use one for restxq and the other for xqueryservlet,
    OR I do away with RESTXQ altogether.
    
    I think the latter.
:)
(:import module namespace tenant = "http://pekoe.io/tenant" at "tenant.xqm";:)
(:NONE of these things work because we don't have access to the tenant header or cookie. But how did it work for Booking-List.xql?  :)
(:declare variable $config:tenant := req:header("tenant");
declare variable $config:tenant-path := "/db/pekoe/tenants/" || $config:tenant;
declare variable $config:user := xmldb:get-current-user();
declare variable $config:config-collection-name := $config:tenant-path || "/config/users";

declare variable $config:default-prefs := collection($config:config-collection-name)/config[@for eq 'default'];
declare variable $config:user-prefs := collection( $config:config-collection-name )/config[@for eq $config:user];:)


(: use get-doc-content instead of directly accessing the config file because it will make a new file if none exists.
    I think the intention is to use get- and set- pref rather than getting this doc directly.
:)

(:import module namespace tenant = "http://pekoe.io/tenant" at "tenant.xqm";:)
import module namespace req = "http://exquery.org/ns/request";
(:declare variable $config:tenant := replace(request:get-cookie-value("tenant"),"%22","");:)
declare variable $config:tenant := replace(req:cookie("tenant"),"%22","");
declare variable $config:user := xmldb:get-current-user();
(:declare variable $config:config-collection-name := $tenant:tenant-path || "/config/users";:)
declare variable $config:config-collection-name := "/db/pekoe/tenants/" || $config:tenant || "/config/users";

declare variable $config:default-prefs := collection($config:config-collection-name)/config[@for eq 'default'];

declare variable $config:user-prefs := collection( $config:config-collection-name )/config[@for eq $config:user];


declare function config:get-doc-content($docname) {
    let $fullpath := concat($config:config-collection-name,"/",$docname)
    
    let $doc := doc($fullpath)/config
    let $content := 
        if (exists($doc)) then $doc
        else xmldb:store($config:config-collection-name, $docname, <config for="{$config:user}"/>)
    return doc($fullpath)/config
};

declare function config:get-pref($for) {
    let $log := util:log("warn", "GET config FOR USER " || $config:user || " FROM TENANT COLLECTION " || $config:config-collection-name)
    let $log := util:log("warn", $config:user-prefs)
    let $pref := $config:user-prefs/pref[@for eq $for]
    return 
        if (exists($pref)) then $pref
        else $config:default-prefs/pref[@for eq $for]
};


declare function config:good-name($u) {
    replace($u, "[\W]+","_")
};

declare function config:set-pref($for, $pref-item) {
    let $good-pref := if (($pref-item instance of element()) and name($pref-item) eq "pref") then $pref-item else 
        <pref for='{$for}'>{$pref-item}</pref>
        
    let $docname := concat(config:good-name($config:user), ".xml")
    let $conf := config:get-doc-content($docname)
    
    let $update-or-replace := if (exists($conf/pref[@for eq $for])) 
        then ( update replace $conf/pref[@for eq $for] with $good-pref)
        else (update insert $good-pref into $conf)
    return ()
};
