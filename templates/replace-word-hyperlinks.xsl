<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:doctorx="http://gspring.com.au/pekoe/templates/docxt" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:rs="http://schemas.openxmlformats.org/package/2006/relationships" exclude-result-prefixes="xs xd doctorx rs" version="2.0">
    <xsl:param name="links-doc"/>
    <xsl:variable name="links" select="doc($links-doc)//rs:Relationship"/>
    <!-- Replace the Complex Field Character structure with a fldSimple. 
        this transformation will start with the identity-transform at the end. 
        The important action starts when it encounters an element containing the HYPERLINK instruction.  -->
    
    <!--  convert instrText content into a useable placeholder name. (Strip whitespace and quotes - I haven't done the quotes) -->
    <xsl:function name="doctorx:fix-field-name"> 
        <!-- instrText:
            HYPERLINK "http://pekoe.io/bkfa/member/person" \l "first-and-last"
            want 
            http://pekoe.io/bkfa/member/person#first-and-last
           
        -->
        <xsl:param name="instrText"/>
        <xsl:variable name="parts" select="tokenize($instrText,'\s+')[starts-with(.,'&#34;')]"/>
        <xsl:value-of select="string-join(for $p in $parts return translate($p,'&#34;',''),'#')"/>
    </xsl:function>


    <!-- the main action. Replace a Complex Field Character structure with a fldSimple -->
    <xsl:template match="*[w:r/w:instrText[contains(.,'http://pekoe.io')]]">
        <!-- this matches a para, tc or similar container. Copy it, and its attributes, then process the first child. 
            Each child must explicitly apply-templates to the following sibling. 
            A Mode is used to indicate whether we're inside the Complex Field or not. 
        -->
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates mode="outside" select="child::*[1]"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="outside" match="node() | @*"><!-- not sure if attributes need to be matched here. --> 
        <!-- Initially, this should match a Run (r). if the run contains a complex-field-character "begin", switch modes. else copy the content -->
        <xsl:choose>
            <xsl:when test="descendant::w:fldChar/@w:fldCharType[. eq 'begin']">
                <!-- Don't copy - just change modes and go next. -->
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy> <!-- copy this element and its children, because it's not of any interest. -->
                    <xsl:apply-templates select="node() | @*" mode="#default"/>
                </xsl:copy>
                <xsl:apply-templates mode="outside" select="following-sibling::*[1]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template mode="inside" match="node()">
        <!-- These nodes are following a "begin". -->
        <xsl:choose>
            <xsl:when test="descendant::w:fldChar/@w:fldCharType[. eq 'end']">
                <!-- Don't copy it. Switch back to outside for the following sibling -->
                <xsl:apply-templates mode="outside" select="following-sibling::*[1]"/>
            </xsl:when>
            <xsl:when test="descendant::w:instrText[contains(.,'HYPERLINK')]">
                <!-- Sadly, this is NOT the Run I need to copy. The one I want is after the "separator" - the second following-run
                <fldChar fldCharType="separate"/>
                 -->
                <xsl:variable name="Hyperlink">
                    <xsl:value-of select=".//w:instrText"/>
                </xsl:variable>
                <a href="{doctorx:fix-field-name($Hyperlink)}">Replace Me</a>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/> <!-- next -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/>
            </xsl:otherwise> <!-- remove any other "inside" node -->
        </xsl:choose>
    </xsl:template>
    <xsl:template match="w:hyperlink">
        <xsl:variable name="rid" select="./@r:id"/>
        <xsl:variable name="url" select="$links[@Id eq $rid]/string(@Target)"/>
        <xsl:variable name="anchor-ref" select="@w:anchor"/>
        <xsl:choose>
            <xsl:when test="starts-with($url,'http://pekoe.io')">
                <a href="{string-join(($url,$anchor-ref),&#34;#&#34;)}">Replace Me</a>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- identity transform -->
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>