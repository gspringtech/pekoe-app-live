xquery version "3.0";
(: REMEMBER TO SET PERMISSIONS ON THIS FILE :)

import module namespace pekoe-http = "http://pekoe.io/http" at "modules/http.xqm";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(: If you get here and there's no subdomain that's an error:)
declare variable $local:selected-tenant := req:header("tenant");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:selected-tenant ;



declare  
%rest:GET
%rest:path("/pekoe/browse")
%rest:query-param("collection","{$colpath}", "/files")
%output:media-type("text/html")
%output:method("html5")
function local:browse($colpath) {
<html><head>
<meta charset="UTF-8"/>
<title>Pekoe List</title>
</head>
<body>
<div>Tenant: {$local:selected-tenant}. Path: {$local:tenant-path}{$colpath}</div>
<h1>{$colpath}</h1>


</body>
</html>

};

()