xquery version "3.1";
declare variable $local:tenant := request:get-header("tenant");
declare variable $local:tenant-path := "/db/pekoe/tenants/" || $local:tenant;

declare variable $local:this-script := request:get-effective-uri();
declare variable $local:action := request:get-parameter("action","");
declare variable $local:collection :=  util:collection-name( request:get-servlet-path());
declare variable $local:safe-path := request:get-parameter("report","");
declare variable $local:report-file := $local:tenant-path || substring-after($local:safe-path,'/pekoe-files');
declare variable $local:report := doc($local:report-file);



declare variable $local:from-date := adjust-date-to-timezone(xs:date("2012-09-01"),());
declare variable $local:to-date := adjust-date-to-timezone(xs:date("2012-09-30"),());


declare function local:make-report() {
    let $report := doc($local:report-file)
    let $query-name := concat(substring-before(util:document-name($local:report-file),".xml"),".xql")
    let $stored := xmldb:store(util:collection-name($report), $query-name,$report//xquery/string(.), "application/xquery")
    return $stored

};

declare function local:create-form() {
util:declare-option("exist:serialize", "method=xhtml media-type=text/html doctype-system=html"),
<html>
  <head>
    <title>Form</title>
    <script type="text/javascript" src="/pekoe-common/jquery/dist/jquery.js"></script>
    <link rel="stylesheet" href="/pekoe-common/jquery-ui-1.11.0/jquery-ui.css" />
    <link rel="stylesheet" href="/pekoe-common/dist/css/bootstrap.css" />
    <link rel="stylesheet" href="/pekoe-common/list/list-items.css" />
    <link rel="stylesheet" href="/pekoe-common/dist/font-awesome/css/font-awesome.min.css" />
    <script type="text/javascript" src="/pekoe-common/jquery-ui-1.11.0/jquery-ui.js"></script>
    <script type="text/javascript" src="/pekoe-common/dist/js/bootstrap.min.js"></script>
    <script type='text/javascript' > // <![CDATA[
        $(function () {
        $('.date').datepicker({"dateFormat":"yy-mm-dd"});
        });
    // ]]>
    </script>
  </head>
  <body>
<h1>{$local:report/report/string(name)}</h1>
<p>{$local:report-file}</p>
<form method='get' action='/exist/pekoe-files/report'>
<input type='hidden' name='report' value='{$local:safe-path}' />
<input type='hidden' name='title' value='{$local:report//title/string(.)}' />
{
    for $input in $local:report//input
    let $name := $input/string(name)
    let $input-type := $input/string(type)
    return <div>{$name} <input class='{$input-type}' type='text' name='{$name}' /></div>
}
<input type='submit' name='action' value='Submit' />
</form>
</body>
</html>
};

(:  general pattern for these reports is to create an iframe, then load a FORM. The user submits required params and the
    report is generated - within the iframe. The advantage of this is that the associated HTML and CSS can be 
    as complex as desired, without interfering with Pekoe.
    
    :)

local:create-form()
