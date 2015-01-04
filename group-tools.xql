xquery version "3.0";

(:sm:get-group-members('pekoe-admin'):)
(: sm:create-group('pekoe-tenant-admins','admin','Members will see advanced menu items in Pekoe Workspace'):)
(: sm:add-group-member('pekoe-tenant-admins','tdbg@tdbg.com.au'),:)
(: sm:remove-group('pekoe-admin'),:)
 string-join(sm:list-groups(),', '),
 sm:find-groups-by-groupname('tdbg_')