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

(: Pekoe GROUPS:
    pekoe-system
    pekoe-tenant-admins
    pekoe-tenants
    pekoe-users
    
    pekoe-tenants has all the pekoe users who are allowed to create/own files in the system (this includes the <tenant>_staff users)
    pekoe-users has all the users who are allowed to login to Pekoe (does not include the _staff and _admin users)
    
    WHY aren't the three _admin users in pekoe-tenants?
    
TENANTS
tdbg
cm
bkfa
-------------
ADMIN-GROUPS
    bkfa_admin
    cm_admin
    tdbg_admin
-------------
STAFF-GROUPS
bkfa_staff
pekoe-tenants
cm_staff
pekoe-tenants
pekoe-tenants
tdbg_staff
-------------
-------
PEKOE-SYSTEM
------
    pekoe-system
-------
PEKOE-TENANT-ADMINS
------
-------
PEKOE-TENANTS
------
    admin
    admin-b@cm
    admin-l@cm
    adrian@bkfa
    alana-p@cm
    alister-p@cm
    amanda-p@cm
    amber-g@cm
    angela-h@cm
    bkfa_staff
    cheryl-s@cm
    cm_staff
    erica@bkfa
    fiona-b@cm
    fiona@bkfa.org.au
    form-one@cm
    frank-g@cm
    hilary@bkfa
    jacqui-p@cm
    jess-h@cm
    john@cm
    kellie@bkfa
    kirbyt@cm
    lauren-r@cm
    nichola-z@cm
    penny@cm
    rebecca@bkfa
    renee-t@cm
    ryan@papertopixels.com.au
    sarah-p@cm
    shelby-s@cm
    simon-g@cm
    tamara-b@cm
    tdbg@thedatabaseguy.com.au
    tdbg_staff
    zeshi@bkfa
-------
PEKOE-USERS
------
    admin
    admin-b@cm
    admin-l@cm
    adrian@bkfa
    alana-p@cm
    alister-p@cm
    amanda-p@cm
    amber-g@cm
    angela-h@cm
    cheryl-s@cm
    cm_external
    erica@bkfa
    fiona-b@cm
    fiona@bkfa.org.au
    form-one@cm
    frank-g@cm
    hilary@bkfa
    jacqui-p@cm
    jess-h@cm
    john@cm
    kellie@bkfa
    kirbyt@cm
    lauren-r@cm
    nichola-z@cm
    penny@cm
    rebecca@bkfa
    renee-t@cm
    ryan@papertopixels.com.au
    sarah-p@cm
    shelby-s@cm
    simon-g@cm
    tamara-b@cm
    tdbg@thedatabaseguy.com.au
    zeshi@bkfa
:)