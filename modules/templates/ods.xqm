xquery version "1.0";
module namespace ods = "http://www.gspring.com.au/pekoe/templates/ods";
declare namespace t = "urn:oasis:names:tc:opendocument:xmlns:text:1.0";
declare namespace office="urn:oasis:names:tc:opendocument:xmlns:office:1.0";
declare namespace table="urn:oasis:names:tc:opendocument:xmlns:table:1.0";
declare namespace util = "http://exist-db.org/xquery/util";
declare variable $ods:code-point-A := 64; 


declare variable $ods:schema := doc("/db/pekoe/config/schema.xml");

(:declare variable $ods:doc := doc("/db/pekoe/templates/Residential/Vendor-Statement.xml");:)

(:  A string representing a base-26 number will be converted to a sequence of integers . E.g. IZ to (12,26)  :)
declare function ods:letter-to-base26($letters) {
(: e.g. "BBD" :)
    let $codes := string-to-codepoints($letters) (: (66, 66, 68) :)
    return for $i in $codes return ($i - $ods:code-point-A) (: (2,2,4) :)
};

(:   A sequence of integers representing a base26 number will be converted to a decimal number.
     e.g. IZ -> (12, 26) -> 260
:)
declare function ods:base26-to-decimal ($seq) {
    ods:base26-to-decimal($seq,1)
};
declare function ods:base26-to-decimal ($seq, $pow) {
    if (empty($seq)) 
    then 0 
    else ($seq[last()] * $pow) + ods:base26-to-decimal($seq[position() ne last()], $pow *26)
};

(: 
    A spreadsheet is a sparse-array (???). The "holes" are indicated by the attribute "number-rows-repeated" 
    Find a row by its index number. Return empty if not found.
:)
declare function ods:find-start-row($current-row , $accumulated-index as xs:integer, $desired-row as xs:integer)  {
(:  table:table-row table:number-rows-repeated="16"
    So, the next table-row index will be the accumulated-index + ( 1 or number-rows-repeated) 
:)
     if ($accumulated-index eq $desired-row)
        then $current-row
        else 
            let $repeated := $current-row/@table:number-rows-repeated 
            let $new-index := $accumulated-index + (if (empty($repeated)) then 1 else $repeated cast as xs:integer)
            return 
                if ($new-index le $desired-row) then 
                (: I got caught by the following-sibling axis - it selects ALL following siblings - not the first. Should be called "following-siblings" :)
                    ods:find-start-row($current-row/following-sibling::table:table-row[1], $new-index, $desired-row)
                    else ()
};

declare function ods:find-start-cell($current-cell, $accumulated-cell-index, $desired-cell-index) {
    if ($accumulated-cell-index eq $desired-cell-index) 
        then $current-cell
        else 
            let $repeated := $current-cell/@table:number-columns-repeated 
            let $new-index := $accumulated-cell-index + (if (empty($repeated)) then 1 else $repeated cast as xs:integer)
            return 
                if ($new-index le $desired-cell-index) then 
                    ods:find-start-cell($current-cell/following-sibling::table:table-cell[1], $new-index, $desired-cell-index)
                    else ()
};

(:  What do I want to produce here? 

In the first instance, I want the names of the cells - these should be in the first column

clientName
printingdate
clientMyobNumber
amount
amountInWords
purpose
propertyAddress
paymentType
totalAmount

Then, when processing for merge, I'll want to iterate over the second column.
How will this be integrated into the "field-editor"??

:)

declare function ods:process-range($range,$spreadsheet) {

    let $range-parts := tokenize( replace($range, ":", ""), "\.")   (: "$Sheet1.$A$4:.$B$6" -> ("$Sheet1","$B$3","$B$51") :) 
    let $table-name := replace($range-parts[1],"'|\$" , "") (: "Sheet1"  Get rid of quotation marks and $ :)
    let $start-cell := tokenize($range-parts[2],"\$")  (: $B$3 -> (, B, 3)  :)
    let $end-cell := tokenize($range-parts[3],"\$")   (: "$B$51" -> (, B, 51) :) 
    let $row-start := xs:integer($start-cell[3])  (: 3 :) 
    let $row-end := xs:integer($end-cell[3])  (: 51 :)
    let $current-column := ods:base26-to-decimal(ods:letter-to-base26($start-cell[2]))
    
    (: Find the range start :)
    let $start-row := 
        let $current-row := $spreadsheet//table:table[@table:name eq $table-name]/table:table-row[1]
        let $accumulated-index := 1
        let $desired-row := $row-start
        return ods:find-start-row($current-row, $accumulated-index, $desired-row)
    
(:   Must assume that each row is significant. :)
    let $row-count := $row-end - $row-start
  for $row in  ($start-row, $start-row/following-sibling::table:table-row[position() = 1 to $row-count] ) 
    (: Must perform this every time because the sparse array is not regular   :)
    let $ph-cell := 
        let $current-cell := $row/table:table-cell[1]
        let $accumulated-cell-index := 1
        let $desired-cell-index := $current-column
        return ods:find-start-cell($current-cell, $accumulated-cell-index, $desired-cell-index)
     
    (:
    <table:table-row table:style-name="ro1" table:number-rows-repeated="3">
         <table:table-cell table:number-columns-repeated="2"/>
        </table:table-row>
        
        :)
  
    return 
      replace($ph-cell/string(.), '^[\W]+|[\W]+$', '') (: trim element whitespace :)
      (:{$start-cell/following-sibling::table:table-cell[1]/string(.)}</ph>:)
};

