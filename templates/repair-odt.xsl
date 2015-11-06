<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" exclude-result-prefixes="xs" version="2.0">
    <xsl:output indent="no"/>
    <xsl:strip-space elements="*"/>
    <!-- 
        Fix problems with ODT templates.
        1/ table-cell with value-type ne string
        2/ multiple adjacent identical links.
        
        The first happens when OO decides that a cell-value is not a simple string and converts it to a date, time, boolean, or float. This is a PITA
        because of the structure:
        <table:table-cell table:style-name="Table1.B2" office:value-type="float"
                        office:value="2008">
            <text:p text:style-name="Table_20_Contents">
                <text:a xlink:type="simple"
                    xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/year"
                    text:style-name="Internet_20_link"
                    text:visited-style-name="Visited_20_Internet_20_Link">2008</text:a>
            </text:p>
        </table:table-cell>
       I would have to carefuly replicate all this stuff after testing that the content is indeed a pekoe-field.
       
       I think it would be easier to replace the table-cell value-type with a string and remove the float-value (or date-value or whatever)
       
       
       The second problem happens when OO converts a date to long form inside a hyperlink. Because the ordinal indicator is superscripted, its text is special - 
       causing OO to break the link into 3 separate links.
       <table:table-cell table:style-name="Table1.A2" office:value-type="string">
            <text:p text:style-name="Table_20_Contents">
                <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/paid-date" text:style-name="Internet_20_link" text:visited-style-name="Visited_20_Internet_20_Link">22</text:a>
                <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/paid-date" text:style-name="Internet_20_link" text:visited-style-name="Visited_20_Internet_20_Link">
                    <text:span text:style-name="T1">nd</text:span>
                </text:a>
                <text:a xlink:type="simple" xlink:href="http://pekoe.io/bkfa/member/membership?output=history#/paid-date" text:style-name="Internet_20_link" text:visited-style-name="Visited_20_Internet_20_Link"> January 2015</text:a>
            </text:p>
        </table:table-cell>
        
        Okay - the second one can be overcome by using a different date format, or putting the date into the hyperlink dialog, 
        but the first one will still happen.
        
        Here's the current EXAMPLE:
        <text:p text:style-name="Standard"><text:span text:style-name="T1">Purpose:</text:span><text:a xlink:type="simple"
            xlink:href="http://pekoe.io/cm/land-division/property/applicant/client?context=receipt[last()]#purpose"
                ><text:span text:style-name="T1"
            >applicant-receipt-purpose</text:span></text:a><text:a xlink:type="simple"
            xlink:href="http://pekoe.io/cm/land-division/property/applicant/client?context=receipt[last()]#purpose"
                ><text:span text:style-name="T2"> </text:span></text:a></text:p>
                
    AND the surprisingly simple solution... check the preceding sibling. If it has the same href, then don't output anything.                
    -->
    <xsl:template match="text:a[starts-with(./@xlink:href,'http://pekoe.io/') and (preceding-sibling::text:a)[1]/@xlink:href eq ./@xlink:href]"/>
    <xsl:template match="table:table-cell[@office:value-type ne 'string' and exists(.//text:a[starts-with(@xlink:href,'http://pekoe.io')])]">
        <table:table-cell office:value-type="string">
            <xsl:copy-of select="@table:style-name"/>
            <xsl:apply-templates/>
        </table:table-cell>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>