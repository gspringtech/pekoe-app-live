module namespace tm = "http://pekoe.io/templates/management";

(: 2016-04-15
   I was thinking of making this the source of all the functions that normally are run by the trigger - but there are too many things going on.
   The whole templates-meta thing needs to be considered.
:)

import module namespace ods="http://www.gspring.com.au/pekoe/merge/ods" at "merge-ods.xqm";
import module namespace odt="http://www.gspring.com.au/pekoe/merge/odt" at "merge-odt.xqm";
import module namespace docx="http://www.gspring.com.au/pekoe/merge/docx" at "merge-docx.xqm";
import module namespace ptxt="http://www.gspring.com.au/pekoe/merge/txt" at "merge-txt.xqm";
import module namespace phtml="http://www.gspring.com.au/pekoe/merge/pekoe-html" at "phtml.xqm";
import module namespace mailx="http://www.gspring.com.au/pekoe/merge/mailx" at "merge-mailx.xqm";
import module namespace textx="http://www.gspring.com.au/pekoe/merge/textx" at "merge-textx.xqm";


import module namespace rp = "http://pekoe.io/resource-permissions" at "../modules/resource-permissions.xqm";

declare function tm:extract-and-store-content-from($uri,$col) {
    let $doctype := substring-after($uri, ".")
    let $doc := switch ($doctype) 
        case "docx" return docx:extract-content($uri,$col)
        case "odt" return odt:extract-content($uri,$col)
        case "ods" return ods:extract-content($uri, $col)
        
        case "txt" return ptxt:extract-content($uri,$col)
        case "xml" return tm:handle-xml-template($uri,$col)
        default return <unknown-doctype>{$doctype}</unknown-doctype>
    return $uri
};

declare function tm:handle-xml-template($uri,$col) {
    let $doc-element := doc($uri)/*
    return typeswitch ($doc-element)
    case element(mail) return mailx:extract-content($uri,$col)
    case element(text) return textx:extract-content($uri,$col)
   
(:  TODO    ADD HTML TEMPLATE HANDLER  :)
    default return util:log("warn", "UNKNOWN XML TEMPLATE DOCTYPE " || local-name($doc-element) )
};