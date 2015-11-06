<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Jul 31, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
            <xd:p>
                All this has to do is replace the special pekoe- elements with the content found in the links document.
                e.g. 
<!--                <link original-href='client-name'>Alister</link>
                <pekoe-string name='client-name'/>
                -->
                
                The PROBLEM is that the "original-href" is NOT the original placeholder name. I've had to use 
                "http://pekoe.io/cm/residential/purchaser/person?output=first-and-last" and 
                "http://pekoe.io/cm/residential/property/address?output=address-on-one-line" 
                which is just not helpful as I still need to _link_ these in the LINKS document:
                
               <!-- 
               <link original-href="http://pekoe.io/cm/residential/purchaser/person?output=full-name" placeholder="cm/residential/purchaser/person?output=full-name" field-path="/residential/purchaser/person">
                    <output name="full-name" fragment=""/>
                    <output-or-xquery/>
                </link>
               -->
                
                Problem:
                The create-links functions are based on the original-href
                The Merge uses the original-href - but this can be fixed (but means updating all templates)
<!--               <link original-href="http://pekoe.io/cm/residential/referee/name">-->
                The Placeholder-links Template for editing the links DOES show the placeholder (but it shoudn't be editible in this case.)
                
                
            </xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:strip-space elements="*"/>
    <xsl:output method="xml" cdata-section-elements="" omit-xml-declaration="yes"/>
    <xsl:param name="template-content"/>
    <xsl:variable name="path-to-template-content" select="concat('xmldb:exist://', $template-content )"/>
    <xsl:variable name="phlinks" select="/links"/> <!--  a reference to the root is needed because another document is imported. -->
    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test="doc-available($path-to-template-content)">
                <xsl:apply-templates select=" doc( $path-to-template-content )/* "/>
            </xsl:when>
            <xsl:otherwise>
                <error>Permission Denied</error>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="pekoe-string">
        <xsl:variable name="ph" select="./@name"/>
        <xsl:variable name="val" select="$phlinks/link[@placeholder eq $ph]/string()"/>
        <table:table-cell office:value-type="string">
            <text:p>
                <xsl:value-of select="$val"/>
            </text:p>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="pekoe-date">
        <xsl:variable name="ph" select="./@name"/>
        <xsl:variable name="val" select="$phlinks/link[@placeholder eq $ph]/string()"/>
        <table:table-cell office:value-type="date" office:date-value="{$val}">
            <text:p>
                <xsl:value-of select="$val"/>
            </text:p>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="pekoe-value">
        <xsl:variable name="ph" select="./@name"/>
        <xsl:variable name="type" select="./@type"/>
        <xsl:variable name="val" select="$phlinks/link[@placeholder eq $ph]/string()"/>
        <table:table-cell office:value-type="{$type}" office:value="{$val}">
            <text:p>
                <xsl:value-of select="$val"/>
            </text:p>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>