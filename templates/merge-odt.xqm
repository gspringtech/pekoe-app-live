xquery version "3.0" encoding "UTF-8";
(: Copyright 2014-2015 Geordie Springfield Pty Ltd, Australia
:)

module namespace odt="http://www.gspring.com.au/pekoe/merge/odt";
declare namespace t="urn:oasis:names:tc:opendocument:xmlns:text:1.0";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare copy-namespaces preserve, inherit;
import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';
declare option exist:serialize "omit-xml-declaration=yes"; (: TODO - fix this :)

declare variable $odt:repair-odt-stylesheet := 'repair-odt.xsl';



declare variable $odt:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> Jul 31, 2014</xd:p>
            <xd:p><xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml"  cdata-section-elements="" omit-xml-declaration="yes"/>
    <xsl:param name="template-content" />
    <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $template-content )" />
    <xsl:variable name="phlinks" select="/links"/> <!--  a reference to the root is needed because another document is imported. -->

    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test='doc-available($path-to-template-content)'>
                <xsl:apply-templates select=" doc( $path-to-template-content )/* "/> 
            </xsl:when>
            <xsl:otherwise>
                <error>Permission Denied</error>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

<!-- 
    The output function should handle results containing more than one value - for example, using a string-join($v,', ')
    If there are multiple elements in the link, it's expected that the hyperlink will be within a table-row/table-cell.
    The row will be repeated for each element in the first cell.
    Any other cells containing hyperlinks will be processed using the current index.
-->

<!-- BEWARE of DATES
    <table:table-cell table:style-name="Table1.B2" office:value-type="date" office:date-value="2008-01-01">  ***** HERE
        <text:p text:style-name="Table_20_Contents">
            <text:a xlink:type="simple" xlink:href="http://pekoe.io/member/membership?output=history#paid-date">01/01/08</text:a>
        </text:p>
    </table:table-cell>
    
    <table:table-row>
                    <table:table-cell table:style-name="Table1.A2" office:value-type="float" office:value="2007">
                        <text:p text:style-name="Table_20_Contents">
                            <text:a xlink:type="simple" xlink:href="http://pekoe.io/tdbg/member/membership?output=history#/year">2007</text:a>
                        </text:p>
                    </table:table-cell>
                    <table:table-cell table:style-name="Table1.B2" office:value-type="date" office:date-value="2008-01-01">
                        <text:p text:style-name="Table_20_Contents">
                            <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/paid-date">01/01/08</text:a>
                        </text:p>
                    </table:table-cell>
                    <table:table-cell table:style-name="Table1.C2" office:value-type="string">
                        <text:p text:style-name="Table_20_Contents">
                            <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/receipt-number">CR123</text:a>
                        </text:p>
                    </table:table-cell>
-->

    <!-- process a TABLE ROW containing at least one pekoe-hyperlink -->
    <xsl:template match="table:table-row[.//text:a[starts-with(@xlink:href,'http://pekoe.io')]]">
        <!-- 
            Aim here is to copy the tr for each repetition of the value in the first field. 
            We want a table, so the number of values in the first field determines the number of rows. 
        -->
        <xsl:variable name="first-field" select="(.//text:a)[1]/@xlink:href" /> 
        <xsl:message>Hello first-field: <xsl:value-of select='$first-field'/></xsl:message>
        <xsl:variable name="row-count" select="count($phlinks/link[@original-href eq $first-field]/*)" /> <!-- what if it's ZERO ???? -->
        <xsl:variable name="this-row" select="." />
        
        <xsl:if test="$row-count eq 0 and $phlinks/link[@original-href eq $first-field] ne ''" > <!-- handle the case where there is no child element, only a value -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="0" as="xs:integer" tunnel="yes" /></xsl:apply-templates>
        </xsl:if>
        
        <xsl:for-each select="1 to $row-count"><!-- context is now the index number - hence the use of a variable in the select...  -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="." as="xs:integer" tunnel="yes" /></xsl:apply-templates> 
        </xsl:for-each>
    </xsl:template>
    
    <!-- table-cells behave like spreadsheets. the @value of the cell is used - regardless of the text - when the type is not string. 
        
        This is an auto-correction enhancement and it's not helpful.
        What are my options?
        Fix it on merge.
        Work out how to use the values
        
        Also, if the hyperlink is applied to a date in long format, there will be 3 hyperlinks - one for 
        
    -->

    
    <xsl:template match="table:table-row" mode="copy">     
        <xsl:copy>
            <xsl:apply-templates  mode="#default" />
        </xsl:copy>
    </xsl:template>

