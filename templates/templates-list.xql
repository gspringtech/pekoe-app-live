xquery version "3.1";

import module namespace dbutil = "http://exist-db.org/xquery/dbutil" at "/db/apps/shared-resources/content/dbutils.xql";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:indent "yes";
(:declare option output:media-type "application/json";:)

declare variable $local:tenant-path-str := '/db/pekoe/tenants/';

declare function local:flat-list-templates($tenant) {
    let $tenant-path := $local:tenant-path-str || $tenant || '/templates'
    return
        dbutil:scan(xs:anyURI($tenant-path), function ($col, $res) {
            if ($res) then
                <item
                    name="{$res}"
                    path=""/>
            
            else
                if ($col) then
                    <collection
                        name="{$col}"
                        path="{$col}"/>
                else
                    ()
        })
};

declare function local:templates-hierarchy($collection, $name) {
    <collection
        path="{$collection}"
        name="{$name}">
        {
            for $c in xmldb:get-child-collections($collection)
            return
                local:templates-hierarchy($collection || '/' || $c, $c)
        }
        {
            for $r in xmldb:get-child-resources($collection)
            return
                <item
                    name="{$r}"
                    path="{$collection || '/' || $r}"/>
        }
    </collection>
};


declare function local:collections($collection, $name) {
    if (empty(xmldb:get-child-collections($collection))) then () else
    <collections
        path="{$collection}"
        name="{$name}">
        {
            for $c in xmldb:get-child-collections($collection)
            let $cc := $collection || '/' || $c
            where not(empty(xmldb:get-child-collections($cc)))
            return
                <sub-col>{attribute path {$cc}}{$c}</sub-col>
        }
    </collections>,
    for $c in xmldb:get-child-collections($collection)
    return local:collections($collection || '/' || $c,$c)
};

declare function local:items($collection) {
    <items
        path="{$collection}">
        {
            for $r in xmldb:get-child-resources($collection)
            return
                <item
                    name="{$r}"
                    path="{$collection || '/' || $r}"/>
        }
    </items>,
    for $c in xmldb:get-child-collections($collection)
    return
        local:items($collection || '/' || $c)
};

(: I think a better output would be
 <db>
  <collections></collections>
  <items></items>:)

(:local:flat-list-templates('cm'):)

(: TODO - change the output to produce a completely flat list of {key : '/db/pekoe/templates', value:  {name: 'Templates', contents: [{key'Business',
    NOT QUITE RIGHT- but want to end up with a DICTIONARY
:)

(:local:templates-hierarchy('/db/pekoe/tenants/cm/templates', 'Templates'):)
let $col := '/db/pekoe/tenants/cm/templates' (: DON'T GO HIGHER than TEMPLATES!! :)
return
    <bag>
        {local:collections($col, 'Templates')}
       
        {local:items($col)}
    </bag>


(:
 This is the output I'm after for collections:
 
 {:collections
  [{:path "/templates",
    :name "Templates",
    :children
    [{:path "/templates/Business", :name "Business"}
     {:path "/templates/Lease", :name "Lease"}
     {:path "/templates/Residential", :name "Residential"}]}
   {:path "/templates/Business",
    :name "Business",
    :children
    [{:path "/templates/Business/Vendor", :name "Vendor"}
     {:path "/templates/Business/Purchaser", :name "Purchaser"}]}
   {:path "/templates/Residential",
    :name "Residential",
    :children
    [{:path "/templates/Residential/Purchaser", :name "Purchaser"}
     {:path "/templates/Residential/Vendor", :name "Vendor"}]}]}}



:)




