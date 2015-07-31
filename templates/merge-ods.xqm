xquery version "3.0";
module namespace ods = "http://www.gspring.com.au/pekoe/merge/ods";

declare namespace xlink="http://www.w3.org/1999/xlink";

declare namespace office="urn:oasis:names:tc:opendocument:xmlns:office:1.0";
declare namespace table="urn:oasis:names:tc:opendocument:xmlns:table:1.0";
declare namespace util = "http://exist-db.org/xquery/util";
declare variable $ods:code-point-A := 64; 
import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';

declare variable $ods:merge-stylesheet := doc('merge-ods.xsl');

(: 
    Public functions
    ods:merge($template, $transaction, $content) ??
    ods:extract-content($uri, $collection)
    ods:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI)
:)

declare function ods:extract-content($uri, $col) {
    ods:store-modified-content($uri,$col),
    ods:update-links($col)
};

(: NEW approach - use the generic link-maker.
    The important feature of the link-maker is that it won't overwrite an existing link definition.
:)
declare function ods:update-links($col) {
    let $range-placeholders := ods:extract-placeholder-names(doc($col || '/content.xml'))
(:  I feel like this is where the whole hyperlink vs placeholder argument has come back to bite me.
    
    The problem is that the whole supply chain must be modified to handle placeholders.
    Currently they are an unnecessary remnant from pekoe 2. Not even sure why I add them to the links.
    
:)
    let $updated-links := links:update-links-doc($col, $range-placeholders, 'ods')
    return xmldb:store($col,"links.xml",$updated-links)
};

declare function ods:make-link() {
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
};

declare function ods:store-modified-content($uri,$col){
    let $content := zip:xml-entry($uri, "content.xml")
(:  I think I will have to do this...   :)
(:    let $transformed := transform:transform($content,$odt:repair-odt-stylesheet, ()):)
    let $transformed := $content
    return xmldb:store($col, "content.xml", $transformed)
};

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
  
    return replace($ph-cell/string(.), '^[\W]+|[\W]+$', '')
      (:<link>{attribute ph-name {replace($ph-cell/string(.), '^[\W]+|[\W]+$', '')}}</link>:) (: trim element whitespace :)
      (:{$start-cell/following-sibling::table:table-cell[1]/string(.)}</ph>:)
};


(: THIS FUNCTION GETS THE XPATHs which are needed to find the cells to replace. :)
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
(:  I could update the cell right here - put in a REPLACE ME Hyperlink. But first I need to know what's there.  :)
(:  Must handle the office:value-type. one of 

    string      (nothing except the p text)
    float       office:value
    percentage  office:value
    currency    office:value
    date        office:date-value='2009-01-31' and p text is the locale formatted version 31/01/09
    time        office:value
    boolean     office:boolean-value='false' and text FALSE
    
:)
    
(:    let $path-to-data-cell := string-join(("",ods:make-path($value-cell/ancestor-or-self::*)), "/"):)
(:  this cell will now contain the hyperlink - either as text or an actual hyperlink. Will need to check  :)
(:    let $name := replace($ph-cell/string(.), '^[\W]+|[\W]+$', '') (\: trim element whitespace :\):)
    let $name := if ($ph-cell//xlink:a) then $ph-cell//xlink:a/string(@href)
        else $ph-cell/string()
(:    let $hyperlink := util:log('info', 'CELL ' || $name || ' path: ' ||  $path-to-data-cell || ' and contents: '):)
(:    let $log := util:log('info',$value-cell):)
    let $update := switch ($value-cell/@office:value-type)
        case ('string') return update replace $value-cell with <pekoe-string name='{$name}' /> 
        case ('date') return update replace $value-cell with <pekoe-date name='{$name}' />
        default return update replace $value-cell with <pekoe-value name='{$name}' type='{$value-cell/@office:value-type/string()}'/>
(:    

Number:
<table-cell office:value-type="float" office:value="64">
    <p xmlns="urn:oasis:names:tc:opendocument:xmlns:text:1.0">64</p>
</table-cell>
Date:
<table-cell office:value-type="date" office:date-value="2012-04-27">
    <p xmlns="urn:oasis:names:tc:opendocument:xmlns:text:1.0">27/04/12</p>
</table-cell> 
Text:
<table-cell office:value-type="string">
    <p xmlns="urn:oasis:names:tc:opendocument:xmlns:text:1.0">23 Gray Street Jamestown</p>
</table-cell> 


:)
    return 
      $name

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

(: This is the original entry point for extracting the names :)
declare function ods:extract-placeholder-names($doc) {

    let $placeholders-range := $doc//table:named-range[@table:name eq "placeholders"]/@table:cell-range-address/data(.)
    (:return $placeholders-range:)
    let $spreadsheet := $doc/. 
    
    return if(empty($placeholders-range)) then () else (ods:process-range2($placeholders-range, $spreadsheet),ods:process-range($placeholders-range, $spreadsheet))
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

declare function ods:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI) {
    let $template-content := $template-bundle-path || "/content.xml"
    let $merged := transform:transform($intermediate, $ods:merge-stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param>
        </parameters>) 
    let $binary-form := util:string-to-binary(util:serialize($merged, "method=xml"))
    let $path-in-zip := 'content.xml' (: Which file in the odt are we replacing. :)
    return if ($merged instance of element(error)) then $merged else zip:update($template-file-uri, $path-in-zip, $binary-form)
};
