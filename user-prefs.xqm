xquery version "3.0";
(: *************** SetUID is applied. *************** SetUID is applied. *************** SetUID is applied. :)

(:

There are some basic advantages in using JSON - it's simply much easier to integrate with a Javascript front end like Angular.
However, the disadvantages are becoming more apparent.
1/ Can't easily edit a user-file or the default.
2/ Can't run a script to modify all of them (here on the server) without jumping parsing the json
3/ Can't easily include "default" items into the Bookmarks. (e.g. Files, Welcome, or Admin functions.)

I guess a simple rule might be that JSON is good if there's no round-trip involved.

This conversion process possibly could be replaced by custom stylesheet. But even
better would be a Json Proxy wrapped around the XML. I'm looking forward to trying that.
I suspct it will still be a custom solution, but it could be simpler and 
better able to cope with changes to the Bookmark spec.

So  - I've chosen to send and receive XML. The conversion functions are specific and quite simple.
I could probably improve the code.

        // this is more reliable than serialising xml as json, or using x2js or similar.
        function convertBookmarksFromXML(x) { // x is an Angular Object containing a Document
            var newBookmarks = {groups:[],dirty: false};
            x.find('group').each(function(){
                var g = $(this);
                var group = {title: g.children('title').text(), items:[] };
                newBookmarks.groups.push(group);
                g.find('item').each(function () {
                    var i = $(this);
                    group.items.push({
                        title:  i.find('title').text(),
                        href:   i.find('href').text(),
                        type:   i.find('type').text(),
                        active: i.find('active').text() === 'true'
                    });
                });
            });
            return newBookmarks;
        }
        
        function newEl(od,n,t) {
            var el = od.createElement(n);
            el.textContent = t;
            return el;
        }
        
        function convertBookmarksToXML(){
            var od = (new DOMParser()).parseFromString('<pref for="bookmarks"></pref>', 'text/xml');
            var doc = od.documentElement;
            myBookmarks.groups.forEach(function(e) {
                var g = od.createElement("group");
                var t = od.createElement("title");
                t.textContent = e.title;
                g.appendChild(t);
                e.items.forEach(function (el) {
                    var item = od.createElement('item');
                    item.appendChild(newEl(od,'title',el.title));
                });
                doc.appendChild(g);
            });
        }
        
:)

declare namespace prefs = "http://pekoe.io/user-prefs";

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";


(: If you get here and there's no subdomain that's an error.
    BUT - this makes it hard to test outside of the Request.
:)
declare variable $prefs:selected-tenant := req:header("tenant");
declare variable $prefs:tenant-path := "/db/pekoe/tenants/" || $prefs:selected-tenant ;
declare variable $prefs:config-collection-name := $prefs:tenant-path || "/config/users";
declare variable $prefs:user := sm:id()//sm:real/sm:username/text();
declare variable $prefs:admin-group := "pekoe-tenant-admins";                                                       (: Awkward - but necessary. Members of <tenant>_admin should also belong to this group. OR MAYBE NOT:)
declare variable $prefs:user-is-admin := sm:is-dba($prefs:user) or sm:id()//sm:real//sm:group = $prefs:admin-group;
declare variable $prefs:default-prefs := collection( $prefs:config-collection-name )/config[@for eq 'default'];
declare variable $prefs:user-prefs := collection( $prefs:config-collection-name )/config[@for eq $prefs:user];
declare variable $prefs:tenant-admin := $prefs:selected-tenant || "_admin";                                         (: Unless I make it a setting - tested using this group :)
(:declare variable $prefs:admin-prefs :=  collection($prefs:config-collection-name )/config[@for eq $prefs:tenant-admin];:)
declare variable $prefs:all-prefs :=     doc('/db/pekoe/common/common-bookmarks.xml')//item;
declare variable $prefs:admin-prefs :=   $prefs:all-prefs except $prefs:all-prefs[@for eq 'dba'];
declare variable $prefs:common-prefs :=  $prefs:admin-prefs except $prefs:admin-prefs[@for eq $prefs:admin-group];


