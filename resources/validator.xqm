module namespace v="http://gspring.com.au/pekoe/validator";
declare variable $v:schematron-compiler := xs:anyURI("xmldb:exist:///db/apps/pekoe/pekoe-support/iso-schematron-xslt2/iso_svrl_for_xslt2.xsl");


declare function v:validate($doc as node(), $schematron as xs:anyURI ) {
    (: Need to compile and store this ...  :)
    let $validator := local:get-compiled-validator($schematron)
(:            transform:transform(
                doc($schematron), 
                $v:schematron-compiler
                ,()
                ):)
    return transform:transform(
        $doc,
        $validator,()
        )
};

(: Probably also want to change the result format - or post process the results.
    May also want to emulate the built-in validator commands which 
    validate returning a boolean OR
    report - returning xml
 :)
 
 declare function local:get-compiled-validator($schematron-path as xs:anyURI) {
    let $s-path := xs:string($schematron-path)
    let $xsl-path := concat(substring-before($s-path,"."),".xsl")
    return
        if (exists(doc($xsl-path)) and 
            xmldb:last-modified(util:collection-name($xsl-path), util:document-name($xsl-path)) gt xmldb:last-modified(util:collection-name($s-path),util:document-name($s-path))) then doc($xsl-path) (: need to check mod time :)
        else local:compile-schematron($s-path,$xsl-path)
 };
 
 declare function local:compile-schematron($schematron-path, $xsl-path) {
    let $compiled := transform:transform(
                    doc($schematron-path), 
                    $v:schematron-compiler
                    ,()
                )
    let $stored := xmldb:store(util:collection-name($schematron-path), $xsl-path, $compiled)
    return doc($stored)
 };