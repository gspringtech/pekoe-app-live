xquery version "3.0";
module namespace tm = "http://pekoe.io/templates/management";
(:
    Module handles activity in the tenant's /templates collection
    after-create-collection - create a matching collection in /templates-meta
    after-delete-colletion - delete matching collection
    after-create-document -     
        - create matching collection using the good-name(document name)
        - extract 
:)
(: collection.xconf for the Trigger needs to be stored in /db/system/config/pekoe/tenants/XXX/templates/ - part of setup.xql :)

declare namespace trigger = "http://exist-db.org/xquery/trigger";
import module namespace ods="http://www.gspring.com.au/pekoe/merge/ods" at "merge-ods.xqm";
import module namespace odt="http://www.gspring.com.au/pekoe/merge/odt" at "merge-odt.xqm";
import module namespace docx="http://www.gspring.com.au/pekoe/merge/docx" at "merge-docx.xqm";
import module namespace ptxt="http://www.gspring.com.au/pekoe/merge/txt" at "merge-txt.xqm";
import module namespace phtml="http://www.gspring.com.au/pekoe/merge/pekoe-html" at "phtml.xqm";
import module namespace mailx="http://www.gspring.com.au/pekoe/merge/mailx" at "merge-mailx.xqm";
import module namespace textx="http://www.gspring.com.au/pekoe/merge/textx" at "merge-textx.xqm";

import module namespace rp = "http://pekoe.io/resource-permissions" at "../modules/resource-permissions.xqm";


declare variable $tm:log-level external;


(: ------------------- TRIGGER HANDLERS -------------------- :)

declare function trigger:after-create-collection($uri) {
    tm:log(("AFTER CREATE COLLECTION ",$uri)),
    rp:create-collection(tm:tenant-meta-collection($uri),substring-after($uri,"templates/"))
};

declare function trigger:after-delete-collection($uri) {
    tm:log(("AFTER DELETE COLLECTION ",$uri)),
    let $col := tm:tenant-meta-collection($uri) || substring-after($uri,"templates/")
    return if (xmldb:collection-available($col)) then xmldb:remove($col) else ()
};

declare function trigger:after-move-document($old, $new) {
    tm:log(("AFTER MOVE DOCUMENT old: ",$old, " new: ", $new)),
    tm:created(xs:string($new))
};

declare function trigger:after-move-collection($uri as xs:anyURI, $new-uri as xs:anyURI) { (: Correct order of params :)
    tm:log(("AFTER MOVE COLLECTION ", $uri, " TO ", $new-uri)),
    (:  The move is either into a sub-collection or up to the parent. The ideal would be to simply move the corresponding collection  :)
    tm:move-collection($uri, $new-uri)
};

declare function trigger:after-create-document($uri as xs:anyURI) {
    tm:created(xs:string($uri))
};

(: DELETE the bundle from templates-meta/
    NOTE: CAN'T USE UTIL:DOCUMENT-NAME WHEN THE DOCUMENT HAS BEEN DELETED
:)
declare function trigger:after-delete-document($uri as xs:anyURI) {
    tm:log(("AFTER DELETE DOCUMENT", $uri)),
    tm:deleted(string($uri))   
};

