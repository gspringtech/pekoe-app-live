xquery version "3.0" encoding "UTF-8";
(: Copyright 2012 Geordie Springfield Pty Ltd Australia :)

module namespace merge-txt="http://www.gspring.com.au/pekoe/merge/txt";
import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';

declare option exist:serialize "method=text media-type=text/plain";
(:
    This is not much use as it stands. Firstly, the INPUT approach hasn't been established and then the OUTPUT needs to match that.
    What am I trying to say?
    - There's no TEXT Template format  
    - There's no standard approach for handling individual field values in a fragment.
    
    For example, it's highly likely that you'll write "name: value" in a text template for a schema
    with /properties/property(@name, value) (and property is obviously a fragment)
    and expect to get "locations: Coorong, Daintree, ..." as the output from a fragment-script.
    
    This probably works.
    
:)

(: --------------- Extract Content and links from TXO ------------------------ :)
(: Links should be in the same format as in the other templates - a full URI :)

declare function merge-txt:extract-content($uri,$col) {
    xmldb:store($col, "content.xml",<content>{util:binary-to-string(util:binary-doc(xs:string($uri)))}</content>),
    
    let $links := merge-txt:get-hyperlinks($col)
    let $schema-for := $links[1]/tokenize(@path,'/')[2] (: want school-booking from /school-booking/path/to/field :)
    let $log := util:log("warn", "CREATED SOMTIHNG in " || $col || " for " || $schema-for)
    return xmldb:store($col,"links.xml",<links template-type='txt'>{attribute for {$schema-for}}{$links}</links>)
};


declare function merge-txt:get-hyperlinks($col) {
    let $content := doc($col || "/content.xml")/content/text()
    for $x in tokenize($content, "\n")
    return links:make-link($x)
};

declare function merge-txt:transform($data) {
    for $f in $data
    return $f
};

declare function merge-txt:merge($intermediate, $template-file,$job-id) {
    let $new-fn := concat("text-",$job-id,".txt")
    let $merged := merge-txt:transform($intermediate)
    let $header :=  response:set-header('Content-disposition', concat('attachment; filename=',$new-fn))
    return response:stream-binary(util:string-to-binary($merged),"text/plain")
};