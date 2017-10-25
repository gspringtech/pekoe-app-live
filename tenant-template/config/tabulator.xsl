<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xd" version="2.0">
    <xsl:import href="../../../common/resources/tabulator.xsl"/>
    <xsl:template name="heading">
        <xsl:param name="report"/>
        <h1>
            <xsl:value-of select="$report/title"/>
            <xsl:if test="//report/date"> - <xsl:value-of select="//report/date"/>
            </xsl:if>
        </h1>
    </xsl:template>
</xsl:stylesheet>