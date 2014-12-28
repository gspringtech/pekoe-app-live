xquery version "3.0";
(: 
    Module: ge.
   Produce a list of all Templates, showing including metadata for the associated schema-type and template-type.
   The List will be used in the BAG.
   
   Get ph-links for a template.
   Produce a list of all paths for a schema.? (for use as links in a template)
   
   Templates are stored as the original document.
   A trigger is fired on modification to that directory, 
   A "bundle" will be created for each Template in /templates-meta
   The bundle will contain
   - template-content file
   - links.xml
   - merge.xql
   
:)
module namespace templates="http://www.gspring.com.au/pekoe/admin-interface/templates";
import module namespace tm="http://pekoe.io/templates/management" at "templates/template-trigger.xqm";

declare copy-namespaces preserve, inherit; 

declare variable $templates:fileExtensions := "txt ods odt docx xml";
declare variable $templates:common-path :=    "/db/pekoe/common/templates";

declare function templates:check-all-permissions($fp) {
    true()
};


(: NOTE: The new form of Template management creates a "bundle" for a template in the /templates-meta collection
The bundle will contain a /links.xml document.
    
:)

declare function templates:display-templates-list($collection as xs:string) as element()* {
    let $xColl := collection($collection)
    
    for $childString in xmldb:get-child-resources($collection)
    let $fp := concat($collection,'/',$childString)
    let $extension := substring-after($childString,'.')
    let $title := substring-before($childString,'.')
    
    let $meta-doc-path := tm:full-meta-path($fp)
    let $doctype := doc($meta-doc-path || "/links.xml")/links/string(@for)
    let $log := util:log("warn","GETTING TEMPLATE INFO FOR file " || $fp || " IN COLLECTION " || $collection || " META-PATH " || $meta-doc-path || " for " || $doctype)
    
    order by $childString
    return 
        <li class='item' type='item' fileType="{$extension} {$doctype}" title="{$fp}">{$title}</li>
};


declare function templates:display-collections-list($collection as xs:string) as element()* {
    for $child in xmldb:get-child-collections($collection)
    let $path := concat($collection, '/', $child)
    order by $child
    return
        <li class='sublist' type='sublist' path='{$path}'><span class='folder'>{$child}</span>{
        let $sublist := templates:get-simple-listing($path)
        return if ($sublist) then <ul>{$sublist}</ul> else ()
        }</li>
};

declare function templates:get-simple-listing($colName as xs:string) as element()* {
    (templates:display-collections-list($colName), templates:display-templates-list($colName))
};

declare function templates:get-meta-file-name($file) {
   concat($file,"/ph-links.xml")
};

(:
    Consider the alternative.
    Upload a Template (docx, odt, ods, txt, html)
    ask for the links.
    Not sure about ods. BUT the rest have "pekoe:/school-booking/day?meeting-at" or similar. 
    This is "field-path" || "output-script"
    There are set modules which can extract these things.
    
    The desired end-result is 
    1) a list of all templates - and their doctypes (e.g. school-booking) - must be extracted
    2) a list of the Links in a single template - must be extracted
    3) when needed, a generated XQL which uses the links to extract data from a file and merge it using a stylesheet.
    
    Now the first case is something which will be slow to generate, and only changes when a template is added/removed. 
    (need a trigger for that)
    Otherwise, it can, and should, be cached on the browser. (indexedDB)
    IT IS ONLY USED FOR THE BAG.
    
    
    The second case is again something that doesn't change unless the template changes.
    It should also be cached in the browser. It is easy and relatively quick to generate this list of Links.
    (The slowest part is the unzip/extract)
    
    But also consider: unzip/extract MUST be performed every time. (except for HTML and TXT)
    
    THE TEMPLATE IS DEFINITIVE. IT IS THE CANONICAL FORM OF THE TEMPLATE.
    
    A TRIGGER could take care of all this.
    
    on add/remove/modify whatever
    create a new /tenant/x/templates-meta/path/to/template.xql
    
    this query will contain
    
    get-links()
    
    merge()
    
    
    
    
    
    

:)

declare function templates:get-phlinks($template, $tenant-path) {
    let $log:= util:log("warn","GET-PH-LINKS FOR " || $template)
    let $meta-path := tm:full-meta-path($template) || "/links.xml"
    let $links := doc($meta-path)
    let $doctype := $links/links/data(@for)
    let $site-commands := doc($tenant-path || "/config/site-commands.xml")//commands[@for eq $doctype]
(:    let $template-commands := $links/commands -- Just an idea.
:)
    
    return 
        <template name='{$template}' >
            <commands>
                {$site-commands/*}
            </commands>
            {$links}
        </template>
};
