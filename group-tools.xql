xquery version "3.0";

(: sm:add-group-member('tdbg_staff','tdbg@thedatabaseguy.com.au'),:)
sm:add-group-member('bkfa_staff','fiona@bkfa.org.au'),
sm:add-group-member('bkfa_admin','fiona@bkfa.org.au'), 
(: string-join(sm:get-group-members('pekoe-users'),', '),:)
(: sm:create-group('','admin','Members will see advanced menu items in Pekoe Workspace'):)

(: sm:remove-group('admin_tdbg'),:)
 string-join(sm:list-groups(),', '),
(: sm:find-groups-by-groupname('tdbg_'),:)
 ()