xquery version "3.0";
(:
 : Tenant Post install and Permission Repair.
 : 
 : Consider also having an XML document which details the permissions so that a lookup can be performed
 : :)


declare function local:get-specifics($resource) {
    let $new-job := 
        <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="bkfa_staff" group="bkfa_staff" mode="r-sr-x---">
            <sm:acl entries="0"/>
        </sm:permission>
    let $r := util:document-name($resource)
    let $c := util:collection-name($resource)
    let $p := sm:get-permissions(xs:anyURI($resource))
    
    return
        <p path="{$resource}" mode="{$p/sm:permission/string(@mode)}" owner="{$p/sm:permission/string(@owner)}" group="{$p/sm:permission/string(@group)}" />
    (: This is not quite right because some resources will be owned by admin or by specific users.   :)
};


local:get-specifics('/db/pekoe/tenants/bkfa/config/serial-numbers/documentation.xml')