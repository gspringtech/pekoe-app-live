xquery version "3.0";
<bad-paths>{
let $doctype := 'residential'
let $schema := collection('/db/pekoe/tenants/cm/schemas')/schema[@for eq $doctype]
let $schema-paths :=  $schema/(field,fragment-ref)[starts-with(@path,'/')]/@path/string()


for $f in collection('/db/pekoe/tenants/cm/templates-meta')/links[@for eq $doctype]/link[not(@field-path = $schema-paths)]
return <t>{attribute path {substring-after(substring-before($f/base-uri(),'/links.xml'),'/db/pekoe/tenants/cm/templates-meta/')}, attribute field-path {$f/@field-path/string()}, $f/@placeholder/string()}</t>
}</bad-paths>