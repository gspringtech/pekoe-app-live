xquery version "3.0";

(: If this is a Job or Schema conversion, remember to fix the Template-meta files. :)
(: return a deep copy of  the element and all sub elements :)
declare function local:copy($element as element()) as element() {
   element {node-name($element)}
      {$element/@*,
          for $child in $element/node()
              return
               if ($child instance of element())
                 then local:copy($child)
                 else $child
      }
};

declare function local:replace-root($root-name, $element) {
    element {$root-name}
      {$element/@*,
          for $child in $element/node()
              return
               if ($child instance of element())
                 then local:copy($child)
                 else $child
      }
    
};

for $d in collection('/db/pekoe/tenants/bkfa/files/distribution')/annual-distribution
let $col := util:collection-name($d)
let $doc := util:document-name($d)
let $du := local:replace-root("annual-grant-distribution",$d)
return $du
(:return xmldb:store($col,$doc,$du):)