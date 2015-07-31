xquery version "3.0";

let $ss := <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    
   <xsl:template match="/">
       <xsl:apply-templates />
   </xsl:template> 
   
   <xsl:template match="node() | @*">
       <xsl:copy>
           <xsl:apply-templates select="node() | @*"/>
       </xsl:copy>
   </xsl:template>
    
   <xsl:template match="default-value">
       <defaultValue><xsl:apply-templates /></defaultValue>
   </xsl:template>
    
</xsl:stylesheet>

for $d in collection('/db/pekoe')/schema[.//default-value]

let $t := transform:transform($d, $ss, ())
let $uri := string(base-uri($d))
let $col := util:collection-name($uri)
let $doc := util:document-name($uri)
return xmldb:store($col,$doc,$t)