(: This is called when the document is replaced.
    To make this work, the script changes the owner (to the current user) and mode of the meta-files,
    then the files are modified, (in 'create') and then finally the owner is returned to _staff and the mode to 'closed-and-available'
:)
declare function trigger:after-update-document($uri as xs:anyURI) {
(:    tm:log(("AFTER UPDATE DOCUMENT", $uri || ' USER ' || sm:id()//sm:real/sm:username/string() )),:)
    let $meta-col := tm:bundle-col(string($uri))
    return tm:unlock-files($meta-col)
    ,
    tm:created(string($uri))
};


(: ---------------- Pekoe Template functions --------------------:)

declare function tm:move-collection($old-uri,$new-uri) {
    (:  Going to assume that the collection already has all the right bits in it - so assume that it's not coming from outside of templates.   :)
    let $source-collection := substring-before($old-uri, "/templates") || "/templates-meta" || substring-after($old-uri,"/templates")
    let $new-collection := substring-before($new-uri, "/templates") || "/templates-meta" || substring-after($new-uri,"/templates")
    let $target-collection := util:collection-name(substring-before($new-uri, "/templates") || "/templates-meta" || substring-after($new-uri,"/templates")) (: parent collection :)
    
    return if (xmldb:collection-available($source-collection) and xmldb:collection-available($target-collection)) then xmldb:move($source-collection, $target-collection) else tm:log('UNABLE TO MOVE')
};

(: get the parent-collection path in templates-meta for a document in templates :)
declare function tm:col-meta-path($full-doc-path) {
    let $doc-col := util:collection-name($full-doc-path)
    return 
    (substring-before($doc-col, "/templates") || "/templates-meta" || substring-after($doc-col,"/templates"))
};

declare function tm:full-meta-path($full-doc-path) { (: e.g. /db/pekoe/tenants/tdbg/templates/Programs/Wildlife-day.docx :)
    let $doc-name := tm:good-name(util:document-name($full-doc-path))
    let $doc-col := util:collection-name($full-doc-path)
    return 
    (substring-before($doc-col, "/templates") || "/templates-meta/" || substring-after($doc-col,"/templates") || "/" ||  $doc-name)
};


(: Getting really untidy here. This module needs a rewrite. :)
declare function tm:bundle-col($path as xs:string) {
    let $col-path := tm:col-meta-path($path)
    let $docname := util:document-name($path)
    let $good-name := tm:good-name($docname)
    return $col-path || '/' || $good-name
};

declare function tm:deleted($path as xs:string) {
   let $meta-col := tm:col-meta-path($path)
    let $docname := tokenize($path, '/')[position() eq last()]
    let $good-name := tm:good-name($docname)
    let $meta-path-to-bundle := $meta-col || "/" || $good-name
    let $debg := tm:log("TEMPLATE TRIGGER GOING TO DELETE COLLECTION " || $meta-path-to-bundle)
    let $good-col := if (xmldb:collection-available($meta-path-to-bundle) and not(ends-with($meta-path-to-bundle, "/templates-meta"))) then xmldb:remove($meta-path-to-bundle) else ()
    return ()
};

declare function tm:created($path as xs:string) {
    (:    To create a collection, need the parent-collection and the new-col-name :)
    let $col-path := tm:col-meta-path($path)
    let $docname := util:document-name($path)
    let $permissions := rp:template-permissions($path) (: Should only need to set permissions on CREATE. rwxrwx--- col-owner, col-owner :)
    
    let $good-name := tm:good-name($docname)
    let $good-col := rp:create-collection($col-path, $good-name)
    let $content-file := tm:extract-and-store-content-from($path,$good-col)
    let $p := tm:fix-permissions($good-col)
    
    return ()
};

declare function tm:unlock-files($meta-col) {
    for $res in xmldb:get-child-resources($meta-col)
    let $log := tm:log( '^^^^^^^^^^^ TRIGGER CALLS LOCK ON ' ||$meta-col || '/' || $res)
    return rp:lock-file($meta-col || '/' || $res) (: What??? :)
};


declare function tm:fix-permissions($meta-col) {
    for $res in xmldb:get-child-resources($meta-col)
    let $log := tm:log('^^^^^^^^^^^ TRIGGER CALLS UNLOCK ON ' ||$meta-col || '/' || $res)
    return rp:unlock-file($meta-col || '/' || $res)
};

declare function tm:log($msgs as xs:string+) { 
    util:log-app('warn','pekoe.io', ("PEKOE " || string-join($msgs,'. ')))
};

(:
    Requirements
    Every file in the templates/ collection will be treated as a template.
    These actions must be performed when a collection is created or modified
        - create|delete|rename the corresponding collection in templates-meta/
        
    These actions must be performed after a file is added or modified in any way
        - create (if needed) a matching collection in templates-meta/
        - if it is a bundle-type (docx, odt, ods, xlxs) then extract the content as xml to the templates-meta/collection
        - extract into memory all the LINK elements (using the appropriate module)
        - generate an XQuery <template-name>.xql using the LINK elements.
        - this XQuery should have these functions:
            - get-links
            - merge(job)
        - add the path to 
    This action must be performed when the file is deleted (and/or moved). Moving a file is the same as delete and add.
    First, 
    
    IDEA: construct a template BUNDLE in templates-meta
    That will simplify the process of storing and deleting the stuff
    templates-meta/Program/Wildlife-day.odt/
                                            links.xml
                                            Wildlife-day.xml
                                            Wildlife-day.xql 
    ... then I don't need to create an overall list of templates and their doctype, I can just query collection($templates-meta)/links/@for
    
    Also, when deleting (moving, renaming, whatever), I simply delete the bundle.

:)

declare function tm:tenant-meta-collection($uri) {
    let $tenant := substring-before($uri,"/templates")
    return $tenant || '/templates-meta/'
};


declare function tm:handle-xml-template($uri,$col) {
    let $doc-element := doc($uri)/*
    return typeswitch ($doc-element)
    case element(mail) return mailx:extract-content($uri,$col)
    case element(text) return textx:extract-content($uri,$col)
    (:  TODO    ADD HTML TEMPLATE HANDLER  :)
    default return tm:log("UNKNOWN XML TEMPLATE DOCTYPE " || local-name($doc-element) )
};


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


(:
Ah - Microsoft. Thou crock full of shit. Here's my new "Link" - it's a Hyperlink. 
And where is the link?

<w:hyperlink r:id="rId10" w:history="1">
    <w:proofErr w:type="gramStart"/>
    <w:r w:rsidRPr="0033197E">
        <w:rPr>
            <w:rStyle w:val="Hyperlink"/>
            <w:sz w:val="36"/>
            <w:szCs w:val="36"/>
        </w:rPr>
        <w:t>teacher</w:t>
    </w:r>
    <w:proofErr w:type="gramEnd"/>
</w:hyperlink>

It's in the word/_rels/document.xml.rels
<Relationship Id="rId10" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="http://pekoe.io/bgaedu/school-booking/school/teacher?output=name" TargetMode="External"/>
                        
:)


declare function tm:good-name($u) {
    replace($u, "[\W]+","_")
};
