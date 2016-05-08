xquery version "3.0";
(: This module is called by the controller for a merge. 
   It will check and update the schema-module and also the template-merge query if the source files change
   BUT I DON'T WANT IT TO CHECK. 
   I WANT A SEPARATE QUERY THAT PERFORMS THE UPDATE.
   
   There are two updates - the Schema Module and
   the Template MERGE.
   It will also check the associated stylesheets and this function itself.
   (e.g. the schema.xml or the content.xml)
   
   :)

module namespace merge="http://www.gspring.com.au/pekoe/merge";
import module namespace rp = "http://pekoe.io/resource-permissions" at "../modules/resource-permissions.xqm";

declare variable $merge:module-path := system:get-module-load-path();
declare variable $merge:merge-module-mod-dateTime := xmldb:last-modified('/db/apps/pekoe/templates','merge-generators.xqm');
declare variable $merge:xslt-merger-mod-dateTime := xmldb:last-modified('/db/apps/pekoe/templates','generate-merge-xquery.xsl');
declare variable $merge:xslt-schema-mod-dateTime := xmldb:last-modified('/db/apps/pekoe/templates','generate-xquery-module-from-schema.xsl');


(:If the schema-mod date is less than the date of this file, or the date of the xslt-schema, then regenerate it. :)

(:  Generate a module of functions from the schema provided. Update this when the schema is found to be modified.
    Store the module in the same collection as the schema. eg school-booking.xqm 
    
:)
declare function merge:generate-xquery-module-for-schema($schema-file) {
    let $schema-doc := doc($schema-file)
(:    let $debug := util:log('info','%%%%%%%%%%%%%%% schema for ' || $schema-doc/schema/@for):)
    let $schema-last-mod := xmldb:last-modified(util:collection-name($schema-file), util:document-name($schema-file)) 
    let $xql-name := concat($schema-doc/schema/@for, ".xqm")
    let $xql-last-mod := xmldb:last-modified(util:collection-name($schema-file), $xql-name)
    let $up-to-date := ($xql-last-mod = max(($merge:merge-module-mod-dateTime, $merge:xslt-merger-mod-dateTime, $merge:xslt-schema-mod-dateTime, $xql-last-mod, $schema-last-mod)))
    return 
        if (empty($schema-doc)) then <result>A schema for {$schema-file} isn't available</result>
        else if (empty($xql-last-mod) or not($up-to-date))
        then
        let $col := util:collection-name($schema-doc)
        let $log := util:log("warn", concat("GENERATING SCHEMA MODULE for ",$schema-file, " path: ", request:get-effective-uri()))
        let $transformer := doc("/db/apps/pekoe/templates/generate-xquery-module-from-schema.xsl")
        let $result := transform:transform($schema-doc, $transformer, ())
        let $serialized := util:serialize($result, "method=xml")
        let $stored := xmldb:store($col, $xql-name, $serialized, "application/xquery")
        let $col-permissions := rp:collection-permissions($col)
        let $chown := sm:chown(xs:anyURI($stored),"admin")
        let $chgrp := sm:chgrp(xs:anyURI($stored),$col-permissions("col-group"))
        let $chmod := sm:chmod(xs:anyURI($stored),$rp:merge-permissions) (: rwxr-x--- :)
        return <result>{$stored}</result> 
        else  <result>Schema module for {$schema-file} is up to date</result>
};

declare function merge:get-schema($doctype, $tenant) {
    let $tenant-path := '/db/pekoe/tenants/' || $tenant 
    let $local-schema := collection($tenant-path)/schema[@for eq $doctype][1]
    
    return 
        if (not(empty($local-schema)))
        then  $local-schema
        else 
            let $default-schema := collection('/db/pekoe/common/schemas')/schema[@for eq $doctype]
            return
                if (not(empty($default-schema))) then $default-schema
                else ()
};

declare function merge:check-schema($doctype,$tenant) { 
    let $schema-path := document-uri(root(merge:get-schema($doctype, $tenant)))
    let $check := merge:generate-xquery-module-for-schema(string($schema-path))
    return $schema-path
};

declare function merge:check-merge-query($template, $tenant, $template-bundle, $schema-path) {
    let $ph-links-last-mod := xmldb:last-modified($template-bundle, "links.xml") 
    let $xql-last-mod := xmldb:last-modified($template-bundle, "merge.xql")
    
    let $up-to-date := ($xql-last-mod = max(($merge:merge-module-mod-dateTime, $merge:xslt-merger-mod-dateTime, $merge:xslt-schema-mod-dateTime, $xql-last-mod, $ph-links-last-mod)))
    let $log := if (not($up-to-date)) then util:log('info', '$$$$$$$$$$ TEMPLATE EXPIRED: ' || $template-bundle || ' TENANT ' || $tenant) else ()
    return 
        if (empty($xql-last-mod) or not($up-to-date))  
        then merge:make-merge-xql($template,$template-bundle,$tenant,$schema-path)
        else ($template-bundle || "/merge.xql")
};

