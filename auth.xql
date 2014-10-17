import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare 
%rest:GET
%rest:path("/login")
%rest:produces("application/json")
%output:media-type("application/json")
function local:login() {
    <rest:response>
        <http:response status="{$pekoe-http:HTTP-401-UNAUTHORIZED}">
        <http:header name="Location" value="login"/>
        <http:header name="WWW-Authenticate" value="Form" />
        </http:response>
    </rest:response>
};

declare 
%rest:GET
%rest:path("/login-error")
%rest:produces("application/json")
%output:media-type("application/json")
function local:login-error() {
    if (xmldb:get-current-user() ne "guest") then
    <rest:response>
        <http:response status="{$pekoe-http:HTTP-403-FORBIDDEN}">
        You ({xmldb:get-current-user()}) do not have sufficient privileges to access this resource.
        </http:response>
    </rest:response>
    else local:login()
};

()