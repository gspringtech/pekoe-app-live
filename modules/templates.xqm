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

TODO - rewrite this as JSON. Rewrite the bureau-a-gradin to use JSON.
    
:)

declare function templates:display-templates-list($collection as xs:string, $defaults) as element()* {
    let $xColl := collection($collection)
    let $safe-col := substring-after($collection,'templates/') (: add the templates/ in below as its used when searching the list to reveal the default template. :)
    for $childString in xmldb:get-child-resources($collection)
    let $fp := concat($collection,'/',$childString)
(:    let $log := util:log('info',$fp):)
    let $extension := substring-after($childString,'.')
    let $doc := if ($extension eq 'xml') then doc($fp) else ()
    let $correct-type := if ($doc) then $doc/*/name(.) else $extension
(:  It might look like a hack - but there are only a handful of template-types, so why not?...  :)
    let $mail-to := if ($correct-type eq 'mail') then translate($doc/mail/to, '{}','') else ()
    let $mail-to-path := if ($mail-to) then $doc//link[id eq $mail-to]/string(path) else ()
    let $title := substring-before($childString,'.')
    
    let $meta-doc-path := tm:full-meta-path($fp)
    let $full-path := $meta-doc-path || "/links.xml"
    order by $childString
    return if (not(doc-available(xs:anyURI($full-path))) or not(sm:has-access(xs:anyURI($full-path), 'r'))) then (util:log('warn','####### TEMPLATE-meta links NOT AVAILABLE for ' || $fp))
      else
      let $doctype := doc($meta-doc-path || "/links.xml")/links/string(@for)
(:      let $log := util:log('info',$defaults($doctype)):)
      let $is-default := $fp eq $defaults($doctype) (: There is no guarantee that the default file exists. Remember - look in the /templates/ not /templates-meta/ :)
        (: TODO - filter out irrelevent right here. OR force this to be cached.     :)
      return 
          <li class='item' data-doctype="" data-file-type="t-{$correct-type} {$doctype}" data-path="{$fp}" title='/templates/{$safe-col}/{$childString}'>
          {if ($is-default) then attribute data-default-for {$doctype} else ()}
          {if ($mail-to)    then attribute data-mail-to {$mail-to} else ()}
          {if ($mail-to)    then attribute data-mail-to-path {$mail-to-path} else ()}
          {$title}
          </li>
};


declare function templates:display-collections-list($collection as xs:string, $defaults) as element()* {
    for $child in xmldb:get-child-collections($collection)
    let $path := concat($collection, '/', $child)
    let $safe-col := substring-after($path,'templates/')
    order by $child
    return
        <li class='sublist' path='/templates/{$safe-col}'><span class='folder'>{$child}</span>{
        let $sublist := templates:get-simple-listing($path,$defaults)
        return if ($sublist) then <ul>{$sublist}</ul> else ()
        }</li>
};

declare function templates:get-simple-listing($colName as xs:string, $defaults) as element()* {
    (templates:display-collections-list($colName,$defaults), templates:display-templates-list($colName,$defaults))
};



(:
   
    The desired end-result is 
    1) a list of all templates - and their doctypes (e.g. school-booking) - must be extracted
    2) a list of the Links in a single template - must be extracted
    3) when needed, a generated XQL which uses the links to extract data from a file and merge it using a stylesheet.
    
    The LINKS document is definitive. NOT THE TEMPLATE. 
    
    
    When getting the links for a template, we include the APPLICABLE Commands.
    
    To determine the applicable Commands:
    Get the template doctype (from links)
    Get the template type From Links (docx, odt, textx, mailx) 
   
    e.g. 
    links for="ad-booking" template-type="textx" template-updated="2015-05-11T17:50:08.402+09:30" tenant="bkfa"
    
let $links := collection('/db/pekoe/tenants')/links[@template-type eq 'xtext']
for $link in $links
return update value $link/@template-type with 'textx'
    
    Filter by these things. Somehow.
    
    I already know 
    links/@for - doctype (ad-booking, lease etc)
    links/@template-type - mailx or odt etc
    links/@tenant
    and the template name.
    
    Now I want commands that are filtered by doctype, template-type, template name. 
    Which means I need to construct the commands differently, AND ask the question differently.
    
    Instead of 
    <commands for="member">
        <command name="Download" action="download" description="Download to edit. For print or custom email." template-type="docx,odt">
    let $site-commands := doc($tenant-path || "/config/site-commands.xml")//commands[contains(@for,$doctype)]
    a first naive update:
    let $site-commands := doc($tenant-path || "/config/site-commands.xml")//commands[contains(@for,$doctype) and contains(@template-type, $template-type)]
    but the problem with this is that it doesn't filter for commands for='' -> ALL doctypes or command/@template-type = ''
    
    How do I construct a map out of this? because maps have nice overriding mechanisms.
    and then how do I get the data OUT of the map?
    
    First, the NAME should be unique - meaning there can only be one command of that name. 
    The most specific command is the winner
    
    /db/pekoe/common/config/site-commands.xml
    <commands for='*'>
      <command name='Save'>...
      
   /db/pekoe/tenants/bkfa/site-commands.xml
   AND possibly          /other-commands.xml collection('/db/pekoe/tenants/bkfa/config')//commands
    <commands for='member'>
        <command name='Mail to' template-type='mail'>
        <command name='Mail to client' template-type='docx'>
            Merge the docx and attach it to a mail message to the Client.
            This is different to the template-type=mail which contains the from and to within it.
    
    <commands for='inventory'>
        <command name='Save' template-type='*'>
            Always validate the form before saving by checking that the stock level is not zero (or something like that)
            Do this in Javascript for this doctype only. Regardless of the template type.
    <command name='Save'
    <command name='Mail to'
    
    AND FINALLY - I _DO_ WANT TO OVERRIDE FOR A TEMPLATE.
    For example, 'Booking Confirmation' - this requires a generated 'Confirmation Letter' to be attached.
    How can I check this before sending an email?
    
    Even with Schematron Validation, I still need to indicate this special requirement - so a command is the best place.
    
    ??? WHAT 
    
    I would like to override Save. Close can remain a Default.
    
    let $config-commands := if (doc-available(doc('/db/pekoe/common/config/site-commands.xml'))) then ...
    But this is NOT a MAP. And the advantage of XML is that I can write a Schema and Edit it (somehow - eventually)
    
    If I create a map out of this, how will I serialise it? JSON?
    commands[@for = ('*', $doctype)]/command[@template-type = ('*', 'docx')]
    
    
    xquery version "3.1";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

let $commands := collection('/db')/site-commands
let $map := map:new(

    for $command in $commands/commands[@for = ('*','ad-booking')]/command[  matches(@template-type,'\*|docx')]
    return map {$command/@name: $command/string()}
    
)
return
    serialize($map, 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
        
        
    
:)
(:
declare function templates:map-commands($site-commands, $doctype, $template-type) {
    let $match-for  := '\*|' || $doctype
    let $match-type := '\*|' || $template-type
    return map:new(
        for $command in $site-commands/commands[matches(@for, $match-for)]/command[matches(@template-type,$match-type)]
        return map {$command/@name: $command/string()}
    )
};

declare function templates:get-commands() {

    let $common-commands := doc('/db/pekoe/common/common-commands.xml')/site-commands
    let $tenant-commands := collection('/db/pekoe/tenants/bkfa/config')/site-commands
    
    let $doctype := 'transport'
    let $template-type := 'docx'
    
    let $common-map := 
        templates:map-commands($common-commands, $doctype, $template-type)
    let $map := map:new(($common-map,templates:map-commands($tenant-commands,  $doctype, $template-type)))
        
    (\: The bloody order is wrong. :\)
    
    return
        serialize($map, 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>)
};:)
        

declare function templates:get-phlinks($template, $tenant-path) {
    let $meta-path := tm:full-meta-path($template) || "/links.xml"
    
    let $links := doc($meta-path)
    let $doctype := $links/links/data(@for)
    let $template-type := $links/links/@template-type/string()
    
    let $defaults := templates:get-defaults($tenant-path,$doctype)
    
    let $match-for  := '\*|\s?' || $doctype || '\s?'
    let $match-type := '\*|\s?' || $template-type || '\s?'
    
    let $common-commands := doc('/db/pekoe/common/common-commands.xml')//commands[matches(@for,$match-for)]/command[matches(@template-type,$match-type)]
    let $common-map := map:new(for $c in $common-commands return map:entry( $c/@name/string() , $c ) ) 
    let $tenant-commands := collection($tenant-path || "/config")//commands[matches(@for,$match-for)]/command[matches(@template-type,$match-type)]
    let $tenant-map := map:new(($common-map, for $c in $tenant-commands return map{$c/@name/string() : $c } )) (: use the map to override any common commands :) 
   
(:   how annoying. If there's a command in the template-links doc, it will be included into the result - but not override any other version. Instead, i'll have to
remove it from the links. Too hard to remove from a map with recursion :)
    let $template-map := if (exists($links//command)) then map:remove($tenant-map, $links//command/@name/string() ) else $tenant-map
    
    
    
(:  AAARGHHHH. I HAVE SPENT A FULL DAY TRYING TO DIAGNOSE AND WORK AROUND THE BUG IN PREDICATES.
    Still missing a specific filter for the template NAME.
    Alternatively, as previously considered, why not put the SPECIFIC command into the LINKS document?
    
    Regarding the ORDER of Commands
    The best approach I can think of at the moment is to have a 'command-order' element in site-commands.
    alternative is to use the position of the key in $commands
:)

(:    let $template-commands := $links/commands -- Just an idea.
    Default fields.
    Get the default fields from document "default.xxx"
    Maybe also get any 'default' fields from the current path?
    These will need to be marked as 'default' so the Form can mark them as such.
:)
    
    return 
        <template name='{$template}' for='{$doctype}'>
            <commands>{for $k in map:keys($template-map) return $template-map($k)}</commands>
            {if (not(empty($defaults))) then <default-links>{$defaults/link}</default-links> else () }
            {$links}
        </template>
};

(:This doesn't work. It doesn't alllow for different doctypes. :)

declare function templates:get-defaults($tenant-path,$doctype) {
    let $default-doc-path := $tenant-path || '/templates-meta'
(:    For TESTING, use an XML document here. :)
    return collection($default-doc-path)/default-links[@for eq $doctype]
 
};
