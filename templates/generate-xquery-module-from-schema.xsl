<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xd" version="2.0">
    <xsl:output indent="no" media-type="application/xquery" method="text"/>
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 30, 2011</xd:p>
            <xd:b>Modified: Jan 21, 2015</xd:b>
            <xd:p>
                <xd:b>Author:</xd:b> Alister Pillow</xd:p>
            <xd:p/>
            <xd:p>
                <xd:b>Description:</xd:b> Generate XQuery functions from the named OUTPUT elements in
                the schema. These functions will be imported by the Template-Query when
                Merging. </xd:p>
            <xd:p>
               OUTPUT FUNCTIONS are UNIQUELY NAMED. These are not METHODS. There is no possibility of
                overriding a function at the top-level of the schema with one on a field.                
            </xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:variable name="schema-root" select="string(/schema/@for)"/><!-- functions are in the namespace of the schema-root -->
    <xsl:template match="/schema">xquery version "3.0";
module namespace ps="http://www.gspring.com.au/schema-module/<xsl:value-of select="$schema-root"/>";
import module namespace pekoe="http://www.gspring.com.au/pekoe/output-functions" at "xmldb:exist://db/apps/pekoe/templates/common-output-functions.xqm";
import module namespace site="http://gspring.com.au/pekoe/site-tools" at "../config/site-tools.xqm";
<xsl:apply-templates/>
    </xsl:template>
    
    <!--
        A TABLE needs to have a wrapper (created by  the template-stylesheet-generator) 
        Pass a param with the index-position number - or just run in a for-loop and make sure the CONTEXT is correct
        for-each??
        
        2012-01-26: MAYBE a table should have all its content generated through one function. 
        So instead of depending on an array for each element, we generate a structure for the whole table out of one Output function:
        <table>
        <fees><actual>23</actual><total>466</total></fees> 
        <fees><actual>22</actual><total>423</total></fees> 
        </table>
        
        But this is going to be hard to make and explain.
                
        FIELD-CHOICE (OR choice ELEMENT):
        Given something like
        <choice path='/member/company-or-person'>
            <fragment-ref path='/member/company'...
            <fragment-ref path='/member/person'...
            <output name='title-for-mailing'
            
                ... Need to pass /member/(company|person) to the GENERATED Output function
        declare function ps:title-for-mailing($path) 
        OR In the merge function generator
        let $context := ...
        ps:title-for-mailing($context)
        -->
    <xsl:template match="output[@name and xpath/text()]">
declare function ps:<xsl:value-of select="string(@name)"/> ($path) {
        <xsl:copy-of select="./xpath/(* | text())"/> 
};
    </xsl:template>
    
<!--    <xsl:template match="output[ancestor::fragment]">
         
    </xsl:template>-->
    <xsl:template match="node()">
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>