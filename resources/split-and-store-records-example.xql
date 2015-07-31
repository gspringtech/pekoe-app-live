xquery version "3.0";
xmldb:create-collection('/db/pekoe/tenants/bkfa/files/members','2015'),
for $m in doc('/db/pekoe/tenants/bkfa/files/members-2015.xml')//member
let $dn := 'member-' || format-number(xs:integer($m/id),'000000') || '.xml'
let $stored := xmldb:store('/db/pekoe/tenants/bkfa/files/members/2015',$dn, $m)
return $stored