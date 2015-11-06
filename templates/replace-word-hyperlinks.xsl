<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rs="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:doctorx="http://gspring.com.au/pekoe/templates/docxt" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd doctorx rs" version="2.0">
    <xsl:param name="links-doc"/>
    <xsl:variable name="links" select="doc($links-doc)//rs:Relationship"/>
    <!-- Replace the word hyperlinks with an anchor to make it simple.
        Probably TOO SIMPLE - I'm losing the Style.
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


    <!-- the main action. Replace a Complex Field Character structure with a fldSimple.
    -->
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
                
                 Might be better to create the variable and then pass it to the run after the 'separator'. Or else try to copy that run.
                 Copy the follwing-sibling run containing text:
                 <w:r w:rsidR="007569F4" w:rsidRPr="00D4224E">
               <w:rPr>
                   <w:rStyle w:val="Hyperlink"/>
                   <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                   <w:sz w:val="22"/>
                   <w:szCs w:val="22"/>
               </w:rPr>
               <w:t xml:space="preserve">Jo </w:t>
           </w:r>
                 -->
                <xsl:variable name="Hyperlink">
                    <xsl:value-of select="doctorx:fix-field-name(.//w:instrText)"/>
                </xsl:variable>
                <w:r>
                    <w:rPr>
                        <xsl:copy-of select="(./following-sibling::w:r[w:t])[1]/w:rPr/*[local-name(.) ne 'rStyle']"/>
                    </w:rPr>
                    <w:t>
                        <a href="{($Hyperlink)}">Replace Me</a>
                    </w:t>
                </w:r>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/> <!-- next -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="inside" select="following-sibling::*[1]"/>
            </xsl:otherwise> <!-- remove any other "inside" node -->
        </xsl:choose>
    </xsl:template>
    
    
    <!-- 
        I need to copy the w:rPr element.
        
        This...
        <w:hyperlink r:id="rId10" w:history="1">
                <w:r w:rsidR="009B62A0">
                    <w:rPr>
                        <w:rStyle w:val="Hyperlink"/>
                        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                        <w:b/>
                        <w:sz w:val="22"/>
                        <w:szCs w:val="22"/>
                        <w:lang w:val="en-AU"/>
                    </w:rPr>
                    <w:t>21st August 2014</w:t>
                </w:r>
            </w:hyperlink>
         ... is completely replaced by ...
         <a xmlns="" href="http://pekoe.io/bkfa/ad-booking/ad-date?output=aust-date">Replace Me</a>
         and consequently losing the style block.
         
         Now part of the problem is  the <rStyle @val=Hyperlink/>
         Can I just replace that bit?
         
         The original code - before conversion to a hyperlink:
         
         <w:r w:rsidR="00D93622">
                <w:rPr>
                    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                    <w:b/>
                    <w:sz w:val="22"/>
                    <w:szCs w:val="22"/>
                    <w:lang w:val="en-AU"/>
                </w:rPr>
                <w:t>21</w:t>
            </w:r>
            <w:r w:rsidR="00D93622" w:rsidRPr="00D93622">
                <w:rPr>
                    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                    <w:b/>
                    <w:sz w:val="22"/>
                    <w:szCs w:val="22"/>
                    <w:vertAlign w:val="superscript"/>
                    <w:lang w:val="en-AU"/>
                </w:rPr>
                <w:t>st</w:t>
            </w:r>
            <w:r w:rsidR="00D93622">
                <w:rPr>
                    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                    <w:b/>
                    <w:sz w:val="22"/>
                    <w:szCs w:val="22"/>
                    <w:lang w:val="en-AU"/>
                </w:rPr>
                <w:t xml:space="preserve"> August</w:t>
            </w:r>
            <w:r>
                <w:rPr>
                    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>
                    <w:b/>
                    <w:sz w:val="22"/>
                    <w:szCs w:val="22"/>
                    <w:lang w:val="en-AU"/>
                </w:rPr>
                <w:t xml:space="preserve"> 2014</w:t>
            </w:r>
            
            
    -->
    <xsl:template match="w:t" mode="hyperlink">
        <xsl:param name="full-path" tunnel="yes"/>
        <xsl:copy>
            <a href="{$full-path}">Replace Me</a>
        </xsl:copy>
    </xsl:template>
    
    <!-- Delete the hyperlink style <w:rStyle w:val="Hyperlink"/> -->
    <xsl:template match="w:rStyle[@w:val eq 'Hyperlink']" mode="hyperlink"/>
    <xsl:template match="w:hyperlink">
        <xsl:variable name="rid" select="./@r:id"/>
        <xsl:variable name="url" select="$links[@Id eq $rid]/string(@Target)"/>
        <xsl:variable name="anchor-ref" select="@w:anchor"/>
        <xsl:choose>
            <xsl:when test="starts-with($url,'http://pekoe.io')"><!-- I want to copy the first RUN - and replace the content of the w:t with an anchor -->
                <xsl:apply-templates mode="hyperlink" select="w:r[1]">
                    <xsl:with-param name="full-path" select="string-join(($url,$anchor-ref),&#34;#&#34;)" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="node() | @*" mode="hyperlink">
        <xsl:param name="full-path" tunnel="yes"/>
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="hyperlink"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- identity transform -->
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>