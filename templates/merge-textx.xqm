xquery version "3.0" encoding "UTF-8";
(: Copyright 2015 Geordie Springfield Pty Ltd Australia 
    Must provide the merge() and extract-content()
    
    This module will be used by the /templates trigger when a document is added/modified AND when a Merge is performed.
    When called by the trigger, it will modify the mail document - replacing text placeholders {{name}} with 
    the associated link/path to create an hyperlink <a href='http://pekoe.io/<tenant>/path/to/field'>REPLACE</a>
    
    When called by merge, it will replace all those hyperlinks with the content of the $intermediate form.
:)

module namespace textx="http://www.gspring.com.au/pekoe/merge/textx";

import module namespace links = 'http://pekoe.io/merge/links' at 'create-links.xqm';

declare variable $textx:repair-stylesheet := "repair-textx.xsl";


declare variable $textx:stylesheet := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> 11th May, 2015</xd:p>
            <xd:p><xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p>This stylesheet is called by the merge function in merge-textx. It's context is the links document (the "intermediate form").
                It receives the template-content as a parameter.
                I'm not sure why it's this way around. The context is changed in the root xsl-template from the links to the template-content.
                
                If I do it the other way it will be similar to the repair-pxml which replaces placeholders {{placeholder}} with a hyperlink.
                Except I don't need the hyperlink. I only need the placeholder (and the field-path) and the value from the intermediate.
             </xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output method="text" />
    
    <xsl:param name="template-content" />
    <xsl:param name="job-path" />
    <xsl:param name="tenant-path" />
    <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $template-content )" />
    <xsl:variable name="phlinks" select="/links"/> <!--  a reference to the root is needed because another document is imported. -->


    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test='doc-available($path-to-template-content)'>
                <xsl:apply-templates select=" doc( $path-to-template-content )//content "/> 
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
  
  
  In this case, the transform only applies to the /text/content element.
  It's a text-substitution problem - replacing {{placeholder}} with /links/link[@placeholder = $placeholder]
 
    -->
    <xsl:template match="attachment[starts-with(.,'files/')]">
        <attachment><xsl:value-of select="$tenant-path" />/<xsl:value-of select="." /></attachment>
    </xsl:template>
    
    <xsl:template match="attachment[a]">

        <xsl:variable name="href" select="a/@href" />  
        <xsl:variable name="link" select="($phlinks/link[@original-href eq $href]/*)/normalize-space(string(.))" />
        <xsl:choose>
            <xsl:when test='starts-with($link, "files/")' >
                <attachment>/db/pekoe/tenant/bkfa/blah blah <xsl:value-of select='$link' /></attachment>
                </xsl:when>
            <xsl:when test='$link eq ""' ></xsl:when>
            <xsl:otherwise>
                <attachment><xsl:value-of select="$job-path" />/<xsl:value-of select='$link' /></attachment>
            </xsl:otherwise>
            </xsl:choose>
    </xsl:template>

<!-- 
I'd like to be able to match the whitespace used in repeating lines:
    {{address-lines}}
    currently produces... (only the first line is indented)
    
    29 Chasewater Street
Lower Mitcham
SA 5062
_________

To fix this, I would need to copy the line. But by the time I get to this <a href='field-path'>...
I have already output the indent text.

One option is to use a different kind of placeholder, (not an anchor)
Or to put special markup into the text - perhaps an empty placeholder {{    }} 
   containing the whitespace or other formatting - perhaps a tab or " - ".
   
But this would need to wrap the whole line. Perhaps it is a {{REPEAT - {{address-lines}}}}
The stylesheet could go into a MODE where the marked text is copied - but that would be hard .
Perhaps the ANCHOR could contain the whitespace and/or text.
Or perhaps the output function should deal with it. (this is the worst idea)


--> 
    <xsl:template match="a">        
        <xsl:variable name="href" select="@href" />      
        <xsl:variable name="text" select="$phlinks/link[@original-href eq $href]" />
        <xsl:apply-templates select="if ($text/line) then $text/line else $text" />
    </xsl:template>
<!-- <xsl:value-of select="$phlinks/link[@original-href eq $href]" /> -->
<xsl:template match="line">
<xsl:value-of select='.'/><xsl:text>&#xa0;
</xsl:text>
</xsl:template>


</xsl:stylesheet>
; (: --------------------- END OF XML STYLESHEET ------------------:)


(: This is called by the generated template-merge query after it has constructed the $intermediate data structure. (Which probably should be a MAP) :)
declare function textx:merge($intermediate, $template-bundle-path, $template-file-uri as xs:anyURI) {

    let $template-content := $template-bundle-path || "/content.xml" 
    let $merged := transform:transform($intermediate, $textx:stylesheet, 
        <parameters>
            <param name="template-content">{attribute value {$template-content}}</param> 
            <param name="job-path">{attribute value {request:get-attribute('job-bundle')}}</param>
            <param name="tenant-path">{attribute value {request:get-attribute('tenant-path')}}</param>
        </parameters>) 
    return util:string-to-binary($merged)
};


(: 'extract' (copy) the content into templates-meta, extracting the Links and cleaning up the content. :)
declare function textx:extract-content($uri,$col) {
    textx:store-modified-content($uri,$col),
    textx:update-links($uri, $col)
  
};

declare function textx:update-links($uri, $col) {
    let $all-placeholders-from-template := distinct-values(doc($col || "/content.xml")//a/@href[starts-with(., "http://pekoe.io/")])
    let $debug := util:log('info', '%%%%%%%%%%%% EXTRACTED LINKS FROM xTEXT : ' || string-join($all-placeholders-from-template, ', '))
    let $updated-links := links:update-links-doc($col, $all-placeholders-from-template, 'text')
    return xmldb:store($col,"links.xml",$updated-links)
};

declare function textx:store-modified-content($uri,$col){
    (:   Consider storing the 'links' in 'mail-links.xml' - like word-links.  :)
    let $content := doc($uri)
    let $transformed := transform:transform($content,$textx:repair-stylesheet, ())
    return xmldb:store($col, "content.xml", $transformed)
};

declare function textx:get-hyperlinks($uri) {
(:  Need a wildcard namespace because there might be HTML namespaced anchors.  :)
    for $a in doc($uri)//*:a[starts-with(./@href,'http://pekoe.io')]
    return links:make-link($a/@href/string())
};

(:
This was easy, but the mail-message may contain html with hyperlinks - which won't be listed here. 
These links allow placeholders to be used in text fields.
declare function textx:get-hyperlinks($uri) {

    for $a in doc($uri)//link
    return links:make-link("http://pekoe.io" || $a/path/string())
};:)