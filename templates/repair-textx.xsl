<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> 11th May 2015</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p>Replace placeholders {{ph-name}} with hyperlinks.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:variable name="match">\{\{([^}]+)\}\}</xsl:variable>
    <xsl:variable name="root" select="/"/>
    <xsl:key name="links" match="link" use="string(placeholder)"/>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- 
    In this template, fields are represented by placeholders in the text:
    Dear {{first-name}}, 
    etc
    the path for these is found in the template links.
    
    Replace these placeholders with standard hyperlinks which can be more easily processed.
    -->
    <xsl:template match="link"/> <!-- delete the links from the output -->
    <xsl:template match="content/text()[contains(.,'{{')]">
        <xsl:analyze-string select="." regex="{$match}">
            <xsl:matching-substring>
                <xsl:variable name="link-id" select="regex-group(1)"/>
                <a>
                    <xsl:attribute name="href" select="key('links',$link-id, $root )/string(path)"/>REPLACE</a>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:value-of select="."/>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    <xsl:template match="node() | @*" mode="delete"/>
    
    <!-- TODO - Incorporate this... -->
    <!-- Emit text, 75 character max per line, recursively -->
    <!-- Thanks to Tim Hare 2005 from the ical2ics stylesheet  -->
    <xsl:template name="emit_text">
        <xsl:param name="limit" select="number(75)"/>
        <!-- default limit is 75 " -->
        <xsl:param name="line"/>
        <xsl:value-of select="substring(normalize-space($line),1,$limit)"/>
        <!-- Output the newline string -->
        <xsl:text>
</xsl:text>
        <xsl:if test="string-length($line) &gt; $limit">
            <xsl:text> </xsl:text>
            <xsl:call-template name="emit_text">
                <xsl:with-param name="limit" select="($limit - 1)"/>
                <!-- use 74 allow for space -->
                <xsl:with-param name="line" select="substring($line,($limit + 1))"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>