declare
%rest:GET
%rest:path('/pekoe/user/screen/{$screen}')
function prefs:log-screen-size($screen) {
    util:log('info' , 'SCREEN DATA ' || $screen || ' for USER ' || $prefs:user)
};

(:
    Need to add this somewhere:
    var avail = [screen.availWidth,screen.availHeight].join('x');
    var screenD = [screen.width,screen.height].join('x');
    var inner = [window.innerWidth,window.innerHeight].join('x');
    
    $.get('/exist/restxq/pekoe/user/screen/' + [avail,screenD,inner].join('_'));


:)



(: RESTXQ doesn't provide mch help with errors. I had accidently created two functiions with the same name and arity. :)

declare 
%rest:GET
%rest:path("/pekoe/user/bookmarks")
function prefs:get-bookmarks-que() {
try {
    if (sm:has-access(xs:anyURI($prefs:tenant-path),'r--')) then prefs:get-bookmarks()
    else <rest:response>
            <http:response status="{$pekoe-http:HTTP-412-PRECONDITIONFAILED}">
                <http:header name="Location" value="/exist/restxq/pekoe/tenant"/>
            </http:response>
        </rest:response>        
        } catch * { util:log("debug", $err:description) }
};

declare 
%rest:POST("{$body}")
%rest:path("/pekoe/user/bookmarks")
%rest:consumes("text/xml")
function prefs:store-bookmarks($body) {
    prefs:set-pref("bookmarks", $body)

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

(:These are not prefs - these are bookmarks 
    Consider having a read-only "group" which belongs to 
    admin_tdbg
    config for=admin_tdbg
    <pref for = bookmarks>
        templates
        schemas
        ?
        
    Also note - BKFA need 3 levels - they need a general user and a restricted user 
    plus an admin
    
    So the 
:)
(:declare function prefs:add-admin-prefs($base-prefs) {
()
};

declare function prefs:get-bookmarks() {

    let $log := util:log("warn", "GET config FOR USER " || $prefs:user || " FROM TENANT COLLECTION " || $prefs:config-collection-name)
    let $pref := $prefs:user-prefs/pref[@for eq $for]
    let $user-prefs :=
        if (exists($pref)) then $pref
        else $prefs:default-prefs/pref[@for eq $for]
    return if (sm:is-dba(xmldb:get-current-user())) then 
        prefs:add-admin-prefs($user-prefs)
        else $user-prefs
};:)

declare function prefs:get-bookmarks() {
    let $log := util:log-app('info','login.pekoe.io', $prefs:user || ' LOGGED-IN  TO ' || $prefs:selected-tenant || ' FROM ' || req:header('X-Real-IP'))
    let $user-bookmarks := prefs:get-pref('bookmarks')
    let $common-prefs := if (sm:is-dba($prefs:user)) then $prefs:all-prefs else if ($prefs:user-is-admin) then $prefs:admin-prefs else $prefs:common-prefs

    return <pref for='bookmarks' tenant='{$prefs:selected-tenant}'>{$user-bookmarks/group,<group type="locked">
            <title>Pekoe</title>{$common-prefs}</group>}</pref>
};

declare function prefs:get-pref($for) {
    let $pref := $prefs:user-prefs/pref[@for eq $for]
    return 
        if (exists($pref)) then $pref
        else $prefs:default-prefs/pref[@for eq $for]
};


declare function prefs:good-name($u) {
    replace($u, "[\W]+","_")
};

declare function prefs:set-pref($for, $pref-item) {
(:    let $log := util:log("warn", "PREFS NAME IS " || name($pref-item/*) || " is document? " || $pref-item instance of document-node()):)
    let $good-pref := if (($pref-item instance of document-node()) and name($pref-item/*) eq "pref") then $pref-item/* else 
        <pref for='{$for}'>{$pref-item}</pref>
        
    let $docname := concat(prefs:good-name($prefs:user), ".xml")
    let $conf := prefs:get-doc-content($docname)
    
    let $update-or-replace := if (exists($conf/pref[@for eq $for])) 
        then ( update replace $conf/pref[@for eq $for] with $good-pref)
        else (update insert $good-pref into $conf)
    return <result>success</result>
};

()