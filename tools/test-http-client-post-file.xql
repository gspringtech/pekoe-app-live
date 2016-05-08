xquery version "3.0";


let $full-path := '/db/pekoe/tenants/cm/files/jobs/2016/01/RT-000072/Residential-Cover-20160111.odt'
let $content := util:binary-doc($full-path)

let $urlencoded :=
      <http:request method="post" http-version="1.0">
         <http:body media-type="application/x-www-form-urlencoded">a=3&amp;b=4</http:body>
      </http:request>
      
let $formdata :=
      <http:request method="post" http-version="1.0">
         <http:multipart media-type="multipart/form-data" boundary="xyzBouNDarYxyz">
            <http:header name="Content-Disposition" value='form-data; name=path'/>
            <http:body media-type="text/plain">{$full-path}</http:body>
            <http:header name="Content-Disposition"
           value="form-data; name=doc; filename=rcover.odt"/>
        <http:body media-type="binary">
        {$content}
        </http:body>
         </http:multipart>
      </http:request>
let $request :=
      (: choose the one you want to test :)
      if ( false() ) then $urlencoded else $formdata
return
  http:send-request($request, "http://info.gspring.com.au")