declare function ods:process-range2($range,$spreadsheet) {

    let $range-parts := tokenize( replace($range, ":", ""), "\.")   (: "$Sheet1.$A$4:.$B$6" -> ("$Sheet1","$B$3","$B$51") :) 
    let $table-name := replace($range-parts[1],"'|\$" , "") (: "Sheet1"  Get rid of quotation marks and $ :)
    let $start-cell := tokenize($range-parts[2],"\$")  (: $B$3 -> (, B, 3)  :)
    let $end-cell := tokenize($range-parts[3],"\$")   (: "$B$51" -> (, B, 51) :) 
    let $row-start := xs:integer($start-cell[3])  (: 3 :) 
    let $row-end := xs:integer($end-cell[3])  (: 51 :)
    let $current-column := ods:base26-to-decimal(ods:letter-to-base26($start-cell[2]))
    
    (: Find the range start :)
    let $start-row := 
        let $current-row := $spreadsheet//table:table[@table:name eq $table-name]/table:table-row[1]
        let $accumulated-index := 1
        let $desired-row := $row-start
        return ods:find-start-row($current-row, $accumulated-index, $desired-row)
    
(:   Must assume that each row is significant. :)
    let $row-count := $row-end - $row-start
  for $row in  ($start-row, $start-row/following-sibling::table:table-row[position() = 1 to $row-count] ) 
  
    (: Must perform this every time because the sparse array is not regular   :)
    let $ph-cell := 
        let $current-cell := $row/table:table-cell[1]
        let $accumulated-cell-index := 1
        let $desired-cell-index := $current-column
        return ods:find-start-cell($current-cell, $accumulated-cell-index, $desired-cell-index)
        
        
    let $value-cell := $ph-cell/following-sibling::table:table-cell[1] (: the next cell :)
    (:
    <table:table-row table:style-name="ro1" table:number-rows-repeated="3">
         <table:table-cell table:number-columns-repeated="2"/>
        </table:table-row>
        
        :)
    let $path-to-data-cell := string-join(("",ods:make-path($value-cell/ancestor-or-self::*)), "/")
(:    let $path-to-data-cell := name($ph-cell):)
    let $name := replace($ph-cell/string(.), '^[\W]+|[\W]+$', '') (: trim element whitespace :)
    
    return 
(:      <ph name="{$name}" path="{$path-to-data-cell}" />:)
    string-join(($name,$path-to-data-cell),"--") (: need an unlikely separator. This is unravelled by templates:get-phlist :)

};

(: This function :)
declare function ods:name-and-position($n as element()) as xs:string {
  concat( name($n), '[', 1 + count( $n/preceding-sibling::*[node-name(.) eq node-name($n)] ), ']')
};

declare function ods:name-and-position2($n as element()) as xs:string {
let $name := name($n)
let $pcs :=  $n/preceding-sibling::element()[name(.) = $n/name(.)]
let $count := 1
return  concat($name,'[', 1 + $count , ']')
};

declare function ods:make-path($vc) as item()* {
    for $n in $vc/ancestor-or-self::* 
    return $n/ods:name-and-position(.)
};


declare function ods:extract-placeholder-names($doc) {
(:ods:base26-to-decimal(ods:letter-to-base26("IZ")):)

    let $placeholders-range := $doc//table:named-range[@table:name eq "placeholders"]/@table:cell-range-address/data(.)
    (:return $placeholders-range:)
    let $spreadsheet := $doc/. 
    
    return if(empty($placeholders-range)) then () else ods:process-range($placeholders-range, $spreadsheet)
};

declare function ods:placeholders-list($template) {
(: Instead of creating a simple list of placeholder names, we want to construct a list of enhanced ph elements.
    We need the name and the path :)
    let $basedoc := substring-before($template, '.')
    let $contentDoc := concat("http://localhost:8080/exist/rest",$basedoc,".xml")

    let $doc := doc($contentDoc)
    let $placeholders-range := $doc//table:named-range[@table:name eq "placeholders"]/@table:cell-range-address/data(.)
    let $spreadsheet := $doc/. 
    
    return if(empty($placeholders-range)) then () else ods:process-range2($placeholders-range, $spreadsheet)
};

(:let $doc := doc("/db/pekoe/templates/Residential/complex-spreadsheet-placeholders.xml")
return ods:extract-placeholders($doc):)




(: Will return the merged template content for a spreadsheet. :)
declare function ods:merge($template, $transaction, $content) {
(: template is full path to binary doc. $transaction is the full path to the job, $content is the Job /txo DATA :)
    let $template-content-path := string-join((tokenize($template,"\.")[position() < last()],"xml"),".") 
    let $template-content := doc($template-content-path)
    return $template-content
    
};
