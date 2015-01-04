(:import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";:)

(: As desired, a tenant who logs using another tenants address will not see anything. However,
I still need to tell them something. "Please login at your own address" or something.

:)

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare 
%rest:GET
%rest:path("/login")
%rest:produces("text/html")
%output:method("html5")
function local:login() {
    <rest:response>
        <http:response status="401">
        <http:header name="Location" value="form" />
        <http:header name="WWW-Authenticate" value="Form" />
        </http:response>
    </rest:response>
    ,
    <html><head><title>Login</title></head>
  <body>
  <div>
                          <form action='/exist/j_security_check'>
                            <input type="text" name="j_username" placeholder="Username" />
                            <input type="password" name="j_password" placeholder="Password" />
                            <input type="submit" value="Login" />
                        </form>
                        </div>
                        </body>
                        </html>
};
(:

declare 
%rest:GET
%rest:path("/login/form-test")
%output:media-type("text/html")
%output:method("html5")
function local:login() {
  <html><head><title>Login</title></head>
  <body>
  <div>
                          <form action='/exist/j_security_check' ng-submit="submit()">
                            <input ng-model="user.username" type="text" name="user" placeholder="Username" />
                            <input ng-model="user.password" type="password" name="pass" placeholder="Password" />
                            <input type="submit" value="Login" />
                        </form>
                        </div>
                        </body>
                        </html>
};:)



declare 
%rest:GET
%rest:path("/login-error")
%rest:produces("text/html")
%output:method("html5")
function local:login-error() {
    if (xmldb:get-current-user() ne "guest") then
    <rest:response>
        <http:response status="403">
        You ({xmldb:get-current-user()}) do not have sufficient privileges to access this resource.
        </http:response>
    </rest:response>
    else local:login()
};

()