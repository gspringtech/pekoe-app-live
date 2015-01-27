xquery version "3.0";
module namespace tm = "http://pekoe.io/templates/management";
(:Sadly I have lost a morning's work. I had been importing the merge files. Specifically, I think it was on Owl in Sublime - the templates.xqm :)
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
import module namespace ods="http://www.gspring.com.au/pekoe/templates/ods" at "ods.xqm";
import module namespace odt="http://www.gspring.com.au/pekoe/merge/odt" at "merge-odt.xqm";
import module namespace docx="http://www.gspring.com.au/pekoe/merge/docx" at "merge-docx.xqm";
import module namespace ptxt="http://www.gspring.com.au/pekoe/merge/txt" at "merge-txt.xqm";
import module namespace phtml="http://www.gspring.com.au/pekoe/templates/pekoe-html" at "phtml.xqm";

declare variable $tm:log-level external;

declare function trigger:after-create-collection($uri) {
    tm:log(("after create collection",$uri)),
    tm:create-collection(tm:tenant-meta-collection($uri),substring-after($uri,"templates/"))
};

declare function trigger:after-delete-collection($uri) {
    tm:log(("after delete collection",$uri)),
    let $col := tm:tenant-meta-collection($uri) || substring-after($uri,"templates/")
    return if (xmldb:collection-available($col)) then xmldb:remove($col) else ()
};

(:declare function trigger:before-create-document($uri as xs:anyURI) {
    tm:log(("XQuery Trigger called BEFORE document '", $uri, "' created."))
};
:)
declare function trigger:after-create-document($uri as xs:anyURI) {
    tm:log(("TEMPLATE TRIGGER called after document '", $uri, "' CREATED.")),
    tm:created(xs:string($uri))
    
};

(: get the parent-collection path in templates-meta for a document in templates :)
declare function tm:col-meta-path($full-doc-path) {
    let $doc-col := util:collection-name($full-doc-path)
(:    let $col-debg := util:log("warn", "DOC COL IS " || $doc-col):)
    return 
    (substring-before($doc-col, "/templates") || "/templates-meta" || substring-after($doc-col,"/templates"))
};

declare function tm:full-meta-path($full-doc-path) { (: e.g. /db/pekoe/tenants/tdbg/templates/Programs/Wildlife-day.docx :)
    let $doc-name := tm:good-name(util:document-name($full-doc-path))
    let $doc-col := util:collection-name($full-doc-path)
    let $log := util:log("warn", "CONSTRUCTING FULL-META-PATH docname:" || $doc-name || " doc-col:" || $doc-col || " FROM DOC:" || $full-doc-path)
    return 
    (substring-before($doc-col, "/templates") || "/templates-meta/" || substring-after($doc-col,"/templates") || "/" ||  $doc-name)
};

(: DELETE the bundle from templates-meta/
    NOTE: CAN'T USE UTIL:DOCUMENT-NAME WHEN THE DOCUMENT HAS BEEN DELETED
:)
declare function trigger:after-delete-document($uri as xs:anyURI) {
    tm:log(("TEMPLATE TRIGGER called after '", $uri, "' DELETED.")),
    tm:deleted(string($uri))   
};

(: This is called when the document is replaced :)
declare function trigger:after-update-document($uri as xs:anyURI) {
    tm:log(("MODIFIED THIS DOCUMENT ", $uri, " IN COLLECTION ", util:collection-name(xs:string($uri)))),
    tm:deleted(string($uri)),
    tm:created(string($uri))
};

declare function tm:deleted($path as xs:string) {
   let $meta-col := tm:col-meta-path($path)
    let $docname := tokenize($path, '/')[position() eq last()]
    let $good-name := tm:good-name($docname)
    let $meta-path-to-bundle := $meta-col || "/" || $good-name
    let $debg := util:log("warn", "TEMPLATE TRIGGER GOING TO DELETE COLLECTINO " || $meta-path-to-bundle)
    let $good-col := if (xmldb:collection-available($meta-path-to-bundle) and not(ends-with($meta-path-to-bundle, "/templates-meta"))) then xmldb:remove($meta-path-to-bundle) else ()
    return ()
};

declare function tm:created($path as xs:string) {
    (:    To create a collection, need the parent-collection and the new-col-name :)
    let $col-path := tm:col-meta-path($path)
    let $docname := util:document-name($path)
    let $good-name := tm:good-name($docname)
    (:let $log := util:log("warn", "GOING TO CREATE A COLLECTION " || $good-name || " in collection " || $col-path):)
    let $good-col := xmldb:create-collection($col-path, $good-name)
    let $content-file := tm:extract-and-store-content-from($path,$good-col)
    let $compiled-query := tm:generate-query-for($content-file,$good-col)
    return ()
};

declare function tm:log($msgs as xs:string+) { 
    util:log($tm:log-level, $msgs)
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

declare function tm:create-meta-directory($template-path) {
()
};

declare function tm:create-collection($basepath, $subpath){
    if ($subpath = ("","/")) then $basepath
    else 
        let $subdirname := tokenize($subpath,"/")[1]
        let $subdir := $basepath || '/' || $subdirname
        let $newcoll := 
            if (xmldb:collection-available($subdir)) then ()
            else 
                (xmldb:create-collection($basepath,$subdirname))
        return tm:create-collection($subdir, string-join(tokenize($subpath,'/')[position() gt 1],'/'))
};

declare function tm:extract-and-store-content-from($uri,$col) {
    let $doctype := substring-after($uri, ".")
    let $doc := switch ($doctype) 
(:    I will need to call functions in the docx to do this. It requires two files to find the links. :)
        case "docx" return docx:extract-content($uri,$col)
        case "odt" return odt:extract-content($uri,$col)
 (:        case "ods" return zip:xml-entry($uri, "content.xml")
        :)
        case "txt" return ptxt:extract-content($uri,$col)
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
declare function tm:generate-query-for($content-file,$col) {
(: See merge-generators.xqm :)
    ()
};

declare function tm:good-name($u) {
    replace($u, "[\W]+","_")
};
