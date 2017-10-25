(:
    Uses py3o.fusion in a docker-compose instance.
    Installed on DPC in /home/admeen/docker/py3o
    run with
    docker-compose up -d
    (-d for daemon - but leave off to see console messages)
    
    See also aliMac Development/docker/py3o/
    
    DOESN'T work for WORD - but LibreOffice CAN convert DOCX to PDF.
    CONSIDER replacing this with my original approch - a Clojure server 
    
    It's my intention to make this available via the Letter-opener "close" page, and/or a Site Command
    
    User can Edit the original (Save and Edit - as they currently do)
    then "Convert to PDF"
    
    Somehow this will need to be moved to S3.
    
:)
import module namespace http = "http://expath.org/ns/http-client";
(:  curl -F "targetformat=pdf" -F "image_mapping={}" -F "tmpl_file=@tests/test1.odt" http://localhost:8765/form
   :)
   
let $f := "/db/pekoe/tenants/cm/files/test-jobs/Residential-Cover-abc-123.odt"
   return 
if (util:binary-doc-available($f)) then

   let $doc-name := util:document-name($f)
   let $col := util:collection-name($f)
   let $renamed := substring-before($doc-name,".") || ".pdf"
   let $content := util:binary-doc($f)
   let $mime := xmldb:get-mime-type($f)
    let $request := 
        <http:request
            method="POST" 
            href="http://localhost:8765/form" http-version="1.0">
            <http:multipart media-type="multipart/form-data" boundary='-------xyzBouNDarYxyz'>
                <http:header name="Content-Disposition" value='form-data; name="targetformat"'/>
                <http:body media-type="text/plain">pdf</http:body>
                <http:header name="Content-Disposition" value='form-data; name="image_mapping"'/>
                <http:body media-type="text/plain">{{}}</http:body>
                <http:header name="Content-Disposition" value='form-data; name="tmpl_file"; filename="{$doc-name}"'/>
                <http:header name="Content-Type" value="application/octet-stream" />
                <http:body method="binary" media-type="binary">{$content}</http:body>
            </http:multipart>
        </http:request>
    
        let $res := http:send-request($request) 
        return 
            if ($res[1]/@status ne '400') then 
                let $pdf := $res[2]
                return xmldb:store($col, $renamed, $pdf)
            else $res[1]
else ("no doc")