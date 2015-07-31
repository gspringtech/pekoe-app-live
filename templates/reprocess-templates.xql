xquery version "3.0";
import module namespace tenant="http://pekoe.io/tenant" at "/db/apps/pekoe/modules/tenant.xqm";


import module namespace dbutil="http://exist-db.org/xquery/dbutil" at "/db/apps/shared-resources/content/dbutils.xql";
import module namespace odt="http://www.gspring.com.au/pekoe/merge/odt" at "merge-odt.xqm";
import module namespace docx="http://www.gspring.com.au/pekoe/merge/docx" at "merge-docx.xqm";
import module namespace ptxt="http://www.gspring.com.au/pekoe/merge/txt" at "merge-txt.xqm";
(:import module namespace phtml="http://www.gspring.com.au/pekoe/templates/pekoe-html" at "phtml.xqm";:)
import module namespace mailx="http://www.gspring.com.au/pekoe/merge/pxml" at "merge-pxml.xqm";
(:import module namespace rp = "http://pekoe.io/resource-permissions" at "../modules/resource-permissions.xqm";:)
import module namespace tm="http://pekoe.io/templates/management" at "/db/apps/pekoe/templates/template-trigger.xqm";

declare function local:reprocess($tenant, $sub-collection) {
    let $collection := string-join(('/db/pekoe/tenants', $tenant, 'templates', $sub-collection), "/")
    let $fn := function ($col, $res) {
        if ($res) then
        let $full-meta-path := tm:full-meta-path(string($res))
        let $log := util:log('debug','********************** processing ' || $full-meta-path)
        return
        switch (substring-after($res,'.'))
        case "docx" return docx:replace-links($full-meta-path)
        case "odt" return odt:replace-links($full-meta-path)
        case "txt" return ptxt:replace-links($full-meta-path)
        case "xml" return mailx:replace-links($full-meta-path)
        default return <unknown-doctype>{$full-meta-path} not known</unknown-doctype>
    else ()
    }
    return dbutil:scan($collection, $fn)
};


local:reprocess('cm', ()),
tenant:fix-ownership(xs:anyURI('/db/pekoe/tenants/cm/templates-meta'),'cm_staff','cm_staff')