<!-- Replace a hyperlink by its content
  <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/person?output=first-and-last">Joe Bloggs</text:a>
 
    -->

    <xsl:template match="text:a">
        <xsl:param name="index" select="0" tunnel="yes"/> <!-- NOTE - MUST indicate that we EXPECT a tunnelled param here. -->
        <xsl:variable name="href" select="@xlink:href" /> 
        <xsl:choose>
            <xsl:when test="$index eq 0">
                <xsl:value-of select="$phlinks/link[@original-href eq $href]/string(.)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="($phlinks/link[@original-href eq $href]/*)[$index]/string(.)" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
; (: --------------------- END OF ODT STYLESHEET ------------------:)

(: --------------- Extract Content and links from ODT ------------------------ :)

declare function odt:extract-content($uri,$col) {
(:    xmldb:store($col, "content.xml", zip:xml-entry($uri, "content.xml")),:)
    odt:store-modified-content($uri,$col),
    let $links := odt:get-hyperlinks($col)
    let $schema-for := $links[1]/tokenize(@path,'/')[2] (: want school-booking from /school-booking/path/to/field :)
    return xmldb:store($col,"links.xml",<links template-type='odt'>{attribute for {$schema-for}}{$links}</links>)
};

declare function odt:store-modified-content($uri,$col){
    let $content := zip:xml-entry($uri, "content.xml")
    let $transformed := transform:transform($content,$odt:repair-odt-stylesheet, ())
    return xmldb:store($col, "content.xml", $transformed)
};

declare function odt:get-hyperlinks($col) {
    for $x in distinct-values(doc($col || "/content.xml")//t:a/@xlink:href[starts-with(., "http://pekoe.io/")])
    return links:make-link($x)
(:    let $tenant-link := substring-after($x, "http://pekoe.io/")   (\:  bgaedu/school-booking/school/teacher?output=name  :\)
    let $tenant := substring-before($tenant-link,'/') (\: 'bgaedu' or 'common':\)
    let $full-link := substring-after($tenant-link,$tenant) (\: /school-booking/school/teacher?output=name :\)
    let $link := substring-before($full-link,'#')
    let $output := substring-after($full-link,"#")
    
    return if (normalize-space($link) ne '') then  <link>{attribute for {$tenant}}{attribute path {$link}}{attribute output {$output}}</link> else ():)
};

(:<text:a xlink:type="simple"
          xlink:href="http://pekoe.io/tdbg/school-booking/day?output=first-visit-date"
                                >First-visit-date</text:a></text:p>
:)

(: --------------- Extract placeholders from ODT ------------------------ :)

declare function odt:extract-placeholder-names($doc) {
    for $n in $doc//t:placeholder
    return $n/@t:description               
};

(: --------------------------------------- MERGE odt --------------------------------------:)

(:
zip:update($href as xs:anyURI, $paths as xs:string+, $binaries as xs:base64Binary+) as xs:base64Binary? 
:)

(: This is the only REQUIRED function - will be called by the <template>.xql
   Given the data $intermediate, and the $template-file path.
   
   Find the template-content (in config/template-content/...)
   put the data values into the template-content
   add template-content to the odt file
   stream the result as a download back to the client.
   (That last step should be replaced - should simply return the binary to the calling <template>.xql 
   - which could then pass it to a suitable output function
:)
declare function odt:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI) {

    let $template-content := $template-bundle-path || "/content.xml"
    
(:    let $optinos := util:declare-option("exist:serialize","method=xml indent=no omit-xml-declaration=yes"):)

    let $merged := transform:transform($intermediate, $odt:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param>
            </parameters>) 
    let $binary-form := util:string-to-binary(util:serialize($merged, "method=xml"))
    let $path-in-zip := 'content.xml' (: Which file in the odt are we replacing. :)
(:    let $binary-doc := util:binary-doc($template-file) (\: this is the template ZIP :\):)
    return if ($merged instance of element(error)) then $merged else zip:update($template-file-uri, $path-in-zip, $binary-form)
};
