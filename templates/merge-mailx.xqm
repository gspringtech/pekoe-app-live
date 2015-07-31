xquery version "3.0" encoding "UTF-8";
(: Copyright 2015 Geordie Springfield Pty Ltd Australia 
    Must provide the merge() and extract-content()
    
    This module will be used by the /templates trigger when a document is added/modified AND when a Merge is performed.
    When called by the trigger, it will modify the mail document - replacing text placeholders {{name}} with 
    the associated link/path to create an hyperlink <a href='http://pekoe.io/<tenant>/path/to/field'>REPLACE</a>
    
    When called by merge, it will replace all those hyperlinks with the content of the $intermediate form.
:)

module namespace mailx="http://www.gspring.com.au/pekoe/merge/mailx";

import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';

declare variable $mailx:repair-xmail-stylesheet := "repair-mailx.xsl";

declare variable $mailx:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> 27th Feb, 2015</xd:p>
            <xd:p><xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml"  cdata-section-elements="" omit-xml-declaration="yes" indent="no"/>
    
    <xsl:param name="template-content" />
    <xsl:param name="job-path" />
    <xsl:param name="tenant-path" />
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

       <!-- I'm not handling TABLES in Mail messages. I will need to. -->

<!-- Replace a hyperlink by its content
  <a href="http://pekoe.io/bkfa/ad-booking/org">REPLACE</a>
 
    -->
    
    <!-- This form is a bit of a hack but relies on the resource being stored in the tenant's files collection (somewhere).
        These paths are added directly into the Template.
    -->
    <xsl:template match="attachment[starts-with(.,'files/')]">
        <attachment><xsl:value-of select="$tenant-path" />/<xsl:value-of select="." /></attachment>
    </xsl:template>
    
    <!-- This form is for when the attachment is stored in the job-bundle. The Template's placeholder will be replaced with an Anchor.   -->
    <xsl:template match="attachment[a]">

        <xsl:variable name="href" select="a/@href" />  
        <!-- The problem is happening because I'm adding two local files. I think there should be a for-each or something.  -->
        <xsl:variable name="link" select="($phlinks/link[@original-href eq $href]/*)/normalize-space(string(.))" />
        <xsl:for-each select="$link">
            <xsl:choose>
                <xsl:when test='starts-with(., "files/")' >
                    <attachment><xsl:value-of select="$tenant-path" /><xsl:value-of select='.' /></attachment>
                    </xsl:when>
                <xsl:when test='. eq ""' ></xsl:when>
                <xsl:otherwise>
                    <attachment><xsl:value-of select="$job-path" />/<xsl:value-of select='.' /></attachment>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="a">        
        <xsl:variable name="href" select="@href" />         
        <xsl:value-of select="$phlinks/link[@original-href eq $href]/normalize-space(string(.))" />
    </xsl:template>



</xsl:stylesheet>
; (: --------------------- END OF XML STYLESHEET ------------------:)


(: This is called by the generated template-merge query after it has constructed the $intermediate data structure. (Which probably should be a MAP) :)
declare function mailx:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI) {

    let $template-content := $template-bundle-path || "/content.xml" 
    let $merged := transform:transform($intermediate, $mailx:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param> 
            <param name="job-path">{attribute value {request:get-attribute('job-bundle')}}</param>
            <param name="tenant-path">{attribute value {request:get-attribute('tenant-path')}}</param>
        </parameters>) 
    return $merged
};

declare function mailx:replace-links($col) {
    if (doc-available(xs:anyURI($col || '/links.xml'))) then xmldb:remove($col,'links.xml') else (),
    if (ends-with($col, "_xml")) then 
        let $uri := replace(replace($col,"_xml", ".xml"), "/templates-meta/", "/templates/")
        return mailx:update-links($uri, $col)
    else ()
};

(: 'extract' (copy) the content into templates-meta, extracting the Links and cleaning up the content. :)
declare function mailx:extract-content($uri,$col) {
    mailx:store-modified-content($uri,$col),
    mailx:update-links($uri, $col)
  
};

declare function mailx:update-links($uri, $col) {
    let $all-placeholders-from-template := distinct-values(doc($col || "/content.xml")//a/@href[starts-with(., "http://pekoe.io/")])
    let $debug := util:log('info', '%%%%%%%%%%%% EXTRACTED LINKS FROM MAILX : ' || string-join($all-placeholders-from-template, ', '))
    let $updated-links := links:update-links-doc($col, $all-placeholders-from-template, 'mailx')
    return xmldb:store($col,"links.xml",$updated-links)
};

declare function mailx:store-modified-content($uri,$col){
    (:   Consider storing the 'links' in 'mail-links.xml' - like word-links.  :)
    let $content := doc($uri)
    let $transformed := transform:transform($content,$mailx:repair-xmail-stylesheet, ())
    let $content-path := xmldb:store($col, "content.xml", $transformed)
    let $log := util:log("info",'STORED CONTENT INTO ' || $content-path)
(:    let $l := util:log('info',$transformed):)
    return $content-path
};

declare function mailx:get-hyperlinks($uri) {
(:  Need a wildcard namespace because there might be HTML namespaced anchors.  :)
    for $a in doc($uri)//*:a[starts-with(./@href,'http://pekoe.io')]
    return links:make-link($a/@href/string())
};

(:
This was easy, but the mail-message may contain html with hyperlinks - which won't be listed here. 
These links allow placeholders to be used in text fields.
declare function mailx:get-hyperlinks($uri) {

    for $a in doc($uri)//link
    return links:make-link("http://pekoe.io" || $a/path/string())
};:)