xquery version "3.0";
(:

There are some basic advantages in using JSON - it's simply much easier to integrate with a Javascript front end like Angular.
However, the disadvantages are becoming more apparent.
1/ Can't easily edit a user-file or the default.
2/ Can't run a script to modify all of them (without jumping through serious hoops)
3/ Can't easily include "default" items into the Bookmarks. (e.g. Files, Welcome, or Admin functions.)


For JSON see p123 of the book (pdf 146)
<container json:array="true"><thing>a</thing></container>
[{thing : 'a'}]

    see http://expath.org/spec/http-client for info on http:response
    
    <http:response status = integer
                  message = string>
   (http:header*,
     (http:multipart |
      http:body)?)
</http:response>                                                                                                                                                                                                                                                                                                                                                                                                                             
    
    
:)

module namespace prefs = "http://pekoe.io/user-prefs";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(: If you get here and there's no subdomain that's an error.
    BUT - this makes it hard to test outside of the Request.
:)
declare variable $prefs:selected-tenant := req:header("tenant");
declare variable $prefs:tenant-path := "/db/pekoe/tenants/" || $prefs:selected-tenant ;
declare variable $prefs:config-collection-name := $prefs:tenant-path || "/config/users";
declare variable $prefs:user := sm:id()//sm:real/sm:username/text();
declare variable $prefs:default-prefs := collection( $prefs:config-collection-name )/config[@for eq 'default'];
declare variable $prefs:user-prefs := collection( $prefs:config-collection-name )/config[@for eq $prefs:user];


declare 
%rest:GET
%rest:path("/pekoe/user/bookmarks")
%rest:produces("application/json")
%output:media-type("application/json")
(:%output:method("json"):)
function prefs:get-bookmarks-json() {
(:util:log('warn','CURRENT TENANT PATH IS ' || $prefs:tenant-path),:)
    if (sm:has-access(xs:anyURI($prefs:tenant-path),'r--')) then prefs:get-pref("bookmarks")/text()
    else <rest:response>
            <http:response status="{$pekoe-http:HTTP-412-PRECONDITIONFAILED}">
                <http:header name="Location" value="/exist/restxq/pekoe/tenant"/>
            </http:response>
        </rest:response>
        
};

declare 
%rest:POST("{$body}")
%rest:path("/pekoe/user/bookmarks")
%rest:consumes("application/json")
%output:media-type("application/json")
(:%output:method("json"):)
function prefs:store-bookmarks-json($body) {
    prefs:set-pref("bookmarks", util:base64-decode($body))

};

(: TODO  - somehow need to make these functions accessible outside restxq. I guess the real problem is that I'm using variables inside a module. :)
declare function prefs:get-doc-content($docname) {
    let $fullpath := concat($prefs:config-collection-name,"/",$docname)
    
    let $doc := doc($fullpath)/config
    let $content := 
        if (exists($doc)) then $doc
        else xmldb:store($prefs:config-collection-name, $docname, <config for="{$prefs:user}"/>)
    return doc($fullpath)/config
};

declare function prefs:get-pref($for) {
    let $log := util:log("warn", "GET config FOR USER " || $prefs:user || " FROM TENANT COLLECTION " || $prefs:config-collection-name)
(:    let $log := util:log("warn", $prefs:user-prefs):)
    let $pref := $prefs:user-prefs/pref[@for eq $for]
    return 
        if (exists($pref)) then $pref
        else $prefs:default-prefs/pref[@for eq $for]
};


declare function prefs:good-name($u) {
    replace($u, "[\W]+","_")
};

declare function prefs:set-pref($for, $pref-item) {
    let $good-pref := if (($pref-item instance of element()) and name($pref-item) eq "pref") then $pref-item else 
        <pref for='{$for}'>{$pref-item}</pref>
        
    let $docname := concat(prefs:good-name($prefs:user), ".xml")
    let $conf := prefs:get-doc-content($docname)
    
    let $update-or-replace := if (exists($conf/pref[@for eq $for])) 
        then ( update replace $conf/pref[@for eq $for] with $good-pref)
        else (update insert $good-pref into $conf)
    return ()
};

