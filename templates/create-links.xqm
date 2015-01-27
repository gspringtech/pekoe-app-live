xquery version "3.0";
module namespace links = 'http://pekoe.io/merge/links';

declare function links:make-link($path) {
if (not(matches($path,'^http://[^/]*/'))) then (util:log('debug','LINK DOES NOT START WITH HTTP ' || $path)) 
else 
    let $tenant-link := replace($path, '^http://[^/]*/','')
    let $tenant := substring-before($tenant-link,'/') (: 'bgaedu' or 'common':)
    let $full-link := substring-after($tenant-link,$tenant) (: /member/membership?output=history#/receipt-number :)
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
        if (normalize-space($path) ne '') 
        then <link>
            {attribute tenant {$tenant}}
            {attribute path {$field-path}}
            {attribute original-href {$path}}
            {if (empty($fragment)) then () else attribute fragment {$fragment}}
            {if (empty($query)) then () else attribute query {$query}}
            </link> 
        else (util:log('debug','COULD NOT CONSTRUCT LINK FROM ' || $tenant-link))
};
