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
(: 
    This function updates (or creates) the links document based on hyperlinks.
    It won't replace any existing links and will add new ones at the start (to make it easier to edit the links doc)
    See below for the placeholder version of this.
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
    (: hyperlinks are supposed to start with pekoe.io/tenant   :)
    let $tenant-link-raw := replace($path, '^http://pekoe.io/','') (:  $tenant-link = cm/residential/settlement-date?output=current-date :)
    let $tenant-link := xmldb:decode($tenant-link-raw)
    let $parts := tokenize($tenant-link,'/')
    return map {"tenant": $parts[1], "doctype": $parts[2] } (: 'bgaedu' or 'common' or 'cm :)
};


(: This version only handles one output. :)
declare function links:x-make-link($path) {  (:$path = http://pekoe.io/cm/residential/settlement-date?output=current-date :)
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

(:
    Examples: (all start with http://pekoe.io/tenant-id)
    "/residential/purchaser/person?output=address-after&amp;output=suburb-state-postcode",
    "/residential/purchaser/person?output=address-after#line1",
    "/residential/property/address#line1",
    "/residential/purchaser/person?output=address-after&amp;output=suburb-state-postcode#madeup",
    "/residential/purchaser/person?context=address&amp;output=suburb-state-postcode"

:)

declare function links:make-link($path) {  
    if (not(matches($path,'^http://[^/]*/'))) then (util:log('WARN','LINK DOES NOT START WITH HTTP ' || $path))
    else 
        let $tenant-link-raw := replace($path, '^http://[^/]*/','') (:  $tenant-link = cm/residential/settlement-date?output=current-date :)
        let $tenant-link := xmldb:decode($tenant-link-raw)
        let $tenant := substring-before($tenant-link,'/') (: 'bgaedu' or 'common' or 'cm :)
        
        let $full-link := substring-after($tenant-link,$tenant) (: /member/membership?output=history#receipt-number or /residential/settlement-date?output=current-date :)
        
        (: Tokenize has the advantage of always returning the string even if it doesn't match the delimiter :)
        let $parts := tokenize($full-link,'\?')  (: Split the path and query :)
        let $path-and-fragment := tokenize($parts[1],'#') (: The path might end with a fragment - not a query:)
        return element link {
            attribute original-href {$path},
            attribute placeholder {$tenant-link},
            attribute field-path {$path-and-fragment[1]},
            if ($path-and-fragment[2]) (: must be a fragment identifier at the end of the path. Convert to output/@fragment :)
            then element output {attribute name {}, attribute fragment {$path-and-fragment[2]}} 
            else (),
            
            if ($parts[2]) then  (: Must be a query string :)
                for $part in tokenize($parts[2],'&amp;')
                let $name-and-fragment := tokenize($part,'#')
                let $name-parts := tokenize($name-and-fragment[1],'=')  (: unfortunately need to test for 'context=' :)
                return element output {
                    if ($name-parts[1] eq "context") 
                    then (attribute name {}, attribute fragment {$name-parts[2]})
                    
                    else (attribute name {$name-parts[2]}, attribute fragment {$name-and-fragment[2]})
                }
            else ()
            ,element output-or-xquery {}
            
        }

};



(: ------------------------  PLACEHOLDER VERSION ----------------------- :)

declare function links:update-placeholders-doc($col, $all-placeholders-from-template, $template-type) {
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
            return if (exists($existing-links-doc/link[@placeholder eq $ph])) then () 
            else links:make-placeholder-link($ph)
        }
        {  (: Existing links - unless it has been removed :)
            $existing-links-doc/link[@placeholder = $all-placeholders-from-template]
        }
        {$existing-links-doc/command}
    </links>
};

(:declare function links:get-tenant-from-path($path) {
    (\: hyperlinks are supposed to start with pekoe.io/tenant   :\)
    let $tenant-link-raw := replace($path, '^http://pekoe.io/','') (\:  $tenant-link = cm/residential/settlement-date?output=current-date :\)
    let $tenant-link := xmldb:decode($tenant-link-raw)
    let $parts := tokenize($tenant-link,'/')
    return map {"tenant": $parts[1], "doctype": $parts[2] } (\: 'bgaedu' or 'common' or 'cm :\)
};
:)

declare function links:make-placeholder-link($path) {  (:$path = http://pekoe.io/cm/residential/settlement-date?output=current-date :)

    element link {
        attribute original-href {},
        attribute placeholder {$path},
        attribute field-path {},
        <output-or-xquery/>
    }
    
};

