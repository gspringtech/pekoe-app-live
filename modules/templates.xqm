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
import module namespace tm="http://pekoe.io/templates/management" at "../templates/template-trigger.xqm";

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
   
    The desired end-result is 
    1) a list of all templates - and their doctypes (e.g. school-booking) - must be extracted
    2) a list of the Links in a single template - must be extracted
    3) when needed, a generated XQL which uses the links to extract data from a file and merge it using a stylesheet.
    
    THE TEMPLATE IS DEFINITIVE. IT IS THE CANONICAL FORM OF THE TEMPLATE. 
    This is why templates-meta contains generated content and should not be edited.
    
    The trigger will...
    on add/remove/modify whatever
    create a new /tenant/x/templates-meta/path/to/template_bundle
    
:)

declare function templates:get-phlinks($template, $tenant-path) {
    let $meta-path := tm:full-meta-path($template) || "/links.xml"
    let $defaults := templates:get-defaults($template, $tenant-path)
    let $links := doc($meta-path)
    let $doctype := $links/links/data(@for)
    let $site-commands := doc($tenant-path || "/config/site-commands.xml")//commands[@for eq $doctype]
(:    let $template-commands := $links/commands -- Just an idea.
    Default fields.
    Get the default fields from document "default.xxx"
    Maybe also get any 'default' fields from the current path?
    These will need to be marked as 'default' so the Form can mark them as such.
:)
    
    return 
        <template name='{$template}' >
            <commands>
                {$site-commands/*}
            </commands>
            {if (not(empty($defaults))) then <default-links >{attribute for {$defaults/links/string(@for)}}{$defaults//link}</default-links> else () }
            {$links}
        </template>
};

(:This doesn't work. It doesn't alllow for different doctypes. :)

declare function templates:get-defaults($template, $tenant-path) {
    let $default-doc-path := $tenant-path || '/templates-meta/default.xml'
(:    For TESTING, use an XML document here. :)
    return if (doc-available($default-doc-path)) then doc($default-doc-path)
    else ()
};
