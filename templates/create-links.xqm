xquery version "3.0";
module namespace links = 'http://pekoe.io/merge/links';
(:
Placeholders V4: the Hyperlink is 
http://pekoe.io/tenant/doctype/placeholder-and-output-hint
e.g. 
http://pekoe.io/cm/lease/settlement-date
http://pekoe.io/cm/lease/client-full-name
http://pekoe.io/cm/residential/last-receipt-date?aust-short-date

A link is now this:
<link tenant='' doctype='' placeholder='' field-path='' fragment='' originl-href=''>
    <output query='' />
</link>
The only thing of significance is the original-href which will be used to find and replace the hyperlink in the template during merge.
The hyperlink only serves as a HINT. The DBA will assign the actual field path, output function(s) and fragment identifier when editing the Links document.

However, those examples could be used like this:


<link tenant='cm' doctype='lease' placeholder='settlement-date' path='' 
    fragment='' original-href='http://pekoe.io/cm/lease/settlement-date' />
    
I don't know if having <output> elements will work. The merge.xql replacs the content of the link with a 


:)
(: $existing-links-doc is the links.xml for this template if it exists. What if it doesn't yet exist? I guess it must be an empty <links/> element 
    $all-placeholders-from-template is a sequence of hrefs plucked from the pekoe-hyperlinks in the template. 
:)

declare function links:update-links-doc($col, $all-placeholders-from-template, $template-type) {
    let $existing-links-doc := doc($col || '/links.xml')/links
    let $existing-links := if ( exists($existing-links-doc) ) then $existing-links-doc else  <links />
    let $tenant-and-doctype := links:get-tenant-from-path($all-placeholders-from-template[1])
    let $for := if ($existing-links-doc/@for/string() ne '') then $existing-links-doc/@for/string() else $tenant-and-doctype?doctype
    return 
    <links for='{$for}' 
        template-type='{$template-type}' 
        template-updated='{current-dateTime()}' 
        tenant="{$tenant-and-doctype?tenant}">
        {  (: New links come first :)
            for $ph in $all-placeholders-from-template
            return if (exists($existing-links-doc/link[@original-href eq $ph])) then () 
            else links:make-link($ph)
        }
        {  (: Existing links - unless it has been removed :)
            $existing-links-doc/link[@original-href = $all-placeholders-from-template]
        }
        {$existing-links-doc/command}
    </links>
};

declare function links:get-tenant-from-path($path) {
    (: Placeholders are supposed to start with pekoe.io/tenant   :)
    let $tenant-link-raw := replace($path, '^http://pekoe.io/','') (:  $tenant-link = cm/residential/settlement-date?output=current-date :)
    let $tenant-link := xmldb:decode($tenant-link-raw)
    let $parts := tokenize($tenant-link,'/')
    return map {"tenant": $parts[1], "doctype": $parts[2] } (: 'bgaedu' or 'common' or 'cm :)
};


declare function links:make-link($path) {  (:$path = http://pekoe.io/cm/residential/settlement-date?output=current-date :)
    if (not(matches($path,'^http://[^/]*/'))) then (util:log('WARN','LINK DOES NOT START WITH HTTP ' || $path))  
    else 
        let $tenant-link-raw := replace($path, '^http://[^/]*/','') (:  $tenant-link = cm/residential/settlement-date?output=current-date :)
        let $tenant-link := xmldb:decode($tenant-link-raw)
        let $tenant := substring-before($tenant-link,'/') (: 'bgaedu' or 'common' or 'cm :)
        
        let $full-link := substring-after($tenant-link,$tenant) (: /member/membership?output=history#/receipt-number or /residential/settlement-date?output=current-date :)
        
(:   If the hyperlink contains a full field specifier, parse it and create a LINK with output-name and/or output-fragment     :)
        let $parts := tokenize($full-link,'#') (: Separate any fragment part :)
        let $fragment := $parts[2]
        let $remainder := tokenize($parts[1],"\?") (: Any query - containing an output= :)
        let $query := $remainder[2]
        let $field-path := $remainder[1]
        let $link := 
     
        element link {
            attribute original-href {$path},
            attribute placeholder {$tenant-link},
            (: This is really a 'HINT' as to what the field should be. :)
            attribute field-path {$field-path},
            if ($query ne '' or $fragment ne '') then (
            element output {
                attribute name {substring-after($query, "output=")},
                attribute fragment {$fragment}
            }
            ) else (),
            <output-or-xquery/>
            }
        return $link
};

declare function links:old-make-link($path) {  (:$path = http://pekoe.io/cm/residential/settlement-date?output=current-date :)
    if (not(matches($path,'^http://[^/]*/'))) then (util:log('WARN','LINK DOES NOT START WITH HTTP ' || $path))  
    else 
        let $tenant-link := replace($path, '^http://[^/]*/','') (:  $tenant-link = cm/residential/settlement-date?output=current-date :)
        let $tenant := substring-before($tenant-link,'/') (: 'bgaedu' or 'common' or 'cm :)
        let $full-link := substring-after($tenant-link,$tenant) (: /member/membership?output=history#/receipt-number or /residential/settlement-date?output=current-date :)
        let $parts := tokenize($full-link,'#')
        let $fragment := $parts[2]
        let $remainder := tokenize($parts[1],"\?")
        let $query := $remainder[2]
        let $field-path := $remainder[1]
    (:    
    let $link := if (contains($full-link,'#')) then substring-before($full-link, '#') else $full-link
    let $field-path := if (contains($link,'?')) then substring-before($link,"?") else $link
    let $fragment := if (contains($full-link,'#')) then substring-after($full-link,'#') else ()
    :)
    return 
        if ($tenant ne '' and $full-link ne '') 
        then <link>
            {attribute tenant {$tenant}}
            {attribute path {$field-path}}
            {attribute original-href {$path}}
            {if (empty($fragment)) then () else attribute fragment {$fragment}}
            {if (empty($query)) then () else attribute query {$query}}
            </link> 
        else (util:log('debug','COULD NOT CONSTRUCT LINK FROM ' || $tenant-link))
};
