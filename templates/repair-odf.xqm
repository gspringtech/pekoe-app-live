xquery version "3.1";

module namespace odf-repair = "http://pekoe.io/odf-repair";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
(:declare option exist:serialize "method=xhtml media-type=application/xhtml+html";:)

declare function odf-repair:repair-odf($uri) {
    if (empty($uri)) then "No File at " || $uri 
    else
    let $log := util:log("warn","REPAIR ODF " || $uri)
    let $col := util:collection-name($uri)
    let $fn := util:document-name($uri)
    let $content := zip:xml-entry($uri, "content.xml")
    let $binary-form := util:string-to-binary(serialize($content, <output:serialization-parameters><output:method value='xml'/><output:indent value='no'/></output:serialization-parameters>))
    let $updated := odf-tools:replace-content(xs:anyURI('xmldb:exist://' || $uri), $binary-form )
    let $stored := xmldb:store($col, $fn, $updated)
    (:
      This $d contains valid content, but the package is corrupt. Try extracting and then replacing the content.xml
      first, extract the content
    :)
    
    return $uri
    
};