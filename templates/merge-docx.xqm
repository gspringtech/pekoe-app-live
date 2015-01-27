xquery version "3.0" encoding "UTF-8";
(: Copyright 2012 Geordie Springfield Pty Ltd Australia :)

module namespace docx="http://www.gspring.com.au/pekoe/merge/docx";
declare namespace w="http://schemas.openxmlformats.org/wordprocessingml/2006/main";
declare namespace rs="http://schemas.openxmlformats.org/package/2006/relationships";
declare namespace r ="http://schemas.openxmlformats.org/officeDocument/2006/relationships";

(:declare namespace file-store="http://www.gspring.com.au/pekoe/fileStore";:)
declare copy-namespaces preserve, inherit; (: WAS "preserve" :)
import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';
declare option exist:serialize "method=text media-type=application/xquery";

declare variable $docx:replace-hyperlinks-stylesheet := "replace-word-hyperlinks.xsl";


declare variable $docx:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> Apr 19, 2012</xd:p>
            <xd:p><xd:b>Author:</xd:b> apillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
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
    
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>

<!-- 
    The output function should handle results containing more than one value - for example, using a string-join($v,', ')
    If there are multiple elements in the link, it's expected that the hyperlink will be within a table-row/table-cell.
    The row will be repeated for each element in the first cell.
    Any other cells containing hyperlinks will be processed using the current index.
-->
    <!-- process a TABLE ROW containing at least one pekoe-hyperlink        

    -->
    <xsl:template match="w:tr[w:tc/*/a]">
        <!-- 
            Aim here is to copy the tr for each repetition of the value in the first field. 
            Sounds confusing - but it's simple enough. We want a table, so the number of values in the first field determines the 
            number of rows. 
            (The first field doesn't have to be in the first column of the table.)                    
        -->
        <xsl:variable name="first-field" select="(.//a)[1]/@href/string(.)" /> <!-- must be a better way to get the mergefield name. -->
        <xsl:variable name="row-count" select="count($phlinks/link[@original-href eq $first-field]/*)" /> <!-- what if it's ZERO ???? -->
        <xsl:variable name="this-row" select="." />
        
        <xsl:if test="$row-count eq 0 and $phlinks/link[@original-href eq $first-field] ne ''" > <!-- handle the case where there is no child element, only a value -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="0" as="xs:integer" tunnel="yes" /></xsl:apply-templates>
        </xsl:if>
        
        <xsl:for-each select="1 to $row-count"><!-- context is now the index number - hence the use of a variable in the select...  -->
            <xsl:apply-templates select="$this-row" mode="copy"><xsl:with-param name="index" select="." as="xs:integer" tunnel="yes" /></xsl:apply-templates> 
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="w:tr" mode="copy">     
        <xsl:copy>
            <xsl:apply-templates  mode="#default" />
        </xsl:copy>
    </xsl:template>

<!-- 
Hyperlinks in the word document have been replaced by <a href='...'>Replace Me</a>

    -->

    <xsl:template match="*:a">
        <xsl:param name="index" select="0" tunnel="yes"/> <!-- NOTE - MUST indicate that we EXPECT a tunnelled param here. -->
        <xsl:variable name="href" select="@href" />
       <w:r>            
            <w:t><xsl:choose>
                <xsl:when test="$index eq 0">
                    <xsl:value-of select="$phlinks/link[@original-href eq $href]/string(.)" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="($phlinks/link[@original-href eq $href]/*)[$index]/string(.)" />
                </xsl:otherwise>
            </xsl:choose></w:t>
        </w:r>
    </xsl:template>
    
    <xsl:template match='node() | @*' mode='delete'/>


</xsl:stylesheet>
;

(: --------------- Extract placeholders from Word. At the same time, clean up the content. This will simplify the merge. Replace all pekoe hyperlinks with <a href="...">Sample</a>.  ------------------------ :)

declare function docx:extract-content($uri,$col) {
    xmldb:store($col,"word-links.xml",zip:xml-entry($uri, "word/_rels/document.xml.rels")),
    docx:store-modified-content($uri,$col),
    let $links := docx:get-hyperlinks($col)
    let $schema-for := $links[1]/tokenize(@path,'/')[2] (: want school-booking from /school-booking/path/to/field :)
    return xmldb:store($col,"links.xml",<links template-type='docx'>{attribute for {$schema-for}}{attribute mod-datetime {current-dateTime()}}{$links}</links>)
};


declare function docx:store-modified-content($uri,$col){
    let $content := zip:xml-entry($uri, "word/document.xml")
    let $links-doc := $col || '/word-links.xml'
    let $transformed := transform:transform($content,$docx:replace-hyperlinks-stylesheet, <parameters><param name='links-doc' value='{$links-doc}'/></parameters>)
    return xmldb:store($col, "content.xml", $transformed)
};

declare function docx:get-hyperlinks($col) {
    for $a in distinct-values(doc($col || "/content.xml")//a/@href)
    return links:make-link($a)
};



(:
    Ah - Microsoft. Thou crock full of shit. Here's my new "Link" - it's a Hyperlink. 
    And where is the link?
    
    <w:hyperlink r:id="rId10" w:history="1">
        <w:proofErr w:type="gramStart"/>
        <w:r w:rsidRPr="0033197E">
            <w:rPr>
                <w:rStyle w:val="Hyperlink"/>
                <w:sz w:val="36"/>
                <w:szCs w:val="36"/>
            </w:rPr>
            <w:t>teacher</w:t>
        </w:r>
        <w:proofErr w:type="gramEnd"/>
    </w:hyperlink>
    
    It's in the word/_rels/document.xml.rels
    <Relationship Id="rId10" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="http://pekoe.io/bgaedu/school-booking/school/teacher?output=name" TargetMode="External"/>
    And NOTE. the namespace of Relationship is NOT the same as the document relationship - even though they are clearly related. How fucking stupid.
    AND the anchor-ref is in the Hyperlink, not the Relationship.
:)


(: 

:)
declare function docx:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI) {

    let $template-content := $template-bundle-path || "/content.xml" 
 (:   let $stored := xmldb:store('/db/temp','inter.xml',$intermediate)
    let $log := util:log("warn",concat("Doc ", $template-content, " available? ", doc-available($template-content)))
    let $log := util:log("warn",xmldb:get-current-user())
    let $log := util:log("warn",concat("CONTEXT: ", request:get-effective-uri())):)

    let $merged := transform:transform($intermediate, $docx:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param> 
            </parameters>) 
    let $binary-form := util:string-to-binary(util:serialize($merged, "method=xml"))

    let $path-in-zip := 'word/document.xml' (: Which file in the DOCX or ODT are we replacing. :)
(:    let $binary-doc := util:binary-doc($template-file) (\: this is the template ZIP :\):)
    return zip:update($template-file-uri, $path-in-zip, $binary-form)
};

