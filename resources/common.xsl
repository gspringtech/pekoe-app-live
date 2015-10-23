<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:pekoe="http://www.gspring.com.au/pekoe" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 30, 2011</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
            <xd:p>
                <xd:b>Description:</xd:b> A collection of common xsl functions which can be used by
                all schemas. </xd:p>
            <xd:p>doc("/db/pekoe-system/common.xsl")//*:function/string(@name)</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="pekoe:aust-short-date">
        <xsl:param name="date" as="xs:date"/>
        <xsl:value-of select="format-date($date,'[D,2]-[M,2]-[Y,4]')"/>
    </xsl:function>
    <xsl:function name="pekoe:currency">
        <xsl:param name="amount"/>
        <xsl:value-of select="format-number($amount,'$#,##0.00')"/>
    </xsl:function>
</xsl:stylesheet>