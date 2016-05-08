xquery version "3.1";
(: This will probably need SETUID SETUID SETUID so that it can "capture" and "release". :)

import module namespace tenant = "http://pekoe.io/tenant" at "xmldb:exist:///db/apps/pekoe/modules/tenant.xqm";
import module namespace pqt="http://gspring.com.au/pekoe/querytools" at "xmldb:exist:///db/apps/pekoe/modules/querytools.xqm";
import module namespace rp = "http://pekoe.io/resource-permissions" at "modules/resource-permissions.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:action := request:get-parameter("action", "capture");
declare variable $local:file := request:get-parameter("file","");
declare variable $local:path := substring-after($local:file, "exist/webdav"); (: Being really lazy here. MUST FIX THESE PATHS :)
(:declare variable $local:collection-path := $tenant:tenant-path || "/files";:)

(: The aim here is to display a Pekoe Tab and open the requested file in the Word Processor. 
    Prior to opening the file, this script should:
    - check that the user belongs to the owner's group
    - change the owner to the current user
    
    and then when the page loads, the file should be able to be opened by setting the location to the supplied path - which we have validated.
    
    Then, when the User closes this Tab, we will respond to the Close message by 
    - sending 
    
    The browser sends a request for this page with the ?file= param.
    The server "captures" the file for the current user and returns this page
    The page is rendered and the browser is asked to open the file. That's all good.
:)

(: resource permissions
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
:)


declare function local:really-lock-file($href, $res) {
    let $uri := xs:anyURI($href)
    let $locked := xmldb:document-has-lock($res('collection'), $res('docname')) 
    let $is-closed-and-available := $res('mode') eq $rp:template-permissions 
    let $log := util:log-app('info','pekoe.io','>>>> LOCK RESOURCE FOR >>>>> ' || $res?username || ' >>>>> ' || substring-after($href, '/db/pekoe/tenants') || ' >>>>>')
    return if (not($locked) and $is-closed-and-available)
    then (sm:chown($uri,$res?username), (: DON'T CHANGE THE GROUP. The Group determines who can READ the file, which can be different to who can EDIT. :)
    sm:chmod($uri, $rp:open-for-editing), util:wait(2000))
    else 
        (: Usually this is because the user already has the file open.   :)
        util:log-app('warn','pekoe.io', ">>>>>>>>>>>>>>>>>> NOT ABLE TO LOCK RESOURCE. SYSTEM-LOCKED? " 
        || (if ($locked) then 'YES' else 'NO') 
        || ', AVAILABLE? ' 
        || (if ($is-closed-and-available) 
            then 'YES'
            else ('NO because:' || $res('mode'))) )            
};


declare function local:capture-file() {
    local:really-lock-file($local:path, rp:resource-permissions($local:path))
};

declare function local:release-file() {
    util:log-app('info','pekoe.io', '<<<< UNLOCK RESOURCE FOR <<< ' || sm:id()//sm:real/sm:username/string() || ' <<<<< ' ||  substring-after($local:path,'/db/pekoe/tenants') || ' <<<<'),
    rp:template-permissions(xmldb:decode($local:path))    
};
    (: Letter-opener received request for file neo:https://cm.pekoe.io/exist/webdav/db/pekoe/tenants/cm/files/jobs/2016/04/RT-000090/Identification-Checklist--20160407.odt:)
    
    (: Okay - we're hitting this page with the file path  as shown above.
       Now is the time to "capture" this file - by changing the owner to "me" if not already.
       Finally, the big "Close" button is going to send a "release" request to this page.
    :)
    
    
    
(: --------------------- Main Query wrapped in HTML -------------------------------------------------:)
if (request:get-method() eq 'POST') then util:log-app('warn','pekoe.io','GOT CLOSE') 
else if ($local:action eq "release") 
        then ( local:release-file(), "Success" ) (: Should do http response 200 :)
    else 
<html><head><title>Letter Opener</title>
<script type='text/javascript' src='/pekoe-common/jquery/dist/jquery.js' ></script>
<style type='text/css'> /* <![CDATA[ */
body {text-align: center}
/* ]]> */
</style>
<script>
//<![CDATA[

var search = location.search.substring(1);
var args = JSON.parse('{"' + decodeURI(search).replace(/"/g, '\\"').replace(/&/g, '","').replace(/=/g,'":"') + '"}');

function openFile() {
    location.href = args.file;
};

$(function() {

    var gs = {};
     gs.service = (function (){
        var s = {};
        if (window.parent !== window) { // must be a child frame
            s = window.parent.AuthService;
            gs.angular = window.parent.angular;
            gs.scope = gs.angular.element(window.frameElement).scope();
        } else {
            s.getTenant = function () {
                return document.cookie;
            }
        }
        return s;
    })();
    
    
    
    $('#close').on('click',function() {
        args.action = "release";
        console.log(location.href);
        console.log(location.origin + location.pathname + "?" + $.param(args));
        //location.href = location.origin + location.pathname + "?" + $.param(args);
        
        $.get(location.href,{"action":"release"},function (d,ts) {
            gs.scope.removeTab(gs.scope.this.$index);
            gs.scope.$apply();
            //$('#content').html('<h2 style="color:green">You may now close this Tab</h2>');
			//if (window.readyToClose) { window.readyToClose(); } // call the tabs.service in Pekoe Workspace and try to close this tab
			//else {console.warn("no CLOSE method");}
		});
		
    });
    openFile();
    console.log('gs.service',gs.scope);
});
//]]>
</script>
</head>
    <body>
{
(
    local:capture-file(),
    util:log('warn', '000000000 Letter-opener received capture request for file ' || request:get-parameter('file','')),
<div id='content'>
<h1>Remember to close the file</h1>
<p>Close the file in your word processor and then click this close button..</p>
<p style="text-align:center; font-size: larger"><button id='close'>Close</button></p>
<div>Click <a href='javascript:openFile();'>here</a> to open it again</div>
</div>
)
}
</body></html>