(: Given a template path, generate an xquery from its Links file
    AND THE ONE MAJOR FLAW IN MY LINKS COMMAND IS THAT I DON'T KNOW THE ORIGINAL TEMPLATE.
    BECAUSE I'M LOOKING AT THE TEMPLATES-META .../links.xml
    and the path to get here is a one-way transform of the document name:
    /templates/Bookings/My-booking.docx
    -> /templates-meta/Bookings/My_booking_docx
    /templates/Bookings/My_booking.docx
    -> /templates-meta/Bookings/My_booking_docx
    I have no reliable way of lookup. 
    The only solution is to reprocess ALL the links files, adding the original path. (That would be an UPDATE INSERT - not a regenerate)
    and that's ugly if I choose to MOVE the document.

:)
declare function merge:make-merge-xql($template, $template-bundle, $tenant, $schema-path) {

    let $links := doc($template-bundle || "/links.xml")
    let $gen-path := "/db/apps/pekoe/templates/generate-merge-xquery.xsl" (: xmldb:exist:///db/apps/pekoe/modules/templates/:)
    let $params :=   <parameters>
                <param name='path-to-schema-col' value='{util:collection-name(string($schema-path))}' />
                <param name='template-file' value='{$template}' />
                <param name='template-meta-path' value='{$template-bundle}' />
                <param name='tenant' value='{$tenant}' />
            </parameters>
    let $links-query := transform:transform($links, doc($gen-path), $params)
    let $serialized := util:serialize($links-query, "method=xml")
    let $serialized2 := if (empty($serialized)) then current-dateTime() else $serialized
    let $stored := xmldb:store($template-bundle, "merge.xql", $serialized2, "application/xquery")
    let $col-permissions := rp:collection-permissions($template-bundle)
    let $chown := sm:chown(xs:anyURI($stored),"admin")
    let $chgrp := sm:chgrp(xs:anyURI($stored),$col-permissions("col-group"))
    let $chmod := sm:chmod(xs:anyURI($stored),$rp:merge-permissions)

    return $stored (: the path to the merge :)
};

(: Change this to a MAP. Fix it for /db/pekoe/tenants/xxx.
    Might want to incorporate the trigger code here - or push that code out to a module so it can be
    used in both the trigger and here.
    
    Template should be /db/pekoe/tenants/tdbg/templates/path/to/Thankyou.docx
    replace /templates/ with /templates-meta/
    replace .docx with _docx (replace . with _)
:)
declare function merge:template-parts($template) {
    let $doc-name := util:document-name($template)
    let $bundle-name := replace($doc-name, "[\W]+","_")
    let $template-bundle := replace(replace($template, $doc-name,$bundle-name), "/templates/","/templates-meta/") 
    return $template-bundle
};

(:
    TO MERGE a Job with a Template <name>:
    need the template content (for Word or ODT this is xml) from    config/template-content/path/name.xml       (extracted when the file is uploaded)
    need the template LINKS file from                               config/template-meta/path/name.xml          (created when? Edited by admin user - manual process)
    need the glue query (the "merge-xql") from                      config/template-meta/path/name.xql          (generated automatically if it doesn't exist or is outdated)
    
    The merge request is actually a command stored in config/site-commands.xml:
        var path = o.template + "?action=download&amp;job=" + o.file.getPath();
        window.location.href= "merge" + path;
        
    The LINKS file is a tuple of (placeholder-name, field-path, output-name?)
    
    This query simply ensures that the merge-xql is available and up-to-date. The fun
:)


(: ----------------------------- THIS IS IT - it's just a path munge.  ------------------------ :)
(: And other than the checking functions, it simply converts the template path to a templates-meta path with /merge.xql on the end. 
    
:)
(: Called by controller.xql when processing a /merge path.
/merge/path/to/template?job=/path/to/job
$template-query = merge:get-links-query(/path/to/template)
<forward url=/rest{$template-query} > this is where the merge happens

This function makes sure there's an up-to-date merge-xql file available and returns its path.
The merge file will perform the actual merge.
:)

declare function merge:get-links-query-path($template,$tenant) { 
    (: e.g. given      /db/pekoe/templates/Education/Tax-Invoice.docx,         
    return        /db/pekoe/templates-meta/Education/Tax_Invoice_docx/merge.xql       :)
    let $template-bundle := merge:template-parts($template)
     return substring-after(($template-bundle || "/merge.xql"),"/db/pekoe")
};


declare function merge:update-links-query($template, $tenant) { 
    (: e.g. given      /db/pekoe/templates/Education/Tax-Invoice.docx,         
    return        /db/pekoe/templates-meta/Education/Tax_Invoice_docx/merge.xql   
    :)
(:    let $log := util:log('warn', '999999999 Update Links query for $template:' || $template || ' and $tenant:' || $tenant):)
    let $template-bundle := merge:template-parts($template)
    let $schema-doctype := doc($template-bundle || '/links.xml')/links/string(@for)
    let $schema-path := merge:check-schema($schema-doctype,$tenant)
    let $merge-path := merge:check-merge-query($template, $tenant, $template-bundle,$schema-path)
    return 
(:        xs:anyURI( $merge-path):)
        substring-after($merge-path,"/db/pekoe")
(:substring-after($merge-path,"/db/pekoe/"):)
};


