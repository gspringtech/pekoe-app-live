xquery version "3.0";

declare function local:new-user($username, $full-name, $tenant, $email, $password) {
    let $primary-group:= $tenant || "_staff"
    let $groups := ("pekoe-users","pekoe-tenants")
    return sm:create-account($username, $password, $primary-group, $groups, $full-name, $email)
    
(:  
sm:create-account($username as xs:string, $password as xs:string, $primary-group 
as xs:string, $groups as xs:string*, $full-name as xs:string, $description as xs
:string)
:)
};

local:new-user("username","Full Name", "tenant-code","TENANT Staff email", "password")
