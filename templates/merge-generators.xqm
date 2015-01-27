xquery version "3.0";
(: This module is called by the controller for a merge. 
   It will check and update the schema-module and also the template-merge query if the source files change 
   (e.g. the schema.xml or the content.xml)
   
   :)

module namespace merge="http://www.gspring.com.au/pekoe/merge";



(:  Generate a module of functions from the schema provided. Update this when the schema is found to be modified.
    Store the module in the same collection as the schema. eg school-booking.xqm 
    
:)
declare function merge:generate-xquery-module-for-schema($schema-file) {
    let $schema-doc := doc($schema-file)
    let $schema-last-mod := xmldb:last-modified(util:collection-name($schema-file), util:document-name($schema-file)) 
    let $xql-name := concat($schema-doc/schema/@for, ".xqm")
    let $xql-last-mod := xmldb:last-modified(util:collection-name($schema-file), $xql-name)
    
    return 
        if (empty($schema-doc)) then <div>A schema for {$schema-file} isn't available</div>
        else if (empty($xql-last-mod) or ($schema-last-mod gt $xql-last-mod))
        then
        let $coll := util:collection-name($schema-doc)
        let $log := util:log("warn", concat("GENERATING SCHEMA MODULE for ",$schema-file, " path: ", request:get-effective-uri()))
        let $transformer := xs:anyURI("generate-xquery-module-from-schema.xsl")
        let $result := transform:transform($schema-doc, $transformer, ())
        let $serialized := util:serialize($result, "method=xml")
        let $stored := xmldb:store($coll, $xql-name, $serialized, "application/xquery")
        return $stored 
        else  <div>Schema module for ${$schema-file} is up to date</div>
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
    return 
        if (empty($xql-last-mod) or ($ph-links-last-mod gt $xql-last-mod))  
        then merge:make-merge-xql($template,$template-bundle,$tenant,$schema-path)
        else ($template-bundle || "/merge.xql")
};

(: Given a template path, generate an xquery from its Links file :)
declare function merge:make-merge-xql($template, $template-bundle, $tenant, $schema-path) {

    let $links := doc($template-bundle || "/links.xml")
    let $gen-path := "generate-links-xql.xsl" (: xmldb:exist:///db/apps/pekoe/modules/templates/:)
    let $params :=   <parameters>
                <param name='path-to-schema-col' value='{util:collection-name(string($schema-path))}' />
                <param name='template-file' value='{$template}' />
                <param name='template-meta-path' value='{$template-bundle}' />
                <param name='tenant' value='{$tenant}' />
            </parameters>
    let $links-query := transform:transform($links, xs:anyURI($gen-path), $params)

    let $serialized := util:serialize($links-query, "method=xml")
    let $serialized2 := if (empty($serialized)) then current-dateTime() else $serialized
    let $stored := xmldb:store($template-bundle, "merge.xql", $serialized2, "application/xquery")
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

(:    let $debug := util:log("debug", "TEMPLATE IS " || $template || " AND BUNDLE IS " || $template-bundle || " DOCNAME " || $doc-name):)
(:    let $template-file := util:document-name($template)
    let $name := substring-before($template-file,".")
    let $template-path := util:collection-name($template)
    let $sub-path := substring-after($template-path, "templates")  :)  
    return $template-bundle
(:    map {
        "bundle" := $template-bundle,
(\:        "merge" := $template-bundle || "/merge.xql",
        "links" := $template-bundle || "/links.xml",
        "content" := $template-bundle || "/content.xml",:\)
        "type" := substring-after($template,'.')
    }:)
(:    <parts>
        <merge><path>/db/pekoe/config/template-meta{$sub-path}</path>/<name>{$name}.xql</name></merge>
        <links><path>/db/pekoe/config/template-meta{$sub-path}</path>/<name>{$name}.xml</name></links>
        <content><path>/db/pekoe/config/template-content{$sub-path}</path>/<name>{$name}</name>.xml</content>  
        <type>{substring-after($template-file, ".")}</type>
    </parts>:)
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

(: Called by controller.xql when processing a /merge path.
/merge/path/to/template?job=/path/to/job
$template-query = merge:get-links-query(/path/to/template)
<forward url=/rest{$template-query} > this is where the merge happens

This function makes sure there's an up-to-date merge-xql file available and returns its path.
The merge file will perform the actual merge.
:)

declare function merge:get-links-query($template,$tenant) { (: e.g. given /db/pekoe/templates/Education/Tax-Invoice.docx, return  :)

    let $template-bundle := merge:template-parts($template)
    let $schema-doctype := doc($template-bundle || '/links.xml')/links/string(@for)
    let $schema-path := merge:check-schema($schema-doctype,$tenant)
    let $merge-path := merge:check-merge-query($template, $tenant, $template-bundle,$schema-path)
    return 
        substring-after($merge-path,"/db/pekoe")
};



