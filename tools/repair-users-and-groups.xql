xquery version "3.0";
(:let $groups := 'admin_bkfa bkfa_admin bkfa_staff cm_admin cm_legal cm_staff pekoe-system pekoe-tenant-admins pekoe-tenants pekoe-users staff_bkfa tdbg_admin tdbg_staff':)

(: To LOGIN, a user must belong to pekoe-users.
 : To create files or do anything else, the user must belong to pekoe-tenants.
 : This includes the _staff user.
 : :)

declare function local:fix-groups($u, $staff-group) {
    sm:add-group-member('pekoe-tenants',$u), sm:add-group-member('pekoe-users',$u), sm:add-group-member($staff-group,$u)
};

declare function local:list-users-and-groups($tenant) {
    for $u in sm:list-users()[ends-with(.,$tenant)]
    return <user name='{$u}'>{string-join(sm:get-user-groups($u),' ')}</user>
    
};

declare function local:create-tenant-user($uname, $tenant, $is-admin){
    ()
}; 

()

(:sm:remove-group-member('pekoe-users','cm_staff'):)
(:sm:add-group-member('pekoe-tenants','cm_staff'):)


(:let $required-for-login := ('pekoe-tenants','pekoe-users'):)
(::)
(:let $tenant-admin-users := ('john@cm','penny@cm'):)
(:let $staff-group := map {'cm_staff': '@cm', 'bkfa_staff' : '@bkfa', 'tdbg_staff' : '@tdbg'}:)

(:for $u in sm:list-users()[ends-with(.,'@bkfa')]:)
(:return :)
(:    return sm:chown(xs:anyURI('/db/pekoe/tenants/cm/config/serial-numbers/pt.xml'),'cm_staff'):)
(:    return sm:list-users()[contains(.,'fiona')]:)
(:return  local:list-users-and-groups('@bkfa'):)

(:    sm:add-group-member('pekoe-tenants',$u):)
 (:string-join(sm:list-groups(),' '):)