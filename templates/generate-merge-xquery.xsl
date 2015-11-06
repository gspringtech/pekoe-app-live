<?xml version="1.0" encoding="UTF-8"?>
<!-- (: Copyright 2012 Geordie Springfield Pty Ltd Australia :) -->
<xsl:stylesheet xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xd" version="2.0">
    
    <!-- 
            Output functions - discussion: 
            
                    Use a global namespace for Output names.
                    Don't use overrides. Run a validator to ensure that output function/@names are unique for the schema.
                    What a shame.
                    The only possible way to have non-global placeholder names is to use a map on the field .
                    So instead of member:first-and-last($job/coordinator/person) it would be
                    member:coordinator_person{"first-and-last":= function($context) {...} etc. Or something like that.
                    OH - but hang on. Here it's just a name. This is complex.
                    
                -->
    
    <!--  This file is a generator for the final part of the Merge process. Each template will have an XQuery generated using this file. 
          If the template is 
               /tenants/xxx/template/path/to/Template.docx then this file will be 
          /tenants/xxx/template-meta/path/to/Template_docx/merge.xql
          
    	  The CONTEXT of this stylesheet is the links file (generated from the Template).
    	  The result of this stylesheet is an XQuery which is provided with a Job file.
    	  
    	  The query will produce an 'intermediate' form which extracts values from the job, applies any post-processing 'output' functions
    	  and presents the results for each "link".
    	  The results may take the form of simple string values OR
    	  one or more elements. 
    	  The only reason for using elements in the output is if the field is in a table.
    	  
    	  This is a generic stylesheet as it is unaffected by the template-type or job-type.
    	  However the resulting query is very specifically tied to both those things.
    	  
    	  
    	  e.g. 
  <links for="school-booking" template-kind="docx">
    <link field-path="/school-booking/day" output-name="visit-date"/>
    <link field-path="/school-booking/school/name" output-name=""/>
    <link field-path="/school-booking/school/teacher" output-name=""/>
    <link field-path="/school-booking/school/year" output-name=""/>
    	  
    	  IMPORTANT: this generator should be as minimal as possible - all work should be done in the associated modules.
    	  Otherwise, code changes will require regenerating this for every template. 
    	  BUT what about the Schema? I guess if the schema changes then this module needs regenerating. 
    	  So that could be part of the test for freshness on this process.
    	  
    	  As the regeneration is automatic, it doesn't matter. Use this stylesheet to pull the correct (see below) output function
    	  into this generated query.
    	  
    	  2015-01-22: It's too hard to create a schema.xqm where output functions are somehow namespaced according to field/fragment/fragment-ref path.
    	   This relates to the pekoe-schema-v4 which has outpt functions for field, fragment, fragment-ref AND field[input/@type eq 'field-choice' and input/list[contains(., $current-fragment-name)]
    	   
    	  
    	  Better to identify the function desired and pull it in here.
         2015-04-18 CHANGES to the Links file:
    <link placeholder='' field-path='' original-href ><output name='' fragment=''></output>* OR <script></script>(0-1)
    With the potential for MULTIPLE OUTPUTS. (Not sure how to make that work.)
    However, the expectation is that an Output function will return a value or node. If it returns more than one node then its expected to go into a table.
    It may return a subtree in which case the @fragment will be used to identify the desired value.
    
    And the output of that process will be passed to the next output. Hmm.
     -->
    <xsl:output method="xml" cdata-section-elements="" omit-xml-declaration="yes"/>
    <xsl:param name="path-to-schema-col" required="yes"/> <!-- e.g /db/pekoe/files/education/schemas/school-booking.xml -->
    <xsl:param name="template-file" required="yes"/>  <!-- e.g /db/pekoe/templates/Education/Concession-ticket-2a.docx-->
    <xsl:param name="tenant" required="yes"/>
    <xsl:param name="template-meta-path" required="yes"/>
    <xsl:variable name="schema-type" select="/links/string(@for)"/> <!-- e.g. "schools", "school-booking", "properties", "schema" -->
    <xsl:variable name="doctype" select="/links/string(@template-type)"/> <!--  "docx", "html" or "txt" -->
    <xsl:variable name="doctype-module" select="concat('merge-',$doctype)"/> <!-- pekoe-docx - to distinguish it from other things.-->
    <xsl:template match="/">
(: 
   This is a Pekoe Merge XQuery for the Template <xsl:value-of select="$template-file"/>
   GENERATED: <xsl:value-of select="format-dateTime(current-dateTime(),'[D]/[M]/[Y] - [h].[m01] [P]')"/>
   
   This XQuery is GENERATED by Pekoe using /pekoe/templates/generate-merge-xquery.xsl from the links file (in template-meta) for each Template.
   The Merge has three parts:
    - get the Field Values using the Field Paths and process using the Output functions (from the schema) using local:collect-values()
    - replace the Field markers in the Template with the appropriate Field Values. (using the appropriate "merge()" according to $doctype)
    - emit the result in appropriate form (might be zipped into a docx or delivered as HTML into a new Tab).
   
       pekoe-docx:doc-transform($input as node(), $links) 
   to produce the final output. This is where the merge happens.

 :)
xquery version "3.0";     

import module namespace pekoe="http://www.gspring.com.au/pekoe/output-functions" at "xmldb:exist:///db/apps/pekoe/templates/common-output-functions.xqm";
<!-- The Schema module containing the output functions -->
        <!-- will need to change the namespace to make it tenant-specific -->
import module namespace <xsl:value-of select="$schema-type"/>="http://www.gspring.com.au/schema-module/<xsl:value-of select="$schema-type"/>" 
        at "xmldb:exist://<xsl:value-of select="$path-to-schema-col"/>/<xsl:value-of select="$schema-type"/>.xqm";
<!-- the doctype module -->
import module namespace <xsl:value-of select="$doctype-module"/>="http://www.gspring.com.au/pekoe/merge/<xsl:value-of select="$doctype"/>" 
        at "xmldb:exist:///db/apps/pekoe/templates/<xsl:value-of select="$doctype-module"/>.xqm";
<!-- the site-specific module - per tenant -->
import module namespace site="http://gspring.com.au/pekoe/site-tools" 
        at "/db/pekoe/tenants/<xsl:value-of select="$tenant"/>/config/site-tools.xqm";
        
        
    
declare copy-namespaces preserve, inherit; 
    
<!-- This is the important part. When this query is run, collect-values will generate a structure that matches the original <links> file - except
    that each link will contain its RESULT - a value or node or sequence of nodes. It could be replaced by a map I suppose. 
    Finally, below, the Main Query will merge the LINKS with the original Template to produce the desired output.
    -->
    (: Links data generator for the <xsl:value-of select="$schema-type"/> schema :)
declare function local:collect-values($job) { 
    <xsl:apply-templates/>
};
    
(: MAIN QUERY :)
    
    let $job-file := request:get-parameter("realpath", "")  
    let $job := doc($job-file) <!-- would be useful to put some error checking here -->
    let $intermediate := local:collect-values($job) <!-- this function is created below... -->
    (: let $debug := xmldb:store("/db/temp","intermediate.xml", $intermediate) :)
    let $merged-content := <xsl:value-of select="$doctype-module"/>:merge($intermediate, "<xsl:value-of select="$template-meta-path"/>", xs:anyURI("<xsl:value-of select="$template-file"/>")) <!-- e.g. docx:merge() -->
    (: your site file must determine how to proceed - perhaps based on some parameter. :)
    return site:delivery($job, "<xsl:value-of select="$template-file"/>", $merged-content)
        
<!--    return <xsl:value-of select="$doctype-module" />:merge($intermediate, "<xsl:value-of select="replace($template-file, '/db/pekoe/templates(.*)\.docx$','/db/pekoe/config/template-content$1.xml')"  />", $job-id)     -->
    <!-- See discussion in Chasewater about OUTPUT SCENARIOS -->
    </xsl:template>
    
    <!--  GENERATE this:
        <link ph-name="School-address" field-path="/school-booking/school" output-name="address-on-one-line">
            { let $context := $job/school-booking/school
              return school-booking:address-on-one-line($context)    
            }
        </link> 
        OR 
        <link ph-name="Inv-num" field-path="/school-booking/invoice/number" output-name="">
            { $job/school-booking/invoice/number/string(.) }
        </link>
                NEW
        <link placeholder='just a placeholder' field-path='/specific/field/path[possibly-with-predicate]' > ALONE OR WITH ...
            <output name='' fragment='sub-tree/path/to/field ' /> OR
            <output name='address-on-one-line' /> OR
            <output name='last-receipt' fragment='amount' /> OR
            <xquery>current-date()</xquery> OR 
            <xquery>$job/@modified-by/string()</xquery> Or
            ? Treat as error or simply join with / ?
            <output name='' fragment='cheese'/>
            <output name='' fragment='cake'/>
            These will produce 
declare function local:collect-values($job) { 
    let $context := $job/specific/field/path[possibly-with-predicate]
    return $context
};

declare function local:collect-values($job) { 
    let $context := $job/specific/field/path[possibly-with-predicate]
    return $context/sub-tree/path/to/field
};

declare function local:collect-values($job) { 
    let $context := $job/specific/field/path[possibly-with-predicate]
    return lease:address-on-one-line($context)
};        

declare function local:collect-values($job) { 
    let $context := $job/specific/field/path[possibly-with-predicate]
    return lease:last-receipt($context)/amount
};      

declare function local:collect-values($job) { 
    current-date()
};  

declare function local:collect-values($job) { 
    $job/@modified-by/string()
}; 

And Finally, chained outputs?
        <link placeholder='just a placeholder' field-path='/specific/field/path[possibly-with-predicate]' > ALONE OR WITH ...
            <output name='last-receipt' fragment='amount' /> AND
            <output name='currency' />

declare function local:collect-values($job) { 
    let $context := $job/specific/field/path[possibly-with-predicate]
    let $output1 := lease:last-receipt($context)/amount
    return lease:currency($output1) 
};              
    
    NOTE: only ONE XQUERY but multiple OUTPUTs
    -->
    <xsl:template match="links">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="template-path" select="$template-file"/>
            <xsl:attribute name="run-date">{current-dateTime()}</xsl:attribute>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    
    <!-- Create a copy of the LINK, with the appropriate script to generate the output - e.g. 
            {                    
            let $var0 := $job/residential/purchaser/person
            let $var1 := residential:full-name($var0)
            return $var1
            }
    -->
    <xsl:template match="link">
        <xsl:variable name="output-functions" select="count(./output)"/>
        <xsl:variable name="lastOutput" select="concat('$var',$output-functions)"/>
        <link>
            <xsl:apply-templates select="@original-href"/>
            <xsl:apply-templates select="@placeholder"/>
        {<xsl:choose>
                <xsl:when test="empty(./xquery) and $output-functions eq 0"> <!-- this is a value result.  -->
            $job<xsl:value-of select="@field-path"/>
                </xsl:when>
            <!-- 
                I would like to use the xquery AND outputs in a chain. The problem is that outputs are functions (in the schema-module)
                while the xquery expects to operate on the $path.
                
                Sequential outputs look like this in the merge query:
                    {                    
                        let $var0 := $job/residential/property/vendor/person  - this is the $path
                        let $var1 := residential:full-name($var0)               - then automatically generated variable names.
                        let $var2 := residential:and-join($var1)
                        return $var2
                    }
                    
                    Currently, XQUERY simply overrides any Outputs.
                    
            -->
                <xsl:when test="./xquery">
            (: XQUERY :)
            let $path := $job<xsl:value-of select="@field-path"/>
            return <xsl:value-of select="./xquery"/>
                </xsl:when>
                <xsl:otherwise><!-- 
                    Use a global namespace for Output names.
                    Don't use overrides. Run a validator to ensure that output function/@names are unique for the schema.
                    What a shame.                    
                -->                    
            let $var0 := $job<xsl:value-of select="@field-path"/>
                    <xsl:for-each select="output">
                        <xsl:variable name="previousOutput" select="concat('$var',position() - 1)"/>
                        <xsl:variable name="nextOutput" select="concat('$var', position() )"/>
                        <xsl:variable name="fragment-part" select="if (./@fragment ne '') then concat('/',./@fragment) else ()"/>
                        <xsl:choose>
                            <xsl:when test="./@name ne ''">
                                <xsl:variable name="op-prefix" select="if (starts-with(./@name,'pekoe:')) then '' else concat($schema-type,':')"/>
            let <xsl:value-of select="$nextOutput"/> := <xsl:value-of select="$op-prefix"/>
                                <xsl:value-of select="./@name"/>(<xsl:value-of select="$previousOutput"/>)<xsl:value-of select="$fragment-part"/>
                            </xsl:when>
                            <xsl:otherwise>
            let <xsl:value-of select="$nextOutput"/> := <xsl:value-of select="$previousOutput"/>
                                <xsl:value-of select="$fragment-part"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
            return <xsl:value-of select="$lastOutput"/>
<!-- return $output2 -->
                </xsl:otherwise>
            </xsl:choose>
            }
        </link>
    </xsl:template>
    <xsl:template match="output-or-xquery"/>
    <xsl:template match="command"/>

    
    <!-- OLD VERSION -->
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>