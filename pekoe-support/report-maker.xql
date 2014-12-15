declare variable $local:this-script := request:get-effective-uri();
declare variable $local:action := request:get-parameter("action","");
declare variable $local:collection :=  util:collection-name( request:get-servlet-path());
declare variable $local:job-file := request:get-parameter("job","");
declare variable $local:job := doc($local:job-file);



declare variable $local:from-date := adjust-date-to-timezone(xs:date("2012-09-01"),());
declare variable $local:to-date := adjust-date-to-timezone(xs:date("2012-09-30"),());

declare function local:frame() {
    util:declare-option("exist:serialize" ,"method=xhtml media-type=application/xhtml+html"),
    response:set-header("Cache-Control","max-age=3600"),
    <iframe  seamless="seamless" src='{$local:this-script}?action=get-params&amp;job={$local:job-file}' style='border:none; width:100%; height:100%;'>
    </iframe>
};

declare function local:make-report() {
    let $report := doc($local:job-file)
    let $query-name := concat(substring-before(util:document-name($local:job-file),".xml"),".xql")
    let $stored := xmldb:store(util:collection-name($report), $query-name,$report//xquery/string(.), "application/xquery")
    return $stored

};

declare function local:create-form() {
util:declare-option("exist:serialize", "method=xhtml media-type=text/html doctype-system=html"),
<html><head><title>Form</title>
 <link href="/exist/pekoe/lib/jquery/jquery-ui-1.8.12.custom/css/custom-theme/jquery-ui-1.8.12.custom.css" rel="stylesheet" type="text/css" />
            <link href="/exist/pekoe/lib/jquery/css/custom-theme/jquery-ui-1.8.14.custom.css" rel="stylesheet" type="text/css" />
            <script type="text/javascript" src="/exist/pekoe/lib/jquery/jquery-ui-1.8.12.custom/js/jquery-1.5.1.min.js"></script>
            
            <script type="text/javascript" src="/exist/pekoe/lib/jquery/jquery-ui-1.8.12.custom/js/jquery-ui-1.8.12.custom.min.js"></script>
            <script type='text/javascript' > // <![CDATA[
                $(function () {
                $('.date').datepicker({"dateFormat":"yy-mm-dd"});
                });
            // ]]>
            </script>
            </head><body>
<h1>{$local:job/report/string(name)}</h1>
<form method='get' action='/exist/pekoe/report'>
<input type='hidden' name='job' value='{$local:job-file}' />
<input type='hidden' name='title' value='{$local:job//title/string(.)}' />
{
    for $input in $local:job//input
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

if ($local:action eq "get-params") then local:create-form()
else local:frame()