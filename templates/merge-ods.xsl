<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Jul 31, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
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
        <xsl:variable name="val" select="$phlinks/link[@original-href eq $ph]/string()"/>
        <table:table-cell office:value-type="string">
            <text:p>
                <xsl:value-of select="$val"/>
            </text:p>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="pekoe-date">
        <xsl:variable name="ph" select="./@name"/>
        <xsl:variable name="val" select="$phlinks/link[@original-href eq $ph]/string()"/>
        <table:table-cell office:value-type="date" office:date-value="{$val}">
            <text:p>
                <xsl:value-of select="$val"/>
            </text:p>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="pekoe-value">
        <xsl:variable name="ph" select="./@name"/>
        <xsl:variable name="type" select="./@type"/>
        <xsl:variable name="val" select="$phlinks/link[@original-href eq $ph]/string()"/>
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