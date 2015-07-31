xquery version "3.0";
string-join(let $links := collection('/db/pekoe/tenants/cm/templates-meta/Agencies')//link
return distinct-values(for $p in $links return $p/@original-href/substring-after(.,'http://pekoe.io/cm'))
,',')
