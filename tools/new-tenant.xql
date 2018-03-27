xquery version "3.1";
(:
    Given a name and abbreviation, create:
    - tenant collection as a copy of the tenant-template
    - fix permissions on those files
    - rename any significant portions
    - create <tenant>_staff, <tenant>_admin and add to pekoe-tenants?
    
    ADD subdomain to GANDI
:)

declare function local:users-and-groups() {
(:sm:list-groups(),:)
"TENANTS",
collection('/db/pekoe/tenants')/tenant/string(@id),
"-------------",
"ADMIN-GROUPS",
for $admin-user in sm:list-users()[ends-with(.,'_admin')] return ("    " || sm:get-user-groups($admin-user)),
"-------------",
"STAFF-GROUPS",
for $admin-user in sm:list-users()[ends-with(.,'_staff')] return ("    " || sm:get-user-groups($admin-user)),
"-------------",

for $group in sm:find-groups-by-groupname("pekoe-")

return ("-------", upper-case($group), "------", for $user in sm:get-group-members($group) order by $user return ("    " || $user))
};
()

