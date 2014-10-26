xquery version "3.0" encoding "UTF-8";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";


declare  
%rest:GET
%rest:path("/pekoe/welcome")
%output:media-type("text/html")
%output:method("html5")

function local:welcome() {
<html><head>
<meta charset="UTF-8"/>
<title>Welcome to Pekoe</title>
</head>
<body>
<h1>Welcome to Pekoe</h1>
Hi {xmldb:get-current-user()}, you must be new here.
<form method="GET" >
<input type='text' name='test' />
</form>
</body>
</html>

};

()