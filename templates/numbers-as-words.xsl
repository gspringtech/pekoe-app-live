<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">
    <xsl:output indent="yes" method="xml" omit-xml-declaration="yes"/>
    <xsl:variable name="million" select="1000000" as="xs:integer"/>
    <xsl:variable name="thousand" select="1000" as="xs:integer"/>
    <xsl:variable name="hundred" select="100" as="xs:integer"/>
    <xsl:variable name="twenty" select="20" as="xs:integer"/>
    <xsl:variable name="ten" select="10" as="xs:integer"/>
    <xsl:param name="rawInput" select="0"/>
    <xsl:variable name="input" select="xs:decimal($rawInput)"/>
    <xsl:template match="/">
        <results>
            <currency-string>
                <xsl:call-template name="format-currency-string">
                    <xsl:with-param name="input" select="$input"/>
                </xsl:call-template>
            </currency-string>
            <number-in-words>
                <xsl:call-template name="makeWords"><!-- Split into integer and decimal -->
                    <xsl:with-param name="theNumber" select="floor(abs($input))"/>
                </xsl:call-template>
                <xsl:choose>
                    <xsl:when test="floor(abs($input)) eq 1">
                        <xsl:value-of select="//currency-words/integer"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="//currency-words/integers"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:variable name="cents" select="(abs($input) - floor(abs($input))) * 100"/>
                <xsl:if test="$cents gt 0">
                    <xsl:if test="$input gt 1">
                        <xsl:value-of select="//conjunctions/join[@id = 'integer-to-decimal']"/>
                    </xsl:if>
                    <xsl:call-template name="makeWords"><!-- Split into integer and decimal -->
                        <xsl:with-param name="theNumber" select="$cents"/>
                    </xsl:call-template>
                    <xsl:choose>
                        <xsl:when test="$cents eq 1">
                            <xsl:value-of select="//currency-words/decimal"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="//currency-words/decimals"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
            </number-in-words>
        </results>
    </xsl:template>
    <xsl:template name="format-currency-string">
        <xsl:param name="input"/>
        <xsl:text>$</xsl:text>
        <xsl:call-template name="format-number-string">
            <xsl:with-param name="digits" select="string(floor(abs($input)))"/>
        </xsl:call-template>
        <xsl:variable name="cents" select="(abs($input) - floor(abs($input))) * 100"/>
        <xsl:if test="$cents gt 0">
            <xsl:text>.</xsl:text>
            <xsl:value-of select="$cents"/>
        </xsl:if>
    </xsl:template>
    <xsl:template name="makeWords">
        <xsl:param name="theNumber"/>
        <xsl:param name="theWords"/>
        <xsl:variable name="modulator" select="1"/>
        <xsl:variable name="conjunction"/>
        <xsl:variable name="modulator"/>
        <xsl:choose>
            <xsl:when test="$theNumber ge $million">
                <xsl:call-template name="makeWords">
                    <xsl:with-param name="theNumber" select="$theNumber idiv $million"/>
                </xsl:call-template>
                <xsl:value-of select="//other/value[@int eq string($million)]"/>
                <xsl:variable name="remainder" select="$theNumber mod $million"/>
                <xsl:if test="$remainder gt 0">
                    <xsl:choose>
                        <xsl:when test="($remainder idiv $hundred) ge 1">
                            <xsl:value-of select="//conjunctions/join[@id = 'to-hundreds']"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="//conjunctions/join[@id = 'to-tens']"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:call-template name="makeWords">
                        <xsl:with-param name="theNumber" select="$remainder"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$theNumber ge $thousand">
                <xsl:call-template name="makeWords">
                    <xsl:with-param name="theNumber" select="$theNumber idiv $thousand"/>
                </xsl:call-template>
                <xsl:value-of select="//other/value[@int eq string($thousand)]"/>
                <xsl:variable name="remainder" select="$theNumber mod $thousand"/>
                <xsl:if test="$remainder gt 0">
                    <xsl:choose>
                        <xsl:when test="($remainder idiv $hundred) ge 1">
                            <xsl:value-of select="//conjunctions/join[@id eq 'to-hundreds']"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="//conjunctions/join[@id eq 'to-tens']"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:call-template name="makeWords">
                        <xsl:with-param name="theNumber" select="$remainder"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$theNumber ge $hundred">
                <xsl:call-template name="makeWords">
                    <xsl:with-param name="theNumber" select="$theNumber idiv $hundred"/>
                </xsl:call-template>
                <xsl:value-of select="//other/value[@int eq string($hundred)]"/>
                <xsl:variable name="remainder" select="$theNumber mod $hundred"/>
                <xsl:if test="$remainder gt 0">
                    <xsl:value-of select="//conjunctions/join[@id eq 'to-tens']"/>
                    <xsl:call-template name="makeWords">
                        <xsl:with-param name="theNumber" select="$remainder"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$theNumber ge $twenty">
                <xsl:value-of select="//tens/value[$theNumber idiv $ten]"/>
                <xsl:variable name="remainder" select="$theNumber mod $ten"/>
                <xsl:if test="$remainder gt 0">
                    <xsl:value-of select="//conjunctions/join[@id eq 'tens-to-digits']"/>
                    <xsl:call-template name="makeWords">
                        <xsl:with-param name="theNumber" select="$remainder"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$theNumber gt 0">
                <xsl:value-of select="//units/value[$theNumber]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="//other/value[@int eq '0']"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="format-number-string">
        <xsl:param name="digits"/>
        <xsl:variable name="split-three" select="replace($digits,'(.*)(.{3})$','$1-$2' )"/>
        <xsl:choose>
            <xsl:when test="matches($digits,'..{3}')">
                <xsl:call-template name="format-number-string">
                    <xsl:with-param name="digits" select="substring-before($split-three,'-')"/>
                </xsl:call-template>
                <xsl:text>,</xsl:text>
                <xsl:value-of select="substring-after($split-three,'-')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$digits"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>