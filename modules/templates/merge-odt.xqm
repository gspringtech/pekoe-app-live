xquery version "3.0" encoding "UTF-8";
(: Copyright 2014 Geordie Springfield Pty Ltd, Australia

A quick reminder - I don't have a merge-odt library yet, because the merge used to be done IN JAVASCRIPT
Ha!

So I have to think it through again.

And, as a brief aside, remember the plan to use LINKs (hrefs) instead of placeholders - for both Word and ODT.
Also remember that there's an ODS.xqm which might provide some clues as to how to proceed.

:)

module namespace odt="http://www.gspring.com.au/pekoe/merge/odt";
declare namespace t="urn:oasis:names:tc:opendocument:xmlns:text:1.0";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare copy-namespaces preserve, inherit;
(:declare option exist:serialize "method=text media-type=application/xquery";:)

declare option exist:serialize "omit-xml-declaration=yes";




declare variable $odt:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
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
    <xsl:param name="session-user" />    <!-- without this, the transform runs as guest - which is no good. -->
    <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $session-user, '@', $template-content )" />
    <xsl:variable name="phlinks" select="/ph-links"/> <!--  a reference to the root is needed because another document is imported. -->

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

<!-- Might want to look at the key() function to do the lookup on the ph-links/link 
    I really need to investigate a better way to process tabular fields. 
    One option would be to generate a sequence of rows where each row contains an element matching the placeholder-name:
    <row><Date/><booked/><fee/>...</row>
    
    // changing this. I wonder if it's easier to process?
    text:a href=http://pekoe.io/cm/txo/property/address#one-line
    consider also
    text:a href=http://pekoe.io/cm/txo/property/address?output=one-line&then=uppercase (or some better example of parameter within the template)
    
    IMPORTANT to remember that the HREF will contain a valid XPATH ('/txo/property/address')
    and the anchor-ref or output param will refer to something in the schema.
    
    The reason for running this via a generated XQuery is that processing the OUTPUT might require access to the whole document.
    (CHECK Is this ODT approach different to the Word approach? I think it might be.)
-->

    <!-- process a TABLE ROW containing at least one field -->
    <xsl:template match="table:table-row[.//text:placeholder]">
        <!-- 
            Aim here is to copy the tr for each repetition of the value in the first field. 
            We want a table, so the number of values in the first field determines the number of rows. 
        -->
        <xsl:variable name="first-field" select=".//text:placeholder[1]/@text:description" /> 
        <xsl:variable name="row-count" select="count($phlinks/link[@ph-name eq $first-field]/*)" /> <!-- what if it's ZERO ???? -->
        <xsl:variable name="this-row" select="." />
        
        <xsl:if test="$row-count eq 0 and $phlinks/link[@ph-name eq $first-field] ne ''" > <!-- handle the case where there is no child element, only a value -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="0" as="xs:integer" tunnel="yes" /></xsl:apply-templates>
        </xsl:if>
        
        <xsl:for-each select="1 to $row-count"><!-- context is now the index number - hence the use of a variable in the select...  -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="." as="xs:integer" tunnel="yes" /></xsl:apply-templates> 
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="table:table-row" mode="copy">     
        <xsl:copy>
            <xsl:apply-templates  mode="#default" />
        </xsl:copy>
    </xsl:template>

<!-- Replace fld simple by its content and replace the w:t by the value:
    <w:r>
        <w:rPr>
            <w:rFonts w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi" w:cstheme="minorHAnsi"/>
            <w:noProof/>
        </w:rPr>
        <w:t>flab</w:t>
    </w:r>
    -->

    <xsl:template match="text:placeholder">
        <xsl:param name="index" select="0" tunnel="yes"/> <!-- NOTE - MUST indicate that we EXPECT a tunnelled param here. -->
        <xsl:variable name="placeholder-name" select="./@text:description" /> 
        <xsl:choose>
            <xsl:when test="$index eq 0">
                <xsl:value-of select="$phlinks/link[@ph-name eq $placeholder-name]/string(.)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="($phlinks/link[@ph-name eq $placeholder-name]/*)[$index]/string(.)" />
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
    xmldb:store($col, "content.xml", zip:xml-entry($uri, "content.xml")),
(:    xmldb:store($col,"word-links.xml",zip:xml-entry($uri, "word/_rels/document.xml.rels")),:)
    let $links := odt:get-hyperlinks($col)
    let $schema-for := $links[1]/tokenize(@path,'/')[2] (: want school-booking from /school-booking/path/to/field :)
    return xmldb:store($col,"links.xml",<links>{attribute for {$schema-for}}{$links}</links>)
};


declare function odt:get-hyperlinks($col) {
    for $x in doc($col || "/content.xml")//t:a/@xlink:href[starts-with(., "http://pekoe.io/")]
    let $tenant-link := substring-after($x, "http://pekoe.io/")   (:  bgaedu/school-booking/school/teacher?output=name  :)
    let $tenant := substring-before($tenant-link,'/') (: 'bgaedu' or 'common':)
    let $full-link := substring-after($tenant-link,$tenant) (: /school-booking/school/teacher?output=name :)
    let $link := substring-before($full-link,'#')
    let $output := substring-after($full-link,"#")
    
    return if (normalize-space($link) ne '') then  <link>{attribute for {$tenant}}{attribute path {$link}}{attribute output {$output}}</link> else ()
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
declare function odt:merge($intermediate, $template-file-uri as xs:anyURI) {

    let $template-content := concat(substring-before(replace($template-file,"templates/","config/template-content/") , "."), ".xml")
    let $optinos := util:declare-option("exist:serialize","method=xml indent=no omit-xml-declaration=yes")
    let $merged := transform:transform($intermediate, $odt:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param>
            <param name="session-user">{attribute value {concat(encode-for-uri(session:get-attribute('user')), ":", session:get-attribute('password'))}}</param>
            </parameters>) 
    let $binary-form := util:string-to-binary(util:serialize($merged, "method=xml"))
    let $path-in-zip := 'content.xml' (: Which file in the odt are we replacing. :)
(:    let $binary-doc := util:binary-doc($template-file) (\: this is the template ZIP :\):)
    return if ($merged instance of element(error)) then $merged else zip:update($template-file-uri, $path-in-zip, $binary-form)
};
