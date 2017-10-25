xquery version "3.0";

declare function local:copy-and-delete($doc, $dest) {
    let $s-col := util:collection-name($doc)
    let $s-doc := util:document-name($doc)
   return (xmldb:copy($s-col,$dest,$s-doc), xmldb:remove($s-col,$s-doc))
   
};

local:copy-and-delete('/db/pekoe/tenants/cm/mail/message-2016-07-20-16-23-2.xml','/db/pekoe/tenants/cm/dead-letters')
 